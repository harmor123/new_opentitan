/*
 * Testwrapper for hmac_sha3_256
 * key = "key" (3 bytes), msg = "message" (7 bytes)
 */

.section .text.start

.globl main
main:
    la      x2, stack_end
    addi    x2, x2, -64
    bn.xor  w31, w31, w31

    la      x10, test_key
    addi    x11, x0, 3
    la      x12, test_msg
    addi    x13, x0, 7
    la      x14, test_out
    jal     x1, hmac_sha3_256
    ecall

.data

.balign 32
.globl stack
stack:
    .zero 512
stack_end:

.balign 32
.globl hmac_ipad
hmac_ipad:
    .zero 160

.balign 32
.globl hmac_opad
hmac_opad:
    .zero 160

.balign 32
.globl hmac_inner
hmac_inner:
    .zero 32

.balign 32
.globl hmac_key_hashed
hmac_key_hashed:
    .zero 32

.balign 32
.globl const_0x36
const_0x36:
    .rept 40
    .word 0x36363636
    .endr

.balign 32
.globl const_0x5c
const_0x5c:
    .rept 40
    .word 0x5c5c5c5c
    .endr

.balign 32
.globl test_key
test_key:
    .word 0x0079656b    /* "key" */

.balign 32
.globl test_msg
test_msg:
    .word 0x7373656d    /* "mess" */
    .word 0x00656761    /* "age" */

.balign 32
.globl test_out
test_out:
    .zero 32
