#!/usr/bin/env python3
"""生成"三版全实测对照"（ver0_1 / ver0_2 / ver1_1）—— 数字全部来自 JSON，不手抄。

为什么需要它：归档里的 `实验数据/三版对照_全实测.md` 是手写的，早于 ρ 统一 / rc 表尾修复 /
control 修复 / ver1_1 幽灵行删除 / 桩法流修复等若干轮 ⇒ 表里甚至还有 ver1_1 **已删除**的
`keygen_poly_reduce`、`keygen_poly_add` 行，数值也是旧的。改为从三份 JSON 生成后可随时重跑。

口径（与逐版本分解表一致）：
  · 阶段值 = harness 法 Δ = profiling − control（ISS 口径 cycles = insn + stalls）
  · 只列**有实测值**的行；某版本没有该行 ⇒ 显示 `—`
  · `closure: false` 的桩法三行照列（明示不进 Σ）
  · 加速比列 = ver1_1 / ver0_1（两版都有该行时才给）
  · §5「修正记录」从 `test_perf/doc_fragments/three_way_extra.md` 原样读入（手写散文）

用法: python3 test_perf/tools/gen/gen_three_way_doc.py [--out <路径>] [--doc-version "2026-09-20 v4（三版全实测）"]
"""
import argparse
import json
import sys
from pathlib import Path

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = Path(__file__).resolve().parents[3]   # 工具在 test_perf/tools/<类>/ 下 ⇒ 仓库根 = parents[3]
VERS = ("ver0_1", "ver0_2", "ver1_1")
OPS = (("keygen", "keygen"), ("encap", "encap"), ("decap", "decap"))
NON_SIGMA = ("keygen_poly_gen_matrix_shake", "keygen_poly_gen_matrix_rejection",
             "keygen_poly_gen_matrix_stub_overhead")


