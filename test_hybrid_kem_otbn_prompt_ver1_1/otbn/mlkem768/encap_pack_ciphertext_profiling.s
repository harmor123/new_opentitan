/*
 * ver1_1 剖面：encap_pack_ciphertext（FIPS 203 Alg.14 L22–24，c = Compress_u(v) ‖ Compress_v(w)）
 *
 * 阶段映射说明：ver1_1 的内核把 ver0_2 的单块 pack_ciphertext 拆成了
 *   compress_10（u，每多项式 320 B）+ compress_4（v，128 B），
 * 压缩结果直接写进密文缓冲（app 里没有单独的 encode 步骤）。
 * 因此本目标用 ver1_1 的等价序列替换，**阶段名照旧**（Σ 表结构不变）：
 *   compress_10(x2 = 多项式, x3 = 目标压缩字节)，×3
 *   compress_4 (x2 = 多项式, x3 = 目标压缩字节)，×1
 *   两者都是原地压缩（输入多项式被覆盖）。
 *
 * 调用段与 mlkem_encap.s 的 _encrypt_compress_u / _encrypt_compress_v 逐字一致。
 * 与 *_control.s 逐条对应，仅少 4 条 jal。
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

  /* u[0..2] = compress_10(...) -> ct_u + i*320 */
  la   x2, poly_u
  la   x3, ct_u
  jal  x1, compress_10

  la   x2, poly_u
  la   x3, ct_u
  addi x3, x3, 320
  jal  x1, compress_10

  la   x2, poly_u
  la   x3, ct_u
  addi x3, x3, 640
  jal  x1, compress_10

  /* v = compress_4(...) -> ct_v（128 B） */
  la   x2, poly_v
  la   x3, ct_v
  jal  x1, compress_4

  ecall


.section .data
.balign 32

/* NTT 域多项式 = 256 × 32 bit = 1024 B（原地压缩，3 次复用同一缓冲） */
poly_u:
  .zero 1024

.balign 32
poly_v:
  .zero 1024

/* 密文 u 段：3 × 320 B = 960 B */
.balign 32
ct_u:
  .zero 960

/* 密文 v 段：128 B */
.balign 32
ct_v:
  .zero 128
