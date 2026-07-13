/* ================================================================
 * hkdf_sha3_256.s — OTBN HKDF-SHA3-256 密钥派生 (纯函数库)
 *
 * 依赖:
 *   kmac_sha3_template.s — KMAC 硬件驱动 (kmac_init, keccak_send_message 等)
 *   hmac_sha3.s          — HMAC-SHA3-256 (hmac_sha3_256)
 *
 * IKM 由 test wrapper 预拼在 ikm_prebuilt, 本模块直接引用.
 * 无数据段 — 所有缓冲区由调用者通过 .globl label 提供.
 *
 * 公开子程序:
 *   hkdf_extract — HKDF-Extract: PRK = HMAC-SHA3-256(salt, IKM)
 *   hkdf_expand  — HKDF-Expand:  OKM = HKDF-Expand(PRK, info, L)
 *
 * 调用者需提供的 .globl 标签:
 *   input_salt     (32B, 32B对齐) — HKDF salt
 *   ikm_prebuilt   (可变, 32B对齐) — 预拼接的 IKM (len_cls||ss_e||len_pqc||ss_m||ctx||sid)
 *   input_info     (可变, 32B对齐) — HKDF-Expand info 字节序列
 *   input_info_len (4B)           — info 字节长度 (独立于 input_lengths)
 *   input_lengths  (32B, 32B对齐) — IKM 长度字段结构体:
 *       +0: ctx_len  (4B)
 *       +4: sid_len  (4B)
 *       +8: okm_len  (4B)
 *      +12: padding  (16B, 共 32B)
 *   output_okm     (256B, 32B对齐) — OKM 输出缓冲区
 *   t_buf          (32B, 32B对齐)  — T(i) 暂存 (Expand 循环用)
 *   hmac_key_hashed(32B, 32B对齐)  — PRK 暂存 (Extract 输出, Expand 输入)
 *   hmac_inner     (32B, 32B对齐)  — HMAC 内部哈希输出
 *   ikm_buf        (1024B, 32B对齐) — Expand 循环临时消息缓冲区
 *   hmac_ipad      (160B, 32B对齐) — HMAC 工作区
 *   hmac_opad      (160B, 32B对齐) — HMAC 工作区
 *   const_0x36     (160B, 32B对齐) — HMAC 常量 (全 0x36)
 *   const_0x5c     (160B, 32B对齐) — HMAC 常量 (全 0x5C)
 *
 * 算法 (RFC 5869):
 *   Extract:  PRK = HMAC-SHA3-256(salt, IKM)
 *             IKM = be16(32)||ss_e||be16(32)||ss_m||ctx||sid  (role 不放入)
 *   Expand:   T(1) = HMAC-SHA3-256(PRK, info || 0x01)
 *             T(i) = HMAC-SHA3-256(PRK, T(i-1) || info || i)
 *             OKM = T(1) || T(2) || ... || T(N), N = ceil(L/32)
 *   KEM 层 info="" (统一 OKM), 角色绑定由上层实现
 *
 * 关键设计:
 *   - PRK 存储在 hmac_key_hashed (32B < 136B, hmac_sha3_256 不会覆盖)
 *   - Expand 消息缓冲区用 ikm_buf (Extract 之后空闲, 避免与 hmac_opad 冲突)
 *   - 长度字段打包为 32B 结构体 input_lengths (1条 la + 4条 lw, 省指令)
 * ================================================================ */

.section .text

/* ================================================================
 * hkdf_extract — HKDF-Extract 阶段
 *
 * PRK = HMAC-SHA3-256(salt, IKM)
 * 若 salt 为空则使用 32B 全零 (调用者保证传入有效 salt).
 *
 * 输入: 从 DMEM label 读取 (无寄存器参数)
 *       - input_salt (32B): HKDF salt
 *       - ikm_prebuilt: 预拼接的 IKM 字节序列
 *       - input_lengths: 长度字段 (ctx_len, sid_len)
 * 输出: PRK → hmac_key_hashed (32B)
 *
 * 破坏寄存器: x5-x8, x10-x14, ra
 * ================================================================ */
