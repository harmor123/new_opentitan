#!/usr/bin/env python3
"""由 9 份 `stall_profile_*.log` 生成《残差构成（全实测）》—— 数字不手抄。

残差 = 整 app − Σ阶段（表里那个数），历来只被**口头**解释成"wrapper 清零循环 + 框架胶水"。
`test_perf/tools/diag/stall_profile.py` 把 app 的拍数按 PC（退役 + 停滞）归因后：
  · **匿名区**（无符号，如 wrapper 清零循环）与 **框架容器**（`crypto_kem_*`/`indcpa_*`）
    两项是 **PC 级实测**；
  · "其它" = 残差 − 这两项（减法，含 Σ 行 Δ 的前导冗余，可能为负）—— 不做任何名称推断。
  （为什么不用"未覆盖符号"逐个判：`load_text_boundaries` 是**分区**，内核内部标签自成区间，
    按区间判会把它们误判成残差。）

用法: python3 test_perf/tools/gen/gen_residual_doc.py [--out <路径>]
"""
import argparse
import re
import sys
from pathlib import Path

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = Path(__file__).resolve().parents[3]   # 工具在 test_perf/tools/<类>/ 下 ⇒ 仓库根 = parents[3]
VERS = ("ver0_1", "ver0_2", "ver1_1")
OPS = ("keygen", "encap", "decap")


def parse(log: Path):
    t = log.read_text(encoding="utf-8")
    md5 = (re.search(r"md5=([0-9a-f]{32})", t) or [None, "?"])[1]
    ok = "自证：一致 → ✓" in t
    sec = t.split("## 残差拆分", 1)[-1].split("\n## ", 1)[0]
    m = re.search(r"整 app ([\d,]+) 拍 − Σ阶段 ([\d,]+) 拍 = 残差 \*\*([\d,]+) 拍\*\*", sec)
    raw = re.search(r"基准（JSON 实测）：insn ([\d,]+) \+ stalls ([\d,]+) = ([\d,]+) 拍", t)
    vals = {}
    for r in re.finditer(r"^\| ([^|]+?) \| ([\d,\-+]+) \| ([\-\d.]+)% \|", sec, re.M):
        try:
            vals[r.group(1).strip()] = int(r.group(2).replace(",", ""))
        except ValueError:
            pass
    anon = next((v for k, v in vals.items() if "匿名" in k), None)
    cont = next((v for k, v in vals.items() if "容器" in k), None)
    app = int(m.group(1).replace(",", "")) if m else None
    sigma = int(m.group(2).replace(",", "")) if m else None
    res = int(m.group(3).replace(",", "")) if m else None
    return dict(md5=md5, ok=ok, app=app, sigma=sigma, res=res, anon=anon, cont=cont,
                insn=int(raw.group(1).replace(",", "")) if raw else None,
                stalls=int(raw.group(2).replace(",", "")) if raw else None)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(REPO.parent / "md文档/新方案/实验数据/残差构成_全实测.md"))
    args = ap.parse_args()

    D = {}
    for v in VERS:
        for op in OPS:
            p = REPO / "logs_hkem" / f"{v}_profiling" / f"stall_profile_{op}.log"
            if not p.exists():
                print(f"  ⚠ 缺 {p}（该行留空）")
                continue
            D[(v, op)] = parse(p)

    md5s = {d["md5"] for d in D.values()}
    L = ["# 残差构成（三版 × 三 op，全实测）", "",
         "> 数据来源：`logs_hkem/<版本>_profiling/stall_profile_<op>.log`"
         f"（工具 `test_perf/tools/diag/stall_profile.py`，md5 {sorted(md5s)[0][:8]}…；"
         f"{sum(1 for d in D.values() if d['ok'])}/{len(D)} 份自证通过 "
         "= 本循环的 Σ退役/Σ停滞 与 JSON 里那次实测的 insn/stalls 逐位相同）。",
         "> 口径：**残差 = 整 app − Σ阶段**（就是各分解表里那个数）；部件 = 按 PC 的**拍数**"
         "（退役 + 停滞）归因，全部实测。", "",
         "| 版本 | op | 整 app（拍） | Σ阶段（拍） | 残差（拍） | 残差% | 匿名区（wrapper 清零循环） | 框架容器（crypto_kem_*/indcpa_*） | 其它（残差 − 上两项） |",
         "|---|---|---:|---:|---:|---:|---:|---:|---:|"]
    for v in VERS:
        for op in OPS:
            d = D.get((v, op))
            if not d or d["res"] is None or d["anon"] is None or d["cont"] is None:
                L.append(f"| {v} | `{op}` |  |  |  |  |  |  |  |")
                continue
            rest = d["res"] - d["anon"] - d["cont"]
            L.append(f"| {v} | `{op}` | {d['app']:,} | {d['sigma']:,} | {d['res']:,} | "
                     f"{100 * d['res'] / d['app']:.2f}% | {d['anon']:,}（{100 * d['anon'] / d['res']:.1f}%） | "
                     f"{d['cont']:,}（{100 * d['cont'] / d['res']:.1f}%） | {rest:+,} |")
    L += ["",
          "**读法**：残差里 **≈87–97% 是 wrapper 的清零循环**（`sw x0,0(x2); addi x2,x2,4; bne`，"
          "每次迭代 3 条指令 + 1 拍取指停滞 ⇒ ≈4 拍/4 B），其余是外层框架代码；"
          "「其它」一列是减法残量（含 Σ 行 Δ 相对 app 的前导冗余），量级 ≤ ~500 拍。", "",
          "复现：", "", "```bash",
          "python3 test_perf/tools/diag/stall_profile.py --version <版本> --op <keygen|encap|decap> \\",
          "    --target //test_hybrid_kem_otbn_prompt_<版本>/otbn/mlkem768:mlkem768_<keypair|encap|decap> \\",
          "    --out logs_hkem/<版本>_profiling/stall_profile_<op>.log", "```", ""]

    out = Path(args.out)
    out.write_text("\n".join(L) + "\n", encoding="utf-8")
    print(f"[写] {out}（{len(L)} 行）")
    print("\n".join(L[6:16]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
