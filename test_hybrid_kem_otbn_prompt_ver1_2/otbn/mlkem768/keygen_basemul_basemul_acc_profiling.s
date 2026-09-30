/*
 * ver1_1 剖面：keygen_basemul_basemul_acc（FIPS 203 Alg.13 L18，t_hat = A∘s_hat + e_hat）
 *
 * 调用段按 ver1_1 内核约定重写（ver0_2 的 x10/x11/x13/x28/x29 不适用）：
 *   basemul_acc(x2 = a(X), x3 = b(X), x4 = γ 旋转因子表, x5 = c_in(X), x6 = c_out(X))
 *   γ 表用 ntt.s 里的 _basemul_twiddles（app 用的就是它）
 *
 * 与 mlkem_keypair.s 的 _indcpa_row_loop/_indcpa_col_loop 一致：
 *   每行先把累加器清零（32 WDR），再 3 次 basemul_acc；3 行共 9 次。
 *   e_hat[i] 在 app 里预置在累加器中（e 的加法融进 basemul_acc），此处以清零累加器复刻。
 *
 * 与 *_control.s 逐条对应，仅少 9 条 jal（+ 清零段的 loopi 相同）。
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

  la   x4, _basemul_twiddles

  /* ── app（_indcpa_sample_s_loop）：s_hat[j] 缩放到 Montgomery 域（× 2988），basemul ×3 ── */
  la   x2, poly_s_hat
  la   x3, keygen_scale_const_2988
  la   x4, _basemul_twiddles
  la   x5, poly_s_hat
  jal  x1, basemul

  la   x2, poly_s_hat
  la   x3, keygen_scale_const_2988
  la   x4, _basemul_twiddles
  la   x5, poly_s_hat
  jal  x1, basemul

  la   x2, poly_s_hat
  la   x3, keygen_scale_const_2988
  la   x4, _basemul_twiddles
  la   x5, poly_s_hat
  jal  x1, basemul

  /* ── i = 0 ── 清零累加器（app: _indcpa_row_loop 开头） */
  la   x2, acc_poly
  bn.xor w0, w0, w0
  loopi 32, 1
    bn.sid x0, 0(x2++)
    /* End of loop */

  la   x2, poly_a
  la   x3, poly_s_hat
  la   x5, acc_poly
  la   x6, acc_poly
  jal  x1, basemul_acc
  la   x2, poly_a
  la   x3, poly_s_hat
  la   x5, acc_poly
  la   x6, acc_poly
  jal  x1, basemul_acc
  la   x2, poly_a
  la   x3, poly_s_hat
  la   x5, acc_poly
  la   x6, acc_poly
  jal  x1, basemul_acc

  /* ── i = 1 ── */
  la   x2, acc_poly
  bn.xor w0, w0, w0
  loopi 32, 1
    bn.sid x0, 0(x2++)
    /* End of loop */

  la   x2, poly_a
  la   x3, poly_s_hat
  la   x5, acc_poly
  la   x6, acc_poly
  jal  x1, basemul_acc
  la   x2, poly_a
  la   x3, poly_s_hat
  la   x5, acc_poly
  la   x6, acc_poly
  jal  x1, basemul_acc
  la   x2, poly_a
  la   x3, poly_s_hat
  la   x5, acc_poly
  la   x6, acc_poly
  jal  x1, basemul_acc

  /* ── i = 2 ── */
  la   x2, acc_poly
  bn.xor w0, w0, w0
  loopi 32, 1
    bn.sid x0, 0(x2++)
    /* End of loop */

  la   x2, poly_a
  la   x3, poly_s_hat
  la   x5, acc_poly
  la   x6, acc_poly
  jal  x1, basemul_acc
  la   x2, poly_a
  la   x3, poly_s_hat
  la   x5, acc_poly
  la   x6, acc_poly
  jal  x1, basemul_acc
  la   x2, poly_a
  la   x3, poly_s_hat
  la   x5, acc_poly
  la   x6, acc_poly
  jal  x1, basemul_acc

  ecall


.section .data
.balign 32

/* NTT 域多项式 = 256 × 32 bit = 1024 B（3 个缓冲，只测周期） */
poly_a:
  .zero 1024

.balign 32
poly_s_hat:
  .zero 1024

.balign 32
acc_poly:
  .zero 1024

/* Montgomery 缩放常数：每 lane 2988（= 2^64 mod q），与 app 的
 * keygen_scale_const_2988（由 const_2988_wdr 拷 32 个 WDR）逐字一致 */
.balign 32
keygen_scale_const_2988:
  .rept 32
  .word 0x00000bac, 0x00000000, 0x00000bac, 0x00000000
  .word 0x00000bac, 0x00000000, 0x00000bac, 0x00000000
  .endr
