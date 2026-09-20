/*
 * ver1_1 剖面：decap_verify_cmov（FIPS 203 Alg.18 L9–10，c ≠ c' 时 K ← K̄）
 *
 * 调用段按 ver1_1 的 app（mlkem_decap.s L99–L215）重写 —— ver0_2 的
 * bn.cmp/bn.sel/csrrw 循环在 ver1_1 里不存在，ver1_1 用的是：
 *   拷贝 re_enc_u[i] → 暂存（32 次 bn.lid/bn.sid）
 *   10 WDR（v 段 4 WDR）逐字比较：bn.xor + bn.or 累加到 w11，再 bn.or 进 w12
 *   w12 的 8 个 32-bit 字 OR 归约 → x20
 *   bn.mov 选择 K̄'（w10）或 K_fail（w11）
 *
 * 口径说明：app 里每个多项式的比较前会再跑一次 compress_10 / compress_4；
 * 那 4 次调用归到 decap_pack_ciphertext（reuse 行，来自 encap_pack_ciphertext），
 * 本目标只测"拷贝 + 比较 + 归约 + 选择"，避免 Σ 表重复计数。
 * 比较为定长控制流，数据不影响周期。
 *
 * 与 *_control.s 逐条对应，仅少 loopi 内的比较/归约/选择语句（见 control 头部说明）。
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

  /* w12 = 不匹配累加器 */
  bn.xor w12, w12, w12

  /* ── u 段：3 个多项式 ×（拷贝 32 WDR + 比较 10 WDR）── */
  la   x14, re_enc_u
  la   x15, ct_u
  loopi 3, 18
    /* 拷贝 re_enc_u[i] (1024 B) 到暂存缓冲 */
    addi x2, x14, 0
    la   x3, poly_scratch
    loopi 32, 2
      bn.lid x0, 0(x2++)
      bn.sid x0, 0(x3++)

    /* 比较 10 WDR */
    addi x2, x14, 0
    addi x3, x15, 0
    li   x25, 1
    bn.xor w11, w11, w11
    loopi 10, 4
      bn.lid x0, 0(x2++)
      bn.lid x25, 0(x3++)
      bn.xor w2, w0, w1
      bn.or  w11, w11, w2
      /* End of loop */

    bn.or w12, w12, w11

    addi x14, x14, 1024
    addi x15, x15, 320
    /* End of loop */

  /* ── v 段：拷贝 32 WDR + 比较 4 WDR ── */
  la   x2, re_enc_v
  la   x3, poly_scratch
  loopi 32, 2
    bn.lid x0, 0(x2++)
    bn.sid x0, 0(x3++)

  la   x2, re_enc_v
  la   x3, ct_v
  li   x25, 1
  bn.xor w11, w11, w11
  loopi 4, 4
    bn.lid x0, 0(x2++)
    bn.lid x25, 0(x3++)
    bn.xor w2, w0, w1
    bn.or  w11, w11, w2
    /* End of loop */

  bn.or w12, w12, w11

  /* ── w12 的 8 个 32-bit 字 OR 归约 → x20 ── */
  la   x2, reduce_buf
  li   x25, 12
  bn.sid x25, 0(x2)
  lw    x20, 0(x2)
  addi  x3, x2, 4
  loopi 7, 3
    lw   x21, 0(x3)
    or   x20, x20, x21
    addi x3,  x3, 4
    /* End of loop */

  /* ── 选择 K̄'（w10）或 K_fail（w11）── */
  la   x2, k_bar
  li   x25, 10
  bn.lid x25, 0(x2)
  bn.mov w0, w10
  beq  x20, x0, _select_done
  bn.mov w0, w11
_select_done:

  ecall


.section .data
.balign 32

/* 再加密得到的 u'（app 里是 re_enc_u，1024 B × 3；此处用基址 + 步长 320 比较） */
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
