/*
 * Copyright 2026 Hybrid KEM Project Authors. All rights reserved.
 *
 * Test wrapper for kmac_kdf_256 — Hybrid KEM parameters
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

.balign 32
.globl stack
stack:
    .zero 512
stack_end:

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
    .zero 448  /* pad to 512B for phase2 KDK */

.balign 32
.globl kdk_len
kdk_len:
    .word 0x00000040  /* 64 */

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
    .zero 212  /* pad to 256B for phase2 FixedInfo */

.balign 32
.globl fixed_len
fixed_len:
    .word 0x00000029  /* 41 */

.balign 32
.globl okm_len
okm_len:
    .word 0x00000020  /* 32 */

.balign 32
.globl output_okm
output_okm:
    .zero 256
