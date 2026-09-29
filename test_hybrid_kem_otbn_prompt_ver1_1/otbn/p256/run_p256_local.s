/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * Entrypoint for the P-256 ECDH operations of the hybrid-KEM project.
 *
 * ver1_1 本地版（P5）：**只保留本项目用到的两条路径** —— MODE_KEYGEN 与 MODE_ECDH
 * （ver1_1 的 test_p256_only 只调 otcrypto_ecdh_p256_keygen / otcrypto_ecdh_p256）。
 * 其余模式（SIGN / SIGN_CONFIG_K / VERIFY / SIDELOAD_SIGN / SIDELOAD_KEYGEN / SIDELOAD_ECDH
 * / POINTONCRV_CHECK / BASE_POINT_MULT / ARITH_SHARE_SECRET_KEY）的**例程已删**，走到那里会
 * 落到 unimp 硬失败；但**模式常量与全部内存符号保留**（cryptolib 的 p256.c 引用它们，
 * 链接期必须可见）。域乘走本目录的 p256_base.s（bn.p256mul）。
 */

/**
 * Mode magic values, generated with
 * $ ./util/design/sparse-fsm-encode.py -d 6 -m 11 -n 11 \
 *     --avoid-zero -s 380925547
 *
 * Call the same utility with the same arguments and a higher -m to generate
 * additional value(s) without changing the others or sacrificing mutual HD.
 *
 * TODO(#17727): in some places the OTBN assembler support for .equ directives
 * is lacking, so they cannot be used in bignum instructions or pseudo-ops such
 * as `li`. If support is added, we could use 32-bit values here instead of
 * 11-bit.
 */
.equ MODE_KEYGEN, 0x497
.equ MODE_SIGN, 0x734
.equ MODE_SIGN_CONFIG_K, 0x563
.equ MODE_VERIFY, 0x5D8
.equ MODE_ECDH, 0x1AD
.equ MODE_SIDELOAD_KEYGEN, 0x7E
.equ MODE_SIDELOAD_SIGN, 0x64D
.equ MODE_SIDELOAD_ECDH, 0x2F1
.equ MODE_POINTONCRV_CHECK, 0x6AA
.equ MODE_BASE_POINT_MULT, 0x3C6
.equ MODE_ARITH_SHARE_SECRET_KEY, 0x31B

/**
 * Make the mode constants visible to Ibex.
 */
.globl MODE_KEYGEN
.globl MODE_SIGN
.globl MODE_SIGN_CONFIG_K
.globl MODE_VERIFY
.globl MODE_ECDH
.globl MODE_SIDELOAD_KEYGEN
.globl MODE_SIDELOAD_SIGN
.globl MODE_SIDELOAD_ECDH
.globl MODE_POINTONCRV_CHECK
.globl MODE_BASE_POINT_MULT
.globl MODE_ARITH_SHARE_SECRET_KEY

/**
 * Hardened boolean values.
 *
 * Should match the values in `hardened_asm.h`.
 */
.equ HARDENED_BOOL_TRUE, 0x739
.equ HARDENED_BOOL_FALSE, 0x1d4

.section .text.start
.globl start
start:
  /* Read the mode and tail-call the requested operation. */
  la    x2, mode
  lw    x2, 0(x2)

  addi  x3, x0, MODE_KEYGEN
  beq   x2, x3, random_keygen






  /* Copy the caller-provided secret key shares into scratchpad memory.
       dmem[d0] <= dmem[d0_io]
       dmem[d1] <= dmem[d1_io] */
  la       x13, d0_io
  la       x14, d0
  jal      x1, copy_share
  la       x13, d1_io
  la       x14, d1
  jal      x1, copy_share


  addi  x3, x0, MODE_ECDH
  beq   x2, x3, shared_key



  /* Copy the caller-provided secret scalar shares into scratchpad memory.
       dmem[k0] <= dmem[k0_io]
       dmem[k1] <= dmem[k1_io] */
  la       x13, k0_io
  la       x14, k0
  jal      x1, copy_share
  la       x13, k1_io
  la       x14, k1
  jal      x1, copy_share


  /* Invalid mode; fail. */
  unimp
  unimp
  unimp