.globl hkdf_extract
hkdf_extract:
    addi    sp, sp, -8
    sw      ra, 4(sp)              /* 保存返回地址 (hmac_sha3_256 会覆盖 ra) */

    /* ---- 计算 IKM 总长度 ----
     * IKM = be16(32) || ss_e(32) || be16(32) || ss_m(32)  (= 68B 固定)
     *       || ctx || sid
     * (info 不在 IKM 中, 仅在 Expand 阶段使用) */
    la      x8, input_lengths     /* layout: +0=ctx_len, +4=sid_len, +8=okm_len */
    lw      x5, 0(x8)             /* ctx_len */
    lw      x6, 4(x8)             /* sid_len */
    addi    x13, x5, 68
    add     x13, x13, x6           /* ikm_len = 68 + ctx + sid */

    /* ---- HMAC(salt, IKM) → PRK ----
     * PRK 存到 hmac_key_hashed (独立缓冲区, 不与 Expand 的 t_buf 冲突) */
    la      x10, input_salt        /* x10 = salt_ptr */
    addi    x11, x0, 32            /* x11 = salt_len = 32 */
    la      x12, ikm_prebuilt      /* x12 = ikm_ptr (预拼接的 IKM) */
    la      x14, hmac_key_hashed   /* x14 = prk_out */
    jal     x1, hmac_sha3_256      /* PRK = HMAC-SHA3-256(salt, IKM) */

    lw      ra, 4(sp)
    addi    sp, sp, 8
    ret


/* ================================================================
 * hkdf_expand — HKDF-Expand 阶段
 *
 * OKM = HKDF-Expand(PRK, info, L).
 * T(1) = HMAC-SHA3-256(PRK, info || 0x01)
 * T(i) = HMAC-SHA3-256(PRK, T(i-1) || info || i)
 * OKM = T(1) || T(2) || ... || T(N)
 *
 * 输入: 从 DMEM label 读取 (无寄存器参数)
 *       - hmac_key_hashed (32B): PRK (由 hkdf_extract 写入)
 *       - input_lengths[+8]:  okm_len (L)
 *       - input_info_len:     info 字节长度
 *       - input_info:         info 字节序列
 * 输出: OKM → output_okm
 *
 * 破坏寄存器: x8, x10-x29, x30
 * ================================================================ */
.globl hkdf_expand
hkdf_expand:
    /* ---- 读取 OKM 长度 L ----
     * L == 0 时直接返回 (空输出) */
    la      x8, input_lengths     /* layout: +0=ctx, +4=sid, +8=okm */
    lw      x15, 8(x8)             /* okm_len at +8 */
    beq     x15, x0, expand_ret

    addi    x16, x15, 31
    srli    x16, x16, 5            /* N = ceil(L/32) */
    la      x30, input_info_len
    lw      x29, 0(x30)            /* info_len (separate symbol) */
    li      x17, 1                 /* counter i */
    li      x18, 0                 /* okm offset */
    li      x19, 0                 /* T_prev length */

expand_loop:
    /* ---- 构造 HMAC 消息: [T_prev (i>1)] || info || [counter_byte] ---- */
    la      x20, ikm_buf

    /* i > 1: copy T_prev (32B) to msg buffer */
    beq     x19, x0, 1f
    la      x21, t_buf
    li      x22, 8
2:  lw      x23, 0(x21)
    sw      x23, 0(x20)
    addi    x21, x21, 4
    addi    x20, x20, 4
    addi    x22, x22, -1
    bne     x22, x0, 2b

    /* Copy info (x29=info_len from expand entry, no la in loop) */
1:
    beq     x29, x0, 4f             /* info_len == 0 → skip */
    addi    x30, x29, 3
    srli    x30, x30, 2            /* info_words */
    la      x21, input_info
3:  lw      x22, 0(x21)
    sw      x22, 0(x20)
    addi    x21, x21, 4
    addi    x20, x20, 4
    addi    x30, x30, -1
    bne     x30, x0, 3b
