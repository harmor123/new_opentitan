/*
 * Name:        poly_gen_matrix
 *
 * Description: Run rejection sampling on uniform random bytes to generate
 *              uniform random integers mod q
 *
 * Arguments:   - int16_t *r: pointer to output buffer
 *              - unsigned int len: requested number of 16-bit integers (uniform mod q)
 *              - const uint8_t *buf: pointer to input buffer (assumed to be uniformly random bytes)
 *              - unsigned int buflen: length of input buffer in bytes
 *
 * Flags: Clobbers FG0, has no meaning beyond the scope of this subroutine.
 *
 * @param[in]  x10: pointer to seed (KYBER_SYMBYTES = 32)
 * @param[in]  x12: i||j (2 bytes)
 * @param[out] x11: dmem pointer to polynomial
 *
 * clobbered registers: x5-x7, x10-x16, x18-x21, w0-w1, w8-w14, w31
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

  /* Adjust sp to accomodate local variables:
   *   fp - 32: squeeze output buffer (xof_squeeze32 writes 32 bytes: fp-32..fp-1)
   *   fp - 36: x11 save (output pointer)
   *   fp - 40: x10 save (seed pointer)
   *   fp - 44: x5 save (end address, during squeeze)
   *   fp - 64: nonce (2 bytes)
   *   fp - 96: w10 save area (coeff_mask, 32 bytes)
   * CRITICAL: all GPR saves MUST be below fp-32 to avoid squeeze overwrite.
   */
  addi sp, sp, -128

  /* Save x29 (clobbered by xof_shake128_init) */
  sw   x29, -48(fp)
  /* Save x11 (output pointer) */
  sw   x11, -36(fp)

  /* Store nonce to memory */
  sw   x12, -64(fp)

  /* ─── Initialize SHAKE128 via kmac_xof.s ISPR interface ─── */
  /* Save x10 (seed pointer) */
  sw   x10, -40(fp)

  jal   x1, xof_shake128_init

  /* Send seed (32 bytes) */
  lw    x21, -40(fp)     /* Restore seed pointer */
  addi  x20, x0, 32
  addi  x22, x0, 0
  jal   x1, xof_absorb

  /* Send nonce (2 bytes) */
  addi  x21, fp, -64     /* Nonce address */
  addi  x20, x0, 2
  addi  x22, x0, 0
  jal   x1, xof_absorb

  jal   x1, xof_process

  /* Restore x11 (output pointer) */
  lw    x11, -36(fp)

  /* t0 = 508, a1 + 508 is the last valid address */
  addi x5, x11, 512

  /* Compare for flag bits */
  li x16, 3

  /* For masking coeff with 0xFFF */
  bn.xor w31, w31, w31
  bn.addi w10, w31, 1
  bn.rshi w10, w10, w31 >> 244
  bn.subi w10, w10, 1

  li      x18, 12
  la      x6, modulus_bn
  bn.lid  x18, 0(x6)
  bn.rshi w12, w31, w12 >> 240 /* Only keep mod in lowest word */

  li x20, 13
  li x18, 16 /* 1 WDR stores 16 coeffs */
  li x21, 0
  addi x7, x0, 29             /* WDR index for bn.sid (constant, hoisted) */

  /* Loop until 256 coefficients have been written to the output */
_rej_sample_loop:
  /* ─── Save live registers before squeeze ───
   * MUST preserve: x5 (end address), w10 (coeff_mask)
   * x11 is SAFE (not touched by xof_squeeze32)
   */
  sw   x5, -44(fp)       /* Save end address */

  /* Save w10 (coeff_mask) to fp-96.
   * Use x6 (WDR index for bn.sid store)
   * Use x13 (base addr, free throughout) */
  addi x13, fp, -96
  li   x6, 10
  bn.sid x6, 0(x13)

  /* Squeeze — block boundaries handled automatically */
  jal   x1, xof_squeeze32
  bn.xor w29, w29, w30
  addi  x6, fp, -32
  bn.sid x7, 0(x6)

  /* Restore w10 (coeff_mask) */
  addi x13, fp, -96
  li   x6, 10
  bn.lid x6, 0(x13)

  /* Load digest into w8 (shake_reg) */
  li    x6, 8
  bn.lid x6, -32(x8)

  /* Restore x5 (end address) */
  lw    x5, -44(fp)

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

  /* ─── Second squeeze ─── */
  sw   x5, -44(fp)
  addi x13, fp, -96
  li   x6, 10
  bn.sid x6, 0(x13)

  jal  x1, xof_squeeze32
  bn.xor w29, w29, w30
  addi  x6, fp, -32
  bn.sid x7, 0(x6)

  addi x13, fp, -96
  li   x6, 10
  bn.lid x6, 0(x13)

  li    x6, 8
  bn.lid x6, -32(x8)
  lw    x5, -44(fp)

  bn.rshi    w11, w8, w11 >> 240   /* Get one more byte from new shake data*/
  bn.rshi    w8, w31, w8 >> 8 /* Shift out used byte in w8 */

  /* mask candidate */
  bn.and     w14, w10, w11
  bn.cmp     w14, w12
  csrrs      x14, 0x7C0, x0       /* Read flags */
  andi       x14, x14, 3 /* Mask flags */
  bne        x14, x16, _skip_store2a /* Reject if M, C are NOT set to 1, meaningNOT (q > cand) = (q <= cand) */
  bn.rshi    w13, w14, w13 >> 16
  addi       x21, x21, 1
  bne        x21, x18, _skip_store2a
  bn.sid     x20, 0(x11++) /* Store to memory */
  li         x21, 0
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
  addi       x21, x21, 1
  bne        x21, x18, _skip_store2
  bn.sid     x20, 0(x11++) /* Store to memory */
  li         x21, 0

  /* if we have written the last coefficient, exit */
  beq        x11, x5, _end_rej_sample_loop
