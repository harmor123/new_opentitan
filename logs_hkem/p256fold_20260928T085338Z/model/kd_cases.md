# KD case 常量（附录 A 口径：k=−4…7，(k*D) & MASKW，65 位 hex = 260 bit）

| k | 4-bit 二补码标签 | (k*D) & MASKW（0x065 hex） |
|---:|---|---|
| -4 | `c` | `0xffffffffc00000004000000000000000000000003fffffffffffffffffffffffc` |
| -3 | `d` | `0xffffffffd00000003000000000000000000000002fffffffffffffffffffffffd` |
| -2 | `e` | `0xffffffffe00000002000000000000000000000001fffffffffffffffffffffffe` |
| -1 | `f` | `0xfffffffff00000001000000000000000000000000ffffffffffffffffffffffff` |
| 0 | `0` | `0x00000000000000000000000000000000000000000000000000000000000000000` |
| 1 | `1` | `0x000000000fffffffeffffffffffffffffffffffff000000000000000000000001` |
| 2 | `2` | `0x000000001fffffffdfffffffffffffffffffffffe000000000000000000000002` |
| 3 | `3` | `0x000000002fffffffcfffffffffffffffffffffffd000000000000000000000003` |
| 4 | `4` | `0x000000003fffffffbfffffffffffffffffffffffc000000000000000000000004` |
| 5 | `5` | `0x000000004fffffffafffffffffffffffffffffffb000000000000000000000005` |
| 6 | `6` | `0x000000005fffffff9fffffffffffffffffffffffa000000000000000000000006` |
| 7 | `7` | `0x000000006fffffff8fffffffffffffffffffffff9000000000000000000000007` |
