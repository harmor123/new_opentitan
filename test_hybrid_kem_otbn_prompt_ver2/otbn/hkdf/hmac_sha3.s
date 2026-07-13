/* ================================================================
 * hmac_sha3.s -- HMAC-SHA3-256 纯函数库
 *
 * 依赖 kmac_sha3_template.s 提供 KMAC 硬件访问 (kmac_init 等).
 * 无数据段 -- 所有缓冲区由调用者通过 label 提供.
 *
 * 调用约定:
 *   x10 = key_ptr (密钥指针, 需 32B 对齐)
 *   x11 = key_len (密钥长度, 字节)
 *   x12 = msg_ptr (消息指针, 需 32B 对齐)
 *   x13 = msg_len (消息长度, 字节)
 *   x14 = out_ptr (32B 输出缓冲区, 需 32B 对齐, bn.sid 要求)
 *
 *   破坏寄存器: x4-x9, x15-x17, x30, w4, w31
 *   调用者保存: x12(msg_ptr), x13(msg_len), x14(out_ptr), ra
 *
 * 算法 (RFC 2104):
 *   1. 若 key_len > B=136 (SHA3-256 块大小): key = SHA3-256(key)
 *   2. ipad = (key || 0x00...) XOR 0x36   (136 字节)
 *   3. opad = (key || 0x00...) XOR 0x5C   (136 字节)
 *   4. inner = SHA3-256(ipad || message)
 *   5. result = SHA3-256(opad || inner)
 *
 * 优化: ipad/opad 填充与 XOR 均合并为单循环, 节省 ~40 条指令.
 *
 * 调用者需提供的 .globl 标签:
 *   hmac_ipad    (160B, 32B对齐) -- ipad 工作区
 *   hmac_opad    (160B, 32B对齐) -- opad 工作区
 *   hmac_inner   (32B,  32B对齐) -- 内部哈希输出
 *   hmac_key_hashed (32B, 32B对齐) -- 超长密钥哈希后存储
 *   const_0x36   (160B, 32B对齐) -- 全 0x36 常量表
 *   const_0x5c   (160B, 32B对齐) -- 全 0x5C 常量表
 * ================================================================ */

.section .text

.globl hmac_sha3_256
hmac_sha3_256:
    /* ---- Save caller parameters on stack ---- */
    addi    sp, sp, -24            /* 6 slots: ra, msg_ptr, msg_len, out_ptr, key_ptr, key_len */
    sw      ra, 20(sp)
    sw      x12, 16(sp)           /* msg_ptr */
    sw      x13, 12(sp)           /* msg_len */
    sw      x14, 8(sp)            /* out_ptr */

    bn.xor  w31, w31, w31         /* Clear WDR, required by KMAC driver */

    /* ---- 超长密钥处理: key_len > 136 -> SHA3-256(key) -> 32B ----
     * B = 136 (SHA3-256 的 rate), 密钥超过块大小时需先哈希.
     * key_len < 136 或 == 136 时跳过. */
    li      x5, 136
    sub     x30, x11, x5           /* x30 = key_len - 136 */
    srli    x30, x30, 31           /* Sign bit: key_len < 136 -> 1, key_len >= 136 -> 0 */
    bne     x30, x0, hmac_key_ok  /* key_len < 136: no hash needed, use directly */
    beq     x11, x5, hmac_key_ok  /* key_len == 136: no hash needed, use directly */

    /* H(key) -> hmac_key_hashed (32B) */
    sw      x10, 4(sp)            /* Temporarily store key_ptr */
    sw      x11, 0(sp)            /* Temporarily store key_len */
    addi    x10, x0, 0            /* KMAC mode: SHA3-256 */
    jal     x1, kmac_init
    lw      x10, 4(sp)            /* Restore key_ptr */
    lw      x11, 0(sp)            /* Restore key_len */
    jal     x1, keccak_send_message
    la      x10, hmac_key_hashed
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done

    la      x10, hmac_key_hashed  /* Replace key_ptr with the hashed 32B key */
    addi    x11, x0, 32            /* Replace key_len with 32 */

