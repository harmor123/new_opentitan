.section .text.start

.globl main
main:
  /* Deterministic WDR initialization — 与 ver0_1 harness 完全一致 */
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

  /*
   * Software stack.
   * Use stack + 4096 instead of stack_end to avoid the OTBN
   * end-of-section symbol issue seen earlier.
   */
  la   x2, stack
  li   x3, 4096
  add  x2, x2, x3
  addi fp, x2, 0

  /*
   * H(ek) = SHA3-256(pk) —— 官方 xof.s（KMAC 硬件）路径。
   *
   * 调用序列与 ver0_2/app 的 mlkem_keypair.s 中 "hash_h" 段
   * （xof_sha3_256_init → xof_absorb → xof_process → xof_squeeze32
   *   → xof_finish）逐条一致。
   */
  bn.xor w31, w31, w31
  jal   x1, xof_sha3_256_init

  /* Absorb pk = pk_t(1152 B) ‖ pk_rho(32 B)：**两次 absorb**，
     与 mlkem_keypair.s 的 H(pk) 段逐条一致（ver0_2 的 harness 是合并成 1184 B 一次吸收）。 */
  la    x21, input_pk
  addi  x20, x0, 1152
  addi  x22, x0, 0
  jal   x1, xof_absorb

  la    x21, input_rho
  addi  x20, x0, 32
  addi  x22, x0, 0
  jal   x1, xof_absorb

  jal   x1, xof_process

  /* Squeeze 32 bytes: results land as Boolean shares in w29/w30. */
  jal   x1, xof_squeeze32
  bn.xor w0, w29, w30
  la    x12, output_hash
  li    x5, 0
  bn.sid x5, 0(x12)

  /* Finish the KMAC session and release the block. */
  jal   x1, xof_finish

  ecall


.section .data
.balign 32

stack:
  .zero 4096

/* pk_t（3 × 384 B 序列化）+ rho（32 B）：app 里分两次 absorb */
.balign 32
input_pk:
  .zero 1152

.balign 32
input_rho:
  .zero 32

/* SHA3-256 output */
.balign 32
output_hash:
  .zero 32
