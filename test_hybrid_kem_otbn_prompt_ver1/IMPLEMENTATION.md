# Hybrid KEM 实现文档 — ver1 (KMAC-KDF)

## 一、架构

```
Ibex (RV32)                    OTBN (BigNum Accelerator)
  │                               │
  │  dif_otbn_t  ──────────────►  │  p256_shared_key  (ECDH)
  │  load / write / exec / read   │  mlkem768_*       (KeyGen/Encap/Decap)
  │                               │  kmac_kdf_256     (KMAC-KDF, SHAKE256, NIST SP 800-108r1)
  │                               │  kmac_xof.s       (KMAC ISPR 驱动)
  │                               │
  │◄────────────── CHECK_ARRAYS_EQ │
```

全部计算在 OTBN 上完成。哈希 (SHA3/SHAKE) 和密钥派生 (KMAC-KDF) 通过 OTBN ISPR 接口 (`KMAC_CFG`, `KMAC_CTRL`, `KMAC_DATA_S0/S1` 等) 使用 KMAC 硬件加速。OTBN ISPR 经 `otbn_kmac_if.sv` FSM 转换为 KMAC App 接口请求。

## 二、密钥派生 (KMAC-KDF)

```
KMAC-KDF (NIST SP 800-108r1):

  KDK = ss_e(32B) || ss_m(32B)        (64B, 从 ECDH + ML-KEM)

  FixedInfo = Counter(4B, be32 0x00000001)
            || Label(0B, KEM 层无标签)
            || 0x00(1B, 分隔符)
            || Context(32B, "HybridKEM-v1-context-0123456789A")
            || L_bits(4B, be32 0x00000100 = 256)
            = 41B total

  OKM = SHAKE128(KDK || FixedInfo, 32)
```

**与 ver0 (HKDF-SHA3-256) 的区别**：

| | ver0 (旧) | ver1 (新) |
|------|------|------|
| KDF 标准 | RFC 5869 (HKDF) | NIST SP 800-108r1 (KMAC-KDF) |
| 底层 | HMAC-SHA3-256 (软件 Keccak) | SHAKE128 (KMAC 硬件) |
| Extract | PRK = HMAC(salt, IKM) | 不需要 |
| Expand | T(i) = HMAC(PRK, T(i-1)\|\|info\|\|i) | 不需要 |
| 调用次数 | 1 + ceil(L/32) 次 HMAC (每次 2×SHA3) | **1 次 SHAKE128** |
| role 处理 | 不在 IKM 中, 上层处理 | 同, 不在 FixedInfo 中 |

## 三、Phase 1: 密钥生成

```
1. P-256 ECDH: p256_shared_key(d, G) → ss_e (32B)
   OTBN: p256_ecdh_shared_key
   dm[0..63] = d0, dm[64..127] = d1
   dm[128..159] = G.x, dm[160..191] = G.y
   → x0[32], x1[32] → ss_e = x0 ^ x1

2. ML-KEM KeyGen: mlkem768_keypair(coins) → pk_m, sk_m
   OTBN: mlkem768_keypair
   dm[coins] = coins[64]
   → pk_m[1184], sk_m[2400]
   (内部 SHAKE128 通过 mlkem768/kmac_xof.s → KMAC 硬件加速)

输出: PK_Hyb = pk_m || ss_e, SK_Hyb = sk_m || d0
```

## 四、Phase 2: 密钥协商

### Alice (Encapsulation)

```
1. P-256 ECDH: p256_shared_key(d_alice, Q_bob) → ss_e
   输入: d_alice[64], Q_bob[64]
   输出: ss_e = x0 ^ x1 (32B)

2. ML-KEM Encap: mlkem768_encap(coins, pk_m) → ct_m, ss_m
   输入: coins[32], pk_m[1184]
   输出: ct_m[1088], ss_m[32]

3. KMAC-KDF: kmac_kdf_256(KDK, FixedInfo, 32) → OKM
   输入: x20=kdk_ptr(64B), x21=64, x22=fixed_ptr(41B), x23=41, x24=32, x3=okm_ptr
   输出: OKM[32]
```

### Bob (Decapsulation)

```
1. ML-KEM Decap: mlkem768_decap(ct_m, sk_m) → ss_m
   输入: ct_m[1088], sk_m[2400]
   输出: ss_m[32]

2. P-256 ECDH: p256_shared_key(d_bob, Q_alice) → ss_e
   输入: d_bob[64], Q_alice[64]
   输出: ss_e = x0 ^ x1 (32B)

3. KMAC-KDF: kmac_kdf_256(KDK, FixedInfo, 32) → OKM
   同 Alice, OKM_alice == OKM_bob
```

