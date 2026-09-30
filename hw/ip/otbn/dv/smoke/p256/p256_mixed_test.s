/* Copyright lowRISC contributors (OpenTitan project). */
/* Licensed under the Apache License, Version 2.0, see LICENSE for details. */
/* SPDX-License-Identifier: Apache-2.0 */

/**
 * P-256 mixed-instruction test（P6 Step 4：新旧指令交替 / 临时寄存器不串值）。
 *
 * 判据（PDF §11 P6，逐字）：「新旧指令**交替**使用时临时寄存器不会串值」。
 *
 * 做法：**参考值全部先在"干净上下文"里各算一遍**，再到"交替上下文"里重算一遍，
 * 逐位 XOR 后 OR 进 err（w29）：**w29 == 0 即全部通过**。四条交替模式：
 *
 *   B1/B2  旧链 A → bn.p256mul → 旧链 B（旧→新→旧，链级交替）
 *   B3     向量 → bn.p256mul → 向量（插在两条向量指令之间）
 *   B4     bn.p256mul → 向量
 * 另外：
 *   A   别名组合（判据「wa=wb / wd=wa / wd=wb / 三者相同」全覆盖）；
 *   A6  边角：(p-1)^2 = 1（走条件修正路径，且用 wa=wb 形式）；
 *   C   连续两条 bn.p256mul **不同输入、同一目的寄存器**（排除"第一次的暂存被复用"）。
 *
 * ⚠ 两条来自 RTL/ISA 的硬约束，写这类交替测试时必须遵守，否则测的是假象：
 *
 *   ① **先把 WDR 显式清零**。OTBN 每次 start 都会用 URND 随机数把 32 个 WDR 全写一遍
 *      （`otbn_core.sv:1018-1025` 的 `sec_wipe_wdr_q` 分支给 `urnd_data`，
 *       由 `otbn_start_stop_control.sv:289` 的 `OtbnStartStopSecureWipeWdrUrnd` 状态驱动），
 *      而 Python ISS 把 WDR 建模为 0 ⇒ **读未初始化的 WDR 必然 RTL↔ISS 分歧**。
 *      实测：漏掉清零点，`bn.mulqacc` 一读 w2/w3 就报 ACC 分歧（错的是测试、不是 RTL）。
 *
 *   ② **旧链的起头用 `.z`、收尾用 `.wo`**。`bn.mulqacc` 不带写回时 `wrd` 字段是 don't-care、
 *      ACC 保持脏值（`bignum-insns.yml` 的 `bn.mulqacc`：`wrd: bxxxxx`），且 `.wo` 只把 ACC
 *      写回 WDR、**不清** ACC（同文件 `bn.mulqacc.wo` 的 doc）。所以新指令插在两条旧链之间时，
 *      后面的旧链必须自己 `.z` 起头 —— 这是**语义约定**，不是"串值"。
 *      同理，累加链**中途**插入新指令会丢掉已累加的部分（ACC 被覆盖），因此交替点只能取在
 *      链边界上：本程序即按"链 A → 新指令 → 链 B"交替。
 *
 * Oracle（两层）：
 *   ① runner 用 otbn_top_sim，把 RTL 与 Python ISS **逐条指令对拍** —— RTL/ISS 在这条
 *      指令上只要有一点分歧，仿真立刻以 mismatch 报错退出；
 *   ② 本程序自身的 ref-vs-mixed 比较，覆盖"模型与 RTL 都同意、但语义被破坏"的情形。
 */

