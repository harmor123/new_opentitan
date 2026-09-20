/*
 * ver1_1 剖面（实测行）：decap_basemul_acc_x15_profiling
 * decap 的 basemul 族：6 次标度 basemul（解密核 3 + 再加密 3）+ 15 次 basemul_acc（解密 3 + 再加密 12）。
 *
 * 本文件由 test_perf/gen_harness.py 生成（--version ver1_1）。
 * 与同 row 的另一个目标逐条对应，仅差调用 —— Δcycles = profiling − control。
 */
.section .text.start

.globl main
main:
  /* 与 app（mlkem_decap.s）一致的确定性 WDR 初始化 */
  bn.xor w0, w0, w0
  bn.xor w1, w1, w1
  bn.xor w2, w2, w2
  bn.xor w3, w3, w3
  bn.xor w4, w4, w4
  bn.xor w5, w5, w5
  bn.xor w6, w6, w6
  bn.xor w7, w7, w7
  bn.xor w8, w8, w8
  bn.xor w9, w9, w9
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

  /* 栈指针 x31 ← stack（app 的 crypto_kem_* 入口同样写法；内核压栈用 0(x31)） */
  la   x31, stack
  bn.xor w31, w31, w31

  /* MOD CSR ← {q = 3329, mu = -q^-1 mod 2^32}，与 app 一致 */
  la   x2, mlkem768_const_params
  bn.lid x0, 0(x2)
  bn.wsrw MOD, w0

la   x4, _basemul_twiddles

  .rept 6
  la   x2, poly_s
  la   x3, keygen_scale_const_2988
  la   x4, _basemul_twiddles
  la   x5, poly_s
  jal  x1, basemul
  .endr

  .rept 5
  la   x2, acc_poly
  bn.xor w0, w0, w0
  loopi 32, 1
    bn.sid x0, 0(x2++)
    /* End of loop */
  la   x2, poly_a
  la   x3, poly_s
  la   x4, _basemul_twiddles
  la   x5, acc_poly
  la   x6, acc_poly
  jal  x1, basemul_acc
  la   x2, poly_a
  la   x3, poly_s
  la   x4, _basemul_twiddles
  la   x5, acc_poly
  la   x6, acc_poly
  jal  x1, basemul_acc
  la   x2, poly_a
  la   x3, poly_s
  la   x4, _basemul_twiddles
  la   x5, acc_poly
  la   x6, acc_poly
  jal  x1, basemul_acc
  .endr

  ecall


.section .data
.balign 32
poly_a:
  .zero 1024

.balign 32
poly_s:
  .zero 1024

.balign 32
acc_poly:
  .zero 1024

.balign 32
keygen_scale_const_2988:
  .rept 32
  .word 0x00000bac, 0x00000000, 0x00000bac, 0x00000000
  .word 0x00000bac, 0x00000000, 0x00000bac, 0x00000000
  .endr
