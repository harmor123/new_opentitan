#!/usr/bin/env python3
"""从两版 harness JSON 生成"对照表"文档（数字全部现算，不手抄）。

用法:
    python3 test_perf/gen_compare_doc.py --a ver0_1 --b ver0_2 \
        --json-a logs_hkem/ver0_1_profiling/re_ver0_1.json \
        --json-b logs_hkem/ver0_2_profiling/re_ver0_2.json \
        --out "…/md文档/新方案/ver0_1_vs_ver0_2_对照表.md" \
        [--a-label "软件 Keccak"] [--b-label "KMAC 硬件"] [--doc-version "..."] [--backup]
"""
import argparse
import json
import shutil
from pathlib import Path

OPS = ("keygen", "encap", "decap")
OPLAB = {"keygen": "KeyGen", "encap": "Encap", "decap": "Decap"}


def load(p):
    d = json.loads(Path(p).read_text(encoding="utf-8"))
    return d


def stage_map(d, ver):
    """(op, 行名去掉 op 前缀) → row"""
    out = {}
    for r in d["rows"]:
        op = r["phase"].split("_", 1)[0]
        out[(op, r["phase"].replace(op + "_", ""))] = r
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--a", required=True, help="版本 A（基线）")
    ap.add_argument("--b", required=True, help="版本 B（改进版）")
    ap.add_argument("--json-a", required=True)
    ap.add_argument("--json-b", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--a-label", default="")
    ap.add_argument("--b-label", default="")
    ap.add_argument("--title", default="")
    ap.add_argument("--doc-version", default="")
    ap.add_argument("--backup", action="store_true")
    args = ap.parse_args()

    A, B = load(args.json_a), load(args.json_b)
    va, vb = args.a, args.b
    aa, ab = A["apps"][va], B["apps"][vb]
    sa, sb = stage_map(A, va), stage_map(B, vb)
    L = []

    def W(s=""):
        L.append(s)

    W(f"# {args.title or f'{va} vs {vb} 对照表'}\n")
    W(f"> **对照实验**：{va} = {args.a_label or '基线'}；{vb} = {args.b_label or '改进版'}")
    W("> 测量法：同一套 harness 法（`C_net = C_profiling − C_control`），ISS 口径（Cycles = insn + stalls）")
    W(f"> **数据版本：{args.doc_version}**（两版均为全阶段直接测量，`reuse = 0`）")
    W(f"> 明细：`{va}分解表_*.md` · `{vb}分解表_*.md` · 原始数据 `实验数据/{va}/`、`实验数据/{vb}/`\n")

    # §2 macro
    W(f"## 1. 端到端（macro）\n")
    W(f"| 操作 | {va} Cycles | {vb} Cycles | **周期加速** | {va} insn | {vb} insn | **指令加速** | CPI（{va} → {vb}） |")
    W("|---|---:|---:|---:|---:|---:|---:|---|")
    for op in OPS:
        a, b = aa[op], ab[op]
        W("| %s | %s | **%s** | **%.2f×** | %s | %s | %.2f× | %.3f → %.3f |" % (
            OPLAB[op], f"{a['cycles']:,}", f"{b['cycles']:,}", a["cycles"] / b["cycles"],
            f"{a['insn']:,}", f"{b['insn']:,}", a["insn"] / b["insn"],
            a["cycles"] / a["insn"], b["cycles"] / b["insn"]))
    W("\n时间（@100 MHz）：" + " / ".join(f"{aa[o]['cycles']/1e5:.2f}" for o in OPS) +
      " ms → " + " / ".join(f"{ab[o]['cycles']/1e5:.2f}" for o in OPS) + " ms")

    # §3 阶段对照（同名阶段）
    W(f"\n## 2. 阶段级对照（同名阶段直接可比）\n")
    keys = [k for k in sa if k in sb]
    keys.sort(key=lambda k: -(sa[k]["cycles"] + sb[k]["cycles"]))
    # 哈希/采样类：名字含这些词的阶段（含 h_ek / sha3_init_update_final / shake_z_ct）
    HASHW = ("hash", "noise", "gen_matrix", "shake", "h_ek", "sha3_")
    def is_hash(k):
        return any(w in k[1] for w in HASHW)
    W("### 2.1 哈希/采样类（本对照的主角）\n")
    W(f"| 阶段 | {va} | {vb} | 加速 |")
    W("|---|---:|---:|---:|")
    for k in keys:
        if not is_hash(k):
            continue
        a, b = sa[k]["cycles"], sb[k]["cycles"]
        W("| `%s`%s | %s | %s | **%.2f×** |" % (k[1], "" if len({x[0] for x in keys if x[1]==k[1]})==1 else f"（{k[0]}）",
          f"{a:,}", f"{b:,}", a / b))
    W("\n### 2.2 算术/打包类（逐位相同 = 对照有效性的证据）\n")
    W(f"| 阶段 | {va} | {vb} | Δ |")
    W("|---|---:|---:|---:|")
    same = diff = 0
    for k in keys:
        if is_hash(k):
            continue
        a, b = sa[k]["cycles"], sb[k]["cycles"]
        d = a - b
        if d == 0:
            same += 1
        else:
            diff += 1
        W("| `%s`%s | %s | %s | %s |" % (k[1], "" if len({x[0] for x in keys if x[1]==k[1]})==1 else f"（{k[0]}）",
          f"{a:,}", f"{b:,}", "**0 ✓**" if d == 0 else f"**{d:+,}**"))
    W(f"\n⇒ 同名非哈希阶段 **{same} 个逐位相同**、{diff} 个有差异"
      f"（两版哈希实现不同、算术内核同源时这正说明对照有效）。")

    # §4 静态内存
    W("\n## 3. 静态内存对照\n")
    W(f"| 操作 | {va} IMEM | {vb} IMEM | IMEM Δ | {va} DMEM | {vb} DMEM | DMEM Δ |")
    W("|---|---:|---:|---:|---:|---:|---:|")
    for op in OPS:
        a, b = aa[op], ab[op]
        da, db = (a.get("data") or 0) + (a.get("bss") or 0), (b.get("data") or 0) + (b.get("bss") or 0)
        W("| %s | %s B | **%s B** | %s | %s B | %s B | %s |" % (
            OPLAB[op], f"{a['text']:,}", f"{b['text']:,}", f"{b['text']-a['text']:+,}",
            f"{da:,}", f"{db:,}", f"{db-da:+,}"))

    # §5 闭环与残差
    W("\n## 4. 闭环与残差对照\n")
    ca, cb = A["closure"][va], B["closure"][vb]
    W(f"| 闭环项 | {va} | {vb} |")
    W("|---|---|---|")
    W("| 周期 Σ 残差 | " + " / ".join(f"+{ca[o]['residual']:,}（{ca[o]['residual_pct']}%）" for o in OPS) +
      " | " + " / ".join(f"+{cb[o]['residual']:,}（{cb[o]['residual_pct']}%）" for o in OPS) + " |")
    W("| attribution coverage | " + " / ".join(f"{100-ca[o]['residual_pct']:.2f}%" for o in OPS) +
      " | " + " / ".join(f"{100-cb[o]['residual_pct']:.2f}%" for o in OPS) + " |")
    W("\n> 调用闭环（Keccak-f / KMAC API、`bn.mulqacc.wo`）与 `[运行健康检查]` 逐 op 见 `实验数据/<版本>/run.log`。")

    # §6 负载结构
    W("\n## 5. 负载结构（各占本版 macro）\n")
    W(f"| 版本 / 操作 | 哈希/采样类合计¹ | 算术/打包类合计 | Σ 阶段 |")
    W("|---|---:|---:|---:|")
    for ver, S, apps, cl in ((va, sa, aa, ca), (vb, sb, ab, cb)):
        for op in OPS:
            h = sum(r["cycles"] for k, r in S.items() if k[0] == op and r.get("closure", True) and is_hash(k))
            t = cl[op]["sum"]
            W("| %s %s | **%s（%.1f%%）** | %s（%.1f%%） | %s |" % (
                ver, OPLAB[op], f"{h:,}", 100 * h / apps[op]["cycles"],
                f"{t-h:,}", 100 * (t-h) / apps[op]["cycles"], f"{t:,}"))
    W("\n¹ 哈希/采样类 = `poly_gen_matrix` + `H(ek)`/`J(z‖c)` + noise + `G(·)`；其余为算术/打包类。")

    W("""
## 6. 口径纪律（每次更新都要满足）

1. **三档闭环都要列**：指令闭环（`bn.mulqacc.wo` 等）、**调用闭环**（Keccak-f / KMAC API）、周期 Σ 残差。
2. **残差要写清构成**（本对照：wrapper 的清零循环 + 胶水），否则会被误读成测量误差。
3. **每行都要有运行健康检查**：`ERR_BITS = 0` 且执行到自己的 `ecall`；残缺运行（如 2026-09-20 的 `rc` 表尾 bug）会静默产出错值。
4. **同名阶段必须逐位可比**：两版算术内核同源时，非哈希阶段应全部为 0 差；出现非 0 要逐条给理由。""")

    W(f"\n## 7. 复现\n")
    W("```bash")
    W("cd ~/new_pqc/opentitan")
    for v in (va, vb):
        W(f"bazel build //test_hybrid_kem_otbn_prompt_{v}/otbn/mlkem768:all")
    W("for v in %s %s; do" % (va, vb))
    W("  python3 test_perf/harness.py --config test_perf/harness_config.yaml --version $v \\")
    W("      --csv logs_hkem/${v}_profiling/re_${v}.csv --json logs_hkem/${v}_profiling/re_${v}.json \\")
    W("      --markdown logs_hkem/${v}_profiling/re_${v}.md")
    W("done")
    W("```")
    W(f"\n原始数据：`实验数据/{va}/` · `实验数据/{vb}/`（{args.doc_version}）")

    out = Path(args.out)
    if args.backup and out.exists():
        bak = out.with_suffix(".bak.md")
        shutil.copy2(out, bak)
        print(f"[备份] {bak}")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"[写] {out}（{len(L)} 行）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
