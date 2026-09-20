/*
 * ver1_1 对照：decap_verify_cmov（与 profiling 相同的操作数准备与循环骨架，
 *                 但不做比较、不做 OR 归约、不做选择）
 *
 * Δcycles = decap_verify_cmov_profiling − 本目标。
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

  /* 栈指针 x31 ← stack（app 的 crypto_kem_dec 入口同样写法） */
  la   x31, stack
  bn.xor w31, w31, w31

  /* 与 profiling 相同的操作数准备，但不做比较/归约/选择 */
  bn.xor w12, w12, w12

  la   x14, re_enc_u
  la   x15, ct_u
  loopi 3, 12
    addi x2, x14, 0
    la   x3, poly_scratch
    loopi 32, 2
      bn.lid x0, 0(x2++)
      bn.sid x0, 0(x3++)

    addi x2, x14, 0
    addi x3, x15, 0
    li   x25, 1
    bn.xor w11, w11, w11

    addi x14, x14, 1024
    addi x15, x15, 320
    /* End of loop */

  la   x2, re_enc_v
  la   x3, poly_scratch
  loopi 32, 2
    bn.lid x0, 0(x2++)
    bn.sid x0, 0(x3++)

  la   x2, re_enc_v
  la   x3, ct_v
  li   x25, 1
  bn.xor w11, w11, w11

  la   x2, reduce_buf
  li   x25, 12
  bn.sid x25, 0(x2)
  lw    x20, 0(x2)
  addi  x3, x2, 4

  la   x2, k_bar
  li   x25, 10
  bn.lid x25, 0(x2)

  ecall


.section .data
.balign 32

/* 再加密得到的 u'（app 里是 re_enc_u，1024 B × 3） */
re_enc_u:
  .zero 3072

/* 再加密得到的 v'（1024 B） */
.balign 32
re_enc_v:
  .zero 1024

/* 输入密文 u 段（3 × 320 B）与 v 段（128 B） */
.balign 32
ct_u:
  .zero 960

.balign 32
ct_v:
  .zero 128

/* 拷贝暂存（1024 B） */
.balign 32
poly_scratch:
  .zero 1024

/* OR 归约的中转（32 B） */
.balign 32
reduce_buf:
  .zero 32

/* K̄'（app 里是 _seed_buf[32..63]，32 B） */
.balign 32
k_bar:
  .zero 32
