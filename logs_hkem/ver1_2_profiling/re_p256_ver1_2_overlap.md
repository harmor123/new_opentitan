| 版本 | op | 指令 | 停滞 | cycles(=insn+stalls) | ISS run 周期 | text(B) | data(B) | bss(B) | 收尾（err_bits/ecall） |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| p256_ver1_2_overlap | ecdh | 91,795 | 223,417 | 315,212 | 315,412 | 3,688 | 480 | 452 | 0x0 / 1 |
| p256_ver1_2_overlap | mul_modp | 22 | 40 | 62 | 262 | 3,032 | 288 | 452 | 0x0 / 1 |
