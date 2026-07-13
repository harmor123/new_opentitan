# ML-KEM-768 KAT 测试数据

## 目录结构

```
assets/
├── README.md                           ← 本文件
│
├── ML-KEM-768                           ← 已知展开数据 (100 组 d/z/pk/sk/m/ct/ss)
├── PQCkemKAT_2400.rsp                  ← NIST RSP 格式 KAT (100 组, seed→pk/sk/ct/ss)
├── aes256_ctr_drbg.py                  ← NIST SP 800-90A AES-256-CTR DRBG 参考实现
│
├── ML-KEM-keyGen-FIPS203/              ← NIST ACVP keyGen 测试数据
│   ├── prompt.json                     ← 输入: d(32B) + z(32B)
│   └── expectedResults.json            ← 输出: ek(1184B) + dk(2400B)   [tgId=2=ML-KEM-768]
│
├── ML-KEM-encapDecap-FIPS203/          ← NIST ACVP encap/decap 测试数据
│   ├── prompt.json                     ← encap输入: ek+m, decap输入: dk+c
│   └── expectedResults.json            ← encap输出: c+k, decap输出: k  [tgId=2=encap, tgId=5=decap]
│
├── converters/                          ← 转换脚本
│   ├── mlkem768_to_asm.py              ← 已知展开数据 → 汇编 .word (d/z/m 已展开)
│   ├── kat_to_asm.py                   ← ACVP → 汇编 .word (d/z/m 已展开)
│   └── rsp_to_asm.py                   ← RSP → 汇编 .word (AES-CTR DRBG 展开 seed)
│
└── output/                              ← 生成的测试向量
    ├── mlkem768/                        ← 已知数据输出
    │   └── test_NNN/
    │       ├── keypair.s / keypair.dexp
    │       ├── encap.s   / encap.dexp
    │       └── decap.s   / decap.dexp
    │
    ├── kat/                             ← ACVP 输出
    │   └── tcId_NNN/
    │       ├── keypair.s / keypair.dexp
    │       ├── encap.s   / encap.dexp
    │       └── decap.s   / decap.dexp
    │
    └── rsp/                             ← RSP 输出
        └── count_NNN/
            ├── keypair.s / keypair.dexp
            ├── encap.s   / encap.dexp
            └── decap.s   / decap.dexp
```

## 数据和脚本来源

| 文件                 | 来源                | 说明                                 |
| -------------------- | ------------------- | ------------------------------------ |
| `ML-KEM-768`         | NIST KAT / 参考实现 | d/z/pk/sk/m/ct/ss 已展开，可直接使用 |
| `PQCkemKAT_2400.rsp` | NIST KAT 网站       | ML-KEM-768 官方测试向量              |
| `ML-KEM-*FIPS203/`   | NIST ACVP 服务器    | FIPS 203 验证数据                    |
| `aes256_ctr_drbg.py` | ML-KEM 参考实现     | NIST SP 800-90A DRBG                 |

## 三种 KAT 格式的区别

|            | ML-KEM-768 (mlkem768_to_asm.py) | ACVP (kat_to_asm.py)                                   | RSP (rsp_to_asm.py)                  |
| ---------- | ------------------------------- | ------------------------------------------------------ | ------------------------------------ |
| 输入文件   | `ML-KEM-768`                    | `ML-KEM-*FIPS203/prompt.json` + `expectedResults.json` | `PQCkemKAT_2400.rsp`                 |
| Coins 来源 | 直接给定 `d`, `z`, `m` (已展开) | 直接给定 `d`, `z`, `m` (已展开)                        | `seed` (48B) → AES-256-CTR DRBG 展开 |
| 测试组数   | 100 组完整 triple               | keyGen×25, encap×25, decap×10 (triples: 10)            | 100 组完整 triple                    |
| 匹配方式   | 每组自带 pk/sk/ct/ss，无需匹配  | tcId 对齐 (decap = keygen + 60)                        | 每组自带 pk/sk/ct/ss                 |
| 状态       | **三阶段全部通过**              | **仅 keypair + encap**（见下方说明）                   | **无法使用**（见下方说明）           |

## 已知问题

### RSP（无法使用）

