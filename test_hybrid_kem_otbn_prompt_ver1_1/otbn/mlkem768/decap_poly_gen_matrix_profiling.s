/*
 * ver1_1 剖面：decap_poly_gen_matrix（FIPS 203 Alg.18 L8 → Alg.14 L4–8 / Alg.7）
 *
 * 口径：Exact-real-input —— 9 个真实矩阵坐标，rho 取自真实 ACVP ek 的后 32 字节。
 *
 * 调用段按 ver1_1 内核约定重写（ver0_2 的 x10/x11/x12 + 单条 j||i 编码不适用）：
 *   poly_gen_matrix(x2 = rho(64 B 分配), x3 = 列 j, x4 = 行 i, x5 = 输出多项式)
 * 顺序与 mlkem_decap.s 的两层循环一致：i 外层、j 内层。
 *
 * 与 *_control.s 逐条对应，仅少 9 条 jal（Δcycles = profiling − control）。
 */
.section .text.start

.globl main
main:
  /* 与 app（mlkem_decap.s）一致的确定性 WDR 初始化 */
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

  /* 栈指针 x31 ← stack（app 的 crypto_kem_dec 入口同样写法；内核压栈用 0(x31)） */
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
  jal  x1, poly_gen_matrix

  /* A[0][1] */
  li   x4, 0
  li   x3, 1
  jal  x1, poly_gen_matrix

  /* A[0][2] */
  li   x4, 0
  li   x3, 2
  jal  x1, poly_gen_matrix

  /* A[1][0] */
  li   x4, 1
  li   x3, 0
  jal  x1, poly_gen_matrix

  /* A[1][1] */
  li   x4, 1
  li   x3, 1
  jal  x1, poly_gen_matrix

  /* A[1][2] */
  li   x4, 1
  li   x3, 2
  jal  x1, poly_gen_matrix

  /* A[2][0] */
  li   x4, 2
  li   x3, 0
  jal  x1, poly_gen_matrix

  /* A[2][1] */
  li   x4, 2
  li   x3, 1
  jal  x1, poly_gen_matrix

  /* A[2][2] */
  li   x4, 2
  li   x3, 2
  jal  x1, poly_gen_matrix

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
 * 内核用 bn.lid 读 32 B，并按内核约定在偏移 32 处自己追加 j||i，
 * 因此这里按 64 B 分配。
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
