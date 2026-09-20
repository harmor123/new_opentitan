/*
 * ver1_1 剖面：keygen_poly_add（FIPS 203 Alg.13 L18，t = A*s + e）
 *
 * 调用段按 ver1_1 内核约定重写：
 *   poly_add(x2 = a(X), x3 = b(X), x4 = c(X))，每次处理 1 个多项式（1024 B）
 *
 * 口径说明：ver1_1 的 mlkem_keypair.s 把 e 的加法**融进了 basemul_acc 的累加器**
 * （c_in = 预置了 e_hat 的 poly_slot0），app 里没有独立的 poly_add 调用点。
 * 本行测的是同一内核（poly_add）的同等调用次数（3 次，对应 polyvec 的 3 个多项式），
 * 以保持 ver0_1/ver0_2/ver1_1 三版 Σ 表结构可比（口径仍是 Direct）。
 *
 * poly_add 为定长控制流（bn.addvm.8S ×32），周期与数据无关。
 * 与 *_control.s 逐条对应，仅少 3 条 jal。
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

  /* 3 次多项式加法（in-place：c = a + b，c 复用 a 的缓冲） */
  la   x2, result_polyvec
  la   x3, error_polyvec
  add  x4, x0, x2

  jal  x1, poly_add
  jal  x1, poly_add
  jal  x1, poly_add

  ecall


.section .data
.balign 32

/*
 * 3 个多项式 × 1024 B = 3072 B。
 * 定长控制流，零系数足够做周期剖面。
 */
result_polyvec:
  .zero 3072

.balign 32
error_polyvec:
  .zero 3072
