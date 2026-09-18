.section .text

/*
 * For rejection-sampling isolation:
 *
 * SHA3 setup functions are intentionally replaced by no-op stubs.
 * poly_gen_matrix.s itself remains unchanged.
 */

.globl sha3_init
sha3_init:
  ret

.globl sha3_update
sha3_update:
  ret

.globl shake_xof
shake_xof:
  ret


/*
 * shake_out replacement.
 *
 * Instead of executing SHAKE/Keccak, copy the next precomputed
 * 32-byte block into the exact output buffer requested by
 * poly_gen_matrix.
 *
 * x11 = output pointer
 */
.globl shake_out
shake_out:
  /* Load current precomputed stream pointer. */
  la   x3, rejection_stream_ptr
  lw   x4, 0(x3)

  /* Copy exactly 32 bytes. */
  li     x5, 0
  bn.lid x5, 0(x4)
  bn.sid x5, 0(x11)

  /* Advance to next 32-byte block. */
  addi x4, x4, 32
  sw   x4, 0(x3)

  ret
