# P5 Step 3 前置审计：`mul_modp` 调用点的 flags / ACC 依赖

口径：`06_P5_wrapper替换与KAT.md` Step 3。新实现 `bn.p256mul` **不修改任何 flag group**，
旧实现 clobber **FG0**；`p256_base.s:405` 已写下契约「Flags have no meaning beyond the scope of this subroutine」。
方法：每个 `jal x1, mul_modp` 起向下扫 6 条有效指令（跳过空行/注释），出现 FG0 直读、`bn.sel …, FG0.x`、`bn.addc`/`bn.subb` 即判「需同步修正调用方」。
脚本：`run_dir/rtl/clobber_audit.py`（可复跑）。

## 结论：调用点 69 个，命中 0 个 ⇒ **全部「保持」**

两个**已文档化的例外**（`p256_base.s:50-95` 的 `trigger_fault_if_fg0_z` / `trigger_fault_if_fg0_not_z`）是**读取** FG0 做故障检查的
例程，其 FG0 来自各自调用点前面的 `bn.*`，与 `mul_modp` 无关 ⇒ 不在本审计的命中里。

## 逐调用点

| 文件 | 行 | 紧随其后第一条有效指令 | 命中 | 结论 |
|---|---|---|---|---|
| `sw/otbn/crypto/p256_base.s` | 650 | `bn.mov    w14, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 656 | `bn.mov    w15, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 662 | `bn.mov    w16, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 674 | `bn.addm   w18, w14, w15` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 691 | `bn.mov    w18, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 709 | `bn.mov    w11, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 721 | `bn.subm   w11, w12, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 741 | `bn.addm   w15, w16, w16` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 773 | `bn.mov    w15, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 779 | `bn.mov    w16, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 785 | `bn.addm   w12, w19, w16` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 793 | `bn.subm   w11, w19, w15` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 801 | `bn.mov    w13, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 807 | `bn.addm   w13, w13, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 866 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 871 | `bn.mov    w12, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 877 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 882 | `bn.mov    w13, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 889 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 892 | `bn.mov    w14, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 899 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 902 | `bn.mov    w15, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 909 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 912 | `bn.mov    w16, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 919 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 922 | `bn.mov    w17, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 929 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 932 | `bn.mov    w18, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 939 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 942 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 948 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 951 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 957 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 960 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 966 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 969 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 975 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 978 | `bn.mov    w14, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 985 | `bn.mov    w11, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 992 | `bn.mov    w12, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 1112 | `bn.mov    w14, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 1122 | `bn.mov    w15, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 1178 | `bn.addm   w14, w19, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 1185 | `bn.addm   w15, w19, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 1191 | `bn.mov    w16, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 1197 | `bn.addm   w17, w19, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 1203 | `bn.subm   w18, w19, w17` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 1210 | `bn.mov    w8, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 1216 | `bn.mov    w24, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 1219 | `bn.mov    w10, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 1225 | `bn.mov    w15, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 1231 | `bn.subm   w15, w15, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 1496 | `bn.mov    w4, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 1502 | `bn.mov    w5, w19` | — | **保持** |
| `sw/otbn/crypto/p256_base.s` | 1508 | `bn.mov    w6, w19` | — | **保持** |
| `sw/otbn/crypto/p256_isoncurve.s` | 69 | `bn.mov    w25, w19` | — | **保持** |
| `sw/otbn/crypto/p256_isoncurve.s` | 74 | `x three times from x^3.` | — | **保持** |
| `sw/otbn/crypto/p256_isoncurve.s` | 94 | `ret` | — | **保持** |
| `sw/otbn/crypto/p256_isoncurve_proj.s` | 60 | `z^2 three times from 0.` | — | **保持** |
| `sw/otbn/crypto/p256_isoncurve_proj.s` | 72 | `bn.mov    w25, w26` | — | **保持** |
| `sw/otbn/crypto/p256_isoncurve_proj.s` | 77 | `bn.mov    w27, w19` | — | **保持** |
| `sw/otbn/crypto/p256_isoncurve_proj.s` | 91 | `bn.mov    w18, w19` | — | **保持** |
| `sw/otbn/crypto/p256_isoncurve_proj.s` | 99 | `bn.mov    w25, w19` | — | **保持** |
| `sw/otbn/crypto/p256_isoncurve_proj.s` | 104 | `bn.addm   w18, w19, w18` | — | **保持** |
| `sw/otbn/crypto/p256_isoncurve_proj.s` | 120 | `w26 <= dmem[z] */` | — | **保持** |
| `sw/otbn/crypto/p256_isoncurve_proj.s` | 130 | `ret` | — | **保持** |
| `sw/otbn/crypto/p256_shared_key.s` | 137 | `to save memory (not needed afterwards)` | — | **保持** |
| `sw/otbn/crypto/p256_verify.s` | 317 | `la        x3, p256_n` | — | **保持** |
| `sw/otbn/crypto/tests/p256_mul_modp_test.s` | 42 | `ecall` | — | **保持** |

## 局限（如实记录）

- 窗口是**启发式**（默认 6 条有效指令）；命中为 0 属于"未发现依赖"，且有 `p256_base.s:405`
  的显式契约与官方注释背书。若日后新增调用点，重跑本脚本即可。
- ACC：旧实现不消费调用前的 ACC（每次都自清零），新实现可破坏 ACC ⇒ 无需调用方修正；
  ISS 侧已按实测把指令末尾的 ACC 值对齐（见 `04_P3_*.md` §7.3 #9）。
