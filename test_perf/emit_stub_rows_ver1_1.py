#!/usr/bin/env python3
"""为 ver1_1 生成"拒绝采样隔离"三行（桩法），并派生 control。

三行（与 ver0_1/ver0_2 同名同义，均 `closure:false` 不进 Σ）：
  keygen_poly_gen_matrix_shake          XOF 路径：按 ver1_1 的会话模式重放 χOF 调用
  keygen_poly_gen_matrix_rejection      采样路径：真 gen_matrix ×9，χOF 换成桩（读预计算流）
  keygen_poly_gen_matrix_stub_overhead  校准：只调桩 API（= 桩自身开销）

ver1_1 的调用约定（逐字取自 mlkem768/poly_gen_matrix.s 与 mlkem_keypair.s）：
  · poly_gen_matrix(x2=ρ 指针, x3=j, x4=i, x5=输出)   —— i 外层、j 内层，各 0..2
  · χOF：jal xof_shake128_init → (x20=34, x22=0) → jal xof_absorb → jal xof_process
         → la x20,<buf>; loopi 21,3{ jal xof_squeeze32; bn.xor w0,w29,w30; bn.sid x0,0(x20++) }
         → jal xof_finish                    ⇒ 每会话 25 次调用、632 B
  · 内核压栈走 x31（app 入口 la x31, stack）
control 一律由 profiling **删掉所有 jal 行**派生（保证 Δ = 内核净成本的不变式）。

用法: python3 test_perf/emit_stub_rows_ver1_1.py [--out-dir <包目录>]
"""
import argparse
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import fix_controls as F      # noqa: E402  用同一个"删 jal"规则派生 control

ZERO = "\n".join(f"  bn.xor w{i}, w{i}, w{i}" for i in range(32))
PROLOGUE = f"""main:
{'''  /* 与 app 一致的确定性 WDR 初始化 */'''}
{ZERO}

  /* app 入口同样把栈指针放 x31（内核/桩都用 0(x31) 压栈；stack 来自 common_data.s） */
  la   x31, stack
"""

SESSIONS = [(i, j) for i in range(3) for j in range(3)]      # i 外 j 内 = app 顺序


def head(title, note):
    return f"""/*
 * {title}
 * {note}
 *
 * 本文件由 test_perf/emit_stub_rows_ver1_1.py 生成；control 由 profiling 删 jal 派生。
 */
.section .text.start

.globl main
{PROLOGUE}"""


def shake_row():
    L = [head("ver1_1 剖面（子分解）：keygen_poly_gen_matrix_shake",
              "XOF 路径 = 按 app 的会话模式重放 χOF 调用（9 会话 × 25 次），不含采样。")]
    for i, j in SESSIONS:
        L.append(f"""
  /* 会话 nonce 0x{(i << 8) + j:04x}（i={i}, j={j}）：输入 = ρ(32) ‖ j ‖ i = 34 B
     （与 app 的 poly_gen_matrix 逐字一致：LE32 = (i<<8)+j 存到偏移 32） */
  la   x21, expand_buf
  li   x20, {(i << 8) + j}
  sw   x20, 32(x21)
  li   x20, 34
  addi x22, x0, 0
  jal  x1, xof_shake128_init
  jal  x1, xof_absorb
  jal  x1, xof_process
  la   x20, shake_out
  .rept 21
    jal  x1, xof_squeeze32
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr
  jal  x1, xof_finish""")
    L.append("\n  ecall\n")
    L.append("""
.section .data
.balign 32
rho:
  .zero 32
.balign 32
expand_buf:
  .zero 64
.balign 32
shake_out:
  .zero 672
/* 栈由 common_data.s 提供（链接它，避免与其它行重复定义 stack） */""")
    return "\n".join(L) + "\n"


def rejection_row():
    L = [head("ver1_1 剖面（子分解）：keygen_poly_gen_matrix_rejection",
              "真 gen_matrix ×9（i 外 j 内），χOF 由桩替换为预计算流 ⇒ 只测拒绝采样循环。")]
    for i, j in SESSIONS:
        n = (i << 8) + j
        L.append(f"""
  /* A[{i}][{j}]：流指针指向本会话段 */
  la   x6, rejection_stream_ptr
  la   x7, rejection_stream_{n:04x}
  sw   x7, 0(x6)
  la   x2, rho
  li   x3, {j}
  li   x4, {i}
  la   x5, out_poly_{n:04x}
  jal  x1, poly_gen_matrix""")
    L.append("\n  ecall\n")
    L.append("""
.section .data
.balign 32
rho:
  .zero 64
.balign 32
out_poly_0000:
  .zero 1024
.balign 32
out_poly_0001:
  .zero 1024
.balign 32
out_poly_0002:
  .zero 1024
.balign 32
out_poly_0100:
  .zero 1024
.balign 32
out_poly_0101:
  .zero 1024
.balign 32
out_poly_0102:
  .zero 1024
.balign 32
out_poly_0200:
  .zero 1024
.balign 32
out_poly_0201:
  .zero 1024
.balign 32
out_poly_0202:
  .zero 1024
/* 栈由 common_data.s 提供（链接它，避免重复定义 stack） */""")
    return "\n".join(L) + "\n"


def stub_overhead_row():
    L = [head("ver1_1 剖面（子分解）：keygen_poly_gen_matrix_stub_overhead",
              "校准项：只调桩 API（与 χOF 重放同次数），量桩自身开销。")]
    L.append("""
  /* 流指针必须先有效（桩的 xof_squeeze32 会读它） */
  la   x6, rejection_stream_ptr
  la   x7, rejection_stream_0000
  sw   x7, 0(x6)""")
    for _ in SESSIONS:
        L.append("""
  la   x21, expand_buf
  li   x20, 34
  addi x22, x0, 0
  jal  x1, xof_shake128_init
  jal  x1, xof_absorb
  jal  x1, xof_process
  la   x20, shake_out
  .rept 21
    jal  x1, xof_squeeze32
    bn.xor w0, w29, w30
    bn.sid x0, 0(x20++)
  .endr
  jal  x1, xof_finish""")
    L.append("\n  ecall\n")
    L.append("""
.section .data
.balign 32
expand_buf:
  .zero 64
.balign 32
shake_out:
  .zero 672
/* 栈由 common_data.s 提供（链接它，避免与其它行重复定义 stack） */""")
    return "\n".join(L) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out-dir", default=str(REPO / "test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768"))
    args = ap.parse_args()
    out = Path(args.out_dir)
    for row, text in (("keygen_poly_gen_matrix_shake", shake_row()),
                      ("keygen_poly_gen_matrix_rejection", rejection_row()),
                      ("keygen_poly_gen_matrix_stub_overhead", stub_overhead_row())):
        p = out / f"{row}_profiling.s"
        c = out / f"{row}_control.s"
        p.write_text(text, encoding="utf-8")
        c.write_text(F.make_control(text), encoding="utf-8")
        print(f"  [写] {p.name}（{len(text.splitlines())} 行） + {c.name}（control = 删 jal 派生）")
    print("\n还需：① 生成流文件 test_perf/dump_xof_stream.py；② 加 BUILD 目标 + config 阶段行（closure:false）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
