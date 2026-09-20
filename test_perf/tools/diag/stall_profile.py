#!/usr/bin/env python3
"""把 app 的**拍数**按 PC / 符号归因 —— 用来把"残差"拆到部件（**实测**，不估算）。

为什么需要它（#1 残差归因）：
  每版的表里 残差 = 整 app − Σ阶段（如 ver1_1/keygen 8,441 拍 = 6.11%）。它一直被**口头**
  解释成"wrapper 清零循环 + 框架胶水"，但：
    · 指令级拆分已有（残差直方图：ver1_1/keygen 清零循环 ≈5,922 条、框架容器 157 条、其余 317 条），
    · **拍级**一直没有 ⇒ 因为 harness 的 `stalls` 是**一个标量**，不知道 2,045 个停滞拍属于谁。
  本工具补上这一块：用 ISS 自己的记账（`stats.get_insn_count()` / `stats.stall_count` 的**每步增量**）
  一步一拍地把"退役 / 停滞"记到**当前 PC** 上，再按符号边界归因 ⇒ 每部件"拍数"是实测值。

    口径依据（`hw/ip/otbn/dv/otbnsim/sim/sim.py`）：`_on_stall()` 里 `stats.record_stall()`
    记的就是**当前 PC**（跳转/分支的 `has_fetch_stall` 注入的那一拍也走这里）⇒ 逐步增量可精确
    归因；`_on_retire()` 里 `record_insn()` 记的是刚退役的指令。

口径（与 harness 完全一致）：
  · 种子直接取 ISS 自己的 `_TEST_RND_DATA` / `_TEST_URND_SEED`（保证与测量同一条代码路径）；
  · 单步循环逐字镜像 `StandaloneSim.run()`（跳过初始 wipe、wfi 立即返回、RND/URND 即时应答、
    FSM 进 IDLE/LOCKED 即停）——⚠ 因此本工具**必须**是进程里第一个碰 ISS 的角色，
    别在同进程先跑 `H.run_elf()`（那个模块级 `cycle` 会被消费掉，种子序列就变了）；
  · **自证**：本循环的 Σ退役/Σ停滞 必须等于 **JSON 里那次实测**的 insn/stalls（绑到表里的数）；
    不等也照样写日志（方便贴回诊断），但退出码为 1、报告里标 ⚠。

用法:
  python3 test_perf/tools/diag/stall_profile.py --version ver1_1 --op keygen \
      --target //test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768:mlkem768_keypair \
      --out logs_hkem/ver1_1_profiling/stall_profile.log
"""
import argparse
import bisect
import json
import sys
import traceback
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]   # 工具在 test_perf/tools/<类>/ 下 ⇒ 仓库根 = parents[3]
sys.path.insert(0, str(REPO / "hw/ip/otbn/dv/otbnsim"))
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))   # harness.py 在 test_perf/ 顶层

from sim.load_elf import load_elf                                   # noqa: E402
from sim.standalonesim import (StandaloneSim, _TEST_RND_DATA,       # noqa: E402
                               _TEST_URND_SEED)
from sim.state import FsmState                                      # noqa: E402
import harness as H                                                 # noqa: E402

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

CONTAINER = ("crypto_kem_", "indcpa_", "_indcpa_", "_encrypt_core", "_decrypt_core")   # 注意带下划线的内层标签
MAX_CYCLES = 2_000_000


def name_at(pc: int, starts, bnds) -> str:
    i = bisect.bisect_right(starts, pc) - 1
    if i < 0:
        return "(无符号区间)"
    s, e, n = bnds[i]
    return n if s <= pc < e else "(无符号区间)"


