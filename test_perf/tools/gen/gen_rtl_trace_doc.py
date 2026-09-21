#!/usr/bin/env python3
"""把 **RTL 逐函数真实周期数** 汇总成文档（读 JSON，不手抄）。

数据来源（只读）：
  · `logs_hkem/<版本>/rtl/rtl_trace_{keygen,encap,decap}.json` —— `rtl_trace_attr.py` 的产物
    （逐 PC trace → 逐函数：退役 / 停滞 / 取指等待 / 拍数；自证三条）
  · `logs_hkem/<版本>_profiling/re_<版本>.json` —— ISS 口径（macro 拍数，做对照）

产出（**都落在 logs_hkem/ 下**，那里不进 git；分解表用 `--extra` 直接引这些路径即可）：
  · `logs_hkem/<版本>/rtl/RTL实测_<版本>.md`   —— 该版本的「RTL 实测」章节（逐函数含被调拍 + 与 ISS 行对照）
  · `logs_hkem/RTL实测_三版对照.md`            —— 三版逐函数横向对照

口径（与 `rtl_trace_attr.py` 一致，**别改**）：
  `RTL 拍 = 退役 + 停滞 + 取指等待`；取指等待摊给上一条记录所在函数（同 ISS `has_fetch_stall`）
  ⇒ **逐函数拍数之和 == 整段跨度**（100% 归属，无残量）。
  ⚠ 与 ISS 的差是**信息**：KMAC 版（ver0_2/ver1_1）ISS 的 KMAC 时序是粗粒度模型，轮询圈数与
  RTL 不同 ⇒ 指令数/拍数本就应差；差落在哪看 `Δ退役` 列。

用法:
  python3 test_perf/tools/gen/gen_rtl_trace_doc.py                 # 干跑（打印摘要）
  python3 test_perf/tools/gen/gen_rtl_trace_doc.py --write         # 落盘
  python3 test_perf/tools/gen/gen_rtl_trace_doc.py --version ver1_1 --write
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
OPS = (("keygen", "keypair"), ("encap", "encap"), ("decap", "decap"))
TITLE = {"ver0_1": "ver0_1（软件 Keccak）", "ver0_2": "ver0_2（KMAC 硬件哈希）",
         "ver1_1": "ver1_1（官方向量指令 + KMAC）"}
MIN_PCT = 0.10          # 表里逐函数列出 ≥ 该占比的行，其余合并成一行（汇总仍闭合）


def load(v: str):
    """读一个版本的 3 份 rtl_trace JSON + ISS JSON；缺任何一份就返回 None（不静默少写）。"""
    out = {}
    for op, name in OPS:
        p = REPO / f"logs_hkem/{v}/rtl/rtl_trace_{op}.json"
        if not p.exists():
            return None
        out[op] = json.loads(p.read_text(encoding="utf-8"))
    jp = REPO / f"logs_hkem/{v}_profiling/re_{v}.json"
    if not jp.exists():
        return None
    out["iss"] = json.loads(jp.read_text(encoding="utf-8"))
    return out


def op_table(v, op, d, exec_iss):
    """一个 op 的逐函数表（含 ISS 对照列）。返回 markdown 行列表。"""
    sc = d["self_check"]
    span = sc["span"]
    L = [f"| 函数 | **拍（含被调）** | 占 app | 自身拍 | 退役 | 停滞 | 取指等待 | ISS 同函数退役 | Δ退役 |",
         "|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    def _inc(s):
        return s.get("inclusive", s["cycles"])
    ranked = sorted(d["symbols"], key=lambda s: -_inc(s))
    rest = [0, 0, 0, 0, 0]      # name/retire/stall/gap/cycles 的"其余"累计
    for s in ranked:
        if 100 * _inc(s) / span < MIN_PCT:
            rest[1] += s["retire"]
            rest[2] += s["stall"]
            rest[3] += s.get("fetch_wait", 0)
            rest[4] += s["cycles"]
            rest[0] += 1
            continue
        ei = exec_iss.get(s["name"])
        ic = _inc(s)
        L.append(f"| `{s['name']}` | **{ic:,}** | {100 * ic / span:.2f}% | {s['cycles']:,} | "
                 f"{s['retire']:,} | {s['stall']:,} | {s.get('fetch_wait', 0):,} | "
                 + (f"{ei:,}" if ei is not None else "—")
                 + (f" | {s['retire'] - ei:+,} |" if ei is not None else " | — |"))
    if rest[0]:
        L.append(f"| *其余 {rest[0]} 个函数* | — | — | {rest[4]:,} | {rest[1]:,} | {rest[2]:,} | "
                 f"{rest[3]:,} | — | — |")
    L += [f"| **自身拍合计（= 整段跨度）** | — | **100.00%** | **{span:,}** | {sc['sum_E']:,} | "
          f"{sc['sum_S']:,} | {span - sc['sum_E'] - sc['sum_S']:,} | — | — |", ""]
    return L


def frag(v, data) -> str:
    iss = data["iss"]["apps"][v]
    L = [f"## RTL 实测（逐函数真实周期数）· {v}", "",
         f"> 方法 A：同一份 app 在 **RTL**（Earlgrey chip sim，OTBN 连真 KMAC）上跑，按 OTBN 指令级 "
         f"trace 的 PC 逐拍归因。",
         f"> 口径：**含被调拍 = 从进入函数到离开函数的整段（图上 C2 − C1，含它调用的子函数）**；"
         f"**自身拍 = 退役 + 停滞 + 取指等待**（取指等待摊给上一条记录所在函数，同 ISS "
         f"`has_fetch_stall`）⇒ 自身拍逐函数之和 == 整段跨度（100% 归属）。",
         f"> ⚠ 含被调列**不能相加**（被调会被重复计入）；要「加起来等于整段」用自身拍列。",
         f"> 与上面 ISS 表的差是**信息**不是错误：KMAC 版 ISS 的 KMAC 时序是粗粒度模型，轮询圈数与 "
         f"RTL 不同 —— 差落在哪个函数看 `Δ退役` 列（下表的 ISS 列来自 `re_{v}.json`）。", ""]
    for op, name in OPS:
        d = data[op]
        sc = d["self_check"]
        a = iss[op]
        exec_iss = a.get("exec_insn") or {}
        L += [f"### {op}（整段 {sc['span']:,} 拍；ISS macro {a['cycles']:,} 拍，差 "
              f"{100 * (sc['span'] - a['cycles']) / a['cycles']:+.2f}%）", "",
              f"> 自证：Σ`E` {sc['sum_E']:,} == chip `INSN_CNT` {sc.get('chip_insn') or 0:,} "
              f"{'✓' if sc['ok_complete'] else '✗'}；逐函数拍数之和 == 跨度 "
              f"{'✓' if sc['ok_span'] else '✗'}；RTL−ISS 指令数 {sc['d_insn']:+,}、"
              f"停滞（`S`+取指等待−ISS stalls）{sc['d_stall']:+,}。", ""]
        L += op_table(v, op, d, exec_iss)
    return "\n".join(L)


def cross_doc(rows) -> str:
    L = ["# RTL 实测 · 三版逐函数对照（方法 A）", "",
         "> 数据来源：`logs_hkem/<版本>/rtl/rtl_trace_{keygen,encap,decap}.json`"
         "（由 `test_perf/tools/diag/rtl_trace_attr.py` 从 RTL trace 生成）。",
         "> 口径：表中数字是 **含被调拍**（从进入函数到离开函数的整段，图上 `C2 − C1`）；"
         "「自身拍」= 退役 + 停滞 + 取指等待，逐函数相加 == 整段跨度。", ""]
    for op, _name in OPS:
        byv = {}
        for v, data in rows.items():
            byv[v] = {s["name"]: s for s in data[op]["symbols"]}
        names = sorted(set().union(*[set(m) for m in byv.values()]),
                       key=lambda n: -sum(m.get(n, {}).get("inclusive", m.get(n, {}).get("cycles", 0))
                                          for m in byv.values()))
        L += [f"## {op}", "",
              "| 函数 | " + " | ".join(f"{TITLE[v]} 拍" for v in rows) + " |",
              "|---|" + "---:|" * len(rows)]
        for n in names[:25]:
            L.append(f"| `{n}` | " + " | ".join(
                (f"{byv[v][n].get('inclusive', byv[v][n]['cycles']):,}" if n in byv[v] else "—")
                for v in rows) + " |")
        if len(names) > 25:
            L.append(f"| *其余 {len(names) - 25} 个函数（自身拍合计）* | " + " | ".join(
                f"{sum(s['cycles'] for s in byv[v].values() if s['name'] not in names[:25]):,}"
                for v in rows) + " |")
        L.append("")
    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--version", action="append")
    args = ap.parse_args()
    rows, missing = {}, []
    for v in (args.version or list(VERS)):
        d = load(v)
        if d is None:
            missing.append(v)
            print(f"  ✗ {v}: 缺 logs_hkem/{v}/rtl/rtl_trace_*.json（先跑 rtl_trace_attr.py）")
            continue
        rows[v] = d
        ok = all(d[op]["self_check"]["ok_complete"] and d[op]["self_check"]["ok_span"] for op, _ in OPS)
        print(f"  {'✓' if ok else '✗'} {v}: 自证 {'全过' if ok else '**未过**'}；"
              + "  ".join(f"{op} 跨度 {d[op]['self_check']['span']:,}"
                          + f"（ISS {d['iss']['apps'][v][op]['cycles']:,}，"
                          + f"RTL−ISS 指令 {d[op]['self_check']['d_insn']:+,}）" for op, _ in OPS))
    if not rows:
        print("\n没有可生成的数据 ⇒ 未做任何事。")
        return 1
    if not args.write:
        print("\n（干跑：未写文件。确认无误后加 --write）")
        return 0
    for v, d in rows.items():
        p = REPO / f"logs_hkem/{v}/rtl/RTL实测_{v}.md"
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(frag(v, d) + "\n", encoding="utf-8")
        print(f"  [写] {p.relative_to(REPO)}")
    # 三版对照同样落在 logs_hkem/ 下（该目录不进 git）；分解表用 --extra 直接引这些路径即可。
    out = REPO / "logs_hkem/RTL实测_三版对照.md"
    out.write_text(cross_doc(rows) + "\n", encoding="utf-8")
    print(f"  [写] {out.relative_to(REPO)}")
    if missing:
        print(f"  ⚠ 未生成：{', '.join(missing)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
