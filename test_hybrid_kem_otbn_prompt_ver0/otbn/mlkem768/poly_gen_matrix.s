/* Copyright "Towards ML-KEM & ML-DSA on OpenTitan" Authors */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/*
 * Name:        poly_gen_matrix 
 *
 * Description: Run rejection sampling on uniform random bytes to generate
 *              uniform random integers w12 q
 *
 * Arguments:   - int16_t *r: pointer to output buffer
 *              - unsigned int len: requested number of 16-bit integers (uniform w12 q)
 *              - const uint8_t *buf: pointer to input buffer (assumed to be uniformly random bytes)
 *              - unsigned int buflen: length of input buffer in bytes
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: pointer to seed (KYBER_SYMBYTES = 32)
 * @param[in]  x12: i||j (2 bytes)
 * @param[out] x11: dmem pointer to polynomial
 *
 * clobbered registers: x10-x15, x5-x30, w8, w16
 */

.globl poly_gen_matrix
poly_gen_matrix:

  /* 32 byte align the sp */
  andi x15, sp, 31
  beq  x15, x0, _aligned
  sub  sp, sp, x15
_aligned:
  /* save fp to stack, use 32 bytes to keep it 32-byte aligned */
  addi sp, sp, -32
  sw   fp, 0(sp)

  addi fp, sp, 0
  
  /* Adjust sp to accomodate more local variables */
  addi sp, sp, -512

  /* Save values */
  addi x3, x10, 0

  /* Store nonce to memory */
  sw x12, -64(fp)

  .irp reg,x10,x11,x12,x13,x15,x28,x29
    addi sp, sp, -4      /* Decrement stack pointer by 4 bytes */
    sw \reg, 0(sp)      /* Store register value at the top of the stack */
  .endr

  /* Initialize a SHAKE128 operation. */
  la   x10, context
  li   x11, 16
  jal  x1, sha3_init

  la   x10, context
  add  x11, x0, x3 
  li   x12, 32
  jal  x1, sha3_update

  la   x10, context
  add  x11, fp, -64 
  li   x12, 2
  jal  x1, sha3_update

  la   x10, context
  jal  x1, shake_xof

  .irp reg,x29,x28,x15,x13,x12,x11,x10
    lw \reg, 0(sp)      /* Load value from the top of the stack into register */
    addi sp, sp, 4     /* Increment stack pointer by 4 bytes */
  .endr
    
  /* x5 = 508, x11 + 508 is the last valid address */
  addi x5, x11, 512

  /* Compare for flag bits */
  li x16, 3 

  /* For masking coeff with 0xFFF */
  bn.xor w31, w31, w31

  bn.addi w10, w31, 1
  bn.rshi w10, w10, w31 >> 244
  bn.subi w10, w10, 1

  li      x28, 12
  la      x6, modulus_bn
  bn.lid  x28, 0(x6)
  bn.rshi w12, w31, w12 >> 240 /* Only keep w12 in lowest word */


  li x30, 13
  li x28, 16 /* 1 WDR stores 16 coeffs */

  li x31, 0

  /* Loop until 256 coefficients have been written to the output */
