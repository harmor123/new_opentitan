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
   * G(m' || H(ek)) = SHA3-512(64 bytes) → (K, r)
   *
   * 输入 = 32 B 随机数（m'）‖ 32 B H(ek)，共 64 B；
   * 输出 = 32 B K ‖ 32 B r。
   * 调用序列与 ver0_2/app 的 mlkem_encap.s 中 "hash_g" 段逐条一致。
   */
  bn.xor w31, w31, w31
  jal   x1, xof_sha3_512_init

  /* app（mlkem_encap.s）把 m 与 H(ek) 分两次 absorb（两个不连续的缓冲） */
  la    x21, input_m
  addi  x20, x0, 32
  addi  x22, x0, 0               /* unmasked */
  jal   x1, xof_absorb

  la    x21, input_h_ek
  addi  x20, x0, 32
  addi  x22, x0, 0               /* unmasked */
  jal   x1, xof_absorb

  jal   x1, xof_process

  /* K = ss[0:32] */
  jal   x1, xof_squeeze32
  bn.xor w0, w29, w30
  li     x5, 0
  la     x12, output_K
  bn.sid x5, 0(x12)

  /* r = ss[32:64] */
  jal   x1, xof_squeeze32
  bn.xor w0, w29, w30
  li     x5, 0
  la     x12, output_r
  bn.sid x5, 0(x12)

  jal   x1, xof_finish

  ecall


.section .data
.balign 32

stack:
  .zero 4096

/* m（32 B）与 H(ek)（32 B）：app 里分两次 absorb */
.balign 32
input_m:
  .zero 32

.balign 32
input_h_ek:
  .zero 32

.balign 32
output_K:
  .zero 32
.balign 32
output_r:
  .zero 32
