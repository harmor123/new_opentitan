#!/usr/bin/env python3
"""P2 Step 8：把 testbench 日志的逐拍 F 与模型向量逐拍比对，出 `p2_diff.md`（判据：`0 mismatches`）。

比对口径（与 `p2_contract.md` §4 一致）：
  * 模型 fold trace 的 `cycle c` 记的是**该拍运算后**的值；
  * §8 约定「结果在该行周期末锁存，下一周期可用」⇒ tb 在 c 拍 posedge 后读到的寄存器值
    就是同一拍的结果 ⇒ **同号同拍**比对（不做平移）；
  * 本脚本独立地从 JSON 取模型值，并同时核对 tb 日志里自己打印的 `model=` 列与 `OK/DIFF` 标记。

用法：python3 compare_to_model.py --tb-log p2_inject.log --model p2_vectors.json --out p2_diff.md
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

LINE = re.compile(r"^CYC (\S+) (\d+) \| tb=(0x[0-9a-f]+) \| model=(0x[0-9a-f]+) \| (OK|DIFF)$")
SUM = re.compile(r"^(PASS - 0 errors / \d+ checks|Test \*\*\*(PASSED|FAILED)\*\*\*.*)$")

# 值域口径：F 是 260-bit signed。TB 打印的是**二补码位型**（0x…，无负号），
# JSON 里的 F 可能是负数字符串（"-0x…"）⇒ 两边都掩到 260 位再比（掩码后是有符号值的双射）。
MASKW = (1 << 260) - 1


def canon(v):
    return v & MASKW


def file_sha256_lf(path):
    """跨平台哈希口径：先 CRLF→LF 归一化再哈希（等于 git blob 的哈希）。"""
    return hashlib.sha256(Path(path).read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--tb-log", type=Path, required=True)
    ap.add_argument("--model", type=Path, required=True, help="p2_vectors.json")
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    doc = json.loads(args.model.read_text(encoding="utf-8"))
    model = {v["name"]: v for v in doc["vectors"]}
    log_lines = args.tb_log.read_text(encoding="utf-8", errors="replace").splitlines()

    rows = []
    tb_model_col_mismatch = 0
    tb_flag_mismatch = 0
    seen = {}
    for ln in log_lines:
        m = LINE.match(ln.strip())
        if not m:
            continue
        name, cyc, tb_hex, model_hex, flag = m.group(1), int(m.group(2)), m.group(3), m.group(4), m.group(5)
        want = canon(int(model[name]["fold_F"][str(cyc)], 16)) \
            if name in model and str(cyc) in model[name]["fold_F"] else None
        got = canon(int(tb_hex, 16))
        if canon(int(model_hex, 16)) != want:               # 日志里模型列与 JSON 不一致
            tb_model_col_mismatch += 1
        if (flag == "DIFF") != (want is None or got != want):  # 日志自身标记与独立判定不一致
            tb_flag_mismatch += 1
        rows.append((name, cyc, got, want, flag))
        seen.setdefault(name, set()).add(cyc)

    # 覆盖性：每条向量的每个模型周期都必须在日志里出现
    missing = []
    for name, v in model.items():
        for c in sorted(int(x) for x in v["fold_F"]):
            if c not in seen.get(name, set()):
                missing.append("%s@c%d" % (name, c))

    n_mismatch = sum(1 for (_n, _c, got, want, _f) in rows if want is None or got != want)
    tb_summary = [ln.strip() for ln in log_lines if SUM.match(ln.strip())]

    out = ["# P2 逐拍 scoreboard（testbench 日志 ↔ 模型向量）", ""]
    out.append("- tb 日志：`%s`（sha256(LF) `%s`）" % (args.tb_log, file_sha256_lf(args.tb_log)))
    out.append("- 模型向量：`%s`（sha256(LF) `%s`）" % (args.model, file_sha256_lf(args.model)))
    out.append("- 模型脚本 `p256_fold_model.py` 的 sha256(LF)：`%s`" % doc["model_sha256_lf"])
    out.append("- 向量 %d 条；逐拍行 %d 行（模型 fold trace 每条 13 拍：c3 + c10…c21）"
               % (len(model), len(rows)))
    out.append("- 比对口径：模型 `cycle c` ⇒ tb 同拍（结果周期末锁存），**不平移**")
    out.append("")
    out.append("| vector | cycle | tb.F | model.F | equal |")
    out.append("|---|---|---|---|---|")
    for (name, cyc, got, want, fl) in rows:
        out.append("| %s | %d | 0x%x | %s | %s |"
                   % (name, cyc, got, ("0x%x" % want) if want is not None else "（JSON 无此拍）",
                      "yes" if (want is not None and got == want and fl == "OK") else "NO"))
    out.append("")
    out.append("## 判据行")
    out.append("")
    out.append("- `mismatches: %d`" % n_mismatch)
    out.append("- 日志中 `model=` 列与 JSON 不符的行：%d" % tb_model_col_mismatch)
    out.append("- 日志自身 `OK/DIFF` 标记与独立判定不符的行：%d" % tb_flag_mismatch)
    out.append("- 模型周期未在日志中出现：%d%s"
               % (len(missing), ("（例：%s）" % ", ".join(missing[:5])) if missing else ""))
    out.append("")
    if tb_summary:
        out.append("## tb 日志的汇总行（逐字）")
        out.append("")
        out.append("```")
        out.extend(tb_summary)
        out.append("```")
    args.out.write_text("\n".join(out) + "\n", encoding="utf-8")

    bad = n_mismatch + tb_model_col_mismatch + tb_flag_mismatch + len(missing)
    print("wrote %s" % args.out)
    print("逐拍行 %d；mismatches: %d；日志 model 列不符 %d；标记不符 %d；缺失 %d"
          % (len(rows), n_mismatch, tb_model_col_mismatch, tb_flag_mismatch, len(missing)))
    raise SystemExit(1 if bad else 0)


if __name__ == "__main__":
    main()