`.rsp` 文件提供的是 48B `seed`，需要通过 AES-256-CTR DRBG 展开为 `d`、`z`、`m`。
当前 DRBG 实现展开出的 `d`/`z` 与 `.rsp` 期望的 `pk`/`sk` 不匹配，导致 keypair 和 encap 失败。

decap 阶段理论上可用（`ct`、`dk`、`ss` 全部直接取自 `.rsp`，不依赖 DRBG），
但由于 keypair 生成的 `dk` 无法验证，decap 无法串联测试。

### ACVP / KAT（仅 keypair + encap）

- **keypair**：`d`、`z` 直接给定，`ek`/`dk` 可从 `expectedResults.json` 获取，三阶段中唯一完整的闭环。
- **encap**：`m` 和独立 `ek` 直接给定，`ct`/`ss` 可验证。但 encap 使用的 `ek` 与 keypair 生成的 `ek` **不是同一个值**（ACVP 各阶段独立测试，不串联）。
- **decap**：**无法使用**。ACVP decap prompt 只含 `c`，不含 `dk`（`dk` 由测试方提供，不记录在 prompt.json 中）。`kat_to_asm.py` 暂时用 keypair 的 `dk` 填充，因此 `dk` 与 `ct` 不匹配，decap 必然失败。

## 用法

```bash
cd assets/converters

# ML-KEM-768: 导出全部 100 组
python3 mlkem768_to_asm.py

# ML-KEM-768: 导出前 5 组
python3 mlkem768_to_asm.py 5

# ACVP: 导出前 5 组
python3 kat_to_asm.py 5

# ACVP: 导出全部 10 组
python3 kat_to_asm.py -1

# RSP: 导出前 10 组
python3 rsp_to_asm.py 10

# RSP: 导出全部 100 组
python3 rsp_to_asm.py -1
```

## 在 OTBN 测试汇编中使用

```asm
/* 引入 KAT 期望值 */
.include "output/mlkem768/test_000/keypair.s"

/* coins, ek, dk 现在可用 */
test_keypair:
    la   x10, coins       /* coins = d || z (64B) */
    la   x11, output_pk    /* OTBN 生成的 pk */
    la   x12, output_sk    /* OTBN 生成的 sk */
    jal  x1, crypto_kem_keypair

    /* 比较 output_pk vs ek (1184B) */
    /* 比较 output_sk vs dk (2400B) */
```

## ML-KEM-768 参数速查

| 参数            | 值                  |
| --------------- | ------------------- |
| 安全级别        | 3 (NIST)            |
| k (向量维度)    | 3                   |
| η1 (CBD 参数)   | 2                   |
| η2 (CBD 参数)   | 2                   |
| du (压缩)       | 10                  |
| dv (压缩)       | 4                   |
| pk 长度         | 1184 bytes          |
| sk 长度         | 2400 bytes          |
| ct 长度         | 1088 bytes          |
| ss 长度         | 32 bytes            |
| coins (keypair) | 64 bytes (d \|\| z) |
| coins (encap)   | 32 bytes (m)        |

## 汇编标签说明

所有转换器输出统一的标签名，与 OTBN 测试汇编直接兼容：

| 标签    | 含义                               | 长度      | 对应阶段       |
| ------- | ---------------------------------- | --------- | -------------- |
| `coins` | 随机数 (keypair: d\|\|z, encap: m) | 64B / 32B | keypair, encap |
| `ek`    | 封装公钥 (pk)                      | 1184B     | keypair, encap |
| `dk`    | 解封私钥 (sk)                      | 2400B     | keypair, decap |
| `ct`    | 密文                               | 1088B     | encap, decap   |
| `ss`    | 共享密钥                           | 32B       | encap, decap   |

## .dexp 格式说明

`.dexp` 文件存储的是 **DMEM 字节序**（little-endian word order = 硬件实际存储序），
与 `.rsp` 的 big-endian 表示相反。

```
.rsp ek:  A72C2D9C...  (big-endian, MSB first)
  ↓ bytes.fromhex() → [::-1] (整体字节反转)
.dexp ek: 2239b529...  (DMEM order, LSB first)
  ↓ parse_dmem_exp(): bytes.fromhex() → [::-1] (再次反转)
比较值:   A72C2D9C...  (还原为 big-endian，与 .rsp 一致)
```

所有转换器都已自动处理此转换。