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
   * 矩阵生成的 XOF 部分（KMAC 路径）。
   *
   * 逐条重放 poly_gen_matrix ×9 的 KMAC 调用序列：每个 (rho, nonce) 做一次
   * SHAKE128 会话，squeeze 次数与真实执行**逐条目相同**
   * （9 会话 × 15 = **135** = 父行/ISS 实测的动态次数；每会话配额与流文件的标签步长一致）。
   * ⚠ 2026-09-20 前这里写的是旧 ρ 时代的 15/16/15/15/16/15/15/15/15 = 137 ⇒ 多 2 次挤压、
   *   多 2 次 KMAC 轮询，`shake+rejection−stub` 闭合差 +274 拍（判定见 audit_fidelity.py 的 ②''）。
   */

  /* ===== Matrix index 0x0000: 15 × 32-byte squeezes ===== */
  li    x24, 0x0000
  la    x25, nonce_slot
  sw    x24, 0(x25)
  bn.xor w31, w31, w31
  la    x21, rho
  addi  x20, x0, 32
  addi  x22, x0, 0
  la    x21, nonce_slot
  addi  x20, x0, 2
  addi  x22, x0, 0
  .rept 15
    bn.xor w0, w29, w30
    li     x5, 0
    la     x12, squeeze_buf
    bn.sid x5, 0(x12)
  .endr

  /* ===== Matrix index 0x0001: 16 × 32-byte squeezes ===== */
  li    x24, 0x0001
  la    x25, nonce_slot
  sw    x24, 0(x25)
  bn.xor w31, w31, w31
  la    x21, rho
  addi  x20, x0, 32
  addi  x22, x0, 0
  la    x21, nonce_slot
  addi  x20, x0, 2
  addi  x22, x0, 0
  .rept 15
    bn.xor w0, w29, w30
    li     x5, 0
    la     x12, squeeze_buf
    bn.sid x5, 0(x12)
  .endr

  /* ===== Matrix index 0x0002: 15 ===== */
  li    x24, 0x0002
  la    x25, nonce_slot
  sw    x24, 0(x25)
  bn.xor w31, w31, w31
  la    x21, rho
  addi  x20, x0, 32
  addi  x22, x0, 0
  la    x21, nonce_slot
  addi  x20, x0, 2
  addi  x22, x0, 0
  .rept 15
    bn.xor w0, w29, w30
    li     x5, 0
    la     x12, squeeze_buf
    bn.sid x5, 0(x12)
  .endr

  /* ===== Matrix index 0x0100: 15 ===== */
  li    x24, 0x0100
  la    x25, nonce_slot
  sw    x24, 0(x25)
  bn.xor w31, w31, w31
  la    x21, rho
  addi  x20, x0, 32
  addi  x22, x0, 0
  la    x21, nonce_slot
  addi  x20, x0, 2
  addi  x22, x0, 0
  .rept 15
    bn.xor w0, w29, w30
    li     x5, 0
    la     x12, squeeze_buf
    bn.sid x5, 0(x12)
  .endr

  /* ===== Matrix index 0x0101: 16 ===== */
  li    x24, 0x0101
  la    x25, nonce_slot
  sw    x24, 0(x25)
  bn.xor w31, w31, w31
  la    x21, rho
  addi  x20, x0, 32
  addi  x22, x0, 0
  la    x21, nonce_slot
  addi  x20, x0, 2
  addi  x22, x0, 0
  .rept 15
    bn.xor w0, w29, w30
    li     x5, 0
    la     x12, squeeze_buf
    bn.sid x5, 0(x12)
  .endr

  /* ===== Matrix index 0x0102: 15 ===== */
  li    x24, 0x0102
  la    x25, nonce_slot
  sw    x24, 0(x25)
  bn.xor w31, w31, w31
  la    x21, rho
  addi  x20, x0, 32
  addi  x22, x0, 0
  la    x21, nonce_slot
  addi  x20, x0, 2
  addi  x22, x0, 0
  .rept 15
    bn.xor w0, w29, w30
    li     x5, 0
    la     x12, squeeze_buf
    bn.sid x5, 0(x12)
  .endr

  /* ===== Matrix index 0x0200: 15 ===== */
  li    x24, 0x0200
  la    x25, nonce_slot
  sw    x24, 0(x25)
  bn.xor w31, w31, w31
  la    x21, rho
  addi  x20, x0, 32
  addi  x22, x0, 0
  la    x21, nonce_slot
  addi  x20, x0, 2
  addi  x22, x0, 0
  .rept 15
    bn.xor w0, w29, w30
    li     x5, 0
    la     x12, squeeze_buf
    bn.sid x5, 0(x12)
  .endr

  /* ===== Matrix index 0x0201: 15 ===== */
  li    x24, 0x0201
  la    x25, nonce_slot
  sw    x24, 0(x25)
  bn.xor w31, w31, w31
  la    x21, rho
  addi  x20, x0, 32
  addi  x22, x0, 0
  la    x21, nonce_slot
  addi  x20, x0, 2
  addi  x22, x0, 0
  .rept 15
    bn.xor w0, w29, w30
    li     x5, 0
    la     x12, squeeze_buf
    bn.sid x5, 0(x12)
  .endr

  /* ===== Matrix index 0x0202: 15 ===== */
  li    x24, 0x0202
  la    x25, nonce_slot
  sw    x24, 0(x25)
  bn.xor w31, w31, w31
  la    x21, rho
  addi  x20, x0, 32
  addi  x22, x0, 0
  la    x21, nonce_slot
  addi  x20, x0, 2
  addi  x22, x0, 0
  .rept 15
    bn.xor w0, w29, w30
    li     x5, 0
    la     x12, squeeze_buf
    bn.sid x5, 0(x12)
  .endr

  ecall


.section .data
.balign 32

stack:
  .zero 4096

/* 与 keygen_poly_gen_matrix_data.s 中相同的 rho（= 求值时的真实输入） */
.balign 32
rho:
  .word 0x98c02e16
  .word 0x2db100a9
  .word 0xfbbbfad8
  .word 0x1dcbe83f
  .word 0x5f31e8c4
  .word 0x2fd3f02a
  .word 0x13ae1700
  .word 0x28f0196e

.balign 32
nonce_slot:
  .zero 4

.balign 32
squeeze_buf:
  .zero 32
