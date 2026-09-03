# kmac_official — 官方 OTBN KMAC 驱动（逐字来自官方 master）

验证"官方 OTBN↔KMAC 直连驱动"在本工作区可用。`xof.s` 与 `tests/` 下 4 组测试
均从官方 master `sw/otbn/crypto/` 原样提取，未做任何修改。

## 来源

| 文件 | 官方 master 路径 |
|---|---|
| `xof.s` | `sw/otbn/crypto/xof.s`（官方 mlkem1024/mldsa87 共用驱动） |
| `tests/xof_*.{s,hjson}` | `sw/otbn/crypto/tests/` |

## Linux 上运行

```bash
cd ~/new_pqc/opentitan
bazel test //test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:all --cache_test_results=no
```

ISS（otbnsim）已建模 KMAC 接口（`hw/ip/otbn/dv/otbnsim/sim/kmac.py`），此测试
验证驱动逻辑与 ISS 模型一致。RTL 级验证走 verilator chip sim / co-sim。

## 已确认的技术事实

- 工作区汇编器对 ISR/WSR 名大小写不敏感（`operand.py` 查找时 lower()），
  `xof.s` 里的大写名 `KMAC_CFG/KMAC_CTRL/KMAC_STATUS/KMAC_STRB/KMAC_DATA_S0/S1`
  能解析到工作区 `hw/ip/otbn/data/csr.yml`/`wsr.yml` 中的小写条目。
- **注意：工作区 fork 的 KMAC ISR 地址与官方 master 不同**（官方
  kmac_status=0x7db，本 fork=0x7d9，整体偏移 2）。因此同一份 xof.s 二进制
  在本 fork RTL 与官方 master RTL 上不通用——基线若要在"纯官方 RTL"上跑，
  需要用官方 csr.yml 重汇编。这一点须在论文基线口径中说明。
- 官方驱动保留 x28-x30（rate 计数 x28/x29、超时 x30），调用方不得破坏；
  `xof_absorb` 消耗 x20(长度)/x21/x22(两 share 指针，调用后前移)；
  `xof_squeeze24/32` 输出到 w29/w30（布尔双 share，非掩码时 w30=0）。
