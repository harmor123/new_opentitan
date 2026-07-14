# Hybrid KEM 详细流程图 — ver1 (KMAC-KDF)

## Phase 1: 密钥生成 (Bob 离线)

```
┌─ Phase 1: Bob KeyGen ─────────────────────────────────────────────┐
│                                                                    │
│  Step 1: P-256 ECDH                                                │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ OTBN: p256_ecdh_shared_key                                   │ │
│  │                                                               │ │
│  │ Ibex → OTBN:                                                  │ │
│  │   d0[64]  ← kInputD0    (Bob 私钥, 320-bit 份额)              │ │
│  │   d1[64]  ← {0}         (第二份额, 无掩码)                    │ │
│  │   x[32]   ← G.x         (P-256 基点)                          │ │
│  │   y[32]   ← G.y                                               │ │
│  │                                                               │ │
│  │ OTBN 执行: p256_shared_key(d, G)                               │ │
│  │   → scalar_mult_int (321次 double-and-add)                     │ │
│  │   → proj_to_affine → A2B 掩码转换                              │ │
│  │                                                               │ │
│  │ OTBN → Ibex:                                                  │ │
│  │   x[32] ← x0,  y[32] ← x1  (布尔份额)                         │ │
│  │                                                               │ │
│  │ Ibex: ss_e = x0 XOR x1 (32B)                                   │ │
│  │ CHECK: ss_e == kExpectedSsE                                    │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                              ↓ wipe                                │
│  Step 2: ML-KEM-768 KeyGen                                         │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ OTBN: mlkem768_keypair                                        │ │
│  │                                                               │ │
│  │ Ibex → OTBN: coins[64] ← kInputCoinsKp                         │ │
│  │ OTBN → Ibex: pk_m[1184], sk_m[2400]                            │ │
│  │                                                               │ │
│  │ CHECK: pk_m == kExpectedPkM, sk_m == kExpectedSkM              │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
│  输出: PK_Hyb = pk_m[1184] || ss_e[32]                             │
│        SK_Hyb = sk_m[2400] || d0[32]                               │
└────────────────────────────────────────────────────────────────────┘
```

## Phase 2: 密钥协商 (Alice ↔ Bob 在线)

### Alice — 封装

```
┌─ Phase 2 Alice: Encapsulation ────────────────────────────────────┐
│                                                                    │
│  Step 1: P-256 ECDH (临时密钥)                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ OTBN: p256_ecdh_shared_key                                   │ │
│  │                                                               │ │
│  │ Ibex → OTBN:                                                  │ │
│  │   d0[64]  ← d_alice  (临时私钥, KAT: d_bob+1)                 │ │
│  │   d1[64]  ← {0}                                               │ │
│  │   x[32]   ← Q_bob.x  (Bob 公钥, Phase 1 输出)                  │ │
│  │   y[32]   ← Q_bob.y                                           │ │
│  │                                                               │ │
│  │ OTBN 执行: p256_shared_key(d_alice, Q_bob)                     │ │
│  │                                                               │ │
│  │ Ibex: ss_e = x0 XOR x1                                        │ │
│  │ CHECK: ss_e == kExpectedSsE                                    │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                              ↓ wipe                                │
│  Step 2: ML-KEM Encap                                              │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ OTBN: mlkem768_encap                                          │ │
│  │                                                               │ │
│  │ Ibex → OTBN: coins[32], pk_m[1184] (Bob 公钥)                  │ │
│  │ OTBN → Ibex: ct_m[1088], ss_m[32]                              │ │
│  │                                                               │ │
│  │ CHECK: ct_m == kExpectedCtM, ss_m == kExpectedSsM              │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                              ↓ wipe                                │
│  Step 3: KMAC-KDF                                                  │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ OTBN: kmac_kdf_256                                            │ │
│  │                                                               │ │
│  │ Ibex → OTBN:                                                  │ │
│  │   KDK  = ss_e[32] || ss_m[32]  (64B, x20/x21)                 │ │
│  │   FixedInfo = Counter(4B, 0x00000001)                         │ │
│  │             || Label(0B)                                      │ │
│  │             || 0x00(1B)                                       │ │
│  │             || Context[32] ("HybridKEM-v1-context-...")       │ │
│  │             || L_bits(4B, 0x00000100 = 256)  (41B total)     │ │
│  │                                                               │ │
│  │ OTBN 执行:                                                     │ │
│  │   shake128_init → xof_absorb(KDK) → xof_absorb(FixedInfo)     │ │
│  │   → xof_process → xof_squeeze32 → xof_finish                  │ │
│  │                                                               │ │
│  │ OTBN → Ibex: OKM[32]                                          │ │
│  │ CHECK: OKM == kExpectedOkm                                     │ │
│  └──────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────┘
```

### Bob — 解封装

```
┌─ Phase 2 Bob: Decapsulation ──────────────────────────────────────┐
│                                                                    │
│  Step 1: ML-KEM Decap                                              │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ OTBN: mlkem768_decap                                          │ │
│  │                                                               │ │
│  │ Ibex → OTBN: ct_m[1088], sk_m[2400]                            │ │
│  │ OTBN → Ibex: ss_m[32]                                         │ │
│  │                                                               │ │
│  │ CHECK: ss_m == kExpectedSsM                                    │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                              ↓ wipe                                │
│  Step 2: P-256 ECDH (长期密钥)                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ OTBN: p256_ecdh_shared_key                                   │ │
│  │                                                               │ │
│  │ Ibex → OTBN:                                                  │ │
│  │   d0[64]  ← d_bob  (长期私钥)                                  │ │
│  │   d1[64]  ← {0}                                               │ │
│  │   x[32]   ← Q_alice.x                                         │ │
│  │   y[32]   ← Q_alice.y                                         │ │
│  │                                                               │ │
│  │ Ibex: ss_e = x0 XOR x1                                        │ │
│  │ CHECK: ss_e == kExpectedSsE (== Alice ss_e)                    │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                              ↓ wipe                                │
│  Step 3: KMAC-KDF                                                  │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ 同 Alice, KDK 和 FixedInfo 完全一致                            │ │
│  │ OKM_bob == OKM_alice (标准 KEM 正确性)                         │ │
│  └──────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────┘
```

### 密钥关系

```
Bob:   d_bob → Q_bob = d_bob * G (长期, Phase 1)
Alice: d_alice = d_bob + 1 → Q_alice (临时, KAT 确定性)
ECDH:  d_alice * Q_bob == d_bob * Q_alice → ss_e 相同

KMAC-KDF: OKM = SHAKE128(ss_e || ss_m || Counter || 0x00 || Context || L_bits, 32)
           → OKM_alice == OKM_bob
```

### 数据流

| 值 | Phase 1 | Phase 2 Alice | Phase 2 Bob |
|------|---------|--------------|------------|
| ss_e (ECDH) | Bob×G → 输出 | d_alice×Q_bob → KDK | d_bob×Q_alice → KDK |
| ss_m (ML-KEM) | — | mlkem_encap → KDK | mlkem_decap → KDK |
| OKM (KMAC-KDF) | — | 输出 (32B) | 输出 (== Alice) |
