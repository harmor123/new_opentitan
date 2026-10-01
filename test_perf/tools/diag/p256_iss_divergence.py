#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""定位两版 P-256 ECDH 在 **ISS 里**从哪一次域乘开始分道扬镳（ver0_1 软件 mul_modp vs ver1_2 折叠）。

背景：ver0_1 的本地 `otbn/p256` 目标有**装配缺陷**（`p256_isoncurve_proj.s` 缺 `.text` ⇒
51 条指令被写进 `.data`、`jal` 跳飞）⇒ 用它跑 ISS 会在曲线自检处故意触发
`ERR_BITS=0x8`（ILLEGAL_INSN）。本工具用于复核**修正后**的旧侧（官方实现）与新侧（折叠）——
那是 `p256_shared_key` 里"点在曲线上"自检（`bn.cmp w18,w19` + `trigger_fault_if_fg0_z`）失败的
**故意触发**；同源的 ver1_2（同一支测试程序，只有域乘不同）却跑通。本工具把两侧对齐到
**每一次域乘调用**上，直接指出第一次结果不同的调用及其操作数。

原理与**口径更正（2026-10-01 实测发现）**：ISS 的 URND 是**每拍推进**的 Trivium 流
（`_step_exec` 每拍 `URND.step()`）⇒ 两个实现的拍数不同（软件 53 条/次 vs 折叠 1 条 + 27 停滞），
**从第一次域乘起收到的随机值就不同** ⇒ 两跑**不是同一轨迹**，逐次配对只在"随机流尚未分叉"的
前若干次上有效（实测：前 22 次操作数相同，之后不同）。**因此主判据改为每跑自检**：

  · 每一次域乘的返回值都应当 == `(a*b) mod p` —— 与随机流无关；
  · 软件 `mul_modp` 的文档前置条件是 **a,b < p**（折叠指令无此前置条件）⇒ 同时报告
    "操作数 ≥ p"的事件（这类事件的返回值允许 ≠ (a*b) mod p，须单独看）；
  · 中止的一侧额外打印中止前最后 3 次域乘（失败点附近）。

记录内容：每次"进入/离开 mul_modp"事件（w24/w25 操作数、w19 返回值、入口 pc），
以及 `p256_shared_key` 自身指令上的寄存器（自检区 w18/w19）。

自检（不成立即非零退出 ✗）：两侧各自至少 100 次域乘事件（防符号/区间配错）。

用法：
  python3 test_perf/tools/diag/p256_iss_divergence.py \
      --a //test_hybrid_kem_otbn_prompt_ver0_1/otbn/p256:p256_ecdh_shared_key --label-a ver0_1 \
      --b //test_hybrid_kem_otbn_prompt_ver1_2/otbn/p256:p256_ecdh_shared_key --label-b ver1_2
  （--a-elf/--b-elf 可直接给 bazel-bin 下的 ELF 路径）
