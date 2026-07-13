/* ================================================================
 * test_sha3_all_hardware.s
 *
 * 适配极简 KMAC 驱动的全量及边缘测试套件
 * 特点：彻底抛弃 212 字节软件 context，纯硬件状态机流转
 * 依赖：kmac_sha3_template.s (提供所有 kmac_ 和 keccak_ 接口)
 * ================================================================ */

.section .text.start
.globl main
main:
    la      x2, stack_end
    addi    x2, x2, -64

    /* ---- 基础测试 ---- */
    jal     x1, test_sha3_256_empty
    jal     x1, test_sha3_512_empty
    jal     x1, test_sha3_256_msg
    jal     x1, test_sha3_512_msg
    jal     x1, test_shake128_msg
    jal     x1, test_shake256_msg
    jal     x1, test_shake128_empty
    jal     x1, test_shake256_empty
    jal     x1, test_cshake128_empty
    jal     x1, test_cshake256_empty
    jal     x1, test_cshake128_msg
    jal     x1, test_cshake256_msg

    /* ---- 进阶边缘测试 (针对 keccak_send_message 的尾部掩码) ---- */
    jal     x1, test_sha3_256_32b
    jal     x1, test_sha3_256_33b
    jal     x1, test_sha3_256_35b
    jal     x1, test_sha3_256_64b
    jal     x1, test_shake128_64b_run
    /* ---- SHAKE + RUN 测试 ---- */
    jal     x1, test_shake128_1run
    jal     x1, test_shake256_1run

    /* ---- SHAKE rate-cross: 跨 21 lanes 边界 ---- */
    jal     x1, test_shake128_rate_cross

    jal     x1, test_sha3_256_127b

    ecall

/* ==================== 基础测试函数 ==================== */
test_sha3_256_empty:
    addi    x10, x0, 0             /* Mode 0: SHA3-256 */
    jal     x1, kmac_init
    /* 空消息：不调用 keccak_send_message */
    la      x10, sha3_256_empty_out
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done
    ret

test_sha3_512_empty:
    addi    x10, x0, 1             /* Mode 1: SHA3-512 */
    jal     x1, kmac_init
    la      x10, sha3_512_empty_out
    jal     x1, kmac_squeeze_after_process
    /* SHA3-512 digest=64B=8 lanes, rate=9 lanes, 无需 RUN */
    addi    x10, x10, 32
    jal     x1, kmac_squeeze_32B
    jal     x1, kmac_done
    ret

test_sha3_256_msg:
    addi    x10, x0, 0
    jal     x1, kmac_init
    la      x10, my_message
    addi    x11, x0, 8
    jal     x1, keccak_send_message
    la      x10, sha3_256_msg_out
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done
    ret

test_sha3_512_msg:
    addi    x10, x0, 1
    jal     x1, kmac_init
    la      x10, my_message
    addi    x11, x0, 8
    jal     x1, keccak_send_message
    la      x10, sha3_512_msg_out
    jal     x1, kmac_squeeze_after_process
    /* SHA3-512 digest=64B=8 lanes, rate=9 lanes, 无需 RUN */
    addi    x10, x10, 32
    jal     x1, kmac_squeeze_32B
    jal     x1, kmac_done
    ret

test_shake128_msg:
    addi    x10, x0, 2             /* Mode 2: SHAKE128 */
    jal     x1, kmac_init
    la      x10, my_message
    addi    x11, x0, 8
    jal     x1, keccak_send_message
    la      x10, shake128_out
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done
    ret

test_shake256_msg:
    addi    x10, x0, 3             /* Mode 3: SHAKE256 */
    jal     x1, kmac_init
    la      x10, my_message
    addi    x11, x0, 8
    jal     x1, keccak_send_message
    la      x10, shake256_out
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done
    ret

/* ==================== 进阶边缘测试函数 ==================== */
test_sha3_256_32b:
    addi    x10, x0, 0
    jal     x1, kmac_init
    la      x10, msg_32b
    addi    x11, x0, 32
    jal     x1, keccak_send_message
    la      x10, sha3_256_32b_out
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done
    ret

test_sha3_256_33b:
    addi    x10, x0, 0
    jal     x1, kmac_init
    la      x10, msg_33b
    addi    x11, x0, 33
    jal     x1, keccak_send_message
    la      x10, sha3_256_33b_out
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done
    ret

test_sha3_256_35b:
    addi    x10, x0, 0
    jal     x1, kmac_init
    la      x10, msg_35b
    addi    x11, x0, 35
    jal     x1, keccak_send_message
    la      x10, sha3_256_35b_out
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done
    ret

test_sha3_256_64b:
    addi    x10, x0, 0
    jal     x1, kmac_init
    la      x10, msg_64b
    addi    x11, x0, 64
    jal     x1, keccak_send_message
    la      x10, sha3_256_64b_out
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done
    ret

test_shake128_64b_run:
    addi    x10, x0, 2
    jal     x1, kmac_init
    la      x10, my_message
    addi    x11, x0, 8
    jal     x1, keccak_send_message
    /* 第一次挤出 32 字节 (lanes 0~3) */
    la      x10, shake128_64b_out_1
    jal     x1, kmac_squeeze_after_process
    /* 第二次挤出 32 字节 (lanes 4~7, rate=21 远未用完) */
    la      x10, shake128_64b_out_2
    jal     x1, kmac_squeeze_32B
    jal     x1, kmac_done
    ret

