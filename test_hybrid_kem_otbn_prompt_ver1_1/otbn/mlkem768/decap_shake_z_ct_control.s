/*
 * ver1_1 剖面：decap_shake_z_ct（FIPS 203 Alg.18 L9，K̄ = J(z ‖ c) = SHAKE256(z ‖ c, 32)）
 *
 * 调用段与 mlkem_decap.s 的拒绝密钥段逐条一致（同一 KMAC 驱动 API）：
 *   xof_shake256_init
 *   xof_absorb(z_share0, 32, z_share1)   ← z 走掩码吸收通路，与 app 一致
 *   xof_absorb(ct_u,     960, 0)         ← app 把密文拆成 u/v 两段吸收
 *   xof_absorb(ct_v,     128, 0)
 *   xof_process
 *   xof_squeeze32 → w29/w30（布尔共享）→ bn.xor 得 32 B
 *   xof_finish
 *
 * 全部属于被调 API，故 control 只保留 init 之前的操作数准备）。
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


  /* z：share0 为真实值，share1 为 0 份额（app 传 share1 指针 → 走掩码吸收） */
  la   x21, input_z
  la   x22, input_z_share1
  li   x20, 32

  /* ct_u：960 B */
  la   x21, input_ct_u
  li   x20, 960
  li   x22, 0

  /* ct_v：128 B */
  la   x21, input_ct_v
  li   x20, 128
  li   x22, 0


  /* squeeze32 把 32 B 布尔共享字节放进 w29/w30，bn.xor 得到明文输出 */
  bn.xor w11, w29, w30


  ecall


.section .data
.balign 32

/* 隐式拒绝密钥 z（share0 = 真实值，32 B） */
input_z:
  .zero 32

/* z 的第二个份额（全 0，32 B） */
.balign 32
input_z_share1:
  .zero 32

/* 密文 u 段：3 × 320 B = 960 B */
.balign 32
input_ct_u:
  .zero 960

/* 密文 v 段：128 B */
.balign 32
input_ct_v:
  .zero 128