4:
    /* 追加单字节计数器 */
    andi    x21, x17, 0xFF
    sw      x21, 0(x20)
    add     x13, x19, x29          /* msg_len = T_prev_len + info_len */
    addi    x13, x13, 1            /* msg_len += 1 (counter) */

    /* ---- 保存 Expand 循环状态到栈 ----
     * 注意: hmac_sha3_256 会使用 sp[-24..0], 与本栈帧 (sp+16..sp+36) 不重叠 */
    addi    sp, sp, -40
    sw      ra, 36(sp)             /* 返回地址 (hmac_sha3_256 会覆盖 ra) */
    sw      x15, 32(sp)            /* L (okm_len) */
    sw      x16, 28(sp)            /* N remaining */
    sw      x17, 24(sp)            /* counter i */
    sw      x18, 20(sp)            /* okm 偏移 */
    sw      x19, 16(sp)            /* T_prev 长度 */

    /* ---- T(i) = HMAC-SHA3-256(PRK, msg) ----
     * PRK 从 hmac_key_hashed 读取 (不会被 Expand 覆盖)
     * msg 在 ikm_buf 中
     * 输出到 hmac_inner */
    la      x10, hmac_key_hashed   /* key = PRK (固定 32B) */
    addi    x11, x0, 32
    la      x12, ikm_buf           /* msg = T_prev || counter */
    la      x14, hmac_inner
    jal     x1, hmac_sha3_256

    /* ---- 恢复 Expand 循环状态 ---- */
    lw      ra, 36(sp)
    lw      x15, 32(sp)
    lw      x16, 28(sp)
    lw      x17, 24(sp)
    lw      x18, 20(sp)
    lw      x19, 16(sp)
    addi    sp, sp, 40

    /* ---- 拷贝 T(i) → t_buf (下一轮 T_prev) + output_okm ----
     * 拷贝字节数 = min(32, L - offset) */
    la      x20, hmac_inner        /* 源: T(i) */
    la      x21, t_buf             /* 目标1: 下一轮 T_prev */
    la      x22, output_okm        /* 目标2: OKM 输出 */
    add     x22, x22, x18          /* 目标2 += okm 偏移 */

    /* 判断: remaining < 32 ? */
    sub     x23, x15, x18          /* remaining = L - offset */
    addi    x24, x0, 32
    sub     x30, x23, x24          /* remaining - 32 */
    srli    x30, x30, 31           /* 符号: 1 if remaining < 32 */
    bne     x30, x0, expand_partial

    /* remaining >= 32: 完整拷贝 32B (8 words) */
    li      x25, 8
1:  lw      x26, 0(x20)
    sw      x26, 0(x21)
    sw      x26, 0(x22)
    addi    x20, x20, 4
    addi    x21, x21, 4
    addi    x22, x22, 4
    addi    x18, x18, 4
    addi    x25, x25, -1
    bne     x25, x0, 1b
    jal     x0, expand_copy_done

expand_partial:
    /* remaining < 32: 按 word 拷贝, 最后一个 word 用掩码处理尾部 1-3 字节 */
    srli    x25, x23, 2            /* 完整 word 数 */
    beq     x25, x0, expand_partial_tail
1:  lw      x26, 0(x20)
    sw      x26, 0(x21)
    sw      x26, 0(x22)
    addi    x20, x20, 4
    addi    x21, x21, 4
    addi    x22, x22, 4
    addi    x18, x18, 4
    addi    x23, x23, -4
    addi    x25, x25, -1
    bne     x25, x0, 1b

expand_partial_tail:
    /* 尾部 1-3 字节: 读-改-写 + 掩码 (OTBN 无 lb/sb) */
    andi    x23, x23, 3            /* tail 字节数 (1-3) */
    beq     x23, x0, expand_copy_done

    lw      x26, 0(x20)            /* src 尾部 word */
    li      x27, 1
    slli    x28, x23, 3
    sll     x27, x27, x28
    addi    x27, x27, -1           /* 字节掩码: (1 << (8*tail)) - 1 */
    and     x26, x26, x27          /* 只保留尾部有效字节 */

    /* 写 t_buf (读-改-写) */
    lw      x28, 0(x21)
    xori    x29, x27, -1           /* 清零掩码: ~byte_mask */
    and     x28, x28, x29
    or      x28, x28, x26
    sw      x28, 0(x21)

    /* 写 output_okm (读-改-写) */
    lw      x28, 0(x22)
    and     x28, x28, x29
    or      x28, x28, x26
    sw      x28, 0(x22)

    add     x18, x18, x23          /* 更新偏移 */

expand_copy_done:
    /* 更新循环变量, 继续下一轮 */
    li      x19, 32                /* T_prev_len = 32 */
    addi    x17, x17, 1            /* i++ */
    addi    x16, x16, -1           /* N-- */
    bne     x16, x0, expand_loop   /* N > 0 → 继续 */

expand_ret:
    ret
