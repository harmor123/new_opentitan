/* Copyright 2026 Hybrid KEM Project Authors. All rights reserved. */

/*
 * kmac_kdf.s — Software KMAC-KDF key derivation (NIST SP 800-108r1)
 *
 * OKM = SHAKE#(KDK || FixedInfo, L)
 *
 * Pure software implementation using sha3_shake.s primitives:
 *   sha3_init / sha3_update / shake_xof / shake_out
 *
 * API (register-based, matches test_hybrid_kem_otbn_prompt_ver1):
 *   kmac_kdf_128 — KDF with SHAKE128
 *   kmac_kdf_256 — KDF with SHAKE256
 *
 * Calling convention:
 *   x20 = kdk_ptr     (32B-aligned DMEM address)
 *   x21 = kdk_len     (bytes)
 *   x22 = fixed_ptr   (32B-aligned DMEM address, pre-encoded FixedInfo)
 *   x23 = fixed_len   (bytes)
 *   x24 = okm_len     (output bytes, multiple of 32)
 *   x3  = okm_ptr     (32B-aligned DMEM output buffer)
 *
 * DMEM labels required (provided by test wrapper):
 *   context   (212B, 32B-aligned) — SHA3 state (from sha3_shake.s)
 *   rc        (24×32B, 32B-aligned) — Keccak round constants
 *
 * Clobbers: x5-x7, x10-x17, x20-x24, x28-x31, w0-w13, w21-w30, w31, ra
 */

.section .text

.globl kmac_kdf_128
kmac_kdf_128:
    addi    sp, sp, -40
    sw      ra, 36(sp)
    sw      x3,  32(sp)          /* okm_ptr */
    sw      x24, 28(sp)          /* okm_len */
    sw      x22, 24(sp)          /* fixed_ptr */
    sw      x23, 20(sp)          /* fixed_len */
    sw      x20, 16(sp)          /* kdk_ptr */
    sw      x21, 12(sp)          /* kdk_len */

    bn.xor  w31, w31, w31        /* all-zero; required by SW SHA3 */

    /* SHAKE128: rsiz = 200 - 2*16 = 168 bytes (rate) */
    la      x10, context
    addi    x11, x0, 16
    jal     x1, sha3_init

    /* Absorb KDK */
    la      x10, context
    lw      x11, 16(sp)
    lw      x12, 12(sp)
    jal     x1, sha3_update

    /* Absorb FixedInfo */
    la      x10, context
    lw      x11, 24(sp)
    lw      x12, 20(sp)
    jal     x1, sha3_update

    /* Apply SHAKE padding + final permutation → enter squeeze phase */
    la      x10, context
    jal     x1, shake_xof

    /* Squeeze OKM to DMEM */
    la      x10, context
    lw      x11, 32(sp)
    lw      x12, 28(sp)
    jal     x1, shake_out

    lw      ra, 36(sp)
    addi    sp, sp, 40
    ret


.globl kmac_kdf_256
kmac_kdf_256:
    addi    sp, sp, -40
    sw      ra, 36(sp)
    sw      x3,  32(sp)
    sw      x24, 28(sp)
    sw      x22, 24(sp)
    sw      x23, 20(sp)
    sw      x20, 16(sp)
    sw      x21, 12(sp)

    bn.xor  w31, w31, w31

    /* SHAKE256: rsiz = 200 - 2*32 = 136 bytes (rate) */
    la      x10, context
    addi    x11, x0, 32
    jal     x1, sha3_init

    la      x10, context
    lw      x11, 16(sp)
    lw      x12, 12(sp)
    jal     x1, sha3_update

    la      x10, context
    lw      x11, 24(sp)
    lw      x12, 20(sp)
    jal     x1, sha3_update

    la      x10, context
    jal     x1, shake_xof

    la      x10, context
    lw      x11, 32(sp)
    lw      x12, 28(sp)
    jal     x1, shake_out

    lw      ra, 36(sp)
    addi    sp, sp, 40
    ret
