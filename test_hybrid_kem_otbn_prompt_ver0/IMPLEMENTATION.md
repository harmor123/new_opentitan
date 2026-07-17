# Hybrid KEM 实现文档

## 一、架构

```
Ibex (RV32)                    OTBN (BigNum Accelerator)
  │                               │
  │  dif_otbn_t  ──────────────►  │  p256_shared_key  (ECDH)
  │  load / write / exec / read   │  mlkem768_*       (KeyGen/Encap/Decap)
  │                               │  kmac_kdf    (KMAC-KDF: SHAKE256 absorb+squeeze)
  │                               │  hmac_sha3_256 / sha3_shake
  │                               │
  │◄────────────── CHECK_ARRAYS_EQ │
```

全部计算在 OTBN 上完成。HMAC/SHA3 使用纯软件 Keccak-f 置换，无 KMAC 硬件依赖。

## 二、密钥派生

```
IKM = be16(32) || ss_e(32B) || be16(32) || ss_m(32B) || ctx || sid

OKM = SHAKE256(KDK || FixedInfo, L)               (Alice == Bob)

OKM = SHAKE256 squeeze(PRK, info, L)    (KEM 统一输出, info="" 或 16B)
```

- **role 不放入 IKM** — KEM 层 PRK 相同
- **info 独立于 IKM** — 通过 `input_info` + `input_info_len` 传入 Expand
- **角色绑定** — 上层协议二次 KMAC-KDF 从 OKM 派生

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

3. HKDF(ss_e, ss_m) → OKM
   输入: salt[32], IKM[132B], info[16B], info_len=16
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

3. HKDF(ss_e, ss_m) → OKM
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

### KMAC-KDF (SHAKE256) (`kmac_kdf`)

| 符号 | 大小 | 说明 |
|------|------|------|
| `kdk_input` | 96B | KDK = salt||ss_e||ss_m |
| `ikm_prebuilt` | 可变 | IKM = be16(32)\|\|ss_e\|\|be16(32)\|\|ss_m\|\|ctx\|\|sid |
| `input_info` | 可变 | SHAKE256 squeeze info 字节 |
| `input_info_len` | 4B | info 长度 (独立于 input_lengths) |
| `input_lengths` | 3×4B | +0=ctx_len, +4=sid_len, +8=okm_len |
| `output_okm` | 256B | OKM 输出 |

### HMAC-SHA3-256 (deprecated) (`hmac_sha3_256`)

| 寄存器 | 含义 |
|------|------|
| x10 | key_ptr |
| x11 | key_len |
| x12 | msg_ptr |
| x13 | msg_len |
| x14 | out_ptr (32B) |

内部使用 SW SHA3 (`sha3_init`, `sha3_update`, `sha3_final`)，DMEM 缓冲区: `context`, `rc`, `key_buf`, `ipad`, `opad`, `inner_hash`。

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
| OKM Phase 2 | `0xed7ff77d31c73dc55fa297b869cb4d3435eb6c6c1c0065fc004ef52d4a24cbbd` |