/**
 * Helper routine to copy secret key shares.
 *
 * Copies 64 bytes from the source to destination location in DMEM. The source
 * and destination may be the same but should not otherwise overlap.
 *
 * @param x13: dptr_src, pointer to source DMEM location
 * @param x14: dptr_dst, pointer to destination DMEM location
 * @param      dmem[dptr_src..dptr_src+64]: source data
 * @param[out] dmem[dptr_dst..dptr_dst+64]: copied data
 *
 * clobbered registers: x10, w10
 * clobbered flag groups: none
 */
copy_share:
  /* Randomize the content of w10 to prevent leakage. */
  bn.wsrr  w10, URND

  /* Copy the secret key shares into Ibex-visible memory. */
  li       x10, 10
  bn.lid   x10, 0(x13)
  bn.sid   x10, 0(x14)
  bn.lid   x10, 32(x13)
  bn.sid   x10, 32(x14)
  ret


/**
 * Generate a fresh, random keypair.
 *
 * @param[out] dmem[d0]: First share of secret key.
 * @param[out] dmem[d1]: Second share of secret key.
 * @param[out]  dmem[x]: Public key x-coordinate.
 * @param[out]  dmem[y]: Public key y-coordinate.
 */
random_keygen:
  /* Generate secret key d in shares.
       dmem[d0] <= d0
       dmem[d1] <= d1 */
  jal      x1, p256_generate_random_key

  /* Generate public key d*G.
       dmem[x] <= (d*G).x
       dmem[y] <= (d*G).y */
  jal      x1, p256_base_mult

  /* Copy the secret key shares into Ibex-visible memory.
       dmem[d0_io] <= dmem[d0]
       dmem[d1_io] <= dmem[d1] */
  la       x13, d0
  la       x14, d0_io
  jal      x1, copy_share
  la       x13, d1
  la       x14, d1_io
  jal      x1, copy_share

  ecall

shared_key:
  /* Validate the public key (ends the program on failure). */
  jal      x1, p256_check_public_key

  /* If we got here the basic validity checks passed, so set `ok` to true. */
  la       x2, ok
  addi     x3, x0, HARDENED_BOOL_TRUE
  sw       x3, 0(x2)

  /* Generate boolean-masked shared key (d*Q).x.
       dmem[x] <= x0
       dmem[y] <= x1 */
  jal      x1, p256_shared_key

  ecall

mode:
  .zero 4

/* Success code for basic validity checks on the public key and signature. */
.globl ok
.balign 4
ok:
  .zero 4

/* Message digest. */
.globl msg
.balign 32
msg:
  .zero 32

/* Signature R. */
.globl r
.balign 32
r:
  .zero 32

/* Signature S. */
.globl s
.balign 32
s:
  .zero 32

/* Public key x-coordinate. */
.globl x
.balign 32
x:
  .zero 32

/* Public key y-coordinate. */
.globl y
.balign 32
y:
  .zero 32

/* Public key z-coordinate. */
.globl z
.balign 32
z:
  .zero 32

/* Private key input/output buffer. */
.globl d0_io
.balign 32
d0_io:
  .zero 64
.globl d1_io
.balign 32
d1_io:
  .zero 64

/* Secret scalar (k) input buffer. */
.globl k0_io
.balign 32
k0_io:
  .zero 64
.globl k1_io
.balign 32
k1_io:
  .zero 64

/* Verification result x_r (aka x_1). */
.globl x_r
.balign 32
x_r:
  .zero 32

/* DRBG output to XOR with key manager seed. */
.globl attestation_additional_seed
.balign 32
attestation_additional_seed:
.zero 64

.section .scratchpad

/* Secret scalar (k) in two shares: k = (k0 + k1) mod n */
.globl k0
.balign 32
k0:
  .zero 64

.globl k1
.balign 32
k1:
  .zero 64

/* Private key (d) in two shares: d = (d0 + d1) mod n. */
.globl d0
.balign 32
d0:
  .zero 64
.globl d1
.balign 32
d1:
  .zero 64
