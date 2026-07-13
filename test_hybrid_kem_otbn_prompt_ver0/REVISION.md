# 修订记录 (ver0_base — 纯软件基线)

## 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v0.1 | 2026-05-25 | 初始创建：目录结构、Ibex C 调度框架、OTBN 汇编包装器 |
| v0.2 | 2026-05-25 | HKDF/HMAC 纯软件实现（sha3_init/update/final 替代 KMAC 硬件） |
| v0.3 | 2026-05-25 | ML-KEM 三阶段：keypair/encap/decap 库代码迁移自 test/kyber_ver0_base |
| v0.4 | 2026-05-25 | P-256 ECDH 集成（同 HW 版） |
| v0.5 | 2026-06-05 | rc 布局修复: hmac_test.s / hkdf_test.s 每个 .dword 加 .balign 32 (bn.lid 32B 步进) |
| v0.6 | 2026-06-05 | w31 初始化修复: sha3_shake_test.s / hkdf_test.s 添加 bn.xor w31,w31,w31 |
| v0.7 | 2026-06-05 | ML-KEM 测试改用 test/kyber_ver0_base 原始版本 |
| v0.8 | 2026-06-05 | mlkem768/BUILD 移除重复 sha3_shake 规则 |
| v0.9 | 2026-06-05 | co_sim/ 脚本清理: 去除 bnmulv_ver2，路径指向 base |
| v1.0 | 2026-06-05 | **全部 ISS / co_sim / Chip Sim 通过** |
| v1.1 | 2026-06-05 | hmac.s 重写对齐 HW 结构，sha3_shake.s ra 覆盖修复 (x17 保存/恢复) |
| v1.2 | 2026-06-05 | ibex/*.c 清理调试 LOG_INFO，ref/*.py 测试向量更新 (HW+base 同步) |

## 当前测试状态

| 测试 | ISS | co_sim | Chip Sim |
|------|-----|--------|----------|
| SHA3 | PASSED | PASSED | — |
| HMAC | PASSED | PASSED | — |
| HKDF | PASSED | PASSED | PASSED |
| P-256 ECDH | PASSED | PASSED | PASSED |
| ML-KEM keypair | PASSED | PASSED | PASSED |
| ML-KEM encap | PASSED | PASSED | PASSED |
| ML-KEM decap | PASSED | PASSED | PASSED |
| Phase 1 KeyGen | — | — | PASSED |
| Phase 2 Alice | — | — | PASSED |
| Phase 2 Bob | — | — | PASSED |

## 关键修复记录

### rc 布局 (v0.5)

keccakf 使用 `bn.lid x31, 0(x6++)` 加载轮常量，每次加载 32B 并步进 32。hmac_test.s / hkdf_test.s 的 rc 原本是 packed (8B 间距)，需改为每个 .dword 独占 32B 槽（加 .balign 32），否则第 7-24 轮读取越界数据。

### w31 初始化 (v0.6)

sha3_shake.s 所有函数要求 w31 为全零 WDR 常数。ISS 默认清零 WDR，但 RTL 未初始化。sha3_shake_test.s / hkdf_test.s 缺少 `bn.xor w31, w31, w31`，导致 co_sim RTL/ISS 发散。

### mlkem768/BUILD 重复规则 (v0.8)

mlkem768/BUILD 第 18-19 行 `sha3_shake` 规则重复定义，导致 `bazel test ...:all` 分析失败。

## 与 HW 版 (test_hybrid_kem_otbn_prompt_ver2) 差异

| 项目 | HW | SW (base) |
|------|-----|-----------|
| ML-KEM | BNMULV_VER2 加速 | 纯软件基线指令 |
| SHA3/HMAC | KMAC 硬件加速 | 纯软件 Keccak-f |
| HKDF | hkdf_sha3_256.s + KMAC | 同接口，内部用 SW hmac.s |
| P-256 | p256_base.s | 完全相同 |
| 测试向量 | .dexp | 相同 |
