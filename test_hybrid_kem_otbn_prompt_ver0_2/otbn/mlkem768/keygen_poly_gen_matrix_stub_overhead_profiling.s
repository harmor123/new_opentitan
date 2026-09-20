.section .text.start

.globl main
main:
  bn.xor w0,  w0,  w0
  bn.xor w1,  w1,  w1
  bn.xor w2,  w2,  w2
  bn.xor w3,  w3,  w3
  bn.xor w4,  w4,  w4
  bn.xor w5,  w5,  w5
  bn.xor w6,  w6,  w6
  bn.xor w7,  w7,  w7
  bn.xor w8,  w8,  w8
  bn.xor w9,  w9,  w9
  bn.xor w10, w10, w10
  bn.xor w11, w11, w11
  bn.xor w12, w12, w12
  bn.xor w13, w13, w13
  bn.xor w14, w14, w14
  bn.xor w15, w15, w15
  bn.xor w16, w16, w16
  bn.xor w17, w17, w17
  bn.xor w18, w18, w18
  bn.xor w19, w19, w19
  bn.xor w20, w20, w20
  bn.xor w21, w21, w21
  bn.xor w22, w22, w22
  bn.xor w23, w23, w23
  bn.xor w24, w24, w24
  bn.xor w25, w25, w25
  bn.xor w26, w26, w26
  bn.xor w27, w27, w27
  bn.xor w28, w28, w28
  bn.xor w29, w29, w29
  bn.xor w30, w30, w30
  bn.xor w31, w31, w31

  la   x2, stack
  li   x3, 4096
  add  x2, x2, x3
  addi fp, x2, 0

  /*
   * 校准项：只测"桩自身的固定开销"。
   *
   * 调用次数 = app 实测（ISS 动态）：init ×9、absorb ×18、process ×9、
   * squeeze ×135（**每会话 15 块，按会话重指流指针**，见下方每会话块）、finish ×9。
   * 流由 test_perf/gen_xof_stream_from_rho.py 从 ρ 确定性生成
   * （Python `SHAKE128(ρ‖j‖i)`，已与 ISS 抓取的真流逐字节比对通过）。
   *
   * 2026-09-20 前这里是"设一次指针 + 线性走 137 块"：次数陈旧（app 实测 135）
   * 且游走跨会话边界 ⇒ 校准值偏。
   */

  /* xof_shake128_init ×9 */
  .rept 9
    jal x1, xof_shake128_init
  .endr

  /* xof_absorb ×18 */
  .rept 18
    jal x1, xof_absorb
  .endr

  /* xof_process ×9 */
  .rept 9
    jal x1, xof_process
  .endr

  /* xof_squeeze32 ×137 */
  /* 会话 nonce 0x0000：本会话 15 块（= app 实测需求，与流文件配额一致） */
  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0000
  sw   x4, 0(x3)
  .rept 15
    jal  x1, xof_squeeze32
  .endr
  /* 会话 nonce 0x0001：本会话 15 块（= app 实测需求，与流文件配额一致） */
  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0001
  sw   x4, 0(x3)
  .rept 15
    jal  x1, xof_squeeze32
  .endr
  /* 会话 nonce 0x0002：本会话 15 块（= app 实测需求，与流文件配额一致） */
  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0002
  sw   x4, 0(x3)
  .rept 15
    jal  x1, xof_squeeze32
  .endr
  /* 会话 nonce 0x0100：本会话 15 块（= app 实测需求，与流文件配额一致） */
  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0100
  sw   x4, 0(x3)
  .rept 15
    jal  x1, xof_squeeze32
  .endr
  /* 会话 nonce 0x0101：本会话 15 块（= app 实测需求，与流文件配额一致） */
  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0101
  sw   x4, 0(x3)
  .rept 15
    jal  x1, xof_squeeze32
  .endr
  /* 会话 nonce 0x0102：本会话 15 块（= app 实测需求，与流文件配额一致） */
  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0102
  sw   x4, 0(x3)
  .rept 15
    jal  x1, xof_squeeze32
  .endr
  /* 会话 nonce 0x0200：本会话 15 块（= app 实测需求，与流文件配额一致） */
  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0200
  sw   x4, 0(x3)
  .rept 15
    jal  x1, xof_squeeze32
  .endr
  /* 会话 nonce 0x0201：本会话 15 块（= app 实测需求，与流文件配额一致） */
  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0201
  sw   x4, 0(x3)
  .rept 15
    jal  x1, xof_squeeze32
  .endr
  /* 会话 nonce 0x0202：本会话 15 块（= app 实测需求，与流文件配额一致） */
  la   x3, rejection_stream_ptr
  la   x4, rejection_stream_0202
  sw   x4, 0(x3)
  .rept 15
    jal  x1, xof_squeeze32
  .endr

  /* xof_finish ×9 */
  .rept 9
    jal x1, xof_finish
  .endr

  ecall


.section .data
.balign 32

stack:
  .zero 4096
