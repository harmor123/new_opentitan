/* ================================================================
 * kmac_sha3_template.s -- OpenTitan KMAC 硬件极简驱动
 *
 * 寄存器分工:
 *   0xFC2 (kmac_status)    -- FSM 状态: bit0=IDLE, bit1=ABSORB, bit2=SQUEEZE
 *   0x7D9 (kmac_if_status) -- 数据握手: bit0=MSG_WRITE_RDY, bit3=DIGEST_VALID
 *   0x7DB (kmac_cfg)       -- MODE + STRENGTH 配置
 *   0x7DC (msg_send)       -- 触发消息吸收
 *   0x7DD (kmac_cmd)       -- START/PROCESS/RUN/DONE 命令
 *   0x7DE (byte_strobe)    -- 尾部字节有效位掩码
 *
 * 调用约定:
 *   破坏: x5, x6; 各函数具体破坏见注释
 *   w31 由调用者保证为 0 (或由各函数自行清零)
 * ================================================================ */

.section .text

/* ================================================================
 * kmac_init: 初始化 KMAC 硬件，进入 Absorb 状态
 *
 * 输入: x10 = mode (0=SHA3-256, 1=SHA3-512, 2=SHAKE128, 3=SHAKE256)
 * 破坏: x5, x6
 * ================================================================ */
.globl kmac_init
kmac_init:
    addi    x6, x0, 1
.wait_idle:
    csrrs   x5, 0xfc2, x0          /* kmac_status[0]: SHA3_IDLE */
    and     x5, x5, x6
    beq     x5, x0, .wait_idle

    /* Mode dispatch */
    beq     x10, x0, .cfg_sha3_256
    addi    x5, x0, 1
    beq     x10, x5, .cfg_sha3_512
    addi    x5, x0, 2
    beq     x10, x5, .cfg_shake128
    addi    x5, x0, 3
    beq     x10, x5, .cfg_shake256
    ecall                           /* Invalid mode */

.cfg_sha3_256:
    addi    x5, x0, 4               /* MODE=SHA3, STRENGTH=L256 */
    jal     x0, .apply_cfg
.cfg_sha3_512:
    addi    x5, x0, 8               /* MODE=SHA3, STRENGTH=L512 */
    jal     x0, .apply_cfg
.cfg_shake128:
    addi    x5, x0, 32              /* MODE=SHAKE, STRENGTH=L128 */
    jal     x0, .apply_cfg
.cfg_shake256:
    addi    x5, x0, 36              /* MODE=SHAKE, STRENGTH=L256 */

.apply_cfg:
    csrrw   x0, 0x7db, x5           /* kmac_cfg */
    addi    x5, x0, 29              /* CMD_START = 0x1D */
    csrrw   x0, 0x7dd, x5           /* kmac_cmd */
    ret

/* ================================================================
 * keccak_send_message: 发送可变长度消息到 KMAC
 *
 * 输入: x10 = msg_ptr, x11 = byte_len
 * 破坏: x5, x6, x7, w0, w1, w31
 * ================================================================ */
.globl keccak_send_message
keccak_send_message:
    bn.xor  w31, w31, w31           /* w31 = 0 (shift zero reference / share1 zero value) */

    /* Calculate the number of complete 32-byte WDRs */
    srli    x5, x11, 5              /* x5 = byte_len / 32 */
    beq     x5, x0, _no_full_wdr
    slli    x5, x5, 5               /* x5 = complete WDR byte offset */
    add     x5, x10, x5             /* x5 = complete WDR end address */

    /* Full WDR does not require strobe constraints, one preset is sufficient */
    addi    x6, x0, -1              /* x6 = 0xFFFFFFFF */
    csrrw   x0, 0x7de, x6           /* byte_strobe = all valid */

_full_chunk_loop:
    beq     x10, x5, _no_full_wdr
_wait_rdy_full:
    csrrs   x6, 0x7d9, x0           /* kmac_if_status[0]: MSG_WRITE_RDY */
    andi    x6, x6, 1
    beq     x6, x0, _wait_rdy_full

    bn.lid  x0, 0(x10++)            /* Load 256-bit plaintext into w0 */
    bn.wsrw 8, w0                   /* kmac_data_s0 */
    bn.wsrw 9, w31                  /* kmac_data_s1 = 0 */

    csrrw   x0, 0x7dc, x6           /* msg_send = 1 (x6=1 from poll) */
    jal     x0, _full_chunk_loop