_rej_sample_loop:
  .irp reg,x5,x7,x28,x29,x30,x31,x10,x11,x12,x13,x14,x15,x16
    addi sp, sp, -4      /* Decrement stack pointer by 4 bytes */
    sw \reg, 0(sp)      /* Store register value at the top of the stack */
  .endr
  
  /* Preserve WDRs */
  addi x6, fp, -256
  li   x5, 10
  LOOPI 6, 2
    bn.sid x5, 0(x6++)
    addi   x5, x5, 1

  /* First squeeze */
  la     x10, context
  add    x11, fp, -32 
  addi   x12, x0, 32
  jal    x1, shake_out

  addi x6, fp, -256
  li   x5, 10
  LOOPI 6, 2
    bn.lid x5, 0(x6++)
    addi   x5, x5, 1

  li     x6, 8
  bn.lid x6, -32(x8) /* KECCAK_DIGEST */

  .irp reg,x16,x15,x14,x13,x12,x11,x10,x31,x30,x29,x28,x7,x5
    lw \reg, 0(sp)      /* Load value from the top of the stack into register */
    addi sp, sp, 4     /* Increment stack pointer by 4 bytes */
  .endr

  /* With one SHAKE squeeze, we get 32 bytes of data. From this, we can try to
    build 20 coefficients with 3 bytes each two (3 bytes --> 2 coeffs) and are left with 2 bytes
    remainder. We then take the two remaining bytes and one byte from the
    next squeeze operation and try to get another 2 coefficient, leaving us
    with 31 bytes from which we can, again, try to read 20 coefficients and
    are left with 1 byte remainder. From the next 32 bytes, we take 2 bytes
    and try to build 2 coefficients with the remaining 1 byte. Finally, we
    are left with 30 bytes which we can try to turn into 20 coefficients
    without any remainder. lcm(3, 32) = 96, meaning we use 96 bytes of SHAKE
    output each (full) iteration of the main loop. In case we reach the
    target amount of coefficients, we jump to _end_rej_sample_loop and exit. */

  jal        x1, _poly_uniform_inner_loop /* Process floor(32 bytes / 3 bytes) * 3 bytes = 30 bytes */
  beq        x11, x5, _end_rej_sample_loop /* Check if we have finished in the previous loop */

  /* 2 bytes of first squeeze + 1 byte of second squeeze */
  bn.rshi    w11, w8, w31 >> 16     /* Move remaining 2 bytes to the top of w11 */
  
  .irp reg,x5,x7,x28,x29,x30,x31,x10,x11,x12,x13,x14,x15,x16
    addi sp, sp, -4      /* Decrement stack pointer by 4 bytes */
    sw \reg, 0(sp)      /* Store register value at the top of the stack */
  .endr
  
  /* Preserve WDRs */
  addi x6, fp, -256
  li   x5, 10
  LOOPI 6, 2
    bn.sid x5, 0(x6++)
    addi   x5, x5, 1

  /* First squeeze */
  la     x10, context
  add    x11, fp, -32 
  addi   x12, x0, 32
  jal    x1, shake_out

  addi x6, fp, -256
  li   x5, 10
  LOOPI 6, 2
    bn.lid x5, 0(x6++)
    addi   x5, x5, 1

  li     x6, 8
  bn.lid x6, -32(x8) /* KECCAK_DIGEST */

  .irp reg,x16,x15,x14,x13,x12,x11,x10,x31,x30,x29,x28,x7,x5
    lw \reg, 0(sp)      /* Load value from the top of the stack into register */
    addi sp, sp, 4     /* Increment stack pointer by 4 bytes */
  .endr

  bn.rshi    w11, w8, w11 >> 240   /* Get one more byte from new shake data*/
  bn.rshi    w8, w31, w8 >> 8 /* Shift out used byte in w8 */

  /* mask candidate */
  bn.and     w16, w10, w11
  bn.cmp     w16, w12
  csrrs      x14, 0x7C0, x0       /* Read flags */
  andi       x14, x14, 3 /* Mask flags */
  bne        x14, x16, _skip_store2a /* Reject if M, C are NOT set to 1, meaning NOT (q > w11) = (q <= w11) */
  bn.rshi    w13, w16, w13 >> 16
  addi       x31, x31, 1
  bne        x31, x28, _skip_store2a
  bn.sid     x30, 0(x11++) /* Store to memory */
  li         x31, 0
  /* if we have written the last coefficient, exit */
  beq        x11, x5, _end_rej_sample_loop
_skip_store2a:
  bn.rshi    w11, w31, w11 >> 12
  bn.and     w11, w10, w11
  bn.cmp     w11, w12
  csrrs      x14, 0x7C0, x0      /* Read flags */
  andi       x14, x14, 3 /* Mask flags */
  bne        x14, x16, _skip_store2
  bn.rshi    w13, w11, w13 >> 16
  addi       x31, x31, 1
  bne        x31, x28, _skip_store2
  bn.sid     x30, 0(x11++) /* Store to memory */
  li         x31, 0

  /* if we have written the last coefficient, exit */
  beq        x11, x5, _end_rej_sample_loop
