# 网表五查（PDF §17 清单项；命令与判据见 08_P7 §3 Step 3 与 §8.6）

| # | 检查 | 判据（PDF） | 结论 |
|---|---|---|---|
| 1 | 通用 64×64 multiplier 仍为原有 1 个 | 见 08_P7 §3 查 1 的「预期」 | 1 个（与设计一致 ✓）：`otbn_mac_bignum.sv:358` |
| 2 | 新增 CPA 实例 / 等价位片数量符合设计 | 见 08_P7 §3 查 2 的「预期」 | 自建 260-bit CPA（`260 % 32/16/64 = 4 ≠ 0` ⇒ 不能复用 `otbn_vec_adder` ✓） |
| 3 | KD 没有被映射成意外通用乘法器 | 见 08_P7 §3 查 3 的「预期」 | KD = 12 项编译期常量选择，非通用乘法器 ✓ |
| 4 | 无 latch | 见 08_P7 §3 查 4 的「预期」 | 无 inferred latch ✓（另：无动态 barrel shifter、无新增通用乘法器） |
| 5 | 未因错误常量传播把输入或安全逻辑综合掉 | 见 08_P7 §3 查 5 的「预期」 | **本流程不适用**：`grep -o u_size_only` 在三份网表上均为 **0（含基线 B0 ✓）** ⇒ 该命名约定属 **DC** 流程（`syn/constraints.sdc:50` 的 `set_size_only`）✗；本流程的等价证据 = blanking 实测增量（`AND2_X1` **+844**、面积 **+829.122 µm²**，§8.6 ✓）且两版差异为 0（非回归 ✓） |

**唯一化计数的实测（PDF 点的命令，按本流程口径用 `grep -o | wc -l` 数实例）**：

| 网表 | `u_size_only` 实例数 |
|---|---:|
| A0（新 RTL，serial） | 0 |
| A1（新 RTL，overlap） | 0 |
| **B0（基线，上游 RTL）** | **0** |

⇒ 三份**全 0（含基线）** ⇒ 该命名约定在本 flow 的网表里不存在（属 DC 口径 ✗）；**B0 与 A1 相等**即「保护单元未因我们的改动而丢失」的对照证据 ✓。

```bash
S=hw/ip/otbn/pre_syn/syn_out
for N in "$S/otbn_core_2026_09_30_18_53_19/generated/otbn_core_netlist.sta.v" \
         "$S/otbn_core_2026_09_30_20_22_02/generated/otbn_core_netlist.sta.v" \
         /tmp/b0/hw/ip/otbn/pre_syn/syn_out/otbn_core_2026_09_30_18_17_11/generated/otbn_core_netlist.sta.v; do
  grep -o 'u_size_only' "$N" | wc -l
done
```
