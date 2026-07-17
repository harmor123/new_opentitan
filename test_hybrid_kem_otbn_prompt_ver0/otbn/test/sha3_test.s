/* ================================================================
 * test_sha3_all_direct.s
 *
 * 完全基于 lowRISC/tiny_sha3 纯软件实现的测试
 * 依赖: keccak_direct.s (sha3_init, sha3_update, sha3_final,
 *       shake_xof, shake_out, keccakf, rc, mask_top_1)
 * ================================================================ */

.section .text.start
.globl main
main:
    bn.xor  w31, w31, w31
    /* ---- Basic tests ---- */
    jal     x1, test_sha3_256_empty
    jal     x1, test_sha3_512_empty
    jal     x1, test_sha3_256_msg
    jal     x1, test_sha3_512_msg
    jal     x1, test_shake128_msg
    jal     x1, test_shake256_msg

    /* ---- Advanced edge tests ---- */
    jal     x1, test_sha3_256_32b
    jal     x1, test_sha3_256_33b
    jal     x1, test_sha3_256_35b
    jal     x1, test_sha3_256_64b
    jal     x1, test_shake128_64b_run

    ecall

/* ==================== Basic test functions ==================== */
test_sha3_256_empty:
    la      x10, context
    li      x11, 32
    jal     x1, sha3_init
    la      x11, sha3_256_empty_out
    jal     x1, sha3_final
    ret

test_sha3_512_empty:
    la      x10, context
    li      x11, 64
    jal     x1, sha3_init
    la      x11, sha3_512_empty_out
    jal     x1, sha3_final
    ret

test_sha3_256_msg:
    la      x10, context
    li      x11, 32
    jal     x1, sha3_init
    la      x11, my_message
    li      x12, 8
    jal     x1, sha3_update
    la      x11, sha3_256_msg_out
    jal     x1, sha3_final
    ret

test_sha3_512_msg:
    la      x10, context
    li      x11, 64
    jal     x1, sha3_init
    la      x11, my_message
    li      x12, 8
    jal     x1, sha3_update
    la      x11, sha3_512_msg_out
    jal     x1, sha3_final
    ret

test_shake128_msg:
    la      x10, context
    li      x11, 16               /* SHAKE128 mdlen = 16 */
    jal     x1, sha3_init
    la      x11, my_message
    li      x12, 8
    jal     x1, sha3_update
    jal     x1, shake_xof
    la      x11, shake128_out
    li      x12, 32
    jal     x1, shake_out
    ret

test_shake256_msg:
    la      x10, context
    li      x11, 32               /* SHAKE256 mdlen = 32 */
    jal     x1, sha3_init
    la      x11, my_message
    li      x12, 8
    jal     x1, sha3_update
    jal     x1, shake_xof
    la      x11, shake256_out
    li      x12, 32
    jal     x1, shake_out
    ret

/* ==================== Advanced edge test functions ==================== */
test_sha3_256_32b:
    la      x10, context
    li      x11, 32
    jal     x1, sha3_init
    la      x11, msg_32b
    li      x12, 32
    jal     x1, sha3_update
    la      x11, sha3_256_32b_out
    jal     x1, sha3_final
    ret

test_sha3_256_33b:
    la      x10, context
    li      x11, 32
    jal     x1, sha3_init
    la      x11, msg_33b
    li      x12, 33
    jal     x1, sha3_update
    la      x11, sha3_256_33b_out
    jal     x1, sha3_final
    ret

test_sha3_256_35b:
    la      x10, context
    li      x11, 32
    jal     x1, sha3_init
    la      x11, msg_35b
    li      x12, 35
    jal     x1, sha3_update
    la      x11, sha3_256_35b_out
    jal     x1, sha3_final
    ret

test_sha3_256_64b:
    la      x10, context
    li      x11, 32
    jal     x1, sha3_init
    la      x11, msg_64b
    li      x12, 64
    jal     x1, sha3_update
    la      x11, sha3_256_64b_out
    jal     x1, sha3_final
    ret

/* SHAKE128 squeeze 64 bytes, write in two separate outputs */
test_shake128_64b_run:
    la      x10, context
    li      x11, 16               /* SHAKE128 mdlen */
    jal     x1, sha3_init
    la      x11, my_message
    li      x12, 8
    jal     x1, sha3_update
    jal     x1, shake_xof
    /* First 32 bytes */
    la      x11, shake128_64b_out_1
    li      x12, 32
    jal     x1, shake_out
    /* second time 32 bytes */
    la      x11, shake128_64b_out_2
    li      x12, 32
    jal     x1, shake_out
    ret

/* ==================== data segment ==================== */
.data


.balign 32
my_message:
    .word 0x74616877
    .word 0x206f6420

.balign 32
msg_32b:
    .zero 32

.balign 32
msg_33b:
    .zero 32
    .byte 0x01

.balign 32
msg_35b:
    .zero 32
    .byte 0x01, 0x02, 0x03

.balign 32
msg_64b:
    .zero 64

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

.global context
context:
.balign 32
.zero 212

.globl rc
.balign 32
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