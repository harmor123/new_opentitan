# P-256 逐帧直方图（来源：frames_p256.csv）

- 总帧数：42318
- 每会话帧数：ECDH A 10585、ECDH B 10585、Keygen A 10574、Keygen B 10574

## 全部帧的 span 直方图（min=9，max=603156）

| span | 帧数 |
|---:|---:|
| 54 | 38390 |
| 124 | 1288 |
| 597 | 1288 |
| 851 | 1284 |
| 14 | 10 |
| 12 | 8 |
| 29 | 8 |
| 9 | 4 |
| 65 | 4 |
| 77 | 4 |
| 210 | 4 |
| 3621 | 4 |
| 15625 | 4 |
| 579543 | 4 |
| 245 | 2 |
| 512 | 2 |
| 7270 | 2 |
| 595507 | 2 |
| 603156 | 2 |
| 403 | 1 |

## `mul_modp` 的 span 直方图（38390 帧）

| span | 帧数 |
|---:|---:|
| 54 | 38390 |

## `mul_modp` 的 (retired, exec_stall, fetch_gap) 形状

- (53, 0, 1) × 38390

## 每符号帧数（Top 20）

| 符号 | 帧数 |
|---|---:|
| mul_modp | 38390 |
| fetch_proj_randomize | 1288 |
| proj_double | 1288 |
| proj_add | 1284 |
| setup_modp | 10 |
| copy_share | 8 |
| p256_scalar_reblind | 8 |
| arithmetic_to_boolean | 4 |
| mod_mul_320x128 | 4 |
| p256_isoncurve | 4 |
| p256_masked_scalar_reblind | 4 |
| proj_to_affine | 4 |
| scalar_mult_int | 4 |
| trigger_fault_if_fg0_z | 4 |
| arithmetic_to_boolean_mod | 2 |
| p256_base_mult | 2 |
| p256_check_public_key | 2 |
| p256_generate_random_key | 2 |
| p256_isoncurve_proj | 2 |
| p256_random_scalar | 2 |
