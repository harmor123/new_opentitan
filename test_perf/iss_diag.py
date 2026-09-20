#!/usr/bin/env python3
"""ISS 单 ELF 诊断：查"某行为什么测出来偏小/没跑到 ecall"。

背景（2026-09-20 发现）：ver0_1 的 `encap_h_ek` 行 Δinsn=7,089（应 ≈63,000），
Δhisto 里 `ecall=-1` ⇒ **profiling 那次运行被 ISS 提前中止了**，而 harness.py
当时**不看 ERR_BITS**，于是把一次残缺运行当成有效测量写进了报告。
同样的指纹还出现在 `decap_hash_g_reuse`（该行数值本身是对的）。

本工具把"那次运行到底怎么结束的"直接打出来：
  · 结束状态（FSM / pending_halt / ERR_BITS 及其枚举名）
  · 指令/周期总数、ecall/jal/loop 计数
  · **最后 N 条真正执行的指令**（verbose trace 的尾部）
  · 循环栈 / 调用栈残留（未弹干净的循环/调用会在这里露出来）
  · DMEM 大小 + 关键数据符号地址（context/rc/input_*/output_*/stack）
    —— 用于核对 bn.lid/bn.sid 需要的 32 B 对齐与"是否越过 DMEM 末尾"

用法（Linux 侧）:
    python3 test_perf/iss_diag.py --target //<pkg>:<目标名>
    python3 test_perf/iss_diag.py --elf bazel-bin/<...>.elf
    python3 test_perf/iss_diag.py --target //...:mlkem768_encap_h_ek_profiling \\
        --target //...:mlkem768_encap_h_ek_control --tail 60

（--target 会先 bazel build + cquery 拿 ELF，和 harness.py 同法。）
"""

import argparse
import contextlib
import io
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "hw/ip/otbn/dv/otbnsim"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from sim.load_elf import load_elf                      # noqa: E402
from sim.standalonesim import StandaloneSim            # noqa: E402
from sim.constants import ErrBits                      # noqa: E402

# 关心的数据符号（bn.lid/bn.sid 的 32 B 对齐 + 是否越界都看它们）
WATCH = ["context", "rc", "mask_top_1", "input_ek", "input_pk", "input_64",
         "input_mh", "output_hash", "output_64", "output_K", "output_r",
         "stack", "poly_a", "poly_b", "acc_poly", "poly_sk"]


def err_names(bits: int) -> str:
    if not bits:
        return "0（无错）"
    hits = []
    for n in dir(ErrBits):
        if n.startswith("_"):
            continue
        v = getattr(ErrBits, n)
        if isinstance(v, int) and v and (bits & v) == v:
            hits.append(f"{n}({v:#x})")
    return f"{bits:#x} = " + " | ".join(hits)


def run_one(label: str, elf: str, tail: int) -> dict:
    sim = StandaloneSim()
    load_elf(sim, str(elf))
    sim.state.ext_regs.commit()
    sim.start(collect_stats=True)

    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        cycles = sim.run(verbose=True, dump_file=None)
    lines = [l for l in buf.getvalue().splitlines() if l.strip()]

    st = sim.state
    histo = dict(sim.stats.insn_histo)
    dmem_bytes = len(st.dmem.data) * 4          # ISS 里的 DMEM 字节数
    syms = getattr(sim, "symbols", {}) or {}

    print("=" * 78)
    print(f"### {label}   ({Path(elf).name})")
    print(f"  cycles={cycles:,}  insn={sim.stats.get_insn_count():,}  "
          f"stalls={sim.stats.stall_count:,}")
    print(f"  结束状态: FSM={st.get_fsm_state()}  pending_halt={st.pending_halt}")
    print(f"  ERR_BITS: {err_names(st._err_bits)}")
    print(f"  ecall={histo.get('ecall', 0)}  jal={histo.get('jal', 0)}  "
          f"jalr={histo.get('jalr', 0)}  loop={histo.get('loop', 0)}  "
          f"loopi={histo.get('loopi', 0)}")
    if histo.get("ecall", 0) == 0:
        print("  ⚠ 这次运行**没有执行到 ecall** ⇒ 被提前中止（数值不可信）")

    # 循环栈 / 调用栈残留
    loop_stack = getattr(st.loop_stack, "stack", [])
    if loop_stack:
        print(f"  ⚠ 循环栈未清空（深度 {len(loop_stack)}）:")
        for lv in loop_stack:
            print(f"      start={lv.start_addr:#x} last={lv.last_addr:#x} "
                  f"剩余迭代={lv.restarts_left + 1}")
    cs = st.gprs.peek_call_stack()
    if cs:
        print(f"  ⚠ 调用栈未弹空（深度 {len(cs)}）: {[hex(a) for a in cs]}")

    # DMEM 布局（32 B 对齐检查）
    print(f"  DMEM={dmem_bytes:,} B")
    for name in WATCH:
        a = syms.get(name)
        if a is None:
            continue
        tag = ""
        if name in ("context", "rc", "mask_top_1"):
            tag = "  (32B 对齐 ✓)" if a % 32 == 0 else "  ✗ 未 32B 对齐"
        print(f"      {name:14s} @ {a:#07x} = {a:>6d}{tag}")
    # 有没有超过 DMEM 末尾的无符号地址符号（常见"最后一段放不下"）
    for name, a in sorted(syms.items(), key=lambda kv: -kv[1]):
        if a >= dmem_bytes and not name.startswith("$"):
            print(f"  ⚠ 符号 {name} @ {a:#x} 已越过 DMEM 末尾({dmem_bytes:#x})")
            break

    print(f"  ---- 最后 {tail} 条执行的指令（verbose trace 尾部）----")
    for l in lines[-tail:]:
        print("   ", l)

    return {"label": label, "cycles": cycles, "insn": sim.stats.get_insn_count(),
            "err_bits": st._err_bits, "ecall": histo.get("ecall", 0)}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", action="append", default=[],
                    help="bazel 目标（可给多个）；先 build 再 cquery 取 .elf")
    ap.add_argument("--elf", action="append", default=[], help="直接给 .elf 路径")
    ap.add_argument("--tail", type=int, default=40, help="打印最后多少条指令")
    args = ap.parse_args()

    import harness as H          # 复用 harness.py 的 bazel_build / bazel_elf

    jobs = []
    for t in args.target:
        H.bazel_build([t])
        jobs.append((t, H.bazel_elf(t)))
    for e in args.elf:
        jobs.append((Path(e).name, e))
    if not jobs:
        print("要么 --target 要么 --elf", file=sys.stderr)
        return 2

    print(f"[诊断] {len(jobs)} 个 ELF；PC/反汇编来自 ISS verbose trace")
    out = [run_one(lbl, elf, args.tail) for lbl, elf in jobs]

    print("=" * 78)
    print("### 汇总")
    for r in out:
        ok = "✓" if r["ecall"] and not r["err_bits"] else "✗"
        print(f"  {ok} {r['label']:52s} insn={r['insn']:>9,} "
              f"ecall={r['ecall']} ERR_BITS={r['err_bits']:#x}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
