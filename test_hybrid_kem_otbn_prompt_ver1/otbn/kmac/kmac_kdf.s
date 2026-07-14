/* Copyright 2026 Hybrid KEM Project Authors. All rights reserved. */

/*
 * kmac_kdf.s — KMAC-KDF 密钥派生 (NIST SP 800-108r1)
 *
 * OKM = SHAKE#(KDK || FixedInfo, L)
 *
 * FixedInfo = Counter(4B, be32 0x00000001) || Label || 0x00 || Context || L_bits(4B, be32)
 *   (Counter + L_bits 由 test wrapper 在 DMEM 中预编码)
 *
 * 依赖: kmac_xof.s (xof_absorb / xof_process / xof_squeeze32 / xof_finish)
 *
 * API:
 *   kmac_kdf_128 — KDF with SHAKE128 (L128)
 *   kmac_kdf_256 — KDF with SHAKE256 (L256)
 *
 * 调用约定:
 *   x20 = kdk_ptr     (32B-aligned DMEM address)
 *   x21 = kdk_len     (bytes)
 *   x22 = fixed_ptr   (32B-aligned DMEM address, pre-encoded FixedInfo)
 *   x23 = fixed_len   (bytes)
 *   x24 = okm_len     (output bytes, must be multiple of 32)
 *   x3  = okm_ptr     (32B-aligned DMEM output buffer)
 *
 * 破坏: x2, x3, x5-x7, x20-x25, x28-x30, w0, w1, w27-w31, ra
 */

.section .text

.globl kmac_kdf_128
kmac_kdf_128:
    addi    sp, sp, -24
    sw      ra, 20(sp)
    sw      x3,  16(sp)           /* okm_ptr */
    sw      x24, 12(sp)           /* okm_len */
    sw      x22, 8(sp)            /* fixed_ptr */
    sw      x23, 4(sp)            /* fixed_len */
    sw      x21, 0(sp)            /* kdk_len */

    /* Preserve kdk_ptr in x7 before xof_absorb clobbers x20-x22 */
    add     x7, x20, x0           /* x7 = kdk_ptr */

    /* Init SHAKE128 */
    jal     x1, xof_shake128_init

    /* Absorb KDK: xof_absorb(n=x21, ptr=x7, share2=0) */
    add     x20, x21, x0           /* n = kdk_len */
    add     x21, x7, x0            /* ptr = kdk_ptr */
    addi    x22, x0, 0
    jal     x1, xof_absorb

    /* Absorb FixedInfo: xof_absorb(n=fixed_len, ptr=fixed_ptr, share2=0) */
    lw      x20, 4(sp)             /* n = fixed_len */
    lw      x21, 8(sp)             /* ptr = fixed_ptr */
    addi    x22, x0, 0
    jal     x1, xof_absorb

    /* Process */
    jal     x1, xof_process

    /* Squeeze OKM in 32B chunks to DMEM */
    lw      x24, 12(sp)            /* okm_len */
    lw      x3,  16(sp)            /* okm_ptr */
    addi    x5, x0, 29             /* WDR index = w29 */
    beq     x24, x0, _kdf128_done

_kdf128_squeeze:
    jal     x1, xof_squeeze32       /* w29=S0, w30=S1 */
    bn.xor  w29, w29, w30           /* unmask: true = S0 ^ S1 */
    bn.sid  x5, 0(x3++)            /* store w29 to DMEM */
    addi    x24, x24, -32
    bne    x24, x0, _kdf128_squeeze

_kdf128_done:
    jal     x1, xof_finish

    lw      ra, 20(sp)
    addi    sp, sp, 24
    ret


.globl kmac_kdf_256
kmac_kdf_256:
    addi    sp, sp, -24
    sw      ra, 20(sp)
    sw      x3,  16(sp)
    sw      x24, 12(sp)
    sw      x22, 8(sp)
    sw      x23, 4(sp)
    sw      x21, 0(sp)

    add     x7, x20, x0             /* x7 = kdk_ptr */

    jal     x1, xof_shake256_init

    add     x20, x21, x0
    add     x21, x7, x0
    addi    x22, x0, 0
    jal     x1, xof_absorb

    lw      x20, 4(sp)
    lw      x21, 8(sp)
    addi    x22, x0, 0
    jal     x1, xof_absorb

    jal     x1, xof_process

    lw      x24, 12(sp)
    lw      x3,  16(sp)
    addi    x5, x0, 29
    beq     x24, x0, _kdf256_done

_kdf256_squeeze:
    jal     x1, xof_squeeze32       /* w29=S0, w30=S1 */
    bn.xor  w29, w29, w30           /* unmask */
    bn.sid  x5, 0(x3++)
    addi    x24, x24, -32
    bne    x24, x0, _kdf256_squeeze

_kdf256_done:
    jal     x1, xof_finish

    lw      ra, 20(sp)
    addi    sp, sp, 24
    ret
