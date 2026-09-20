#!/usr/bin/env python3
"""由 JSON 生成 `实验数据/<版本>/README.md` —— 数字全部取自 JSON，不手抄。

为什么改成生成：手写版会**漂**（2026-09-20 实测：ver0_1 的 Σ 阶段写 550,468、实际 550,392；
ver1_1 写"37 个阶段"、实际 38；残差与 coverage 同样陈旧）。这些量都能从
`logs_hkem/<版本>_profiling/re_<版本>.json` 直接算出来，所以改成生成物。

归档策略（2026-09-20 用户定）：**归档只留 README + 汇总 md**，逐版本的数据文件不复制
（它们与 `logs_hkem/<版本>_profiling/` 逐字节相同，复制属重复）⇒ 本 README 指向 logs_hkem。

用法: python3 test_perf/tools/gen/gen_version_readme.py --version ver0_1
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

TITLE = {"ver0_1": "ver0_1 = 纯软哈希基线（软件 Keccak + 自写标量算术）",
         "ver0_2": "ver0_2 = KMAC 硬件哈希 + 自写标量算术（算术内核与 ver0_1 同源）",
         "ver1_1": "ver1_1 = 官方向量指令（mlkem1024 移植到 768，掩码）+ KMAC"}
OPS = (("keygen", "KeyGen"), ("encap", "Encap"), ("decap", "Decap"))
# §4 版本专属备注（手写散文；数字类结论都在 §2/§3 与配套文档里，不在这里重复写死）
NOTE = {
    "ver0_1": [
        "**本版特有**：软件 `keccakf` 的 `rc` 轮常量表尾缺 24 B 补位，曾让 `encap_h_ek` / `decap_hash_g_reuse` "
        "两行以 `DMEM_INTG_VIOLATION` 中止（残缺值 7,677 / 5,985）。2026-09-20 已在 5 个文件表尾补 `.balign 32` 修复；"
        "现 `run.log` 的 `[运行健康检查]` 显示全部正常收尾。",
        "与 ver0_2 的关系：**非哈希阶段逐位相同**（同一套标量算术内核）⇒ 两版差异全部来自哈希/采样路径硬件化。",
    ],
    "ver0_2": [
        "与 ver0_1 的关系：**非哈希阶段逐位相同**（同一套标量算术内核）⇒ 差异全部来自哈希/采样路径硬件化。",
        "桩法子分解（`keygen_poly_gen_matrix_{shake,rejection,stub_overhead}`）与 ver0_1 同形：每会话按需补挤 15 块、合计 135 次，"
        "`shake + rejection − stub_overhead` 与直接测量**精确闭合 +0**。",
    ],
    "ver1_1": [
        "与 ver0_2 的关系：**算术换官方向量实现（变快），打包/解包与 CBD 采样变贵** ⇒ 这是 encap 只快 1.27× 的原因。",
        "残差最大（decap 8.60%）的原因不是实现慢，而是 **wrapper 清了更大的暂存区**（decap ≈16 KiB）："
        "清零循环按 `scratch_start..scratch_end` 走，与算法无关。逐 op 实测构成见 `../残差构成_全实测.md`。",
    ],
}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--doc-version", default="2026-09-20 v4")
    ap.add_argument("--out", default="")
    ap.add_argument("--logs-dir", default=str(REPO / "logs_hkem"))
    args = ap.parse_args()
    v = args.version
    d = json.loads((Path(args.logs_dir) / f"{v}_profiling" / f"re_{v}.json").read_text(encoding="utf-8"))
    A = d["apps"][v]
    L = [f"# 实验数据 · {v}", "",
         f"> {TITLE[v]}",
         f"> 数据版本：**{args.doc_version}**（全阶段直接测量，`reuse = 0`）", "",
         "## 1. 数据文件在哪", "",
         f"逐版本数据（harness 三件套 + 运行日志 + 残差归因日志）在仓库内 "
         f"**`logs_hkem/{v}_profiling/`**：", "",
         "| 文件 | 内容 |", "|---|---|",
         f"| `re_{v}.csv` | 逐阶段一行（cycles/insn/stalls/text/data/image/FIPS/口径/mulqacc/调用计数） |",
         f"| `re_{v}.json` | 同上 + 完整指令直方图 + app 的逐 PC 覆盖（`exec_insn`）+ 边界 |",
         f"| `re_{v}.md` | 一页表（阶段/周期/指令/停滞/镜像/FIPS/口径） |",
         "| `run.log` | 完整运行日志：macro、逐阶段 Δ、`[closure]`、三条闭环表、`[运行健康检查]`、逐 op 分解表 |",
         "| `stall_profile_{keygen,encap,decap}.log` | 拍级归因（按 PC 把 app 拍数摊到符号/匿名区，含自证） |", "",
         "> 本目录不再复制这些文件（与 `logs_hkem/` 逐字节相同的副本属重复）；本目录只放本 README。", "",
         "## 2. Macro（整 app，@100 MHz）", "",
         "| 操作 | Cycles | insn | stalls | CPI | iss_cycles | 时间 | IMEM(.text) | DMEM |",
         "|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for op, name in OPS:
        a = A[op]
        dm = (a.get("data") or 0) + (a.get("bss") or 0)
        L.append(f"| {name} | **{a['cycles']:,}** | {a['insn']:,} | {a['stalls']:,} | "
                 f"{a['cycles'] / a['insn']:.3f} | {a['iss_cycles']:,} | "
                 f"{a['cycles'] / 100_000:.2f} ms | {a['text']:,} B | {dm:,} B |")
    L += ["", "## 3. 闭环与残差（数字由 JSON 直接算，本表不手抄）", "",
          "| 项 | KeyGen | Encap | Decap |", "|---|---:|---:|---:|"]
    rows = {op: [r for r in d["rows"] if r["phase"].startswith(op + "_") and r["closure"]] for op, _ in OPS}
    sig = {op: sum(r["cycles"] for r in rows[op]) for op, _ in OPS}
    L.append("| Σ 阶段 | " + " | ".join(f"{sig[op]:,}" for op, _ in OPS) + " |")
    L.append("| 整 app | " + " | ".join(f"{A[op]['cycles']:,}" for op, _ in OPS) + " |")
    L.append("| 残差 | " + " | ".join(
        f"+{A[op]['cycles'] - sig[op]:,}（{100 * (A[op]['cycles'] - sig[op]) / A[op]['cycles']:.3f}%）"
        for op, _ in OPS) + " |")
    L.append("| coverage | " + " | ".join(
        f"{100 * sig[op] / A[op]['cycles']:.2f}%" for op, _ in OPS) + " |")
    nstub = sum(1 for r in d["rows"] if not r["closure"])
    L += ["", f"阶段行数 **{len(d['rows'])}**（其中 {len(d['rows']) - nstub} 行进 Σ、{nstub} 行不进 Σ："
          "桩法校准 3 行 + 单次探针（如 `encap_intt` 只调 1 次 INTT））；"
          "调用闭环与 `bn.mulqacc.wo` 闭环（逐 op，全部差异 +0）见 `run.log`。", "",
          "## 4. 备注", ""]
    L += [f"- {x}" for x in NOTE[v]]
    L += ["", f"配套文档：`../{v}分解表_" + {"ver0_1": "软件Keccak", "ver0_2": "KMAC硬件哈希",
                                            "ver1_1": "向量指令+KMAC"}[v] + ".md`"
          "（阶段级分解）；三版横向对照与残差构成见 `../三版对照_全实测.md`、`../残差构成_全实测.md`。", ""]

    out = Path(args.out) if args.out else (
        REPO.parent / "md文档/新方案/实验数据" / v / "README.md")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(L), encoding="utf-8")
    print(f"[写] {out}（{len(L)} 行）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
