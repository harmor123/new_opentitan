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
   * G(d || k) = SHA3-512(d || 0x03) → (rho, sigma)
   *
   * 调用序列与 ver0_2/app 的 mlkem_keypair.s 中 "hash_g" 段逐条一致。
   * k 以 1 字节 0x03 单独 absorb（对应 FIPS 203 的域分隔）。
   */
  bn.xor w31, w31, w31
  jal   x1, xof_sha3_512_init

  la    x21, input_seed          /* d, 32 bytes */
  addi  x20, x0, 32
  addi  x22, x0, 0               /* unmasked */
  jal   x1, xof_absorb

  la    x21, input_k             /* 0x03 */
  addi  x20, x0, 1
  addi  x22, x0, 0
  jal   x1, xof_absorb

  jal   x1, xof_process

  /* Squeeze 1st 32 bytes (rho) */
  jal   x1, xof_squeeze32
  bn.xor w0, w29, w30
  li     x5, 0
  la     x12, output_rho
  bn.sid x5, 0(x12)

  /* Squeeze 2nd 32 bytes (sigma) */
  jal   x1, xof_squeeze32
  bn.xor w0, w29, w30
  li     x5, 0
  la     x12, output_sigma
  bn.sid x5, 0(x12)

  jal   x1, xof_finish

  ecall


.section .data
.balign 32

stack:
  .zero 4096

/* seed d (32 bytes) */
.balign 32
input_seed:
  .zero 32

/* domain separation byte k = 0x03 */
.balign 32
input_k:
  .word 0x00000003

/* SHA3-512 outputs */
.balign 32
output_rho:
  .zero 32
.balign 32
output_sigma:
  .zero 32
