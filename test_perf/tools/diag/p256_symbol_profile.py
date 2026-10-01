#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P-256 自包含测试的**逐符号 ISS 剖面**，旧 vs 新对比（**复用 `test_perf/harness.py` 的既有函数** ✓）。

为什么用它：P-256 历来不进 ML-KEM 的分层表（`test_perf/harness_config.yaml` 里写明「本表只覆盖
ML-KEM」✗）⇒ 那段 −84% 的指令数**具体省在哪**一直只有设备侧的总数（84,679 / 91,893 ✓）。
本工具把 `harness.py` 的 `run_elf` + `exec_per_func`（ISS 逐 PC 覆盖 → 逐符号 ✓，含 halt 自核 ✓）
套到两版**同源**的自包含测试上 ⇒ 直接给出逐符号的指令数与**差值归属** ✓。

同源自包含目标（`srcs` 都是 `p256_ecdh_shared_key_test.s`）：
  //test_hybrid_kem_otbn_prompt_ver1_1/otbn/p256:p256_ecdh_local_test   （旧：官方 mul_modp）
  //test_hybrid_kem_otbn_prompt_ver1_2/otbn/p256:p256_ecdh_local_test   （新：一条 bn.p256mul）
  （单函数测试另有一对 `…:p256_mul_modp_local_test` ✓）

自检（不成立即非零退出 ✗）：两侧的**逐符号执行数之和 == ISS 的 insn**；两 ELF 的 sha256 记进输出 ✓。

用法：
  python3 test_perf/tools/diag/p256_symbol_profile.py \
      --a //test_hybrid_kem_otbn_prompt_ver1_1/otbn/p256:p256_ecdh_local_test --label-a ver1_1 \
      --b //test_hybrid_kem_otbn_prompt_ver1_2/otbn/p256:p256_ecdh_local_test --label-b ver1_2 \
      --out logs_hkem/p256fold_20260928T085338Z/reports/p7_p256_symbols.md
"""
import argparse
import hashlib
import json
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "test_perf"))
import harness  # noqa: E402  （既有工具：run_elf / exec_per_func / bazel_elf / elf_size）


def profile(target: str, label: str):
    elf = harness.bazel_elf(target)
    sha = hashlib.sha256(pathlib.Path(elf).read_bytes()).hexdigest()
    txt, data, bss = harness.elf_size(elf)
    cycles, insn, stalls, histo, calls, bnds, cov = harness.run_elf(elf)     # 内含 halt 自核 ✓
    per = harness.exec_per_func(cov, bnds)
    assert sum(per.values()) == insn, ("逐符号之和 != insn", label, sum(per.values()), insn)
    try:
        called = harness._calls_by_name(calls, bnds)
    except Exception:
        called = {}
    return {"label": label, "target": target, "elf": str(elf), "elf_sha256": sha,
            "text_bytes": txt, "data_bytes": data, "bss_bytes": bss,
            "iss_cycles": cycles, "insn": insn, "stalls": stalls,
            "per_symbol": per, "calls": {k: v for k, v in called.items() if v}}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--a", required=True, help="旧（基线）目标")
    ap.add_argument("--b", required=True, help="新目标")
    ap.add_argument("--label-a", default="A")
    ap.add_argument("--label-b", default="B")
    ap.add_argument("--top", type=int, default=15)
    ap.add_argument("--out", help="结果 markdown 的落点")
    args = ap.parse_args()

    A, B = profile(args.a, args.label_a), profile(args.b, args.label_b)
    syms = sorted(set(A["per_symbol"]) | set(B["per_symbol"]))
    rows = [(s, A["per_symbol"].get(s, 0), B["per_symbol"].get(s, 0)) for s in syms]
    rows.sort(key=lambda r: -(abs(r[1] - r[2])))
    d_insn = A["insn"] - B["insn"]
    d_cyc = A["iss_cycles"] - B["iss_cycles"]
    assert d_insn > 0, ("新的指令数没有变少 ⇒ 先查目标对不对", A["insn"], B["insn"])

    L = ["# P-256 逐符号 ISS 剖面（工具：`test_perf/tools/diag/p256_symbol_profile.py`，复用 `harness.py` ✓）", "",
         "| 项 | %s（旧） | %s（新） | Δ |" % (args.label_a, args.label_b),
         "|---|---:|---:|---:|",
         "| ISS cycles | %d | %d | **−%d（−%.1f%%）** |" % (A["iss_cycles"], B["iss_cycles"], d_cyc,
                                                              100.0 * d_cyc / A["iss_cycles"]),
         "| retired 指令 | %d | %d | **−%d（−%.1f%%）** |" % (A["insn"], B["insn"], d_insn,
                                                             100.0 * d_insn / A["insn"]),
         "| stalls | %d | %d | −%d |" % (A["stalls"], B["stalls"], A["stalls"] - B["stalls"]),
         "| ELF text / data / bss（B） | %d / %d / %d | %d / %d / %d |  |"
         % (A["text_bytes"], A["data_bytes"], A["bss_bytes"], B["text_bytes"], B["data_bytes"], B["bss_bytes"]),
         "| ELF sha256 | `%s…` | `%s…` |  |" % (A["elf_sha256"][:16], B["elf_sha256"][:16]),
         "", "## 逐符号（按 |Δ| 排序，前 %d）" % args.top, "",
         "| 符号 | %s | %s | Δ |" % (args.label_a, args.label_b), "|---|---:|---:|---:|"]
    for s, a, b in rows[:args.top]:
        L.append("| `%s` | %s | %s | %s |" % (s, format(a, ","), format(b, ","),
                                              ("%+d" % (b - a)) if (b - a) else "0"))
    other = sum(abs(a - b) for s, a, b in rows[args.top:])
    L += ["", "（其余 %d 个符号的 |Δ| 合计 %s）" % (len(rows) - args.top, format(other, ",")), "",
          "**自检**：两侧逐符号之和 == ISS insn ✓（`%s` / `%s`）；halt 由 `run_elf` 内部核对 ✓。" % (
              format(A["insn"], ","), format(B["insn"], ",")), ""]
    md = "\n".join(L)
    print(md)
    if args.out:
        p = pathlib.Path(args.out)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(md + "\n", encoding="utf-8")
        print("[写] %s" % p)
        p.with_suffix(".json").write_text(
            json.dumps({"a": A, "b": B, "delta_insn": d_insn, "delta_cycles": d_cyc},
                       ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print("[写] %s" % p.with_suffix(".json"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
