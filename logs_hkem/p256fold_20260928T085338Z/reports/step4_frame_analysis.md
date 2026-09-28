# Step 4 · 一帧的 53 条指令与那个 fetch gap（基线 `2d87e79bee`）

> 内容 = 文档 `01_P0_基线冻结与复现.md` Step 4 三段命令（4a/4b/4c）的原始输出 + 判据结论。
> 输入：`sw/otbn/crypto/p256_base.s`、`logs_hkem/rtl_extra/stall_levels_ver1_1.json`、`reports/frames_p256.csv`。

## 4a. 静态源码：一帧 = 53 条指令

```
$ sed -n '419,579p' sw/otbn/crypto/p256_base.s | grep -c '^\s*bn\.'
52
$ sed -n '419,579p' sw/otbn/crypto/p256_base.s | grep -n '\bret\b'
143:  ret
```

- 52 条 `bn.*` + 1 条 `ret` = **53 条**；`ret` 在相对第 143 行 = **绝对第 561 行**（419+143−1）。

## 4b. 逐 opcode 的每帧计数（ECDH A 会话，`frames = 9602`）

```
frames 9602
  bn.mulqacc       n=192040  stall=0    fetch=0     n/frames=20.0000
  bn.addm          n=76816   stall=0    fetch=0     n/frames=8.0000
  bn.add           n=67214   stall=0    fetch=0     n/frames=7.0000
  bn.sub           n=48010   stall=0    fetch=0     n/frames=5.0000
  bn.mulqacc.wo    n=38408   stall=0    fetch=0     n/frames=4.0000
  bn.rshi          n=28806   stall=0    fetch=0     n/frames=3.0000
  bn.mulqacc.so    n=19204   stall=0    fetch=0     n/frames=2.0000
  bn.addc          n=9602    stall=0    fetch=0     n/frames=1.0000
  bn.subb          n=9602    stall=0    fetch=0     n/frames=1.0000
  bn.subm          n=9602    stall=0    fetch=0     n/frames=1.0000
  jalr             n=9602    stall=0    fetch=9602  n/frames=1.0000
```

- **`n / frames` 每一项都是整数**（20/8/7/5/4/3/2/1/1/1/1）；合计 `n = 508,906 = 53 × 9,602`。
- 每帧 opcode 数相加：20+8+7+5+4+3+2+1+1+1+1 = **53**，与静态源一致（26 条 `bn.mulqacc*` + 8 `bn.addm` + 7 `bn.add` + 5 `bn.sub` + 3 `bn.rshi` + `bn.addc`/`bn.subb`/`bn.subm` 各 1 + 1 条 `ret`）。
- **帧内唯一的取指气泡挂在 `ret`（jalr）上**：`jalr` 的 `fetch = 9,602`（逐帧 1 拍）、`stall = 0`；其余 10 个 opcode 的 `fetch` **全为 0**。⇒ `E <ret 的 jalr>` → 空 1 拍 → `E <调用方恢复执行的第一条>`。

## 4c. 逐帧 CSV 侧：帧清单与形态

```
帧数 38390 | 会话分布 {'Keygen A': 9593, 'Keygen B': 9593, 'ECDH A': 9602, 'ECDH B': 9602}
首帧   {'session': 'Keygen A', 'frame_id': '11', 'entry_cycle': '1445268', 'resume_cycle': '1445322', 'retired': '53', 'exec_stall': '0', 'fetch_gap': '1'}
第 2 帧 {'session': 'Keygen A', 'frame_id': '12', 'entry_cycle': '1445328', 'resume_cycle': '1445382', 'retired': '53', 'exec_stall': '0', 'fetch_gap': '1'}
形态分布 {('53', '0', '1', '54')}
```

- 相邻 PC 的标法：`entry_cycle = C1`（被调函数第一条记录）→ `resume_cycle = C2`（调用方恢复执行的那一拍），**`span = C2 − C1 = 54`**，其中 53 拍退休 + 1 拍取指空档（`span − retired − exec_stall = 1`）；gap 即 `[C2−1, C2)`。
- **一致性结论**：全部 **38,390** 帧（= 9,593×2 + 9,602×2）的形态都是 `(53, 0, 1, 54)` —— **单一形态、逐实例相同（不是平均）**。

## 判据

| # | 判据 | 结果 |
|---|---|---|
| 1 | 逐 opcode `n / frames` 每项为整数 | ✓ 11/11 项 |
| 2 | `jalr` 的 `fetch_per_inst` 只有键 `'1'` | ✓（fetch 总数 = 9,602 = 帧数） |
| 3 | 其余 opcode 的 `fetch` 全为 0 | ✓ 10/10 |
| 4 | `mul_modp` 帧形态唯一 | ✓ `{(53,0,1,54)}`（38,390 帧） |