_no_full_wdr:
    andi    x5, x11, 31             /* x5 = number of tail bytes (0~31) */
    beq     x5, x0, _keccak_send_message_end

_wait_rdy_tail:
    csrrs   x6, 0x7d9, x0           /* kmac_if_status[0]: MSG_WRITE_RDY */
    andi    x6, x6, 1
    beq     x6, x0, _wait_rdy_tail

    bn.lid  x0, 0(x10)              /* Load tail data (high bits contain garbage) */

    /* Software mask removed: hardware feed_byte_mask in otbn_kmac.sv
     * already masks per-word with byte_strobe. Redundant masking here
     * cost 4*tail_bytes cycles in mask_loop. */
    bn.wsrw 8, w0                   /* kmac_data_s0 */
    bn.wsrw 9, w31                  /* kmac_data_s1 = 0 */

    /* byte_strobe = (1 << x5) - 1, mark only valid tail bytes */
    addi    x6, x0, 1
    sll     x6, x6, x5
    addi    x6, x6, -1
    csrrw   x0, 0x7de, x6
    addi    x6, x0, 1
    csrrw   x0, 0x7dc, x6           /* msg_send = 1 */

_keccak_send_message_end:
    ret

/* ================================================================
 * kmac_process: 点火即走 — 写 CMD_PROCESS 立即返回, 不轮询.
 *
 * keccak-f 在后台运行. 调用者可在 squeeze 之前插入有用工作.
 * kmac_squeeze_32B 的 Word0 检查负责等待 keccak-f 完成.
 *
 * 简单场景(无插入工作): 用 kmac_squeeze_after_process 一次调用.
 * 重叠场景(有插入工作): kmac_process → 干活 → kmac_squeeze_32B.
 *
 * 破坏: x5
 * ================================================================ */
.globl kmac_process
kmac_process:
    addi    x5, x0, 46              /* CMD_PROCESS = 0x2E */
    csrrw   x0, 0x7dd, x5           /* 点火 → keccak-f 开始 */
    ret                             /* 立即返回, 不等待 */

/* ================================================================
 * kmac_squeeze_32B: 挤出 32 字节摘要到 DMEM
 *
 * DIGEST_VALID 检查内联 (省 jal _ensure_digest 开销).
 * SHA3: 4次检查全部 bne 跳转, 从不触发 kmac_run.
 * SHAKE: block 边界内同 SHA3; 跨边界时 bne 不跳→jal kmac_run.
 *
 * 输入: x10 = out_ptr (32-byte aligned)
 * 破坏: x5, w8, w9, w10, w31
 * ================================================================ */
.globl kmac_squeeze_32B
kmac_squeeze_32B:
    bn.xor  w31, w31, w31           /* w31 = 0 (bn.rshi zero reference) */

    /* Word 0 -> w8[63:0]
     * beq 循环: 兼容点火即走 kmac_process 后的初始等待 + SHAKE 独立调用.
     * Word0 永远不会在 SHAKE 边界 (边界总在读出 rate 末字后才触发). */
1:  csrrs   x5, 0x7d9, x0           /* kmac_if_status */
    andi    x5, x5, 8               /* DIGEST_VALID */
    beq     x5, x0, 1b              /* keccak-f 未完成 → 循环等待 */
    bn.wsrr w8, 8                   /* kmac_data_s0 */
    bn.wsrr w9, 9                   /* kmac_data_s1 */
    bn.xor  w8, w8, w9

    /* Word 1 -> w8[127:64] */
    csrrs   x5, 0x7d9, x0
    andi    x5, x5, 8
    bne     x5, x0, 2f
    jal     x1, kmac_run
2:  bn.wsrr w9, 8
    bn.wsrr w10, 9
    bn.xor  w9, w9, w10
    bn.rshi w9, w9, w31 >> 192      /* w9 <<= 64 */
    bn.or   w8, w8, w9

    /* Word 2 -> w8[191:128] */
    csrrs   x5, 0x7d9, x0
    andi    x5, x5, 8
    bne     x5, x0, 3f
    jal     x1, kmac_run
3:  bn.wsrr w9, 8
    bn.wsrr w10, 9
    bn.xor  w9, w9, w10
    bn.rshi w9, w9, w31 >> 128      /* w9 <<= 128 */
    bn.or   w8, w8, w9

    /* Word 3 -> w8[255:192] */
    csrrs   x5, 0x7d9, x0
    andi    x5, x5, 8
    bne     x5, x0, 4f
    jal     x1, kmac_run
