.section .text.start

.globl main
main:
  /*
   * Deterministic WDR initialization.
   */
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
  bn.xor w31, w31, w31

  /*
   * Construct the same fp-relative layout used by crypto_kem_dec.
   *
   * The verify/cmov code uses:
   *   -20(fp): pointer to original ciphertext
   *   -32(fp): pointer to re-encrypted ciphertext
   *    -8(fp): pointer to output shared key
   * -4256(fp): two 32-byte candidate keys
   */
  la   x2, stack
  li   x3, 4608
  add  x2, x2, x3
  addi fp, x2, 0

  la x10, ciphertext
  sw x10, -20(fp)

  la x11, cmp_ciphertext
  sw x11, -32(fp)

  la x12, output_key
  sw x12, -8(fp)

  /*
   * Exact verify block from mlkem_decap.s.
   *
   * Both ciphertext buffers are equal, reproducing the full-match
   * trajectory observed in the real ACVP Decap execution:
   *   bn.cmp ×34
   *   bn.sel ×34
   *   csrrw  ×34
   */
  li      x5, 0
  li      x6, 1
  lw      x10, -20(fp)
  lw      x11, -32(fp)
  li      x7, 1
  bn.subi w2, w31, 1

  LOOPI 34, 8
    beq    x7, x0, _skip_verify
    bn.lid x5, 0(x10++)
    bn.lid x6, 0(x11++)
    bn.cmp w0, w1
    bn.sel w4, w31, w2, FG0.Z
    csrrw  x7, 0x7C0, x0
    srl    x7, x7, 3
_skip_verify:
    nop

  /*
   * Exact cmov block from mlkem_decap.s.
   */
  li      x10, -4256
  add     x10, fp, x10
  bn.lid  x5, 0(x10++)
  bn.lid  x6, 0(x10)

  bn.xor  w3, w0, w1
  bn.and  w3, w3, w4
  bn.xor  w0, w0, w3

  lw      x10, -8(fp)
  bn.sid  x5, 0(x10)

  ecall


.section .data
.balign 32

/*
 * 4608-byte fp-relative workspace.
 *
 * candidate_keys must be exactly fp - 4256.
 *
 * fp = stack + 4608
 * 4608 - 4256 = 352
 */
stack:
  .zero 352

candidate_keys:
  /*
   * true candidate key, 32 B
   * false candidate key, 32 B
   */
  .zero 64

  /*
   * Complete stack area to 4608 B.
   */
  .zero 4192


/*
 * Original ACVP trajectory is full-match.
 * Equal zero buffers therefore reproduce the same verify control flow.
 */
.balign 32
ciphertext:
  .zero 1088

.balign 32
cmp_ciphertext:
  .zero 1088

.balign 32
output_key:
  .zero 32
