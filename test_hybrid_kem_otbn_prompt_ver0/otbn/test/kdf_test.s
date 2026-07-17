/*
 * Copyright 2026 Hybrid KEM Project Authors. All rights reserved.
 *
 * Test wrapper for kmac_kdf_256 — software SHAKE-based KDF
 *
 * Algorithm: OKM = SHAKE256(KDK || FixedInfo, L)
 *
 * Dependencies: kmac_kdf.s + sha3_shake.s
 *
 * DMEM layout:
 *   kdk_input   (64B)   — KDK = salt(32B) || shared_secret(32B)
 *   fixed_info  (41B)   — FixedInfo = Counter || Label || 0x00 || Context || L_bits
 *   output_okm  (32B)   — expected OKM
 */

.section .text.start

.globl main
main:
    la      x2, stack_end
    addi    x2, x2, -64

    /* kmac_kdf_256(kdk_ptr, kdk_len, fixed_ptr, fixed_len, okm_len, okm_ptr) */
    la      x20, kdk_input
    la      x21, kdk_len
    lw      x21, 0(x21)
    la      x22, fixed_info
    la      x23, fixed_len
    lw      x23, 0(x23)
    la      x24, okm_len
    lw      x24, 0(x24)
    la      x3, output_okm
    jal     x1, kmac_kdf_256

    ecall

.data

/* ---- Stack ---- */

.balign 32
.globl stack
stack:
    .zero 512
stack_end:

/* ---- KDK input (salt || shared_secret) ---- */

.balign 32
.globl kdk_input
kdk_input:
    .word 0x46d7335f
    .word 0x0a6426a3
    .word 0x90949a73
    .word 0x03c115ec
    .word 0x3d9f8672
    .word 0xe8b275e6
    .word 0x1d274257
    .word 0x82ebc918
    .word 0x4aac5037
    .word 0x2763658e
    .word 0xfa81d1c3
    .word 0x4b5502b0
    .word 0x04bed2f6
    .word 0xd528dd75
    .word 0x9fef1bf3
    .word 0xac865f83
    .zero 448  /* pad to 512B for phase2 alignment */

.balign 32
.globl kdk_len
kdk_len:
    .word 0x00000040  /* 64 */

/* ---- FixedInfo (pre-encoded: Counter || Label || 0x00 || Context || L_bits) ---- */

.balign 32
.globl fixed_info
fixed_info:
    .word 0x01000000
    .word 0x62794800
    .word 0x4b646972
    .word 0x762d4d45
    .word 0x6f632d31
    .word 0x7865746e
    .word 0x31302d74
    .word 0x35343332
    .word 0x39383736
    .word 0x01000041
    .word 0x00000000
    .zero 212  /* pad to 256B */

.balign 32
.globl fixed_len
fixed_len:
    .word 0x00000029  /* 41 */

.balign 32
.globl okm_len
okm_len:
    .word 0x00000020  /* 32 */

/* ---- Output ---- */

.balign 32
.globl output_okm
output_okm:
    .zero 256

/* ---- SW SHA3 work buffers (required by sha3_shake.s) ---- */

.balign 32
.globl context
context:
    .zero 212

.balign 32
.globl rc
rc:
  .balign 32
  .dword 0x0000000000000001
  .balign 32
  .dword 0x0000000000008082
  .balign 32
  .dword 0x800000000000808a
  .balign 32
  .dword 0x8000000080008000
  .balign 32
  .dword 0x000000000000808b
  .balign 32
  .dword 0x0000000080000001
  .balign 32
  .dword 0x8000000080008081
  .balign 32
  .dword 0x8000000000008009
  .balign 32
  .dword 0x000000000000008a
  .balign 32
  .dword 0x0000000000000088
  .balign 32
  .dword 0x0000000080008009
  .balign 32
  .dword 0x000000008000000a
  .balign 32
  .dword 0x000000008000808b
  .balign 32
  .dword 0x800000000000008b
  .balign 32
  .dword 0x8000000000008089
  .balign 32
  .dword 0x8000000000008003
  .balign 32
  .dword 0x8000000000008002
  .balign 32
  .dword 0x8000000000000080
  .balign 32
  .dword 0x000000000000800a
  .balign 32
  .dword 0x800000008000000a
  .balign 32
  .dword 0x8000000080008081
  .balign 32
  .dword 0x8000000000008080
  .balign 32
  .dword 0x0000000080000001
  .balign 32
  .dword 0x8000000080008008