"""
import argparse
import sys
import pathlib
from collections import deque

REPO = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "test_perf"))
sys.path.insert(0, str(REPO / "hw/ip/otbn/dv/otbnsim"))

from sim.load_elf import load_elf                      # noqa: E402
from sim.standalonesim import StandaloneSim            # noqa: E402
from sim.constants import ErrBits                      # noqa: E402

P_DEC = 0xffffffff00000001000000000000000000000000ffffffffffffffffffffffff


def err_names(bits: int) -> str:
    if not bits:
        return "0（无错）"
    hits = [n for n in dir(ErrBits)
            if not n.startswith("_") and isinstance(getattr(ErrBits, n), int)
            and getattr(ErrBits, n) and (bits & getattr(ErrBits, n)) == getattr(ErrBits, n)]
    return "%#x = %s" % (bits, " | ".join(hits))


def collect(elf: str, label: str) -> dict:
    import harness                                            # noqa: E402
    bounds = harness.load_text_boundaries(elf)
    by = {n: (s, e) for s, e, n in bounds}
    for need in ("mul_modp", "scalar_mult_int", "p256_shared_key"):
        assert need in by, ("ELF 里没有符号 %s" % need, label)

    mul_s, mul_e = by["mul_modp"]
    sc_s, sc_e = by["scalar_mult_int"]
    sh_s, sh_e = by["p256_shared_key"]

    sim = StandaloneSim()
    load_elf(sim, str(elf))
    sim.state.ext_regs.commit()
    sim.start(collect_stats=True)
    sim.state.complete_init_sec_wipe()
    sim.state.wfi_enabled = True
    sim.state.wfi_auto_resume = True
    from sim.standalonesim import _TEST_RND_DATA, _TEST_URND_SEED   # noqa: E402
    urnd_i = 0

    W = sim.state.wdrs
    ev, shared_steps, tail = [], [], deque(maxlen=10)
    pending = None
    prev_kind = None
    n = 0
    while True:
        if sim.state.ext_regs.read("RND_REQ", True):
            sim.state.wsrs.RND.set_unsigned(next(_TEST_RND_DATA), False, False)
        if sim.state.wsrs.URND.requesting:
            sim.state.wsrs.URND.set_seed(_TEST_URND_SEED[urnd_i])
            urnd_i = (urnd_i + 1) % len(_TEST_URND_SEED)
            if urnd_i == 0:
                sim.state.wsrs.URND.reseed_done = True
        pc = sim.state.pc
        rd = lambda i: W.get_reg(i).read_unsigned()
        if mul_s <= pc < mul_e:
            kind = "mul"
        elif sc_s <= pc < sc_e:
            kind = "sc"
        elif sh_s <= pc < sh_e:
            kind = "sh"
        else:
            kind = "other"
        if prev_kind != "mul" and kind == "mul":
            # 进入 mul_modp 的第一拍：w24/w25 就是本次乘法的操作数（调用点由 jal 前几条 mov 设好，
            # 不论调用者在 sc 区还是其它库函数）
            pending = (pc, rd(24), rd(25))
        elif prev_kind == "mul" and kind != "mul":
            ev.append((pending, pc - sc_s, rd(19)))      # 域乘返回值（w19）
            pending = None
        if kind == "sh":
            shared_steps.append((pc - sh_s, rd(8), rd(9), rd(10), rd(18), rd(19), rd(20), rd(21)))
        tail.append((pc, kind))
        prev_kind = kind
        sim.step(verbose=False)
        n += 1
        if str(sim.state.get_fsm_state()) in ("FsmState.IDLE", "FsmState.LOCKED"):
            break

    st = sim.stats
    return {"label": label, "elf": elf, "insn": st.get_insn_count(), "err_bits": sim.state._err_bits,
            "ecall": dict(st.insn_histo).get("ecall", 0), "fsm": str(sim.state.get_fsm_state()),
            "events": ev, "shared": shared_steps, "tail": list(tail),
            "sym": {"mul": (mul_s, mul_e), "sc": (sc_s, sc_e), "sh": (sh_s, sh_e)}}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--a", help="旧（基线）bazel 目标")
    ap.add_argument("--b", help="新 bazel 目标")
    ap.add_argument("--a-elf"), ap.add_argument("--b-elf")
    ap.add_argument("--label-a", default="A")
    ap.add_argument("--label-b", default="B")
    args = ap.parse_args()
    assert (args.a or args.a_elf) and (args.b or args.b_elf), "两侧都要给（--a/--a-elf、--b/--b-elf）"
    if args.a and not args.a_elf:
        import harness
        args.a_elf = harness.bazel_elf(args.a)
    if args.b and not args.b_elf:
        import harness
        args.b_elf = harness.bazel_elf(args.b)

    A, B = collect(args.a_elf, args.label_a), collect(args.b_elf, args.label_b)
    for r in (A, B):
        print("[%s] insn=%s  ERR_BITS=%s  ecall=%s  fsm=%s  mul 调用事件=%d  shared_key 步数=%d"
              % (r["label"], format(r["insn"], ","), err_names(r["err_bits"]), r["ecall"], r["fsm"],
                 len(r["events"]), len(r["shared"])))
    # ── 每跑自检（**这是本工具的主判据**）：每一次域乘的返回值都应当等于 (a*b) mod p，
    #    与随机流无关 ⇒ 两跑可以各自对真值判，不必逐次配对。
    #    （注意：软件 mul_modp 的文档前置条件是 a,b < p；若出现操作数 ≥ p，其返回值可以合法地
    #      不等于 (a*b) mod p —— 折叠指令无此前置条件。所以要同时报告"操作数越界"事件。）
    from sim.isa import p256_mulmodp                                     # noqa: E402
    for r in (A, B):
        ev = [(k, e) for k, e in enumerate(r["events"]) if e[0] is not None]
        ok_true = ok_model = over = 0
        bad_true, bad_range = [], []
        for k, ((pc, a, b), rpc, res) in ev:
            if res == (a * b) % P_DEC:
                ok_true += 1
            else:
                bad_true.append((k, (pc, a, b), rpc, res))
            if res == p256_mulmodp(a, b):
                ok_model += 1
            if a >= P_DEC or b >= P_DEC:
                over += 1
                bad_range.append((k, a, b))
        print("  [自检 %s] 共 %d 次域乘：返回值 == (a*b)mod p 的 %d 次；== ISS 模型 %d 次；"
              "操作数 ≥ p 的 %d 次" % (r["label"], len(ev), ok_true, ok_model, over))
        for k, (pc, a, b), rpc, res in bad_true[:3]:
            print("      ✗ 第 %d 次 ≠ 真值：a=0x%064x（≥p:%s） b=0x%064x（≥p:%s） 读到 0x%064x，"
                  "真值 0x%064x，模型 0x%064x" % (k, a, a >= P_DEC, b, b >= P_DEC, res,
                                                  (a * b) % P_DEC, p256_mulmodp(a, b)))
        for k, a, b in bad_range[:3]:
            print("      ⚠ 第 %d 次操作数越界：a=0x%064x b=0x%064x" % (k, a, b))
        # 中止的一侧：看最后几次（失败点就在附近）
        if r["err_bits"]:
            print("      ↳ 中止前最后 3 次域乘：")
            for k, ((pc, a, b), rpc, res) in ev[-3:]:
                print("        第 %d 次 a=0x%064x b=0x%064x ⇒ 0x%064x（真值 0x%064x）"
                      % (k, a, b, res, (a * b) % P_DEC))
    ea, eb = A["events"], B["events"]
    print("\n=== 逐次域乘配对（次要判据：只在随机流尚未分叉的前若干次上有效 —— 见文件头口径更正）")
    assert len(ea) > 100 and len(eb) > 100, ("事件太少，怀疑符号/区间不对", len(ea), len(eb))
    bad = [k for k in range(min(len(ea), len(eb)))
           if ea[k][0][1:] != eb[k][0][1:] or ea[k][2] != eb[k][2]]
    print("  调用数：%s / %s；不相同的事件数：%d" % (len(ea), len(eb), len(bad)))
    for k in bad[:5]:
        (pa, a, b), sc_pc_a, ra = ea[k]
        (pb, a2, b2), sc_pc_b, rb = eb[k]
        true = (a * b) % P_DEC
        print("  ✗ 第 %d 次" % k)
        print("       %s 操作数 a=0x%064x b=0x%064x（入口 pc %#x）结果 0x%064x"
              % (args.label_a, a, b, pa, ra))
        print("       %s 操作数 a=0x%064x b=0x%064x（入口 pc %#x）结果 0x%064x"
              % (args.label_b, a2, b2, pb, rb))
        print("       真值 (a*b)mod p=0x%064x；A 结果==真值? %s ；B 结果==它自己的 (a2*b2)mod p? %s ；"
              "%s 结果==模型 p256_mulmodp(a2,b2)? %s"
              % (true, ra == true, rb == (a2 * b2) % P_DEC, args.label_b, rb == p256_mulmodp(a2, b2)))
    if not bad:
        print("  ✓ 全部域乘逐次相同（到 %d 次为止）——分歧不在域乘本身" % min(len(ea), len(eb)))

    print("\n=== p256_shared_key 自身指令上的寄存器（自检区；列：偏移 w8 w9 w10 w18 w19 w20 w21）")
    for r in (A, B):
        print(" -- %s（%d 步）" % (r["label"], len(r["shared"])))
        for row in r["shared"][-16:]:
            print("    off=%-4d w8=0x%016x w9=0x%016x w10=0x%016x w18=0x%016x w19=0x%016x w20=0x%016x w21=0x%016x"
                  % tuple(x & ((1 << 64) - 1) for x in row))
    print("\n=== 末尾 10 个 PC（kind: mul/sc/sh/other）")
    for r in (A, B):
        print(" -- %s: %s" % (r["label"], "  ".join("%#x/%s" % (pc, k) for pc, k in r["tail"])))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
