/* ================================================================
 * modp256_test.s - bn.modp256 ISS standalone unit test
 *
 * Tests: basic multiply, square, zero, identity, self-reference,
 *        back-to-back, (p-1)^2=1, bn.lid->bn.modp256, Gx*Gy.
 * Each test stores its result to a unique DMEM label immediately.
 *
 * Rules: no x2(sp)/x8(fp), store after each test, no ; on one line.
 * ================================================================ */

.section .text.start
.globl main
main:
    bn.xor    w31, w31, w31

    /* ---- Test 1: basic multiply 3*5=15 ---- */
    bn.mov    w0, w31
    bn.addi   w0, w0, 3
    bn.mov    w1, w31
    bn.addi   w1, w1, 5
    bn.modp256 w2, w0, w1
    la        x16, t1_3x5
    li        x17, 2
    bn.sid    x17, 0(x16)

    /* ---- Test 2: square 2*2=4 ---- */
    bn.mov    w3, w31
    bn.addi   w3, w3, 2
    bn.modp256 w4, w3, w3
    la        x16, t2_sq
    li        x17, 4
    bn.sid    x17, 0(x16)

    /* ---- Test 3: zero * anything = 0 ---- */
    bn.modp256 w5, w31, w0
    la        x16, t3_zero
    li        x17, 5
    bn.sid    x17, 0(x16)

    /* ---- Test 4: identity a*1=a (must be 3*1=3) ---- */
    bn.mov    w6, w31
    bn.addi   w6, w6, 1
    bn.modp256 w7, w0, w6
    la        x16, t4_id
    li        x17, 7
    bn.sid    x17, 0(x16)

    /* ---- Test 5: wrd==wrs1 self-reference ---- */
    bn.modp256 w0, w0, w1
    la        x16, t5_selfref
    li        x17, 0
    bn.sid    x17, 0(x16)

    /* ---- Test 6: wrd==wrs2 self-reference ---- */
    bn.mov    w8, w31
    bn.addi   w8, w8, 7
    bn.modp256 w8, w6, w8
    la        x16, t6_wrd2
    li        x17, 8
    bn.sid    x17, 0(x16)

    /* ---- Test 7: back-to-back bn.modp256 ---- */
    bn.mov    w9, w31
    bn.addi   w9, w9, 4
    bn.mov    w10, w31
    bn.addi   w10, w10, 9
    bn.modp256 w11, w9, w10
    la        x16, t7_bb1
    li        x17, 11
    bn.sid    x17, 0(x16)
    bn.modp256 w12, w11, w9
    la        x16, t7_bb2
    li        x17, 12
    bn.sid    x17, 0(x16)

    /* ---- Test 8: (p-1)^2 = 1 mod p ---- */
    la        x16, p_minus_1
    li        x17, 13
    bn.lid    x17, 0(x16)
    bn.modp256 w14, w13, w13
    la        x16, t8_pm1sq
    li        x17, 14
    bn.sid    x17, 0(x16)

    /* ---- Test 9: bn.lid -> bn.modp256 back-to-back ---- */
    la        x16, operand_a
    li        x17, 15
    bn.lid    x17, 0(x16)
    bn.modp256 w16, w15, w6
    la        x16, t9_lid
    li        x17, 16
    bn.sid    x17, 0(x16)

    /* ---- Test 10: Gx * Gy mod P256 ---- */
    la        x16, operand_b
    li        x17, 17
    bn.lid    x17, 0(x16)
    bn.modp256 w18, w15, w17
    la        x16, t10_GxGy
    li        x17, 18
    bn.sid    x17, 0(x16)

    ecall

.data
.balign 32

/* P-256 prime minus one: p-1 */
.globl p_minus_1
.balign 32
p_minus_1:
  .word 0xfffffffe
  .word 0xffffffff
  .word 0xffffffff
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000001
  .word 0xffffffff

/* P-256 base point G x-coordinate */
.globl operand_a
.balign 32
operand_a:
  .word 0xd898c296
  .word 0xf4a13945
  .word 0x2deb33a0
  .word 0x77037d81
  .word 0x63a440f2
  .word 0xf8bce6e5
  .word 0xe12c4247
  .word 0x6b17d1f2

/* P-256 base point G y-coordinate */
.globl operand_b
.balign 32
operand_b:
  .word 0x37bf51f5
  .word 0xcbb64068
  .word 0x6b315ece
  .word 0x2bce3357
  .word 0x7c0f9e16
  .word 0x8ee7eb4a
  .word 0xfe1a7f9b
  .word 0x4fe342e2

/* Result labels */
.balign 32
.globl t1_3x5
t1_3x5:       .zero 32
.balign 32
.globl t2_sq
t2_sq:        .zero 32
.balign 32
.globl t3_zero
t3_zero:      .zero 32
.balign 32
.globl t4_id
t4_id:        .zero 32
.balign 32
.globl t5_selfref
t5_selfref:   .zero 32
.balign 32
.globl t6_wrd2
t6_wrd2:      .zero 32
.balign 32
.globl t7_bb1
t7_bb1:       .zero 32
.balign 32
.globl t7_bb2
t7_bb2:       .zero 32
.balign 32
.globl t8_pm1sq
t8_pm1sq:     .zero 32
.balign 32
.globl t9_lid
t9_lid:       .zero 32
.balign 32
.globl t10_GxGy
t10_GxGy:     .zero 32
