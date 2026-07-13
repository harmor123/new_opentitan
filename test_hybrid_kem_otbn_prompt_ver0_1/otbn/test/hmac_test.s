/*
 * HMAC-SHA3-256 test (pure software, no KMAC)
 * key = "key" (3 bytes), msg = "message" (7 bytes)
 */

.section .text.start

.globl main
main:
    la      x2, stack_end
    addi    x2, x2, -64
    bn.xor  w31, w31, w31

    la      x10, test_key         /* key_ptr */
    addi    x11, x0, 3             /* key_len */
    la      x12, test_msg          /* msg_ptr */
    addi    x13, x0, 7             /* msg_len */
    la      x14, test_out          /* out_ptr */
    jal     x1, hmac_sha3_256
    ecall

.data

.balign 32
.globl stack
stack:
    .zero 512
stack_end:

/* ---- SW HMAC/SHA3 work buffers ---- */

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

/* ---- HMAC work buffers (HW-compatible) ---- */

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

/* ---- Constants ---- */

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

/* ---- Test data ---- */

.balign 32
.globl test_key
test_key:
    .word 0x0079656b    /* "key\0" */

.balign 32
.globl test_msg
test_msg:
    .word 0x7373656d    /* "mess" */
    .word 0x00656761    /* "age\0" */

.balign 32
.globl test_out
test_out:
    .zero 32
