/*
 * ver1_1 剖面：keygen_pack_pk（FIPS 203 Alg.13 L19，ek = pk_t ‖ rho）
 *
 * 调用段按 ver1_1 的 app 复刻：keygen 先把 t_hat[i] 用 poly_tobytes 序列化进 pk_t
 * （_indcpa_row_loop 末尾，3 次），再由 pack_pk 拼成 ek。
 *   poly_tobytes(x2 = 多项式 1024 B, x3 = 目标 384 B 序列化缓冲)  ×3
 *   pack_pk     (x10 = pk_t, x11 = rho, x13 = ek 1184 B)        ×1
 * ver0_2 的 pack_pk 内核自带序列化，ver1_1 拆成两个内核 ⇒ 本行含两部分，
 * 与 ver0_2 的 "pack_pk" 行语义对齐。
 *
 * 与 *_control.s 逐条对应，仅少 4 条 jal。
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

  /* t_hat[i] → pk_t + i*384（app：_indcpa_row_loop 末尾） */
  la   x2, src_poly
  la   x3, input_pk
  jal  x1, poly_tobytes

  la   x2, src_poly
  la   x3, input_pk
  addi x3, x3, 384
  jal  x1, poly_tobytes

  la   x2, src_poly
  la   x3, input_pk
  addi x3, x3, 768
  jal  x1, poly_tobytes

  /* ek = pk_t ‖ rho */
  la   x10, input_pk
  la   x11, pk_rho
  la   x13, output_pk
  jal  x1, pack_pk

  ecall


.section .data
.balign 32

/* 源 t_hat[i]（256 × 32 bit = 1024 B，定长控制流，零值足够测周期） */
src_poly:
  .zero 1024

/* 目标 pk_t：3 × 384 B 序列化 = 1152 B */
.balign 32
input_pk:
  .zero 1152

/* 源 rho：32 B */
.balign 32
pk_rho:
  .zero 32

/* 目标 ek = pk_t ‖ rho = 1184 B */
.balign 32
output_pk:
  .zero 1184
