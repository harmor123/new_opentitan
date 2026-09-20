/*
 * ver1_1 剖面：encap_unpack_pk（FIPS 203 Alg.14 L2–3 + §7.2 输入校验）
 *
 * 调用段按 ver1_1 的 app 复刻（ver0_2 的 unpack_pk 内核自带反序列化，
 * ver1_1 拆成 unpack_pk + poly_frombytes，故本行含三部分）：
 *   1) unpack_pk(ek 1184 B → pk_t 1152 B + rho 32 B)
 *   2) _pk_bounds_ok：3 × poly_frombytes(pk_t[i] 384 B → 多项式 1024 B)
 *      + 每个多项式 32 WDR 的 3328 范围检查（bn.subv/bn.shv/bn.or 累加）
 *   3) _encrypt_core 内的 t_hat 解码：3 × poly_frombytes（384 B → 1024 B）
 * 三项合计 6 次 poly_frombytes，与 app 在 encap 侧的解包总次数一致
 * （decap 的 6 次由 reuse 行 decap_unpack_sk_pk 覆盖，factor 1）。
 *
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

  /* 1) 拆包 ek → pk_t, rho */
  la   x10, packed_pk
  la   x12, pk_t_out
  la   x13, rho_out

  /* 2) 公钥系数范围检查（app: _pk_bounds_ok） */
  la     x2, const_3328_vec
  li     x20, 28
  bn.lid x20, 0(x2)              /* w28 = [3328, 3328, ...] */
  bn.xor w27, w27, w27           /* 溢出累加器 */

  la     x14, pk_t_out
  la     x15, poly_scratch
  loopi 3, 9
    addi x2, x14, 0
    addi x3, x15, 0
    addi x2, x15, 0
    loopi 32, 4
      bn.lid x0, 0(x2++)
      bn.subv.8S w0, w28, w0
      bn.shv.8S  w0, w0 >> 31
      bn.or      w27, w27, w0
      /* End of loop */
    addi x14, x14, 384
    /* End of loop */

  bn.cmp w27, w31, FG0
  csrrs x2, FG0, x0
  andi  x2, x2, 8

  /* 3) t_hat 解码（app: _encrypt_core，3 个多项式） */
  la     x14, pk_t_out
  la     x15, poly_scratch
  loopi 3, 5
    addi x2, x14, 0
    addi x3, x15, 0
    addi x14, x14, 384
    addi x15, x15, 1024
    addi x16, x16, 1
    /* End of loop */

  ecall


.section .data
.balign 32

/* 源 ek：3 × 384 B + 32 B rho = 1184 B（定长控制流，零值足够测周期） */
packed_pk:
  .zero 1184

/* 目标 pk_t：1152 B */
.balign 32
pk_t_out:
  .zero 1152

/* 目标 rho：32 B */
.balign 32
rho_out:
  .zero 32

/* 解包暂存多项式：1024 B */
.balign 32
poly_scratch:
  .zero 1024

/* 范围检查常数：[3328] × 8 */
.balign 32
const_3328_vec:
  .word 3328, 3328, 3328, 3328, 3328, 3328, 3328, 3328
