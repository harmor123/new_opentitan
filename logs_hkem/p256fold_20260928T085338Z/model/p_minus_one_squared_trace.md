# (p-1)^2 逐拍 ACC/F trace（[MODEL]，来源：附录 A 模型）

result = 0x1 

## MAC 逐拍（16 步，16 次真乘）

| cycle | product | shift | zero | shift_out | acc_after |
|---:|---|---:|---|---|---|
| 0 | `a0b3` | 64 | True | False | `0xfffffffeffffffff00000001fffffffe0000000000000000` |
| 1 | `a1b2` | 64 | False | False | `0xfffffffeffffffff00000001fffffffe0000000000000000` |
| 2 | `a2b1` | 64 | False | False | `0xfffffffeffffffff00000001fffffffe0000000000000000` |
| 3 | `a3b0` | 64 | False | True | `0x1fffffffdfffffffe` |
| 4 | `a1b3` | 0 | False | False | `0xfffffffffffffffffffffffd` |
| 5 | `a2b2` | 0 | False | False | `0xfffffffffffffffffffffffd` |
| 6 | `a3b1` | 0 | False | False | `0x1fffffffe00000001fffffffc` |
| 7 | `a2b3` | 64 | False | False | `0x1fffffffe00000001fffffffc` |
| 8 | `a3b2` | 64 | False | False | `0x1fffffffe00000001fffffffc` |
| 9 | `a3b3` | 128 | False | False | `0xfffffffe00000002fffffffe0000000100000001fffffffe00000001fffffffc` |
| 10 | `a0b0` | 0 | True | False | `0xfffffffffffffffc0000000000000004` |
| 11 | `a0b1` | 64 | False | False | `0xfffffffffffffffdfffffffe0000000000000004` |
| 12 | `a1b0` | 64 | False | True | `0x1fffffffe` |
| 13 | `a0b2` | 0 | False | False | `0x1fffffffe` |
| 14 | `a1b1` | 0 | False | False | `0xffffffffffffffff` |
| 15 | `a2b0` | 0 | False | False | `0xffffffffffffffff` |

## Fold 逐拍（seed H + 8 行更新 + merge + quotient + correction + WB）

| cycle | op | F / q |
|---:|---|---|
| 3 | seed H | `0x3fffffffc000000000000000000000000000000000000000000000000` |
| 10 | +2A | `0x20000000000000001fffffffc0000000200000002000000000000000000000000` |
| 11 | +2B | `0x200000001fffffffe00000001fffffffe00000004000000000000000000000000` |
| 12 | +P | `0x2fffffffefffffffd000000000000000100000002fffffffe00000001fffffffc` |
| 13 | +Q | `0x3fffffffcffffffff000000000000000100000002fffffffffffffffffffffffd` |
| 14 | -M0 | `0x2fffffffe0000000200000001ffffffff0000000600000001fffffffefffffffc` |
| 15 | -M1 | `0x2fffffffd00000001000000000000000100000004ffffffff00000000fffffffb` |
| 16 | -M2 | `0x2fffffffc0000000100000000000000000000000600000000fffffffdfffffffd` |
| 17 | -M3 | `0x1fffffffe00000001000000000000000000000005fffffffffffffffffffffffb` |
| 18 | +L0 | `0x1fffffffe00000002000000000000000000000001ffffffffffffffffffffffff` |
| 19 | fold q | `0xffffffff00000001000000000000000000000001000000000000000000000000` |
| 20 | conditional +/-p | `0x1` |
| 21 | WDR commit | `0x1` |
