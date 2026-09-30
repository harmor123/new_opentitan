/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * P-256 mixed-instruction test（P6 Step 4：新旧指令交替 / 临时寄存器不串值）。
 *
 * 判据（PDF §11 P6，逐字）：「新旧指令**交替**使用时临时寄存器不会串值」。
 * 本程序把 PDF §14.2 的四组交替模式各做一次**受控对照**：
 *
 *   B1  旧 MAC → 新指令   （bn.mulqacc* 序列，中间插入 bn.p256mul）
 *   B2  新指令 → 旧 MAC   （bn.p256mul 之后紧接 bn.mulqacc* 序列）
 *   B3  向量 → 新指令     （bn.mulvm.8S / bn.addvm.8S 之间插入 bn.p256mul）
 *   B4  新指令 → 向量     （bn.p256mul 之后紧接 bn.mulvm.8S / bn.mulvml.8S）
 *
 * 每组都跑两遍：**参考**（无新指令）与**混合**（插入新指令），
 * 两遍结果 XOR 后 OR 进 err（w29）：**w29 == 0 即全部通过**。
 * 另外检查：
 *   A   别名组合（判据「wa=wb / wd=wa / wd=wb / 三者相同」全覆盖）；
 *   A6  边角：(p-1)^2 = 1（走条件修正路径，且用 wa=wb 形式）；
 *   C   连续两条 bn.p256mul **不同输入、同一目的寄存器**（排除"第一次的暂存被复用"）。
 *
 * ⚠ 写"混合"序列时的语义约束：新指令**会**留下 ACC 末值（与旧实现清 0 不同，
 *   见 P5 的 clobber 审计：`mul_modp` 的调用点都不消费 FG0/ACC）。因此插入点**之后**
 *   的旧代码必须自己显式清零 ACC（用 `.z` 形式）—— 否则那是**语义差异**、不是串值，
 *   不能写成"失败"。本程序所有"后段"旧代码都以 `.z` 开头，正是为此。
 *
 * Oracle（两层）：
 *   ① runner 用 otbn_top_sim，把 RTL 与 Python ISS **逐条指令对拍** —— RTL/ISS 在这条
 *      指令上只要有一点分歧，仿真立刻以 mismatch 报错退出；
 *   ② 本程序自身的 ref-vs-mixed 比较，覆盖"模型与 RTL 都同意、但语义被破坏"的情形。
 */

