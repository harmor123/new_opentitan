# Hybrid KEM 详细流程图

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
│  Step 3: KMAC-KDF (SHAKE256)                                              │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ OTBN: kmac_kdf                                           │ │
│  │                                                               │ │
│  │ IKM = be16(32)||ss_e||be16(32)||ss_m||ctx[32]||sid[32]        │ │
│  │      = 132B                                                   │ │
│  │                                                               │ │
│  │ Extract:  OKM = SHAKE256(KDK || FixedInfo, L)  (KMAC-KDF)                       │ │
│  │ Expand:   OKM = SHAKE256 squeeze(PRK, info, L=32)                   │ │
│  │                                                               │ │
│  │ CHECK: OKM == kExpectedOkm                                      │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
│  发送给 Bob: ct_m[1088]                                            │
│  输出: OKM[32]                                                     │
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
│  │ CHECK: ss_m == kExpectedSsM  (== Alice ss_m)                   │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                              ↓ wipe                                │
│  Step 2: P-256 ECDH (长期密钥)                                     │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ OTBN: p256_ecdh_shared_key                                   │ │
│  │                                                               │ │
│  │ Ibex → OTBN:                                                  │ │
│  │   d0[64] ← d_bob   (长期私钥, Phase 1)                         │ │
│  │   x[32] ← Q_alice.x (Alice 临时公钥)                           │ │
│  │   y[32] ← Q_alice.y                                           │ │
│  │                                                               │ │
│  │ Ibex: ss_e = x0 XOR x1                                        │ │
│  │ CHECK: ss_e == kExpectedSsE  (== Alice ss_e)                   │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                              ↓ wipe                                │
│  Step 3: KMAC-KDF (SHAKE256)                                              │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ 同 Alice, IKM/prk/info 一致                                    │ │
│  │ CHECK: OKM == kExpectedOkm  (== Alice OKM)                     │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
│  KEM 正确性:                                                       │
│    ss_e_alice == ss_e_bob                                          │
│    ss_m_alice == ss_m_bob                                          │
│    OKM_alice  == OKM_bob                                           │
└────────────────────────────────────────────────────────────────────┘
```

### 密钥关系

```
Bob 长期:  d_bob = 0x1420fc41...6d1071
           Q_bob = d_bob * G  = (0x815215ad..., 0xa6d026ab...)

Alice 临时: d_alice = d_bob + 1 = 0x1420fc41...6d1072  (KAT 确定性; 生产用 URND)
           Q_alice = d_alice * G = (0xae2e89b1..., 0x0e5279a1...)

ECDH 验证: d_alice * Q_bob = d_bob * Q_alice = (0x26991c9a..., ...)
           ss_e = x坐标 = 0x26991c9ad0f96b5e92f34e88d1534ca53ae7d4372850497b66fb3cc0e6f14c06
```

### 数据流

```
Phase 1                Phase 2 Alice              Phase 2 Bob
───────                ──────────────              ────────────
d_bob ──→ Q_bob ──→    d_alice ──→ ss_e           ct_m ──→ ss_m
G ──→ ss_e             Q_bob ──┘                  sk_m ──┘
coins ──→ pk_m,sk_m    coins ──→ ct_m             Q_alice ──→ ss_e
                        pk_m ──→ ss_m             d_bob ──┘
                        ss_e,ss_m ──→ OKM         ss_e,ss_m ──→ OKM
                                                  CHECK: OKM == OKM_alice
```
