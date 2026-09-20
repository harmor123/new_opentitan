.section .data
.globl context
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

/* rc 的每个常量占满一个 32 B 槽：低 64 位 = 常量，高 192 位 = 0。
   keccakf 的 IOTA 步 `bn.lid x31, 0(x6++)` 每轮都**整 32 B** 读一个槽，
   包括最后一个槽 —— 所以表尾必须补齐到 32 B。
   若 rc 恰好是已下装 DMEM 镜像里的最后一个符号（缺这 24 B），最后那个整字读
   就会越过镜像；未下装字的 integrity 位无效 ⇒ ISS 报 DMEM_INTG_VIOLATION
   并当场中止运行（2026-09-20 ver0_1 的 encap_h_ek 与 decap_hash_g_reuse
   两行即此因：Δinsn 只有 7,089/5,679，Keccak-f 只跑了 1 个排列）。 */
  .balign 32