.section .text.start

  /* ── 前奏：先把 32 个 WDR 显式清零（见文件头⚠①；本仓库所有正规 OTBN 程序都以此开头）── */
  bn.xor    w0, w0, w0
  bn.xor    w1, w1, w1
  bn.xor    w2, w2, w2
  bn.xor    w3, w3, w3
  bn.xor    w4, w4, w4
  bn.xor    w5, w5, w5
  bn.xor    w6, w6, w6
  bn.xor    w7, w7, w7
  bn.xor    w8, w8, w8
  bn.xor    w9, w9, w9
  bn.xor    w10, w10, w10
  bn.xor    w11, w11, w11
  bn.xor    w12, w12, w12
  bn.xor    w13, w13, w13
  bn.xor    w14, w14, w14
  bn.xor    w15, w15, w15
  bn.xor    w16, w16, w16
  bn.xor    w17, w17, w17
  bn.xor    w18, w18, w18
  bn.xor    w19, w19, w19
  bn.xor    w20, w20, w20
  bn.xor    w21, w21, w21
  bn.xor    w22, w22, w22
  bn.xor    w23, w23, w23
  bn.xor    w24, w24, w24
  bn.xor    w25, w25, w25
  bn.xor    w26, w26, w26
  bn.xor    w27, w27, w27
  bn.xor    w28, w28, w28
  bn.xor    w29, w29, w29
  bn.xor    w30, w30, w30
  bn.xor    w31, w31, w31

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

  /* 旧 MAC / 向量那几段的操作数：从 .data 显式取**非零**值。
     全零会让"串值"类缺陷失效（脏值乘 0 仍是 0），也会掩盖累加链的语义差异。 */
  li        x2, 2
  la        x3, d0
  bn.lid    x2, 0(x3)              /* w2 = d0 */
  li        x2, 3
  la        x3, x
  bn.lid    x2, 0(x3)              /* w3 = x  */

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

  /* ════════════ B0. 参考值：三段旧序列 + 一条新指令，各自在干净上下文里算 ════════════ */

  /* 新指令参考值 */
  bn.p256mul    w14, w24, w25               /* w14 = d0*x */

  /* 链 A（4 条 bn.mulqacc：`.z` 起头、`.wo` 收尾）*/
  bn.mulqacc.z  w2.0, w3.0,  0
  bn.mulqacc    w2.2, w3.2,  0
  bn.mulqacc    w2.3, w3.3, 64
  bn.mulqacc.wo w10, w2.1, w3.1, 64         /* w10 = 链 A 结果（干净上下文）*/

  /* 链 B（3 条 bn.mulqacc）*/
  bn.mulqacc.z  w2.0, w3.0,  0
  bn.mulqacc    w2.1, w3.1, 64
  bn.mulqacc.wo w11, w2.2, w3.2, 64         /* w11 = 链 B 结果（干净上下文）*/

  /* 向量 A（2 条）*/
  bn.mulvm.8S   w12, w2, w3
  bn.addvm.8S   w12, w12, w3                /* w12 = 向量 A 结果（干净上下文）*/

  /* 向量 B（2 条；只比 mulvm 的输出，mulvml 作为上下文一起跑）*/
  bn.mulvm.8S   w13, w25, w26
  bn.mulvml.8S  w13, w25, w26, 1            /* w13 含累加后的末值（干净上下文）*/

  /* ════════════ B1/B2 交替：链 A → 新指令 → 链 B ════════════ */
  bn.mulqacc.z  w2.0, w3.0,  0              /* 链 A 在交替上下文里重跑 */
  bn.mulqacc    w2.2, w3.2,  0
  bn.mulqacc    w2.3, w3.3, 64
  bn.mulqacc.wo w4, w2.1, w3.1, 64          /* 收尾是 `.wo` ⇒ ACC 里仍留着脏值 */
  bn.p256mul    w5, w24, w25                /* ← 插在两条旧链之间（B1：紧跟脏 ACC）*/
  bn.mulqacc.z  w2.0, w3.0,  0              /* 链 B：`.z` 起头（见文件头⚠②）*/
  bn.mulqacc    w2.1, w3.1, 64
  bn.mulqacc.wo w6, w2.2, w3.2, 64
  bn.xor        w23, w4, w10                /* 链 A：交替上下文 vs 干净上下文 */
  bn.or         w29, w29, w23
  bn.xor        w23, w5, w14                /* 新指令：紧随旧链的脏 ACC（B1）*/
  bn.or         w29, w29, w23
  bn.xor        w23, w6, w11                /* 链 B：紧随新指令留下的 ACC（B2）*/
  bn.or         w29, w29, w23

  /* ════════════ B3 向量 → 新指令 → 向量 ════════════ */
  bn.mulvm.8S   w7, w2, w3
  bn.p256mul    w5, w24, w25                /* ← 插在两条向量指令之间 */
  bn.addvm.8S   w7, w7, w3
  bn.xor        w23, w7, w12
  bn.or         w29, w29, w23
  bn.xor        w23, w5, w14
  bn.or         w29, w29, w23

  /* ════════════ B4 新指令 → 向量 ════════════ */
  bn.p256mul    w5, w24, w25                /* ← 新指令在前 */
  bn.mulvm.8S   w8, w25, w26
  bn.mulvml.8S  w8, w25, w26, 1
  bn.xor        w23, w8, w13
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
