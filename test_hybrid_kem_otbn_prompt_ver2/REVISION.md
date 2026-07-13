# 修订记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-06-02 | 重新初始搭建: test_hybrid_kem_otbn_prompt_ver2 目录, standalone chip sim 测试 |
| v1.1 | 2026-06-03 | LOG_INFO "PASS" → "OK" 修复假阳性 |
| v1.2 | 2026-06-03 | ML-KEM keypair/encap/decap chip sim 通过 |
| v2.0 | 2026-06-04 | P-256 深度调试: 定位官方 vs 差异, 测试向量切换为基点 G |
| v2.5 | 2026-06-04 | IKM 去掉 role, HKDF Expand 添加 info 支持 |
| v2.8 | 2026-06-04 | Phase 1/2 拆分: phase1_keygen, phase2_alice/bob |
| v3.0 | 2026-06-04 | 文档完善, ref/ 分为 phase1/phase2 子目录 |
| v3.2 | 2026-06-04 | HKDF info 支持完成: input_info_len 独立符号, 注释更新 |
| v3.4 | 2026-06-04 | **KMAC RTL 修复**: `process_cnt_q` auto-permutation 初始化 |
| v4.0 | 2026-06-05 | **全部 8/8 chip sim 通过**: standalone×6 + Phase1 + Phase2(Alice+Bob) |

## 当前测试状态

| 测试 | ISS | Chip Sim | 验证 |
|------|-----|------|------|
| P-256 ECDH | ✅ | ✅ | x0 ^ x1 == ss_e |
| P-256 KeyGen | ✅ | ✅ | pk_x, pk_y |
| ML-KEM keypair | ✅ | ✅ | pk_m[1184], sk_m[2400] |
| ML-KEM encap | ✅ | ✅ | ct_m[1088], ss_m[32] |
| ML-KEM decap | ✅ | ✅ | ss_m[32] |
| HKDF standalone | ✅ | ✅ | OKM[32] |
| Phase 1 KeyGen | — | ✅ | P-256 + ML-KEM |
| Phase 2 Alice | — | ✅ | ECDH + Encap + HKDF |
| Phase 2 Bob | — | ✅ | Decap + ECDH + HKDF |

## 关键修复记录

### KMAC RTL (`hw/ip/otbn/rtl/otbn_kmac.sv`)

- **process_cnt_q**: auto-permutation (StMsgFeed→StProcessing) 时设为 ProcessCycles，解决连续 HMAC 调用时 Keccak 处理周期跳过

### HKDF 汇编 (`otbn/hkdf/hkdf_sha3_256.s`)

- `hkdf_extract`: IKM 不含 info (info 仅在 Expand 使用)
- `hkdf_expand`: 支持 `input_info` + `input_info_len` 独立传入
- `input_lengths` 布局: +0=ctx, +4=sid, +8=okm_len

### 文件结构 (v3.0)

- `ref/` 分为 `phase1/` (p256_kat.py, gen_kat.py) 和 `phase2/` (hkdf_kat_alice.py, hkdf_kat_bob.py)
- 删除重复的 test wrapper (`otbn/p256/p256_ecdh_shared_key_test.s`), 统一使用 `otbn/test/`