_skip_store2:
  jal        x1, _poly_uniform_inner_loop /* Process floor(31/3)*3 = 30 bytes */
  beq        x11, x5, _end_rej_sample_loop /* Check if we have finished in the previous loop */

  /* 1 byte of second squeeze + 2 bytes of third squeeze */
  bn.rshi    w11, w8, w31 >> 8       /* move remaining 1 byte to the top of w11 */

  /* ─── Third squeeze ─── */
  sw   x5, -44(fp)
  addi x13, fp, -96
  li   x6, 10
  bn.sid x6, 0(x13)

  jal  x1, xof_squeeze32
  bn.xor w29, w29, w30
  addi  x6, fp, -32
  bn.sid x7, 0(x6)

  addi x13, fp, -96
  li   x6, 10
  bn.lid x6, 0(x13)

  li    x6, 8
  bn.lid x6, -32(x8)
  lw    x5, -44(fp)

  bn.rshi    w11, w8, w11 >> 248    /* Get one 2 more bytes from new shake data */
  bn.rshi    w8, w31, w8 >> 16 /* Shift out used 2 bytes */

  /* mask candidate */
  bn.and     w14, w10, w11
  bn.cmp     w14, w12
  csrrs      x14, 0x7C0, x0       /* Read flags */
  andi       x14, x14, 3 /* Mask flags */
  bne        x14, x16, _skip_store4a /* Reject if M, C are NOT set to 1, meaning NOT (q > cand) = (q <= cand) */
  bn.rshi    w13, w14, w13 >> 16
  addi       x21, x21, 1
  bne        x21, x18, _skip_store4a
  bn.sid     x20, 0(x11++) /* Store to memory */
  li         x21, 0
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
  addi       x21, x21, 1
  bne        x21, x18, _skip_store4
  bn.sid     x20, 0(x11++) /* Store to memory */
  li         x21, 0
  /* if we have written the last coefficient, exit */
  beq        x11, x5, _end_rej_sample_loop
_skip_store4:
  jal        x1, _poly_uniform_inner_loop /* Process floor(30/3)*3 = 30 bytes */
  beq        x11, x5, _end_rej_sample_loop /* Check if we have finished in the previous loop */

  /* No remainder! Start all over again. */
  beq        x0, x0, _rej_sample_loop
_end_rej_sample_loop:

  /* Release KMAC hardware */
  jal  x1, xof_finish

  lw         x29, -48(fp) /* restore x29 */
  addi       sp, fp, 0 /* sp <- fp */
  lw         fp, 0(sp)   /* Pop fp */
  addi       sp, sp, 32
  add        sp, sp, x15 /* Correct alignment offset (unalign) */

  ret

_poly_uniform_inner_loop:
  li x19, 1
  LOOPI 20, 12
    beq        x11, x5, _skip_store1

    /* Get the candidate coefficient, multiplied by 2 (see below) */
    bn.and     w11, w10, w8
    bn.cmp     w11, w12
    csrrs      x14, 0x7C0, x0 /* Read flags */

    /* Z L M C */
    andi x14, x14, 3
    bne        x14, x16, _skip_store1 
    bn.rshi    w13, w11, w13 >> 16
    addi       x21, x21, 1
    bne        x21, x18, _skip_store1 /* Accumulator not full yet */

    bn.sid     x20, 0(x11++)                      /* Store to memory */
    li         x21, 0
_skip_store1:
    /* Shift out the 12 bits we have read for the next potential coefficient */
    bn.rshi    w8, w31, w8 >> 12
  ret