_skip_store2:
  jal        x1, _poly_uniform_inner_loop /* Process floor(31/3)*3 = 30 bytes */
  beq        x11, x5, _end_rej_sample_loop /* Check if we have finished in the previous loop */

  /* 1 byte of second squeeze + 2 bytes of third squeeze */
  bn.rshi    w11, w8, w31 >> 8       /* move remaining 1 byte to the top of w11 */
  
  .irp reg,x5,x7,x28,x29,x30,x31,x10,x11,x12,x13,x14,x15,x16
    addi sp, sp, -4      /* Decrement stack pointer by 4 bytes */
    sw \reg, 0(sp)      /* Store register value at the top of the stack */
  .endr
  
  /* Preserve WDRs */
  addi x6, fp, -256
  li   x5, 10
  LOOPI 6, 2
    bn.sid x5, 0(x6++)
    addi   x5, x5, 1

  /* First squeeze */
  la     x10, context
  add    x11, fp, -32 
  addi   x12, x0, 32
  jal    x1, shake_out

  addi x6, fp, -256
  li   x5, 10
  LOOPI 6, 2
    bn.lid x5, 0(x6++)
    addi   x5, x5, 1

  li     x6, 8
  bn.lid x6, -32(x8) /* KECCAK_DIGEST */

  .irp reg,x16,x15,x14,x13,x12,x11,x10,x31,x30,x29,x28,x7,x5
    lw \reg, 0(sp)      /* Load value from the top of the stack into register */
    addi sp, sp, 4     /* Increment stack pointer by 4 bytes */
  .endr

  bn.rshi    w11, w8, w11 >> 248    /* Get one 2 more bytes from new shake data */
  bn.rshi    w8, w31, w8 >> 16 /* Shift out used 2 bytes */

  /* mask candidate */
  bn.and     w16, w10, w11
  bn.cmp     w16, w12
  csrrs      x14, 0x7C0, x0       /* Read flags */
  andi       x14, x14, 3 /* Mask flags */
  bne        x14, x16, _skip_store4a /* Reject if M, C are NOT set to 1, meaning NOT (q > w11) = (q <= w11) */
  bn.rshi    w13, w16, w13 >> 16
  addi       x31, x31, 1
  bne        x31, x28, _skip_store4a
  bn.sid     x30, 0(x11++) /* Store to memory */
  li         x31, 0
  /* if we have written the last coefficient, exit */
  beq        x11, x5, _end_rej_sample_loop
_skip_store4a:
  bn.rshi    w11, w31, w11 >> 12
  bn.and     w11, w10, w11
  bn.cmp     w11, w12
  csrrs      x14, 0x7C0, x0      /* Read flags */
  andi       x14, x14, 3 /* Mask flags */
  bne        x14, x16, _skip_store4
    
  bn.rshi    w13, w11, w13 >> 16
  addi       x31, x31, 1
  bne        x31, x28, _skip_store4
  bn.sid     x30, 0(x11++) /* Store to memory */
  li         x31, 0
  /* if we have written the last coefficient, exit */
  beq        x11, x5, _end_rej_sample_loop
_skip_store4:
  jal        x1, _poly_uniform_inner_loop /* Process floor(30/3)*3 = 30 bytes */
  beq        x11, x5, _end_rej_sample_loop /* Check if we have finished in the previous loop */

  /* No remainder! Start all over again. */
  beq        x0, x0, _rej_sample_loop
_end_rej_sample_loop:
  addi       sp, fp, 0 /* sp <- fp */
  lw         fp, 0(sp)   /* Pop ebp */
  addi       sp, sp, 32
  add        sp, sp, x15 /* Correct alignment offset (unalign) */

  ret

_poly_uniform_inner_loop:

  addi sp, sp, -4
  sw   x29, 0(sp)

  li x29, 1
  LOOPI 20, 12
    beq        x11, x5, _skip_store1

    /* Get the candidate coefficient, multiplied by 2 (see below) */
    bn.and     w11, w10, w8 
    bn.cmp     w11, w12
    csrrs      x14, 0x7C0, x0 /* Read flags */

    /* Z L M C */
    andi x14, x14, 3
    bne        x14, x16, _skip_store1 /* Reject if M, C are NOT set to 1, meaning NOT (q > w11) = (q <= w11) */
    bn.rshi    w13, w11, w13 >> 16
    addi       x31, x31, 1
    bne        x31, x28, _skip_store1 /* Accumulator not full yet */

    bn.sid     x30, 0(x11++)                      /* Store to memory */
    li         x31, 0
_skip_store1:
    /* Shift out the 12 bits we have read for the next potential coefficient */
    bn.rshi    w8, w31, w8 >> 12
  lw   x29, 0(sp)
  addi sp, sp, 4
  ret


