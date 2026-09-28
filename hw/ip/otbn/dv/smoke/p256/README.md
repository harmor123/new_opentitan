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
