/*
 * ver1_1 剖面：keygen_poly_getnoise_eta_1（FIPS 203 Alg.13 L8–15）
 *
 * 调用段按 ver1_1 内核约定重写：
 *   poly_getnoise_eta_1(x2 = 32 B 种子 σ，按 64 B 分配；x3 = nonce N；x4 = 输出多项式)
 *   内核自己把 N 追加到 x2+32，再走 SHAKE256 + CBD 采样。
 *
 * 6 次调用与 mlkem_keypair.s 一致：s 用 N = 0,1,2，e 用 N = 3,4,5。
 * σ 取自真实 ACVP 向量（SHA3-512(d‖0x03) 的后 32 B），与 ver0_2 harness 相同。
 *
 * 与 *_control.s 逐条对应，仅少 6 条 jal。
 */
.section .text.start

.globl main
main:
  /* 与 app（mlkem_keypair.s）一致的确定性 WDR 初始化 */
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

  /* 栈指针 x31 ← stack（app 的 crypto_kem_keypair 入口同样写法；内核压栈用 0(x31)） */
  la   x31, stack
  bn.xor w31, w31, w31

  /* MOD CSR ← {q = 3329, mu = -q^-1 mod 2^32}，与 app 一致 */
  la   x2, mlkem768_const_params
  bn.lid x0, 0(x2)
  bn.wsrw MOD, w0

  /* s[0..2]：N = 0,1,2 */
  la   x2, sigma
  la   x4, out_poly

  li   x3, 0
  jal  x1, poly_getnoise_eta_1

  li   x3, 1
  jal  x1, poly_getnoise_eta_1

  li   x3, 2
  jal  x1, poly_getnoise_eta_1

  /* e[0..2]：N = 3,4,5 */
  li   x3, 3
  jal  x1, poly_getnoise_eta_1

  li   x3, 4
  jal  x1, poly_getnoise_eta_1

  li   x3, 5
  jal  x1, poly_getnoise_eta_1

  ecall


.section .data
.balign 32

/*
 * sigma = SHA3-512(d || 0x03) 的后半段（真实 ACVP 向量）。
 *
 * dac0dd57 b5311d1f 31e4f8d1 1245afe4
 * 7e00c7d1 4106b6d4 c1efd9c3 7531c9a6
 *
 * 内核会覆写偏移 32 处的 nonce 字节，故按 64 B 分配。
 */
sigma:
  .word 0x57ddc0da
  .word 0x1f1d31b5
  .word 0xd1f8e431
  .word 0xe4af4512
  .word 0xd1c7007e
  .word 0xd4b60641
  .word 0xc3d9efc1
  .word 0xa6c93175
  .zero 32

/* 输出多项式 = 256 × 32 bit = 1024 B（6 次复用同一缓冲，只测周期） */
.balign 32
out_poly:
  .zero 1024
