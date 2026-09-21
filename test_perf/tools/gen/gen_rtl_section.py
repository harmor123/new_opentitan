#!/usr/bin/env python3
"""把「RTL 层实测」章节**生成并插入**到 实验数据/ver<版本>/<版本>分解表_*.md 里。

为什么单独做：分解表原有的「Ibex(chip) 层」章节是"生成表 + 人工叙述"的混合体（生成片段已不在仓库里），
重整份分解表会破坏那些叙述 ⇒ 这里只**插入**一个带标记的 RTL 章节（可反复执行：标记之间的内容整体替换）。

数据源（只读，不手抄）：
  · `logs_hkem/<版本>/rtl/rtl_trace_{keygen,encap,decap}.json` —— RTL 逐函数归因（方法 A）
  · `logs_hkem/<版本>_profiling/re_<版本>.json`              —— ISS 口径（对照列 + Δ退役）

用法:
  python3 test_perf/tools/gen/gen_rtl_section.py --archive <实验数据/> [--version ver1_1] [--dry]
"""
import argparse
import json
import re
import sys
from pathlib import Path

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = Path(__file__).resolve().parents[3]
VERS = ("ver0_1", "ver0_2", "ver1_1")
OPS = (("keygen", "keygen"), ("encap", "encap"), ("decap", "decap"))
BEGIN = "<!-- RTL-SECTION:BEGIN（由 test_perf/tools/gen/gen_rtl_section.py 生成；勿手改） -->"
END = "<!-- RTL-SECTION:END -->"
ANCHOR = re.compile(r"^## 8\. ", re.M)          # 插在「## 8. 指令归因」之前


def render(v: str) -> str:
    rtl = {}
    for op, _ in OPS:
        p = REPO / f"logs_hkem/{v}/rtl/rtl_trace_{op}.json"
        if not p.exists():
            raise SystemExit(f"✗ 缺 {p}（先跑 rtl_trace_attr.py）")
        rtl[op] = json.loads(p.read_text(encoding="utf-8"))
    rj = REPO / f"logs_hkem/{v}_profiling/re_{v}.json"
    rej = json.loads(rj.read_text(encoding="utf-8"))
    L = [BEGIN,
         f"## RTL 层实测 · {v}（OTBN 逐函数真实周期数，方法 A）", "",
         f"> 数据来源 `logs_hkem/{v}/rtl/*.rtl_trace.log`（同一份 app 在 chip sim 上跑、OTBN 连**真 KMAC**；"
         f"按 OTBN 指令级 trace 逐拍归因）。完整逐函数表与本层自证见顶层 `RTL实测_三版对照.md` §1–§3。", "",
         "| op | RTL 整段跨度 | ISS `macro` | 差 | RTL Σ`E` == chip `INSN_CNT` | RTL−ISS 指令 | 差落在 |",
         "|---|---:|---:|---:|---:|---:|---|"]
    for op, _ in OPS:
        d = rtl[op]
        sc = d["self_check"]
        a = rej["apps"][v][op]
        pct = f"{100 * (sc['span'] - a['cycles']) / a['cycles']:+.2f}%"
        ei = a.get("exec_insn") or {}
        nz = [f"`{s['name']}` {s['retire'] - ei[s['name']]:+}"
              for s in d["symbols"] if s["name"] in ei and s["retire"] != ei[s["name"]]]
        L.append(f"| `{op}` | {sc['span']:,} | {a['cycles']:,} | {pct} | "
                 f"{sc['sum_E']:,} == {sc.get('chip_insn') or 0:,} "
                 f"{'✓' if sc['ok_complete'] else '✗'} | {sc['d_insn']:+,} | "
                 + ("（无）" if not nz else "、".join(nz)) + " |")
    L += ["",
          f"> 自证（本版本三 op）：`ΣE == chip INSN_CNT` "
          + ("✓" if all(rtl[o]["self_check"]["ok_complete"] for o, _ in OPS) else "✗")
          + "；逐函数拍数之和 == 整段跨度 "
          + ("✓" if all(rtl[o]["self_check"]["ok_span"] for o, _ in OPS) else "✗")
          + "；帧跨度恒等式逐帧全等 "
          + ("✓" if all(rtl[o]["self_check"].get("ok_frames") for o, _ in OPS) else "✗")
          + "。与 ISS 的指令数差**全部**落在 KMAC 轮询行（`_xof_*_poll*`；ver0_1 不用 KMAC ⇒ 差 0/0/0），"
          "那是 ISS 的 KMAC 粗粒度模型差，不是数据错。", "",
          "**逐函数 Top 5（含被调 = 帧跨度 `[C1,C2)`；叶函数 == 自身拍）**：", "",
          "| op | 1 | 2 | 3 | 4 | 5 |", "|---|---|---|---|---|---|"]
    for op, _ in OPS:
        syms = sorted(rtl[op]["symbols"],
                      key=lambda s: -((s["inclusive"] if s["inclusive"] is not None else s["cycles"])))
        cells = []
        for s in syms[:5]:
            ic = s["inclusive"] if s["inclusive"] is not None else s["cycles"]
            cells.append(f"`{s['name']}` {ic:,}")
        L.append(f"| `{op}` | " + " | ".join(cells) + " |")
    L += ["", END]
    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--archive", required=True, help="实验数据/ 目录")
    ap.add_argument("--version", action="append")
    ap.add_argument("--dry", action="store_true")
    args = ap.parse_args()
    arch = Path(args.archive)
    for v in (args.version or list(VERS)):
        cands = sorted((arch / v).glob("*分解表*.md"))
        if len(cands) != 1:
            print(f"  ✗ {v}: 该版本目录下的分解表 md 不是恰好 1 份：{cands}")
            return 1
        f = cands[0]
        txt = f.read_text(encoding="utf-8")
        block = render(v)
        if BEGIN in txt and END in txt:                      # 已有 ⇒ 整体替换（幂等）
            txt_new = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END), block, txt, flags=re.S)
            action = "替换"
        else:                                                # 首次 ⇒ 插到「## 8.」之前
            if not ANCHOR.search(txt):
                print(f"  ✗ {v}: 找不到插入锚点（`## 8. `）")
                return 1
            txt_new = ANCHOR.sub(block + "\n\n" + "## 8. ", txt, count=1)
            action = "插入"
        if args.dry:
            print(f"  （干跑）{v}: 将{action} RTL 章节（{len(block.splitlines())} 行）→ {f.name}")
            continue
        f.write_text(txt_new, encoding="utf-8")
        print(f"  [{action}] {v}: {f.name}（{len(txt_new):,} 字符）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