test_sha3_256_127b:
    addi    x10, x0, 0             /* Mode 0: SHA3-256 */
    jal     x1, kmac_init
    la      x10, msg_127b
    addi    x11, x0, 127           /* 3 full WDR + 31B tail, pos=16, partial */
    jal     x1, keccak_send_message
    la      x10, sha3_256_127b_out
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done
    ret

test_shake128_1run:
    addi    x10, x0, 2             /* Mode 2: SHAKE128 */
    jal     x1, kmac_init
    la      x10, my_message
    addi    x11, x0, 8
    jal     x1, keccak_send_message
    la      x10, shake128_1run_b1
    jal     x1, kmac_squeeze_after_process   /* auto-RUN only if block exhausted */
    la      x10, shake128_1run_b2
    jal     x1, kmac_squeeze_32B
    jal     x1, kmac_done
    ret


test_shake256_1run:
    addi    x10, x0, 3             /* Mode 3: SHAKE256 */
    jal     x1, kmac_init
    la      x10, my_message
    addi    x11, x0, 8
    jal     x1, keccak_send_message
    la      x10, shake256_1run_b1
    jal     x1, kmac_squeeze_after_process
    la      x10, shake256_1run_b2
    jal     x1, kmac_squeeze_32B
    jal     x1, kmac_done
    ret


test_shake128_rate_cross:
    addi    x10, x0, 2             /* Mode 2: SHAKE128 */
    jal     x1, kmac_init
    la      x10, msg_256b
    addi    x11, x0, 256           /* 256B 消息 */
    jal     x1, keccak_send_message
    /* 6 squeezes: 192B > 168B rate, auto-RUN at boundary */
    la      x10, rcx_b1
    jal     x1, kmac_squeeze_after_process
    la      x10, rcx_b2
    jal     x1, kmac_squeeze_32B
    la      x10, rcx_b3
    jal     x1, kmac_squeeze_32B
    la      x10, rcx_b4
    jal     x1, kmac_squeeze_32B
    la      x10, rcx_b5
    jal     x1, kmac_squeeze_32B
    la      x10, rcx_b6
    jal     x1, kmac_squeeze_32B   /* crosses boundary → auto-RUN inside */
    jal     x1, kmac_done
    ret

/* ==================== SHAKE 空消息测试 ==================== */
test_shake128_empty:
    addi    x10, x0, 2             /* Mode 2: SHAKE128 */
    jal     x1, kmac_init
    la      x10, shake128_empty_out
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done
    ret

test_shake256_empty:
    addi    x10, x0, 3             /* Mode 3: SHAKE256 */
    jal     x1, kmac_init
    la      x10, shake256_empty_out
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done
    ret

/* ==================== cSHAKE 测试 (空 customization ≡ SHAKE) ==================== */
test_cshake128_empty:
    addi    x10, x0, 2             /* Mode 2: cSHAKE128 ≡ SHAKE128 */
    jal     x1, kmac_init
    la      x10, cshake128_empty_out
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done
    ret

test_cshake256_empty:
    addi    x10, x0, 3             /* Mode 3: cSHAKE256 ≡ SHAKE256 */
    jal     x1, kmac_init
    la      x10, cshake256_empty_out
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done
    ret

test_cshake128_msg:
    addi    x10, x0, 2             /* Mode 2: cSHAKE128 ≡ SHAKE128 */
    jal     x1, kmac_init
    la      x10, my_message
    addi    x11, x0, 8
    jal     x1, keccak_send_message
    la      x10, cshake128_out
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done
    ret

test_cshake256_msg:
    addi    x10, x0, 3             /* Mode 3: cSHAKE256 ≡ SHAKE256 */
    jal     x1, kmac_init
    la      x10, my_message
    addi    x11, x0, 8
    jal     x1, keccak_send_message
    la      x10, cshake256_out
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done
    ret

/* ==================== 数据段 ==================== */
.data

/* 栈空间 */
.balign 32
.global stack
stack:
    .zero 1024
stack_end:

/* 基础测试消息 "what do " (8 bytes) */
.balign 32
my_message:
    .word 0x74616877    /* "what" little-endian */
    .word 0x206f6420    /* " do " little-endian */
    
/* 边缘测试专用输入数据 */
.balign 32
msg_32b:
    .zero 32

.balign 32
msg_33b:
    .zero 32
    .word 0x00000001

.balign 32
msg_35b:
    .zero 32
    .word 0x00030201

.balign 32
msg_64b:
    .zero 64

/* 127 字节消息 (= 3×32 + 31): pos=16, pad=2, 触发 pad+1 修正 */
.balign 32
msg_127b:
    .zero 96           /* 3 full WDRs (96 bytes) */
    .zero 31           /* partial tail = 31 bytes */

/* 基础测试输出缓冲区 */
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
cshake128_empty_out:  .zero 32

.balign 32
cshake256_empty_out:  .zero 32

.balign 32
cshake128_out:        .zero 32

.balign 32
cshake256_out:        .zero 32

/* 边缘测试专用输出缓冲区 */
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

/* SHAKE+RUN 输出缓冲区 */
.balign 32
shake128_1run_b1:     .zero 32
.balign 32
shake128_1run_b2:     .zero 32
.balign 32
shake256_1run_b1:     .zero 32
.balign 32
shake256_1run_b2:     .zero 32

/* 256B 消息 (for rate-cross test) */
.balign 32
msg_256b:
    .rept 32
    .word 0x74616877    /* "what" little-endian */
    .word 0x206f6420    /* " do " little-endian */
    .endr

/* rate-cross 输出缓冲区 */
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
