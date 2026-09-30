# P-256 fused multiply test (`BN.P256MUL`)

Standalone test for the fused P-256 multiply added with the fold unit (P3).

It runs `BN.P256MUL` on **large operands taken from the official P-256 test vector set**
(`sw/otbn/crypto/tests/p256_ecdh_shared_key_test.s`: the example ECDH scalar `d0` and the example
curve point coordinates `x` and `y`) plus a `(p-1)^2` case, and checks two things at once:

* the results are correct — expected values are cross-checked three ways off-line (the bit-exact
  hardware model `logs_hkem/.../model/p256_fold_model.py`, the Python ISS and a big-integer
  reference), and are written into the program as comments;
* the **RTL agrees with the Python ISS instruction by instruction** — the runner uses
  `otbn_top_sim`, which co-simulates both and aborts on the first mismatch. This is the point of
  this test: it is the end-to-end co-simulation gate for the new instruction and its 28-cycle
  schedule, and it takes about a second.

## Run

```bash
bash hw/ip/otbn/dv/smoke/p256/run_p256_fold.sh
```

Pass: prints `P256 FOLD TEST PASS for program p256_fold_test` and exits 0.

## Regenerating the expected output

`p256_fold_test.expected.txt` is the tracer's final dump: from `Call Stack:` up to (but not
including) the `Simulation statistics` banner. **Only regenerate it from a run that passed the
RTL/ISS co-simulation** (if the two disagree, the simulation aborts and there is no dump to copy):

```bash
cd "$repo_root"
ELF=build-bin/otbn/p256_fold_test/p256_fold_test.elf
SIM=build/lowrisc_ip_otbn_top_sim_0.1/sim-verilator/Votbn_top_sim
$SIM --load-elf="$ELF" -t > /tmp/p256.log 2>&1; echo "exit=$?"
grep -E "Mismatch|ERROR" /tmp/p256.log        # 必须为空
sed -n '/^Call Stack:/,/^Simulation statistics/p' /tmp/p256.log | sed '$d' \
  > /tmp/p256.expected.txt
diff -u hw/ip/otbn/dv/smoke/p256/p256_fold_test.expected.txt /tmp/p256.expected.txt   # 逐行核对
```

Review criteria for that diff: only expected registers may change — `w19` = `d0*x mod p`,
`w20` = `x*y mod p`, `w21` = 1 — plus the call-stack addresses if the program layout changed.
**Every other register must be byte-identical**; anything else means the instruction broke
something and must be investigated before the new golden is committed.

## Contents

| file | purpose |
|---|---|
| `p256_fold_test.s` | the test program (official-vector operands + a `p-1` case) |
| `p256_fold_test.expected.txt` | golden tracer dump (`Call Stack:` section) |
| `run_p256_fold.sh` | assemble + link + build the sim if needed + run + compare |
| `p256_mixed_test.s` | **mixed-instruction** test (P6 Step 4)：新旧指令交替 + 别名组合 |
| `p256_mixed_test.expected.txt` | golden tracer dump（首次运行生成，复核后提交） |
| `run_p256_mixed.sh` | 同上，外加**显式检查 err(w29)==0**（本程序自身的 ref-vs-mixed 比较） |

## Mixed-instruction test（`p256_mixed_test.s` / `run_p256_mixed.sh`）

对应 `07_P6_兼容性与协议端到端.md` 的 **Step 4**（PDF §11 P6：「新旧指令**交替**使用时
临时寄存器不会串值」）。四组交替模式各做一次**受控对照**：同一段旧序列跑两遍 ——
**参考**（无新指令）与**混合**（插入 `bn.p256mul`）—— 结果 XOR 后 OR 进 `w29`：

| 组 | 模式 | 旧指令 |
|---|---|---|
| B1 | 旧 MAC → 新指令 | `bn.mulqacc.z` / `bn.mulqacc` / `bn.mulqacc.so` |
| B2 | 新指令 → 旧 MAC | 同上，新指令在最前 |
| B3 | 向量 → 新指令 | `bn.mulvm.8S` / `bn.addvm.8S` |
| B4 | 新指令 → 向量 | `bn.mulvm.8S` / `bn.mulvml.8S` |

另外检查：**别名组合**（`wa=wb`、`wd=wa`、`wd=wb`、三者相同）、边角 `(p-1)^2 = 1`、
以及**连续两条 `bn.p256mul` 用不同输入、同一目的寄存器**。

⚠ 写"混合"序列的语义约束：新指令**会**留下 ACC 末值（与旧实现清 0 不同，见 P5 的
clobber 审计），所以插入点**之后**的旧代码必须自己显式清零 ACC（用 `.z` 形式）——
否则那是语义差异、不是串值。

**两层判据**：① `otbn_top_sim` 的 RTL↔ISS 逐条对拍（任何分歧直接中断仿真）；
② 程序自身的 ref-vs-mixed 比较（`w29 == 0`，runner 显式断言）。

```bash
bash hw/ip/otbn/dv/smoke/p256/run_p256_mixed.sh            # serial（默认）
bash hw/ip/otbn/dv/smoke/p256/run_p256_mixed.sh overlap    # overlap 档
```

首次运行会生成 golden 并提示复核；第二次起做逐行比对（两种调度共用同一份 golden，
因为最终寄存器 dump 与调度无关）。