4:  bn.wsrr w9, 8
    bn.wsrr w10, 9
    bn.xor  w9, w9, w10
    bn.rshi w9, w9, w31 >> 64       /* w9 <<= 192 */
    bn.or   w8, w8, w9

    addi    x5, x0, 8
    bn.sid  x5, 0(x10)              /* Store 256-bit to DMEM */
    ret

/* ================================================================
 * kmac_squeeze_after_process: CMD_PROCESS + wait + squeeze 32B
 *
 * 合并 kmac_process 的 CMD_PROCESS 写入和 squeeze_32B 的等待.
 * Word0 用 beq 循环等待 keccak-f 完成 (替代原 kmac_process 轮询).
 *
 * 输入: x10 = out_ptr (32-byte aligned)
 * 破坏: x5, w8, w9, w10, w31
 * ================================================================ */
.globl kmac_squeeze_after_process
kmac_squeeze_after_process:
    addi    x5, x0, 46              /* CMD_PROCESS = 0x2E */
    csrrw   x0, 0x7dd, x5           /* 发出 → keccak-f 开始 */

    bn.xor  w31, w31, w31

    /* Word 0: 等 keccak-f 完成 (首次 DIGEST_VALID=0, 循环等待) */
1:  csrrs   x5, 0x7d9, x0
    andi    x5, x5, 8
    beq     x5, x0, 1b              /* DIGEST_VALID=0 → 等待 */
    bn.wsrr w8, 8
    bn.wsrr w9, 9
    bn.xor  w8, w8, w9

    /* Word 1 */
    csrrs   x5, 0x7d9, x0
    andi    x5, x5, 8
    bne     x5, x0, 2f
    jal     x1, kmac_run
2:  bn.wsrr w9, 8
    bn.wsrr w10, 9
    bn.xor  w9, w9, w10
    bn.rshi w9, w9, w31 >> 192
    bn.or   w8, w8, w9

    /* Word 2 */
    csrrs   x5, 0x7d9, x0
    andi    x5, x5, 8
    bne     x5, x0, 3f
    jal     x1, kmac_run
3:  bn.wsrr w9, 8
    bn.wsrr w10, 9
    bn.xor  w9, w9, w10
    bn.rshi w9, w9, w31 >> 128
    bn.or   w8, w8, w9

    /* Word 3 */
    csrrs   x5, 0x7d9, x0
    andi    x5, x5, 8
    bne     x5, x0, 4f
    jal     x1, kmac_run
4:  bn.wsrr w9, 8
    bn.wsrr w10, 9
    bn.xor  w9, w9, w10
    bn.rshi w9, w9, w31 >> 64
    bn.or   w8, w8, w9

    addi    x5, x0, 8
    bn.sid  x5, 0(x10)
    ret

/* ================================================================
 * kmac_run: 触发新一轮 Keccak-f 排列 (仅 SHAKE)
 *
 * 仅当 squeezed_count >= rate 时才需要调用。
 * 破坏: x5, x6
 * ================================================================ */
.globl kmac_run
kmac_run:
    addi    x5, x0, 49              /* CMD_RUN = 0x31 */
    csrrw   x0, 0x7dd, x5           /* kmac_cmd */

    /* First wait for FSM to leave StSqueeze (enter StProcessing = ABSORB state) */
    addi    x6, x0, 2               /* kmac_status[1]: SHA3_ABSORB */
.wait_run_absorb:
    csrrs   x5, 0xfc2, x0
    and     x5, x5, x6
    beq     x5, x0, .wait_run_absorb

    /* Then wait for Keccak to complete, FSM returns to StSqueeze */
    addi    x6, x0, 4               /* kmac_status[2]: SHA3_SQUEEZE */
.wait_run_squeeze:
    csrrs   x5, 0xfc2, x0
    and     x5, x5, x6
    beq     x5, x0, .wait_run_squeeze
    ret

/* ================================================================
 * kmac_done: 释放 KMAC 硬件，回到 Idle
 *
 * 破坏: x5, x6
 * ================================================================ */
.globl kmac_done
kmac_done:
    addi    x5, x0, 22              /* CMD_DONE = 0x16 */
    csrrw   x0, 0x7dd, x5           /* kmac_cmd */

    addi    x6, x0, 1               /* kmac_status[0]: SHA3_IDLE */
.wait_idle_rel:
    csrrs   x5, 0xfc2, x0
    and     x5, x5, x6
    beq     x5, x0, .wait_idle_rel
    ret
