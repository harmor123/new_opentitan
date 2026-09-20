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

  la   x2, stack
  li   x3, 4096
  add  x2, x2, x3
  addi fp, x2, 0

  /*
   * J(z || c) = SHAKE256(z || c, 32)
   *
   * z = implicit-rejection secret (32 B)，c = ciphertext (1088 B)；
   * 输出 32 B。
   * 调用序列与 ver0_2/app 的 mlkem_decap.s 中 "shake256(z||c, 32)" 段逐条一致。
   */
  bn.xor w31, w31, w31

  la    x21, input_z             /* z, 32 bytes */
  addi  x20, x0, 32
  addi  x22, x0, 0               /* unmasked */

  la    x21, input_ct            /* ciphertext, 1088 bytes */
  li    x20, 1088
  addi  x22, x0, 0


  /* squeeze 32 B */
  bn.xor w0, w29, w30
  li     x5, 0
  la     x12, output_shake
  bn.sid x5, 0(x12)


  ecall


.section .data
.balign 32

stack:
  .zero 4096

/* implicit-rejection secret z (32 B) */
.balign 32
input_z:
  .zero 32

/* ML-KEM-768 ciphertext (1088 B) */
.balign 32
input_ct:
  .zero 1088

.balign 32
output_shake:
  .zero 32
