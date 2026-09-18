.section .text

/*
 * 拒绝采样隔离用的桩（ver0_2 / KMAC 路径）。
 *
 * 思路与 ver0_1 版相同：poly_gen_matrix.s **一字不改**，只把它的哈希依赖
 * 换掉 —— KMAC 驱动的 API 全部变成 no-op，唯独 xof_squeeze32 改为从
 * 预计算流里拷 32 字节，从而让拒绝采样循环跑**完全相同的数据轨迹**，
 * 但不付 KMAC 的代价。
 *
 * 与 ver0_1 版的对应关系：
 *   sha3_init / sha3_update / shake_xof   ->  xof_*_init / xof_absorb / xof_process
 *   shake_out (写 x11 指向的缓冲)          ->  xof_squeeze32 (写 w29/w30 两个掩码份额)
 */

.globl xof_shake128_init
xof_shake128_init:
  ret

.globl xof_absorb
xof_absorb:
  ret

.globl xof_process
xof_process:
  ret

.globl xof_finish
xof_finish:
  ret


/*
 * xof_squeeze32 替代：不算 KMAC，直接把预计算流的下一块 32 B 放进 w29，
 * w30 清零 —— 调用方做 bn.xor w0, w29, w30 后即得到与真实 XOF 相同的字节。
 */
.globl xof_squeeze32
xof_squeeze32:
  /* 取当前流指针 */
  la   x3, rejection_stream_ptr
  lw   x4, 0(x3)

  /* w29 = 32 B（真实 SHAKE128 输出） */
  li     x5, 29
  bn.lid x5, 0(x4)
  /* w30 = 0（份额的另一半） */
  bn.xor w30, w31, w31

  /* 前进到下一块 */
  addi x4, x4, 32
  sw   x4, 0(x3)

  ret
