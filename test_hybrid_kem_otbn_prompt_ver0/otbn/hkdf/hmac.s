/* ================================================================
 * hmac.s -- HMAC-SHA3-256 纯软件实现
 *
 * 接口对齐 HW 版 hmac_sha3.s，内部使用 sha3_init/update/final 替代 KMAC。
 * 无数据段 -- 所有缓冲区由调用者通过 label 提供。
 *
 * 调用约定:
 *   x10 = key_ptr
 *   x11 = key_len (字节)
 *   x12 = msg_ptr
 *   x13 = msg_len (字节)
 *   x14 = out_ptr (32B 输出)
 *
 * 调用者需提供的 .globl 标签:
 *   hmac_ipad    (160B, 32B对齐) -- ipad 工作区
 *   hmac_opad    (160B, 32B对齐) -- opad 工作区
 *   hmac_inner   (32B,  32B对齐) -- 内部哈希输出
 *   hmac_key_hashed (32B, 32B对齐) -- 超长密钥哈希后存储
 *   const_0x36   (160B, 32B对齐) -- 全 0x36 常量表
 *   const_0x5c   (160B, 32B对齐) -- 全 0x5C 常量表
 *   context      (212B, 32B对齐) -- SHA3 上下文 (SW SHA3 需要)
 *   rc           (24×32B)        -- Keccak 轮常量 (SW SHA3 需要)
 * ================================================================ */

.section .text

.globl hmac_sha3_256
hmac_sha3_256:
    /* ---- Save caller parameters on stack ---- */
    addi    sp, sp, -24
    sw      ra, 20(sp)
    sw      x12, 16(sp)           /* msg_ptr */
    sw      x13, 12(sp)           /* msg_len */
    sw      x14, 8(sp)            /* out_ptr */

    bn.xor  w31, w31, w31         /* w31=0, 所有 SW SHA3 函数要求 */

    /* ---- 超长密钥处理: key_len > 136 -> SHA3-256(key) -> 32B ---- */
    li      x5, 136
    sub     x30, x11, x5
    srli    x30, x30, 31           /* key_len < 136 → 1 */
    bne     x30, x0, hmac_key_ok
    beq     x11, x5, hmac_key_ok   /* key_len == 136 → skip hash */

    /* H(key) -> hmac_key_hashed (32B) */
    sw      x10, 4(sp)
    sw      x11, 0(sp)
    la      x10, context
    addi    x11, x0, 32            /* mdlen = 32 (SHA3-256) */
    jal     x1, sha3_init
    lw      x10, 4(sp)
    lw      x11, 0(sp)
    la      x12, hmac_key_hashed
    sw      x12, 4(sp)             /* reuse slot for key_hashed ptr */
    lw      x12, 0(sp)             /* key_len */
    jal     x1, sha3_update         /* sha3_update(context, key, key_len) */
    la      x10, context
    la      x11, hmac_key_hashed
    jal     x1, sha3_final          /* H(key) → hmac_key_hashed */

    la      x10, hmac_key_hashed
    addi    x11, x0, 32

hmac_key_ok:
    /* x10 = key_ptr, x11 = key_len */

    /* ---- 构造 ipad + opad: 用 bn.lid/bn.sid 一次搬 32B ----
     * ipad = 0x36... XOR key, opad = 0x5C... XOR key */
    la      x5, hmac_ipad
    la      x6, hmac_opad
    la      x12, const_0x36
    la      x13, const_0x5c
    li      x4, 0
    li      x7, 5                  /* 160B / 32B = 5 */
1:  bn.lid  x4, 0(x12++)
    bn.sid  x4, 0(x5++)
    bn.lid  x4, 0(x13++)
    bn.sid  x4, 0(x6++)
    addi    x7, x7, -1
    bne     x7, x0, 1b

    /* ---- XOR key into ipad/opad ---- */
    la      x5, hmac_ipad
    la      x6, hmac_opad
    srli    x7, x11, 2            /* key_len / 4 (full words) */
    beq     x7, x0, key_tail

key_wloop:
    lw      x8, 0(x10)
    lw      x9, 0(x5)
    lw      x15, 0(x6)
    xor     x9, x9, x8
    xor     x15, x15, x8
    sw      x9, 0(x5)
    sw      x15, 0(x6)
    addi    x10, x10, 4
    addi    x5, x5, 4
    addi    x6, x6, 4
    addi    x7, x7, -1
    bne     x7, x0, key_wloop

key_tail:
    andi    x7, x11, 3            /* tail bytes (1-3) */
    beq     x7, x0, hmac_inner_hash

    li      x16, 1
    slli    x17, x7, 3
    sll     x16, x16, x17
    addi    x16, x16, -1           /* byte mask */

    lw      x8, 0(x10)
    and     x8, x8, x16

    lw      x9, 0(x5)
    xor     x9, x9, x8
    sw      x9, 0(x5)

    lw      x9, 0(x6)
    xor     x9, x9, x8
    sw      x9, 0(x6)

    /* ---- 内部哈希: inner = SHA3-256(ipad[0:136] || message) ---- */
hmac_inner_hash:
    la      x10, context
    addi    x11, x0, 32
    jal     x1, sha3_init

    la      x10, context
    la      x11, hmac_ipad
    addi    x12, x0, 136
    jal     x1, sha3_update

    la      x10, context
    lw      x11, 16(sp)           /* msg_ptr */
    lw      x12, 12(sp)           /* msg_len */
    jal     x1, sha3_update

    la      x10, context
    la      x11, hmac_inner
    jal     x1, sha3_final

    /* ---- 外部哈希: result = SHA3-256(opad[0:136] || hmac_inner[0:32]) ---- */
    la      x10, context
    addi    x11, x0, 32
    jal     x1, sha3_init

    la      x10, context
    la      x11, hmac_opad
    addi    x12, x0, 136
    jal     x1, sha3_update

    la      x10, context
    la      x11, hmac_inner
    addi    x12, x0, 32
    jal     x1, sha3_update

    la      x10, context
    lw      x11, 8(sp)            /* out_ptr */
    jal     x1, sha3_final

    /* ---- Return ---- */
    lw      ra, 20(sp)
    addi    sp, sp, 24
    ret