.section .text.start

  /* ── 输入：与 p256_fold_test 同一组官方向量（低字在前） ── */
  li        x2, 24
  la        x3, d0
  bn.lid    x2, 0(x3)              /* w24 = d0 */
  li        x2, 25
  la        x3, x
  bn.lid    x2, 0(x3)              /* w25 = x  */
  li        x2, 26
  la        x3, y
  bn.lid    x2, 0(x3)              /* w26 = y  */
  li        x2, 27
  la        x3, p_m1
  bn.lid    x2, 0(x3)              /* w27 = p-1 */

  /* err = 0 */
  bn.xor    w29, w29, w29

  /* ════════════ A. 别名组合 ════════════ */

  /* A0（基准，独立寄存器）：w19 = d0*x */
  bn.p256mul w19, w24, w25

  /* A1 wd=wb：w18 ← x，再 w18 = d0*w18 ⇒ 应与 A0 逐位相同 */
  li        x2, 18
  la        x3, x
  bn.lid    x2, 0(x3)
  bn.p256mul w18, w24, w18
  bn.xor    w23, w19, w18
  bn.or     w29, w29, w23

  /* A2（基准，独立寄存器）：w17 = x*y */
  bn.p256mul w17, w25, w26

  /* A3 wd=wa：w21 ← x，再 w21 = w21*y（原地）⇒ 应与 A2 相同 */
  li        x2, 21
  la        x3, x
  bn.lid    x2, 0(x3)
  bn.p256mul w21, w21, w26
  bn.xor    w23, w17, w21
  bn.or     w29, w29, w23

  /* A4 wa=wb：w20 = x*x */
  bn.p256mul w20, w25, w25

  /* A5 三者相同：w22 ← x，再 w22 = w22*w22 ⇒ 应与 A4 相同 */
  li        x2, 22
  la        x3, x
  bn.lid    x2, 0(x3)
  bn.p256mul w22, w22, w22
  bn.xor    w23, w20, w22
  bn.or     w29, w29, w23

  /* A6 边角：(p-1)^2 mod p = 1（wa=wb 形式；走条件修正路径） */
  bn.p256mul w16, w27, w27
  li        x2, 15
  la        x3, one
  bn.lid    x2, 0(x3)
  bn.xor    w23, w16, w15
  bn.or     w29, w29, w23

  /* ════════════ B1 旧 MAC → 新指令 ════════════ */
  bn.mulqacc.z  w2.0, w3.0,  0
  bn.mulqacc    w2.2, w3.2,  0
  bn.mulqacc    w2.3, w3.3, 64
  bn.mulqacc.so w4.L, w2.1, w3.1, 64
  bn.or         w10, w4, w4                 /* 存参考结果 */
  /* 混合：第一个 mulqacc 之后立刻插入新指令；后段以 .z 显式清零 ACC（见文件头⚠） */
  bn.mulqacc.z  w2.0, w3.0,  0
  bn.p256mul    w5, w24, w25                /* ← 插入 */
  bn.mulqacc.z  w2.2, w3.2,  0
  bn.mulqacc    w2.3, w3.3, 64
  bn.mulqacc.so w4.L, w2.1, w3.1, 64
  bn.xor        w23, w10, w4
  bn.or         w29, w29, w23

  /* ════════════ B2 新指令 → 旧 MAC ════════════ */
  bn.mulqacc.z  w2.0, w3.0,  0
  bn.mulqacc    w2.1, w3.1, 64
  bn.mulqacc.so w4.L, w2.2, w3.2, 64
  bn.or         w11, w4, w4                 /* 存参考结果 */
  /* 混合：新指令先跑，紧接着同一段旧序列（后段自清 ACC） */
  bn.p256mul    w5, w26, w24                /* ← 插入 */
  bn.mulqacc.z  w2.0, w3.0,  0
  bn.mulqacc    w2.1, w3.1, 64
  bn.mulqacc.so w4.L, w2.2, w3.2, 64
  bn.xor        w23, w11, w4
  bn.or         w29, w29, w23

  /* ════════════ B3 向量 → 新指令 ════════════ */
  bn.mulvm.8S   w4, w2, w3
  bn.addvm.8S   w4, w4, w3
  bn.or         w12, w4, w4                 /* 存参考结果 */
  /* 混合：两条向量指令之间插入新指令 */
  bn.mulvm.8S   w4, w2, w3
  bn.p256mul    w5, w24, w25                /* ← 插入 */
  bn.addvm.8S   w4, w4, w3
  bn.xor        w23, w12, w4
  bn.or         w29, w29, w23

  /* ════════════ B4 新指令 → 向量 ════════════ */
  bn.mulvm.8S   w4, w25, w26
  bn.mulvml.8S  w6, w25, w26, 1
  bn.or         w13, w4, w4                 /* 存参考结果 */
  /* 混合：新指令之后紧接同一对向量指令 */
  bn.p256mul    w5, w24, w25                /* ← 插入 */
  bn.mulvm.8S   w4, w25, w26
  bn.mulvml.8S  w6, w25, w26, 1
  bn.xor        w23, w13, w4
  bn.or         w29, w29, w23

  /* ════════════ C. 连续两条 bn.p256mul、不同输入、同一目的寄存器 ════════════ */
  bn.p256mul w30, w24, w25                  /* w30 = d0*x */
  bn.p256mul w30, w26, w26                  /* w30 = y*y（覆盖，输入不同）*/
  bn.p256mul w9,  w26, w26                  /* 参照：独立寄存器算 y*y */
  bn.xor     w23, w30, w9
  bn.or      w29, w29, w23

  ecall

.section .data

/* Example ECDH scalar from the official P-256 test vector set (low word first). */
.globl d0
.balign 32
d0:
  .word 0xfe6d1071
  .word 0x21d0a016
  .word 0xb0b2c781
  .word 0x9590ef5d
  .word 0x3fdfa379
  .word 0x1b76ebe8
  .word 0x74210263
  .word 0x1420fc41

/* Example curve point x-coordinate from the same vector set. */
.globl x
.balign 32
x:
  .word 0xbfa8c334
  .word 0x9773b7b3
  .word 0xf36b0689
  .word 0x6ec0c0b2
  .word 0xdb6c8bf3
  .word 0x1628ce58
  .word 0xfacdc546
  .word 0xb5511a6a

/* Example curve point y-coordinate from the same vector set. */
.globl y
.balign 32
y:
  .word 0x9e008c2e
  .word 0xa8707058
  .word 0xab9c6924
  .word 0x7f7a11d0
  .word 0xb53a17fa
  .word 0x43dd09ea
  .word 0x1f31c143
  .word 0x42a1c697

/* p - 1, the largest value below the P-256 prime (low word first). */
.globl p_m1
.balign 32
p_m1:
  .word 0xfffffffe
  .word 0xffffffff
  .word 0xffffffff
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000001
  .word 0xffffffff

/* 常数 1（给 A6 做 (p-1)^2 的期望值）。 */
.globl one
.balign 32
one:
  .word 0x00000001
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
  .word 0x00000000
