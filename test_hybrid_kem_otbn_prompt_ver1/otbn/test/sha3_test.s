/* Copyright 2026 Hybrid KEM Project Authors. All rights reserved. */

/* SHA3 / SHAKE / cSHAKE comprehensive test suite via kmac_xof.s ISPR interface. */

.section .text.start
.globl main
main:
    la      x2, stack_end
    addi    x2, x2, -64

    jal     x1, test_sha3_256_empty
    jal     x1, test_sha3_512_empty
    jal     x1, test_sha3_256_msg
    jal     x1, test_sha3_512_msg
    jal     x1, test_shake128_msg
    jal     x1, test_shake256_msg
    jal     x1, test_shake128_empty
    jal     x1, test_shake256_empty
    jal     x1, test_sha3_256_32b
    jal     x1, test_sha3_256_33b
    jal     x1, test_sha3_256_35b
    jal     x1, test_sha3_256_64b
    jal     x1, test_shake128_64b_run
    jal     x1, test_shake128_1run
    jal     x1, test_shake256_1run
    jal     x1, test_shake128_rate_cross
    jal     x1, test_sha3_256_127b
    ecall

/* ---- Helper: squeeze 32B masked → unmask → store to DMEM ---- */
_sqz_store:
    jal     x1, xof_squeeze32       /* w29=S0, w30=S1 */
    bn.xor  w29, w29, w30           /* unmask */
    bn.sid  x7, 0(x6)              /* store to x6 ptr, x7=WDR index */
    ret

/* ---- Helper: init + absorb + process + squeeze + finish ---- */
_oneshot_sha3:
    jal     x1, xof_process
    jal     x1, _sqz_store
    jal     x1, xof_finish
    ret

/* ---- SHA3-256 empty ---- */
test_sha3_256_empty:
    jal     x1, sha3_256_init
    la      x6, sha3_256_empty_out
    addi    x7, x0, 29
    jal     x0, _oneshot_sha3

/* ---- SHA3-512 empty (64B = 2 squeezes) ---- */
test_sha3_512_empty:
    jal     x1, sha3_512_init
    jal     x1, xof_process
    la      x6, sha3_512_empty_out
    addi    x7, x0, 29
    jal     x1, _sqz_store
    addi    x6, x6, 32
    jal     x1, _sqz_store
    jal     x1, xof_finish
    ret

/* ---- SHA3-256 msg (8B) ---- */
test_sha3_256_msg:
    jal     x1, sha3_256_init
    addi    x20, x0, 8
    la      x21, my_message
    addi    x22, x0, 0
    jal     x1, xof_absorb
    la      x6, sha3_256_msg_out
    addi    x7, x0, 29
    jal     x0, _oneshot_sha3

/* ---- SHA3-512 msg (8B, 64B digest) ---- */
test_sha3_512_msg:
    jal     x1, sha3_512_init
    addi    x20, x0, 8
    la      x21, my_message
    addi    x22, x0, 0
    jal     x1, xof_absorb
    jal     x1, xof_process
    la      x6, sha3_512_msg_out
    addi    x7, x0, 29
    jal     x1, _sqz_store
    addi    x6, x6, 32
    jal     x1, _sqz_store
    jal     x1, xof_finish
    ret

/* ---- SHAKE128 msg (8B) ---- */
test_shake128_msg:
    jal     x1, xof_shake128_init
    addi    x20, x0, 8
    la      x21, my_message
    addi    x22, x0, 0
    jal     x1, xof_absorb
    la      x6, shake128_out
    addi    x7, x0, 29
    jal     x0, _oneshot_sha3

/* ---- SHAKE256 msg (8B) ---- */
test_shake256_msg:
    jal     x1, xof_shake256_init
    addi    x20, x0, 8
    la      x21, my_message
    addi    x22, x0, 0
    jal     x1, xof_absorb
    la      x6, shake256_out
    addi    x7, x0, 29
    jal     x0, _oneshot_sha3

/* ---- SHAKE128 empty ---- */
test_shake128_empty:
    jal     x1, xof_shake128_init
    la      x6, shake128_empty_out
    addi    x7, x0, 29
    jal     x0, _oneshot_sha3

/* ---- SHAKE256 empty ---- */
test_shake256_empty:
    jal     x1, xof_shake256_init
    la      x6, shake256_empty_out
    addi    x7, x0, 29
    jal     x0, _oneshot_sha3

/* ---- Edge: 32B message ---- */
test_sha3_256_32b:
    jal     x1, sha3_256_init
    addi    x20, x0, 32
    la      x21, msg_32b
    addi    x22, x0, 0
    jal     x1, xof_absorb
    la      x6, sha3_256_32b_out
    addi    x7, x0, 29
    jal     x0, _oneshot_sha3

/* ---- Edge: 33B message (full WDR + 1B tail) ---- */
test_sha3_256_33b:
    jal     x1, sha3_256_init
    addi    x20, x0, 33
    la      x21, msg_33b
    addi    x22, x0, 0
    jal     x1, xof_absorb
    la      x6, sha3_256_33b_out
    addi    x7, x0, 29
    jal     x0, _oneshot_sha3

/* ---- Edge: 35B message ---- */
test_sha3_256_35b:
    jal     x1, sha3_256_init
    addi    x20, x0, 35
    la      x21, msg_35b
    addi    x22, x0, 0
    jal     x1, xof_absorb
    la      x6, sha3_256_35b_out
    addi    x7, x0, 29
    jal     x0, _oneshot_sha3

