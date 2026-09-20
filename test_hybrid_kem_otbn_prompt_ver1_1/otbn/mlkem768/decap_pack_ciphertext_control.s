/*
 * ver1_1 剖面（实测行）：decap_pack_ciphertext_control
 * decap 比较前的再压缩：compress_10 ×3（u'）+ compress_4 ×1（v'）。
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

la   x14, ct_u

  .rept 3
  la   x2, poly_u
  addi x3, x14, 0
  addi x14, x14, 320
  .endr

  la   x2, poly_v
  la   x3, ct_v

  ecall


.section .data
.balign 32
poly_u:
  .zero 1024

.balign 32
poly_v:
  .zero 1024

.balign 32
ct_u:
  .zero 960

.balign 32
ct_v:
  .zero 128