def load(v):
    p = REPO / "logs_hkem" / f"{v}_profiling" / f"re_{v}.json"
    return json.loads(p.read_text(encoding="utf-8"))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(REPO.parent / "md文档/新方案/实验数据/三版对照_全实测.md"))
    ap.add_argument("--doc-version", default="2026-09-20 v4（三版全实测）")
    ap.add_argument("--extra", default=str(Path(__file__).resolve().parents[2] / "doc_fragments/three_way_extra.md"))
    args = ap.parse_args()

    D = {v: load(v) for v in VERS}
    R = {v: {r["phase"]: r for r in D[v]["rows"]} for v in VERS}
    A = {v: D[v]["apps"][v] for v in VERS}
    L = []

    def num(x, dash="—"):
        return f"{x:,}" if isinstance(x, (int, float)) else dash

    L.append("# 三版全实测对照（ver0_1 / ver0_2 / ver1_1）")
    L.append("")
    L.append(f"> 数据版本：**{args.doc_version}**；本文件由 `test_perf/tools/gen/gen_three_way_doc.py` "
             "从三份 `re_*.json` 生成（数字不手抄，可随时重跑）。")
    L.append("> 口径：阶段值 = harness 法 Δ = profiling − control（ISS cycles = insn + stalls）；"
             "`reuse = 0`，即全部为直接测量。")
    L.append(f"> ⚠ `{'`、`'.join(NON_SIGMA)}` 三行是 `closure: false` 的桩法子分解，**不进 Σ**。")
    L.append("")
    L.append("")

    # §0 体检
    L.append("## 0. 体检（运行健康检查 + 闭环）")
    L.append("")
    L.append("| 版本 | 行数 | ERR_BITS≠0 | 未跑到 ecall | Σ 阶段 vs 整 app |")
    L.append("|---|---:|---:|---:|---|")
    for v in VERS:
        bad = sum(1 for r in D[v]["rows"] if r.get("prof_err_bits") or r.get("ctrl_err_bits") or r.get("halt_warn"))
        noec = sum(1 for r in D[v]["rows"] if r.get("prof_ecall") != 1)
        summ = []
        for op, _ in OPS:
            sub = [r for r in D[v]["rows"] if r["phase"].startswith(op + "_") and r["closure"]]
            if not sub:
                continue
            app_c = A[v][op]["cycles"]
            tot = sum(r["cycles"] for r in sub)
            summ.append(f"{op}: Σ{tot:,} / {app_c:,}（残差 {app_c - tot:+,}）")
        L.append(f"| {v} | {len(D[v]['rows'])} | {bad} | {noec} | {'；'.join(summ)} |")
    L.append("")

    # §1 macro
    L.append("## 1. Macro：整 app（100 MHz，cycles）")
    L.append("")
    L.append("| op | ver0_1 | ver0_2 | ver1_1 | 加速比 ver0_1÷ver1_1 |")
    L.append("|---|---:|---:|---:|---:|")
    for op, _ in OPS:
        c = [A[v][op]["cycles"] for v in VERS]
        ratio = f"{c[0] / c[2]:.2f}×" if c[2] else "—"
        L.append(f"| `{op}` | {c[0]:,} | {c[1]:,} | {c[2]:,} | {ratio} |")
    tot = [sum(A[v][op]["cycles"] for op, _ in OPS) for v in VERS]
    L.append(f"| **三 op 合计** | **{tot[0]:,}** | **{tot[1]:,}** | **{tot[2]:,}** | "
             f"**{tot[0] / tot[2]:.2f}×** |")
    L.append("")

    # §2 逐 op 阶段
    L.append("## 2. 逐 op 分解：阶段对照（cycles，直接测量）")
    L.append("")
    for op, _ in OPS:
        phases = [r["phase"] for r in D["ver0_1"]["rows"] if r["phase"].startswith(op + "_")] or \
                 [r["phase"] for r in D["ver0_2"]["rows"] if r["phase"].startswith(op + "_")]
        phases = sorted(set(phases) | {r["phase"] for r in D["ver0_2"]["rows"] if r["phase"].startswith(op + "_")}
                        | {r["phase"] for r in D["ver1_1"]["rows"] if r["phase"].startswith(op + "_")},
                        key=lambda p: -max((R[v].get(p, {}).get("cycles") or 0) for v in VERS))
        L.append(f"### {op}")
        L.append("")
        L.append("| 阶段 | ver0_1 | ver0_2 | ver1_1 | 加速比 ver0_1÷ver1_1 |")
        L.append("|---|---:|---:|---:|---:|")
        for ph in phases:
            c = [R[v].get(ph, {}).get("cycles") for v in VERS]
            ratio = f"{c[0] / c[2]:.2f}×" if (c[0] and c[2]) else "—"
            mark = " ⚠" if ph in NON_SIGMA else ""
            L.append(f"| `{ph}`{mark} | {num(c[0])} | {num(c[1])} | {num(c[2])} | {ratio} |")
        for v in VERS:
            sub = [r for r in D[v]["rows"] if r["phase"].startswith(op + "_") and r["closure"]]
            if sub:
                L.append(f"| **Σ（{v}，仅 closure:true）** | " + " | ".join(
                    (f"**{sum(r['cycles'] for r in sub):,}**" if vv == v else "") for vv in VERS) + " | |")
        L.append("")

    # §3 闭环
    L.append("## 3. 闭环体检（Σ 阶段 vs 整 app）")
    L.append("")
    L.append("| 版本 | op | Σ 阶段 | 整 app | 残差 | 残差% | coverage |")
    L.append("|---|---|---:|---:|---:|---:|---:|")
    for v in VERS:
        for op, _ in OPS:
            sub = [r for r in D[v]["rows"] if r["phase"].startswith(op + "_") and r["closure"]]
            if not sub:
                continue
            app_c, tot = A[v][op]["cycles"], sum(r["cycles"] for r in sub)
            res = app_c - tot
            L.append(f"| {v} | `{op}` | {tot:,} | {app_c:,} | {res:+,} | "
                     f"{100 * res / app_c:.3f}% | {100 - 100 * res / app_c:.2f}% |")
    L.append("")

    # §4 静态体积
    L.append("## 4. 静态体积（.text / .data+.bss）")
    L.append("")
    L.append("| 版本 | op | .text (B) | .data+.bss (B) | 合计 (B) |")
    L.append("|---|---|---:|---:|---:|")
    for v in VERS:
        for op, _ in OPS:
            a = A[v][op]
            dm = (a.get("data") or 0) + (a.get("bss") or 0)
            L.append(f"| {v} | `{op}` | {a['text']:,} | {dm:,} | {a['text'] + dm:,} |")
    L.append("")

    # §5 修正记录（手写片段）
    ex = Path(args.extra)
    if ex.exists():
        L.append(ex.read_text(encoding="utf-8").rstrip())
        L.append("")

    out = Path(args.out)
    out.write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"[写] {out}（{len(L)} 行）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