/* ---- Edge: 64B message ---- */
test_sha3_256_64b:
    jal     x1, sha3_256_init
    addi    x20, x0, 64
    la      x21, msg_64b
    addi    x22, x0, 0
    jal     x1, xof_absorb
    la      x6, sha3_256_64b_out
    addi    x7, x0, 29
    jal     x0, _oneshot_sha3

/* ---- SHAKE128 8B msg → 2 squeezes (rate=21, no boundary) ---- */
test_shake128_64b_run:
    jal     x1, xof_shake128_init
    addi    x20, x0, 8
    la      x21, my_message
    addi    x22, x0, 0
    jal     x1, xof_absorb
    jal     x1, xof_process
    la      x6, shake128_64b_out_1
    addi    x7, x0, 29
    jal     x1, _sqz_store
    addi    x6, x6, 32
    jal     x1, _sqz_store
    jal     x1, xof_finish
    ret

/* ---- SHAKE128 8B msg → 2 squeezes ---- */
test_shake128_1run:
    jal     x1, xof_shake128_init
    addi    x20, x0, 8
    la      x21, my_message
    addi    x22, x0, 0
    jal     x1, xof_absorb
    jal     x1, xof_process
    la      x6, shake128_1run_b1
    addi    x7, x0, 29
    jal     x1, _sqz_store
    addi    x6, x6, 32
    jal     x1, _sqz_store
    jal     x1, xof_finish
    ret

/* ---- SHAKE256 8B msg → 2 squeezes ---- */
test_shake256_1run:
    jal     x1, xof_shake256_init
    addi    x20, x0, 8
    la      x21, my_message
    addi    x22, x0, 0
    jal     x1, xof_absorb
    jal     x1, xof_process
    la      x6, shake256_1run_b1
    addi    x7, x0, 29
    jal     x1, _sqz_store
    addi    x6, x6, 32
    jal     x1, _sqz_store
    jal     x1, xof_finish
    ret

/* ---- SHAKE128 rate-cross: 256B msg → 6 squeezes, crosses 168B boundary ---- */
test_shake128_rate_cross:
    jal     x1, xof_shake128_init
    addi    x20, x0, 256
    la      x21, msg_256b
    addi    x22, x0, 0
    jal     x1, xof_absorb
    jal     x1, xof_process
    la      x6, rcx_b1
    addi    x7, x0, 29
    jal     x1, _sqz_store
    addi    x6, x6, 32
    jal     x1, _sqz_store     /* rcx_b2 */
    addi    x6, x6, 32
    jal     x1, _sqz_store     /* rcx_b3 */
    addi    x6, x6, 32
    jal     x1, _sqz_store     /* rcx_b4 */
    addi    x6, x6, 32
    jal     x1, _sqz_store     /* rcx_b5 */
    addi    x6, x6, 32
    jal     x1, _sqz_store     /* rcx_b6: crosses 168B boundary → auto-RUN */
    jal     x1, xof_finish
    ret

/* ---- SHA3-256 127B (3×32 + 31 tail, pad crossing) ---- */
test_sha3_256_127b:
    jal     x1, sha3_256_init
    addi    x20, x0, 127
    la      x21, msg_127b
    addi    x22, x0, 0
    jal     x1, xof_absorb
    la      x6, sha3_256_127b_out
    addi    x7, x0, 29
    jal     x0, _oneshot_sha3

/* ---- Data ---- */
.data

.balign 32
.global stack
stack:
    .zero 1024
stack_end:

.balign 32
my_message:
    .word 0x74616877
    .word 0x206f6420

.balign 32
msg_32b:  .zero 32

.balign 32
msg_33b:
    .zero 32
    .word 0x00000001

.balign 32
msg_35b:
    .zero 32
    .word 0x00030201

.balign 32
msg_64b:  .zero 64

.balign 32
msg_127b:
    .zero 96
    .zero 31

.balign 32
msg_256b:
    .rept 32
    .word 0x74616877
    .word 0x206f6420
    .endr

.balign 32
sha3_256_empty_out:   .zero 32
.balign 32
sha3_512_empty_out:   .zero 64
.balign 32
sha3_256_msg_out:     .zero 32
.balign 32
sha3_512_msg_out:     .zero 64
.balign 32
shake128_out:         .zero 32
.balign 32
shake256_out:         .zero 32
.balign 32
shake128_empty_out:   .zero 32
.balign 32
shake256_empty_out:   .zero 32
.balign 32
sha3_256_32b_out:     .zero 32
.balign 32
sha3_256_33b_out:     .zero 32
.balign 32
sha3_256_35b_out:     .zero 32
.balign 32
sha3_256_64b_out:     .zero 32
.balign 32
shake128_64b_out_1:   .zero 32
.balign 32
shake128_64b_out_2:   .zero 32
.balign 32
sha3_256_127b_out:    .zero 32
.balign 32
shake128_1run_b1:     .zero 32
.balign 32
shake128_1run_b2:     .zero 32
.balign 32
shake256_1run_b1:     .zero 32
.balign 32
shake256_1run_b2:     .zero 32
.balign 32
rcx_b1:  .zero 32
.balign 32
rcx_b2:  .zero 32
.balign 32
rcx_b3:  .zero 32
.balign 32
rcx_b4:  .zero 32
.balign 32
rcx_b5:  .zero 32
.balign 32
rcx_b6:  .zero 32
