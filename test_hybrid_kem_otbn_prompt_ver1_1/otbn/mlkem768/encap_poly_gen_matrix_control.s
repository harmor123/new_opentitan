/*
 * ver1_1 对照：encap_poly_gen_matrix（与 profiling 逐条对应，仅少 9 条 jal）
 *
 * Δcycles = encap_poly_gen_matrix_profiling − 本目标。
 */
.section .text.start

.globl main
main:
  /* 与 app（mlkem_encap.s）一致的确定性 WDR 初始化 */
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

  /* 栈指针 x31 ← stack（app 的 crypto_kem_enc 入口同样写法；内核压栈用 0(x31)） */
  la   x31, stack
  bn.xor w31, w31, w31

  /* MOD CSR ← {q = 3329, mu = -q^-1 mod 2^32}，与 app 一致 */
  la   x2, mlkem768_const_params
  bn.lid x0, 0(x2)
  bn.wsrw MOD, w0

  /* 9 个矩阵坐标：A[i][j]，x4 = 行 i，x3 = 列 j */
  la   x2, rho
  la   x5, output_poly

  /* A[0][0] */
  li   x4, 0
  li   x3, 0

  /* A[0][1] */
  li   x4, 0
  li   x3, 1

  /* A[0][2] */
  li   x4, 0
  li   x3, 2

  /* A[1][0] */
  li   x4, 1
  li   x3, 0

  /* A[1][1] */
  li   x4, 1
  li   x3, 1

  /* A[1][2] */
  li   x4, 1
  li   x3, 2

  /* A[2][0] */
  li   x4, 2
  li   x3, 0

  /* A[2][1] */
  li   x4, 2
  li   x3, 1

  /* A[2][2] */
  li   x4, 2
  li   x3, 2

  ecall


.section .data
.balign 32

/*
 * 一个生成的多项式 = 256 系数 × 32 bit = 1024 B。
 * 只测周期，9 次复用同一输出缓冲。
 */
output_poly:
  .zero 1024

/*
 * rho = 真实 ACVP ML-KEM-768 封装密钥 (ek) 的后 32 字节。
 * 内核按 64 B 分配读取，因此这里按 64 B 分配。
 */
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
  .zero 32
