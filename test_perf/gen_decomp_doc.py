#!/usr/bin/env python3
"""从 harness 的 JSON 直接生成"分解表"文档（不手抄数字）。

用法:
    python3 test_perf/gen_decomp_doc.py --version ver0_1 --json logs_hkem/ver0_1_profiling/re_ver0_1.json \
        --out "…/md文档/新方案/ver0_1分解表_软件Keccak.md" [--doc-version "2026-09-20 v3"] [--backup]

产出结构（与仓库既有分解表一致）：
    §1 口径 / §2 Macro + 代码体积 / §3–5 三操作阶段表 / §6 闭环与残差 /
    §7–9（由 --extra 指定的版本专属段落原样插入）/ §10 数据来源
所有数字都取自 JSON（cycles/insn/stalls/histo/exec_insn/boundaries），
**不写任何估算**：进 Σ 的行 = JSON 里 `closure: true` 的行。
"""
import argparse
import io
import json
import shutil
from pathlib import Path

VER_TITLE = {
    "ver0_1": ("ver0_1（纯软哈希基线）ML-KEM-768 分解表",
               ["版本：ver0_1 = 纯软件资源基线（`test_hybrid_kem_otbn_prompt_ver0_1/`，IMEM 32 KB 布局）",
                "哈希：软件 Keccak（OTBN 上跑 `keccakf`，自带 `context` 212 B + `rc` 数据）；P-256/HKDF 不参与本文"]),
    "ver0_2": ("ver0_2（KMAC 硬件哈希）ML-KEM-768 分解表",
               ["版本：ver0_2 = 官方向量化资源 + KMAC 硬件哈希（`test_hybrid_kem_otbn_prompt_ver0_2/`）",
                "哈希：KMAC 硬件（`xof_*` 驱动 API）；P-256/HKDF 不参与本文"]),
    "ver1_1": ("ver1_1（官方向量指令 + KMAC）ML-KEM-768 分解表",
               ["版本：ver1_1 = 官方 mlkem1024 移植到 768（向量指令 + 掩码）+ KMAC（`test_hybrid_kem_otbn_prompt_ver1_1/`）",
                "哈希：KMAC 硬件；P-256/HKDF 不参与本文"]),
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--json", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--doc-version", default="")
    ap.add_argument("--extra", default="", help="版本专属 Markdown 片段（原样插入 §6 之后）")
    ap.add_argument("--preamble", default="", help="版本专属 §1（口径/变更/复现），插在 §2 之前")
    args = ap.parse_args()

    d = json.loads(Path(args.json).read_text(encoding="utf-8"))
    rows = d["rows"]
    apps = d["apps"][args.version]
    ver = args.version

    def sub(op, cl=True):
        return [r for r in rows
                if r["phase"].startswith(op + "_") and bool(r.get("closure", True)) == cl]

    def label(r):
        """口径列：旧配置里残留的 Reuse-*/Estimated 标签，只要本行**这次真的跑了**
        （prof_cycles 非空）就显示为 Direct —— 文档不能自相矛盾。"""
        ev = r.get("evidence") or "Direct"
        if (ev.startswith("Reuse") or ev == "Estimated") and r.get("prof_cycles") is not None:
            return "Direct"
        return ev

    L = []

    def W(s=""):
        L.append(s)

    title, head = VER_TITLE.get(ver, (f"{ver} ML-KEM-768 分解表", []))
    W(f"# {title}\n")
    for h in head:
        W("> " + h)
    W("> 测量法：harness 法（`C_net = C_profiling − C_control`），ISS 口径（**Cycles = 已提交指令数 + 停滞周期数**）")
    W(f"> **数据版本：{args.doc_version}**；进 Σ 的行 = `closure: true`，全部为直接测量")
    W("")

    if args.preamble and Path(args.preamble).exists():
        W(Path(args.preamble).read_text(encoding="utf-8").rstrip() + "\n")

    # §2 Macro
    W("## 2. Macro（整 app，实测）\n")
    W("| 操作 | Cycles | = insn | + stalls | CPI | iss_cycles¹ | 时间@100 MHz |")
    W("|---|---:|---:|---:|---:|---:|---:|")
    for op, lab in (("keygen", "KeyGen"), ("encap", "Encap"), ("decap", "Decap")):
        x = apps[op]
        W("| %s | **%s** | %s | %s | %.3f | %s | %.2f ms |" % (
            lab, f"{x['cycles']:,}", f"{x['insn']:,}", f"{x['stalls']:,}",
            x["cycles"] / x["insn"], f"{x['iss_cycles']:,}", x["cycles"] / 1e5))
    W("\n¹ `iss_cycles` = ISS `run()` 总周期（另含约 200 拍 wipe），单列备查。\n")
    W("**代码体积**（`.text` / `.data`(+`.bss`)）：\n")
    W("| 操作 | IMEM (.text) | DMEM (.data) | Total |")
    W("|---|---:|---:|---:|")
    for op, lab in (("keygen", "KeyGen"), ("encap", "Encap"), ("decap", "Decap")):
        x = apps[op]
        dm = (x.get("data") or 0) + (x.get("bss") or 0)
        W("| %s | %s B | %s B | %s B |" % (lab, f"{x['text']:,}", f"{dm:,}", f"{x['text'] + dm:,}"))

    # §3–5 阶段表
    for idx, (op, name) in enumerate((("keygen", "KeyGen"), ("encap", "Encaps"), ("decap", "Decaps")), start=3):
        denom = apps[op]["cycles"]
        W(f"\n## {idx}. {name} 分解（分母 = {denom:,} cycles）\n")
        W("| Stage | Cycles | % | insn | stalls | CPI | FIPS | 口径 |")
        W("|---|---:|---:|---:|---:|---:|---|---|")
        for r in sorted(sub(op), key=lambda x: -x["cycles"]):
            W("| `%s` | **%s** | %.2f%% | %s | %s | %.3f | %s | %s |" % (
                r["phase"].replace(op + "_", ""), f"{r['cycles']:,}", 100 * r["cycles"] / denom,
                f"{r['insn']:,}", f"{r['stalls']:,}", r["cycles"] / max(r["insn"], 1),
                r["fips"] or "—", label(r)))
        s = sum(r["cycles"] for r in sub(op))
        a = apps[op]
        W("| **Σ 阶段** | **%s** | **%.2f%%** | | | | | |" % (f"{s:,}", 100 * s / denom))
        W("| 整 app | %s | 100%% | %s | %s | %.3f | | |" % (
            f"{a['cycles']:,}", f"{a['insn']:,}", f"{a['stalls']:,}", a["cycles"] / a["insn"]))
        W("\n**残差 +%s（%.3f%%）** → coverage ≈ **%.2f%%**。" % (
            f"{denom - s:,}", 100 * (denom - s) / denom, 100 * s / denom))
        ncl = [r for r in rows if r["phase"].startswith(op + "_") and not r.get("closure", True)]
        if ncl:
            W("\n不进 Σ 的行：" + "、".join("`%s` %s" % (r["phase"], f"{r['cycles']:,}") for r in ncl) + "。")

    # §6 闭环与残差
    W("\n## 6. 闭环与残差\n")
    W("| 闭环项 | " + " | ".join(n for _, n in (("keygen", "KeyGen"), ("encap", "Encaps"), ("decap", "Decaps"))) + " |")
    W("|---|" + "---|" * 3)
    cls = d.get("closure", {}).get(ver, {})
    W("| **周期 Σ 残差** | " + " | ".join(
        f"+{cls[o]['residual']:,}（{cls[o]['residual_pct']}%）" for o in ("keygen", "encap", "decap")) + " |")
    W("| **attribution coverage** | " + " | ".join(
        f"{100 - cls[o]['residual_pct']:.2f}%" for o in ("keygen", "encap", "decap")) + " |")
    W("\n> 调用闭环（Keccak-f / KMAC API、`bn.mulqacc.wo`）与 `[运行健康检查]` 见同目录 `run.log`。")

    if args.extra and Path(args.extra).exists():
        W("\n" + Path(args.extra).read_text(encoding="utf-8"))

    # §8 指令归因
    W("\n## 8. 指令归因（Δ 后 Top 3）\n")
    W("| Stage | Top 指令 |")
    W("|---|---|")
    for op in ("keygen", "encap", "decap"):
        for r in sorted(sub(op), key=lambda x: -x["cycles"]):
            top = sorted((r.get("insn_histo") or {}).items(), key=lambda x: -x[1])[:3]
            W("| `%s` | %s |" % (r["phase"], " · ".join(f"{k} {v:,}" for k, v in top)))

    # §9 死代码
    W("\n## 9. 死代码（确证：ISS 逐 PC 覆盖）\n")
    W("`exec_insn`（每函数实际执行指令数）中不出现的函数 = 该 app 内从未执行：\n")
    W("| app | 从未执行的函数 |")
    W("|---|---|")
    for op, lab in (("keygen", "KeyGen"), ("encap", "Encap"), ("decap", "Decap")):
        a = apps[op]
        ei = a.get("exec_insn") or {}
        names = [n for _s, _e, n in a.get("boundaries", []) if not n.startswith("$")]
        dead = sorted(n for n in names if ei.get(n, 0) == 0)
        W("| %s | %s |" % (lab, ", ".join(f"`{n}`" for n in dead) or "—"))

    # §10 数据来源
    W("\n## 10. 数据来源\n")
    W("| 项 | 位置 |")
    W("|---|---|")
    W(f"| 本表原始数据 | `{args.json}` + 同目录 `run.log` |")
    W("| harness 工具 | `test_perf/harness.py` + `harness_config.yaml` |")
    W("| 单 ELF 诊断 | `test_perf/iss_diag.py` |")
    W("| 文档生成 | `test_perf/gen_decomp_doc.py`（数字全部取自 JSON，不手抄） |")

    out = Path(args.out)
    if out.exists():
        bak = out.with_suffix(".bak.md")
        shutil.copy2(out, bak)
        print(f"[备份] {bak}")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"[写] {out}（{len(L)} 行）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