def step_profile(elf: str, max_cycles: int = MAX_CYCLES, quiet: bool = False):
    """→ (每PC[退役,停滞], 总退役, 总停滞)。逐字镜像 StandaloneSim.run()。"""
    sim = StandaloneSim()
    load_elf(sim, elf)
    sim.state.ext_regs.commit()
    sim.start(collect_stats=True)
    # 逐字镜像 StandaloneSim.run()（见文件头）
    sim.state.complete_init_sec_wipe()
    sim.state.wfi_enabled = True
    sim.state.wfi_auto_resume = True

    urnd_n = 0
    per = {}
    n_insn = n_stall = 0
    for c in range(1, max_cycles + 1):
        if sim.state.ext_regs.read("RND_REQ", True):
            sim.state.wsrs.RND.set_unsigned(next(_TEST_RND_DATA), False, False)
        if sim.state.wsrs.URND.requesting:
            sim.state.wsrs.URND.set_seed(_TEST_URND_SEED[urnd_n])
            urnd_n = (urnd_n + 1) % len(_TEST_URND_SEED)
            if urnd_n == 0:
                sim.state.wsrs.URND.reseed_done = True

        pc = sim.state.pc
        i0, s0 = sim.stats.get_insn_count(), sim.stats.stall_count
        sim.step(False)
        di = sim.stats.get_insn_count() - i0
        ds = sim.stats.stall_count - s0
        if di or ds:
            e = per.setdefault(pc, [0, 0])
            e[0] += di
            e[1] += ds
            n_insn += di
            n_stall += ds
        if not quiet and c % 50_000 == 0:
            print(f"    … {c:,} 拍：insn {n_insn:,} stalls {n_stall:,} pc={sim.state.pc:#x} "
                  f"fsm={sim.state.get_fsm_state()}", flush=True)
        if sim.state.get_fsm_state() in (FsmState.IDLE, FsmState.LOCKED):
            break
    else:
        raise RuntimeError(f"跑满 {max_cycles:,} 拍仍未进 IDLE/LOCKED（最后 pc="
                           f"{sim.state.pc:#x}，err_bits={sim.state._err_bits:#x}）")
    return per, n_insn, n_stall


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", required=True)
    ap.add_argument("--version", help="用于读 JSON 算残差/自证（建议给）")
    ap.add_argument("--op", default="keygen")
    ap.add_argument("--out", help="报告写到该文件（同时打到 stdout）")
    ap.add_argument("--top", type=int, default=12)
    ap.add_argument("--max-cycles", type=int, default=MAX_CYCLES)
    args = ap.parse_args()

    import hashlib
    _self_md5 = hashlib.md5(Path(__file__).read_bytes()).hexdigest()
    L = [f"# 拍级归因（{args.version or '?'}/{args.op}）  target={args.target}",
         f"# 工具 " + str(Path(__file__).resolve().relative_to(REPO)) + " md5=" + _self_md5, ""]
    ok = None
    fatal = None
    try:
        print(f"[1/4] 构建 {args.target} …", flush=True)
        H.bazel_build([args.target])
        elf = H.bazel_elf(args.target)
        print(f"[2/4] ELF = {elf}", flush=True)
        bounds = H.load_text_boundaries(elf)
        starts = [b[0] for b in sorted(bounds)]
        bnds = sorted(bounds)

        # 基准：**JSON 里记录的那次测量**（不是本进程再跑一次）
        #   ⚠ 别改成 H.run_elf：`_TEST_RND_DATA` 是**模块级有状态的 cycle**，先跑一遍会把
        #   它消费掉 ⇒ 本循环拿到的 RND 序列与测量时不同（2026-09-20 踩过）。
        ref_insn = ref_stalls = ref_cycles = None
        if args.version:
            p = REPO / "logs_hkem" / f"{args.version}_profiling" / f"re_{args.version}.json"
            if p.exists():
                a = json.loads(p.read_text(encoding="utf-8"))["apps"][args.version][args.op]
                ref_insn, ref_stalls, ref_cycles = a["insn"], a["stalls"], a["cycles"]

        print(f"[3/4] 单步跑 ISS（上限 {args.max_cycles:,} 拍，每 5 万拍报进度）…", flush=True)
        per, my_insn, my_stall = step_profile(elf, args.max_cycles)
        print("[4/4] 归因 …", flush=True)

        if ref_insn is None:
            L.append(f"本循环：insn {my_insn:,} + stalls {my_stall:,} = {my_insn + my_stall:,} 拍")
            L.append("自证：**跳过**（没给 --version 或没有对应 JSON ⇒ 无实测基准）")
        else:
            L.append(f"基准（JSON 实测）：insn {ref_insn:,} + stalls {ref_stalls:,} = {ref_cycles:,} 拍")
            L.append(f"本循环：            insn {my_insn:,} + stalls {my_stall:,} = {my_insn + my_stall:,} 拍")
            ok = (my_insn == ref_insn and my_stall == ref_stalls)
            L.append(f"自证：一致 → {'✓（拍级归因可用）' if ok else '✗ 不等，**下面的表不可用**'}"
                     + ("" if ok else f"；Δinsn={my_insn - ref_insn:+,} Δstalls={my_stall - ref_stalls:+,}"))
            if not ok:
                L.append("")
                L.append("> ⚠ 自证未过：说明本循环与测量那次不同源（种子/停止条件/数据）。"
                         "请把本报告整段贴回，先对齐口径再谈归因。")
        L.append("")

        # ③ 按符号汇总
        agg = {}
        for pc, (di, ds) in per.items():
            n = name_at(pc, starts, bnds)
            e = agg.setdefault(n, [0, 0, [pc, 0]])
            e[0] += di
            e[1] += ds
            if di + ds > e[2][1]:
                e[2] = [pc, di + ds]
        tot = my_insn + my_stall
        L.append("## 每符号拍数（退役 + 停滞），按拍数降序")
        L.append("")
        L.append("| 符号 | 退役 | 停滞 | 拍 | 占 app | 热点 PC |")
        L.append("|---|---:|---:|---:|---:|---:|")
        for n, (di, ds, hot) in sorted(agg.items(), key=lambda kv: -(kv[1][0] + kv[1][1])):
            L.append(f"| `{n}` | {di:,} | {ds:,} | {di + ds:,} | "
                     f"{100 * (di + ds) / max(tot, 1):.2f}% | {hot[0]:#x} |")
        L.append("")

        # ④ 热点 PC（识别**无符号**的匿名区，例如 wrapper 清零循环）
        L.append(f"## 热点 PC（Top {args.top}）—— 匿名区会在这里露出 sw/addi/bne 三连")
        L.append("")
        L.append("| PC | 符号 | 退役 | 停滞 | 拍 |")
        L.append("|---|---|---:|---:|---:|")
        for pc, (di, ds) in sorted(per.items(), key=lambda kv: -(kv[1][0] + kv[1][1]))[:args.top]:
            L.append(f"| `{pc:#x}` | `{name_at(pc, starts, bnds)}` | {di:,} | {ds:,} | {di + ds:,} |")
        L.append("")

        # ⑤ 残差拆分（整 app − Σ阶段，按 **PC** 摊到部件）
        if ref_cycles is not None:
            d = json.loads((REPO / "logs_hkem" / f"{args.version}_profiling"
                            / f"re_{args.version}.json").read_text(encoding="utf-8"))
            rows = [r for r in d["rows"] if r["phase"].startswith(args.op + "_") and r["closure"]]
            # ⚠ 只对**两类**做 PC 级精确归因，其余用减法（不做任何名称推断）：
            #   · `load_text_boundaries` 给的是**分区**（每个地址只属于"最近的前一个符号"）⇒
            #     内核内部标签（`_sample_ntt_loop`、`_ntt_layers_loop` …）自成区间，**不在**
            #     父函数区间内 ⇒ 任何"按区间判是否被 Σ 行覆盖"的做法都会把它们误判成残差
            #     （2026-09-20 第一版就是这个瑕疵：ver1_1/keygen 胶水被算成 54,749）。
            #   · 所以：匿名区（无符号）与框架容器各按 PC 实测，"其它" = 残差 − 这两项。
            comp = {"匿名区（无符号，如 wrapper 清零循环）": 0,
                    "框架容器（crypto_kem_*/indcpa_* 及其内层标签）": 0}
            for pc, (di, ds) in per.items():
                nm = name_at(pc, starts, bnds)
                if nm == "(无符号区间)":
                    comp["匿名区（无符号，如 wrapper 清零循环）"] += di + ds
                elif any(nm.startswith(pfx) for pfx in CONTAINER):
                    comp["框架容器（crypto_kem_*/indcpa_* 及其内层标签）"] += di + ds
            sigma = sum(r["cycles"] for r in rows)
            res = ref_cycles - sigma
            rest = res - sum(comp.values())
            L.append("## 残差拆分（整 app − Σ阶段；按 PC 摊到部件，全部实测）")
            L.append("")
            L.append(f"整 app {ref_cycles:,} 拍 − Σ阶段 {sigma:,} 拍 = 残差 **{res:,} 拍**"
                     f"（{100 * res / ref_cycles:.3f}%）")
            L.append("")
            L.append("| 部件 | 拍 | 占残差 | 说明 |")
            L.append("|---|---:|---:|---|")
            L.append(f"| 匿名区（无符号，如 wrapper 清零循环） | {comp['匿名区（无符号，如 wrapper 清零循环）']:,} | "
                     f"{100 * comp['匿名区（无符号，如 wrapper 清零循环）'] / max(res, 1):.1f}% | PC 级实测 |")
            L.append(f"| 框架容器（crypto_kem_*/indcpa_* 及其内层标签） | "
                     f"{comp['框架容器（crypto_kem_*/indcpa_* 及其内层标签）']:,} | "
                     f"{100 * comp['框架容器（crypto_kem_*/indcpa_* 及其内层标签）'] / max(res, 1):.1f}% | PC 级实测 |")
            L.append(f"| 其它（= 残差 − 上两项；含 Σ 行 Δ 的前导冗余，故可能为负） | {rest:,} | "
                     f"{100 * rest / max(res, 1):.1f}% | 减法 |")
            L.append(f"| **合计** | **{res:,}** | 100.0% | 恒等 |")
            L.append("")
            L.append("| 两个实测部件的热点 PC | PC | 拍 |")
            L.append("|---|---:|---:|")
            for nm_tag, key in (("匿名区", "匿名"), ("框架容器", "容器")):
                sel = [(pc, di + ds) for pc, (di, ds) in per.items()
                       if (name_at(pc, starts, bnds) == "(无符号区间)") == (key == "匿名")
                       and (key == "匿名" or any(name_at(pc, starts, bnds).startswith(p)
                                                 for p in CONTAINER))]
                for pc, c in sorted(sel, key=lambda kv: -kv[1])[:6]:
                    L.append(f"| {nm_tag} `{name_at(pc, starts, bnds)}` | `{pc:#x}` | {c:,} |")
            L.append("")
    except BaseException:                       # noqa: BLE001 —— 任何失败都要留下日志
        fatal = traceback.format_exc()
        L += ["## ✗ 失败（不是数据问题，是工具运行失败）", "", "```", fatal.strip(), "```", ""]

    txt = "\n".join(L)
    print(txt)
    if args.out:
        op = Path(args.out)
        op.parent.mkdir(parents=True, exist_ok=True)
        op.write_text(txt + "\n", encoding="utf-8")     # ⚠ 无论成败都写（方便贴回来诊断）
        print(f"\n[写] {op}")
    return 0 if (fatal is None and ok is not False) else 1


if __name__ == "__main__":
    raise SystemExit(main())