### 密钥关系

```
Bob:   d_bob → Q_bob = d_bob * G (长期, Phase 1)
Alice: d_alice = d_bob + 1 → Q_alice (临时, KAT 确定性; 生产用真随机)
ECDH:  d_alice * Q_bob == d_bob * Q_alice → ss_e 相同
```

## 五、OTBN 汇编接口

### P-256 ECDH (`p256_ecdh_shared_key`)

| 符号 | 大小 | 方向 |
|------|------|------|
| `d0` | 64B | Ibex → OTBN |
| `d1` | 64B | Ibex → OTBN |
| `x` | 32B | 双向 (输入点 / 输出 x0) |
| `y` | 32B | 双向 (输入点 / 输出 x1) |

### ML-KEM-768

| 二进制 | 输入 | 输出 |
|------|------|------|
| `mlkem768_keypair` | `coins[64]` | `ek[1184]`, `dk[2400]` |
| `mlkem768_encap` | `coins[32]`, `ek[1184]` | `ct[1088]`, `ss[32]` |
| `mlkem768_decap` | `ct[1088]`, `dk[2400]` | `ss[32]` |

### KMAC-KDF (`kmac_kdf_256`)

| 寄存器 | 含义 |
|------|------|
| x20 | kdk_ptr (DMEM 地址, 32B 对齐) |
| x21 | kdk_len (字节, 典型 64) |
| x22 | fixed_ptr (DMEM 地址, 32B 对齐) |
| x23 | fixed_len (字节, 典型 41) |
| x24 | okm_len (字节, 典型 32) |
| x3 | okm_ptr (DMEM 地址, 32B 对齐) |

内部流程: `shake128_init → xof_absorb(KDK) → xof_absorb(FixedInfo) → xof_process → xof_squeeze32×N → xof_finish`

### KMAC 驱动 (`kmac_xof.s` — ISPR 接口)

| 函数 | 说明 |
|------|------|
| `sha3_256_init` | 配置 SHA3-256 (KMAC_CFG = 0x3b0004) |
| `sha3_512_init` | 配置 SHA3-512 (KMAC_CFG = 0x370008) |
| `shake128_init` | 配置 SHAKE128 (KMAC_CFG = 0x2e0011) |
| `shake256_init` | 配置 SHAKE256 (KMAC_CFG = 0x2a0015) |
| `xof_absorb` | 吸收 n 字节 (x20=n, x21=ptr, x22=0 非掩码) |
| `xof_process` | 发送 PROCESS, 等待首个响应 |
| `xof_squeeze32` | 挤压 32B → w29 (含速率缓冲追踪) |
| `xof_squeeze_unsafe` | 挤压 32B → w29 (无速率追踪, SHA3 用) |
| `xof_finish` | DONE → 检查错误 → CLOSE → 释放 |

保留寄存器 (x28-x30): 速率缓冲剩余 chunks / 总 chunks / 轮询超时计数。

## 六、KAT 测试向量

### Phase 1

| 参数 | 值 |
|------|------|
| d_bob | `0x1420fc41742102631b76ebe83fdfa3799590ef5db0b2c78121d0a016fe6d1071` |
| Q_bob.x | `0x815215ad7dd27f336b35843cbe064de299504edd0c7d87dd1147ea5680a9674a` |
| ss_e (=Q.x) | `0x4a67a98056ea4711dd877d0cdd4e5099e24d06be3c84356b337fd27dad155281` (LE) |

### Phase 2

| 参数 | 值 |
|------|------|
| d_alice | `0x1420fc41742102631b76ebe83fdfa3799590ef5db0b2c78121d0a016fe6d1072` (= d_bob+1) |
| Q_alice.x | `0xae2e89b1692754b3c42c030e0961db5c7ee520266c5a6233d87f20bbfae16aaf` |
| ss_e (ECDH) | `0x26991c9ad0f96b5e92f34e88d1534ca53ae7d4372850497b66fb3cc0e6f14c06` |
| ss_m (ML-KEM encap) | `0xac865f839fef1bf3d528dd7504bed2f64b5502b0fa81d1c32763658e4aac5037` |
| OKM Phase 2 (KMAC-KDF SHAKE256) | `0x3bce19219b4a680c763ca4aa0fbed9f1e5e21184f955a640b5fbf9c7c95bb817` |