hmac_key_ok:
    /* x10 = key_ptr, x11 = key_len (original value or hashed 32B) */

    /* ---- 构造 ipad + opad: 用 bn.lid/bn.sid 一次搬 32B ----
     * ipad = 全 0x36 XOR key -> key XOR 0x36 (因为 ipad 已填 0x36)
     * opad = 全 0x5C XOR key -> key XOR 0x5C
     * 两个缓冲区同时填充, 循环 5 次 (5×32B = 160B) */
    la      x5, hmac_ipad          /* Target: ipad buffer */
    la      x6, hmac_opad          /* Target: opad buffer */
    la      x12, const_0x36        /* Source: all 0x36 constant (160B) */
    la      x13, const_0x5c        /* Source: all 0x5C constant (160B) */
    li      x4, 0
    li      x7, 5                  /* Iteration count: 160B / 32B = 5 */
1:  bn.lid  x4, 0(x12++)          /* Load 32B of 0x36 -> WDR */
    bn.sid  x4, 0(x5++)           /* Store to ipad */
    bn.lid  x4, 0(x13++)          /* Load 32B 0x5C -> WDR */
    bn.sid  x4, 0(x6++)           /* Store to opad */
    addi    x7, x7, -1
    bne     x7, x0, 1b

    /* ---- XOR key: ipad[i] ^= key[i], opad[i] ^= key[i] ----
     * 同时处理 ipad 和 opad, 单个循环完成.
     * 先按完整 word (4B) 处理, 再处理尾部 (1-3B). */
    la      x5, hmac_ipad
    la      x6, hmac_opad
    srli    x7, x11, 2            /* Number of complete words = key_len / 4 */
    beq     x7, x0, pad_tail      /* No complete words, directly process the tail */

pad_wloop:
    lw      x8, 0(x10)            /* Read a word from key */
    lw      x9, 0(x5)             /* Read current position of ipad */
    lw      x15, 0(x6)            /* Read current position of opad */
    xor     x9, x9, x8            /* ipad ^= key -> key ^ 0x36 */
    xor     x15, x15, x8          /* opad ^= key -> key ^ 0x5C */
    sw      x9, 0(x5)             /* Write back to ipad */
    sw      x15, 0(x6)            /* Write back opad */
    addi    x10, x10, 4
    addi    x5, x5, 4
    addi    x6, x6, 4
    addi    x7, x7, -1
    bne     x7, x0, pad_wloop

pad_tail:
    /* 处理 key 的尾部字节 (1-3B, 不足一个 word).
     * OTBN 无 lb/sb, 用读-改-写 + 掩码实现. */
    andi    x7, x11, 3            /* Number of tail bytes (1-3) */
    beq     x7, x0, pad_done

    li      x16, 1
    slli    x17, x7, 3            /* x17 = tail * 8 = shift amount */
    sll     x16, x16, x17
    addi    x16, x16, -1           /* Byte mask: (1 << (8*tail)) - 1 */

    lw      x8, 0(x10)            /* Read key tail word */
    and     x8, x8, x16            /* Keep only valid bytes */

    lw      x9, 0(x5)             /* Read ipad, XOR, write back */
    xor     x9, x9, x8
    sw      x9, 0(x5)

    lw      x9, 0(x6)             /* Read opad, XOR, write back */
    xor     x9, x9, x8
    sw      x9, 0(x6)

pad_done:
    /* ---- 内部哈希: H_inner = SHA3-256(ipad[0:136] || message) ----
     * 流程: kmac_init -> send(ipad, 136) -> send(msg, msg_len)
     *       -> kmac_process -> squeeze_32B(hmac_inner) -> kmac_done */
    addi    x10, x0, 0            /* SHA3-256 mode */
    jal     x1, kmac_init

    la      x10, hmac_ipad
    addi    x11, x0, 136           /* ipad effective length is 136B (rate) */
    jal     x1, keccak_send_message

    lw      x10, 16(sp)           /* msg_ptr */
    lw      x11, 12(sp)           /* msg_len */
    jal     x1, keccak_send_message

    la      x10, hmac_inner
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done         /* Release KMAC hardware */

    /* ---- 外部哈希: H_outer = SHA3-256(opad[0:136] || inner_hash[0:32]) ----
     * 流程: kmac_init -> send(opad, 136) -> send(inner, 32)
     *       -> kmac_process -> squeeze_32B(out_ptr) -> kmac_done */
    addi    x10, x0, 0            /* SHA3-256 mode */
    jal     x1, kmac_init

    la      x10, hmac_opad
    addi    x11, x0, 136
    jal     x1, keccak_send_message

    la      x10, hmac_inner
    addi    x11, x0, 32
    jal     x1, keccak_send_message

    lw      x10, 8(sp)
    jal     x1, kmac_squeeze_after_process
    jal     x1, kmac_done

    /* ---- Return ---- */
    lw      ra, 20(sp)
    addi    sp, sp, 24
    ret
