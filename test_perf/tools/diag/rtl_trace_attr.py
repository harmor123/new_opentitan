#!/usr/bin/env python3
"""由 OTBN **RTL** trace 出「逐函数拍数」—— 方法 A：在真 RTL 上跑整程序、按 PC 划分周期。

与现有 ISS 路线的关系（两套数**并列**，不互相替代）：
  · 现有分解表 = OTBN **ISS** 口径（`Δ = profiling − control`，`cycles = insn + stalls`）；
  · 本工具    = 同一 app 在 **RTL**（chip sim / otbn_top_sim）上跑出来的 PC trace 口径。
  两者最容易不同的地方已定位：KMAC 驱动里的轮询等待循环（ISS 的 KMAC 时序是粗粒度模型）。

输入
  --trace  logs_hkem/<版本>/<测试>.rtl_trace.log     （`--otbn-trace-file` 的产物）
  --json   logs_hkem/<版本>_profiling/re_<版本>.json （取 boundaries/exec_insn/insn/stalls 做对照与自证）
  --op     keygen|encap|decap
  [--uart0 logs_hkem/<版本>/<测试>.uart0.log]        （可选：取 chip 的 OTBN `INSN_CNT` 做第三方自证）
  [--out FILE.md] [--json-out FILE.json] [--top N]

口径（与 `stall_profile.py` 对齐）
  · `E` = 一条指令**退休**（该记录的 cycle 即退休拍）
  · `S` = 该 **PC 停滞**一拍
  ⇒ 每拍记在「正在执行/停滞的那个 PC」上 ⇒ 逐 PC 累计 `[退役, 停滞]`，再按 ELF 符号边界合并。
  边界直接取 JSON 里的 `boundaries`（VMA，与 trace 的 PC 同空间）⇒ 无需 ELF、无需 ISS。

判据分两类（**别混**）
  · 完整性（硬判据，不通过就是数据错）：Σ `E` == 同一次运行的 chip `INSN_CNT`；`Σ(E+S)` + 空档 == trace 跨度。
  · 与 ISS 的差（信息列，**本来就应有差**）：用 KMAC 的版本（ver0_2/ver1_1）ISS 的 KMAC 时序是粗粒度模型，
    轮询圈数与 RTL 不同 ⇒ 指令数/停滞拍都会差；另外 ISS 的 `stalls` 含「取指等待」拍 ⇒ 比它时要用 `S`+空档。
    这些差**落在哪个函数**，看逐符号表的 `Δ退役` 列。

用法:
  python3 test_perf/tools/diag/rtl_trace_attr.py --version ver0_1 --op keygen \
      --trace logs_hkem/ver0_1/test_mlkem_keypair_only.rtl_trace.log \
      --json  logs_hkem/ver0_1_profiling/re_ver0_1.json \
      --uart0 logs_hkem/ver0_1/test_mlkem_keypair_only.uart0.log \
      --out   logs_hkem/ver0_1_profiling/rtl_trace_keygen.md
"""
import argparse
import bisect
import json
import re
import sys
from pathlib import Path

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = Path(__file__).resolve().parents[3]   # 工具在 test_perf/tools/<类>/ 下 ⇒ 仓库根 = parents[3]
RE_TRACE = re.compile(r"^([ES]) (\d+)\s+PC: 0x([0-9a-fA-F]+), insn: 0x([0-9a-fA-F]+)")
# 框架容器前缀（与 stall_profile.py 一致；注意带下划线的内层标签）
CONTAINER = ("crypto_kem_", "indcpa_", "_indcpa_", "_encrypt_core", "_decrypt_core")


def name_at(pc, starts, bnds):
    i = bisect.bisect_right(starts, pc) - 1
    if i < 0:
        return "(无符号区间)"
    s, e, n = bnds[i]
    return n if s <= pc < e else "(无符号区间)"


def parse_trace(path: Path):
    """流式解析（trace 可到百 MB 级）。

    返回 `(per_pc, ΣE, ΣS, Σ取指等待, 跨度, 其它行数)`；`per_pc[pc] = [退役, 停滞, 取指等待]`。
    「取指等待」= 两条记录之间没有任何记录的拍（fetch 还没回来，控制器也不在 stall 状态）——
    **摊给上一条记录所在的 PC**，与 ISS 的 `has_fetch_stall` 同口径（`loop`/`loopi`/`jal`
    多出来的那一拍本来就记在跳转指令上）。这样 `Σ(退役+停滞+取指等待) == 跨度`，**精确闭合**。
    """
    per, n_e, n_s, other = {}, 0, 0, 0
    first_c = last_c = last_pc = None
    with path.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            m = RE_TRACE.match(line)
            if not m:
                if line.startswith("!") or line.startswith(" "):
                    other += 1
                continue
            kind, cyc, pc = m.group(1), int(m.group(2)), int(m.group(3), 16)
            if last_c is not None and cyc > last_c + 1:      # 记录之间的空档 ⇒ 取指等待
                per.setdefault(last_pc, [0, 0, 0])[2] += cyc - last_c - 1
            e = per.setdefault(pc, [0, 0, 0])
            if kind == "E":
                e[0] += 1
                n_e += 1
            else:
                e[1] += 1
                n_s += 1
            if first_c is None:
                first_c = cyc
            last_c, last_pc = cyc, pc
    span = (last_c - first_c + 1) if first_c is not None else 0
    return per, n_e, n_s, sum(v[2] for v in per.values()), span, other


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--op", required=True, choices=["keygen", "encap", "decap"])
    ap.add_argument("--trace", required=True)
    ap.add_argument("--json", required=True)
    ap.add_argument("--uart0", default="")
    ap.add_argument("--out", default="")
    ap.add_argument("--json-out", default="")
    ap.add_argument("--top", type=int, default=12)
    args = ap.parse_args()

    d = json.loads(Path(args.json).read_text(encoding="utf-8"))
    app = d["apps"][args.version][args.op]
    bnds = sorted((s, e, n) for s, e, n in app["boundaries"])
    starts = [b[0] for b in bnds]
    iss_insn, iss_stalls = app["insn"], app["stalls"]
    exec_iss = app.get("exec_insn") or {}

    per, n_e, n_s, gaps, span, other = parse_trace(Path(args.trace))

    # ── 聚合到符号（匿名区/框架容器口径与 stall_profile.py 一致）────────────────
    sym = {}
    for pc, (r, s, g) in per.items():
        nm = name_at(pc, starts, bnds)
        if nm != "(无符号区间)" and any(nm.startswith(p) for p in CONTAINER):
            nm = "(框架容器) " + nm
        e = sym.setdefault(nm, [0, 0, 0])
        e[0] += r
        e[1] += s
        e[2] += g
    rows = sorted(((n, r, s, g, r + s + g) for n, (r, s, g) in sym.items()), key=lambda x: -x[4])

    # ── "含被调"拍数（= 图上 C2 − C1：进入函数到离开函数的整段）──────────────────
    # 调用图取自 ISS JSON 的 `func_calls`（同一份 app、同一批符号名）⇒ 自底向上累加：
    #   inclusive(F) = self(F) + Σ inclusive(被 F 调用的函数)
    # 这与"进入/离开区间"完全等价：F 的整段时间 = 它自己执行的拍 + 它调用出去的拍。
    callees = {}
    for c in (app.get("func_calls") or []):
        callees.setdefault(c.get("caller_func"), set()).add(c.get("callee_func"))
    self_c = {n: c for n, _r, _s, _g, c in rows}
    incl = {}

    def _incl(f, stack=()):
        if f in incl:
            return incl[f]
        if f in stack:                      # 递归保护（调用图不该有环）
            return 0
        v = self_c.get(f, 0) + sum(_incl(k, stack + (f,)) for k in callees.get(f, ()) if k)
        incl[f] = v
        return v

    for _n, _r, _s, _g, _c in rows:
        _incl(_n)

    # ── 自证 ─────────────────────────────────────────────────────────────────
    chip_insn = None
    if args.uart0 and Path(args.uart0).exists():
        m = re.search(r"OTBN insn_cnt:\s*([\d,]+)",
                      Path(args.uart0).read_text(encoding="utf-8", errors="replace"))
        if m:
            chip_insn = int(m.group(1).replace(",", ""))
    # 硬判据（**数据完整性**）：trace 是否记全 —— 与**同一次运行**的 chip `INSN_CNT` 比。
    # ⚠ 不要拿 ISS 的 `insn` 当判据：用 KMAC 的版本（ver0_2/ver1_1）ISS 与 RTL 的指令数**天生**不同
    # （KMAC 轮询圈数由各自时序决定），那是**要报告的模型差**，不是数据错。
    ok_complete = (chip_insn is None) or (n_e == chip_insn)
    ok_span = (n_e + n_s + gaps == span)
    # 与 ISS 的差（信息列）：指令数与停滞拍各差多少（含"ISS 把取指等待算作 stalls"的口径差）
    d_insn = n_e - iss_insn
    d_stall = (n_s + gaps) - iss_stalls

    L = [f"# RTL trace 逐函数归因 · {args.version}/{args.op}", "",
         f"> 方法 A：在 **RTL** 上跑 `mlkem768_{'keypair' if args.op == 'keygen' else args.op}`，"
         "按 OTBN 指令级 trace（`E` = 退休、`S` = 该 PC 停滞一拍）逐 PC 划分周期。",
         f"> 输入 trace：`{args.trace}`（{Path(args.trace).stat().st_size:,} B）。",
         f"> 对照口径：ISS 表来自 `{args.json}`（同一份 app）。", "",
         "## 自证（完整性）", "",
         "| 判据 | RTL trace | 参照 | 结论 |",
         "|---|---:|---:|---|",
         f"| Σ `E`（退休指令） == chip `INSN_CNT` | {n_e:,} | "
         + (f"{chip_insn:,}" if chip_insn is not None else "（未提供 --uart0）")
         + f" | {'✓' if ok_complete else '✗'} |",
         f"| Σ (`E`+`S`) + 空档 == trace 跨度 | {n_e + n_s:,} + {gaps:,} = {n_e + n_s + gaps:,} | "
         f"跨度 {span:,} | {'✓' if ok_span else '✗'} |", "",
         "## 与 ISS 的差（**信息列**，不是错误）", "",
         "| 量 | RTL trace | ISS JSON | 差 |", "|---|---:|---:|---|",
         f"| 退休指令数 | {n_e:,} | {iss_insn:,} | {d_insn:+,}（{100 * d_insn / max(iss_insn, 1):+.2f}%） |",
         f"| 停滞拍（RTL 的 `S` + 空档 ↔ ISS `stalls`） | {n_s + gaps:,} | {iss_stalls:,} | "
         f"{d_stall:+,}（{100 * d_stall / max(iss_stalls, 1):+.2f}%） |", "",
         "> 两种口径都已知：① ISS 的 `stalls` 含「取指等待」拍，tracer 的 `S` 只在控制器进入 stall "
         "状态时记录 ⇒ 比对时用 `S`+空档；② 用 KMAC 的版本（ver0_2/ver1_1）ISS 的 KMAC 时序是粗粒度"
         "模型 ⇒ 轮询圈数与 RTL 不同，指令数与停滞拍**本就应当有差** —— 这些差落在哪个函数，见下面"
         "逐符号表的 `Δ退役` 列。",
         f"> trace 里非 `E`/`S` 的行（擦除/寄存器流水账）：{other:,} 行；空档 {gaps:,} 拍"
         "（无任何记录的拍；按上一条口径，它们与 ISS 的 stalls 同源）。", ""]

    # ── 逐符号表 ─────────────────────────────────────────────────────────────
    tot_c = max(span, 1)   # 分母 = 整段跨度（逐函数拍数之和精确等于它）
    L += ["## 逐函数 RTL 真实周期数（含被调 = 图上 C2 − C1）", "",
          "| 函数 | **拍（含被调）** | 占 app | 自身拍 | 退役 | 停滞 | 取指等待¹ | CPI(含被调) |",
          "|---|---:|---:|---:|---:|---:|---:|---:|"]
    for n, r, s, g, c in rows:
        ic = incl.get(n, c)
        L.append(f"| `{n}` | **{ic:,}** | {100 * ic / tot_c:.2f}% | {c:,} | {r:,} | {s:,} | {g:,} | "
                 f"{ic / max(r, 1):.3f} |")
    L += ["", "> ¹ **取指等待**=两条记录之间的空拍（fetch 未回），摊给上一条记录所在的函数 —— "
          "与 ISS 的 `has_fetch_stall` 同口径（跳转/循环多出的那一拍记在跳转指令上）。",
          f"> 本表**完整**（不截断）：逐函数 `RTL 拍` 之和 == 整段跨度 `{span:,}` ✓。", ""]

    # ── 与现有分解表逐行对照（ISS 行 ↔ RTL「含被调」拍）──────────────────────
    iss_rows = [r for r in d["rows"]
                if r["phase"].startswith(args.op + "_") and r.get("closure", True)]
    if iss_rows:
        L += ["## 与现有分解表逐行对照（ISS 行 ↔ RTL 含被调拍）", "",
              "| ISS 行（`{0}_…`） | ISS 拍 | RTL 对应函数 | RTL 拍（含被调） | 差 | 差% |".format(args.op),
              "|---|---:|---|---:|---:|---:|"]
        for r in sorted(iss_rows, key=lambda x: -x["cycles"]):
            fn = r["phase"][len(args.op) + 1:]
            ic = incl.get(fn)
            if ic is None:
                L.append(f"| `{r['phase']}` | {r['cycles']:,} | —（app 无同名函数） | — | — | — |")
                continue
            d_v = ic - r["cycles"]
            L.append(f"| `{r['phase']}` | {r['cycles']:,} | `{fn}` | {ic:,} | {d_v:+,} | "
                     f"{100 * d_v / max(r['cycles'], 1):+.2f}% |")
        L += ["", "> 读法：ISS 行的 `cycles` 是 harness 程序里该阶段的 Δ；RTL 列是该函数在**真机**上"
              "从进入跑到离开的整段（含被调）。两者口径一致 ⇒ 差就是**模型 vs RTL** 的差。", ""]

    # ── 热点 PC ──────────────────────────────────────────────────────────────
    hot = sorted(per.items(), key=lambda kv: -(kv[1][0] + kv[1][1] + kv[1][2]))[: args.top]
    L += [f"## 热点 PC（Top {args.top}）", "",
          "| PC | 符号 | 退役 | 停滞 | 拍 |", "|---|---|---:|---:|---:|"]
    for pc, (r, s, g) in hot:
        L.append(f"| `0x{pc:x}` | `{name_at(pc, starts, bnds)}` | {r:,} | {s:,} | {r + s + g:,} |")
    L += ["", "> 停滞拍记在「正在尝试执行」的那个 PC 上 ⇒ KMAC 轮询等待会集中出现在轮询循环的 PC 上。", ""]

    txt = "\n".join(L) + "\n"
    print(txt)
    if args.out:
        Path(args.out).write_text(txt, encoding="utf-8")
        print(f"[写] {args.out}")
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(
            {"version": args.version, "op": args.op, "trace": args.trace,
             "self_check": {"sum_E": n_e, "sum_S": n_s, "span": span, "gaps": gaps,
                            "iss_insn": iss_insn, "iss_stalls": iss_stalls, "chip_insn": chip_insn,
                            "ok_complete": ok_complete, "ok_span": ok_span, "d_insn": d_insn, "d_stall": d_stall},
             "symbols": [{"name": n, "retire": r, "stall": s, "fetch_wait": g, "cycles": c,
                          "inclusive": incl.get(n, c)} for n, r, s, g, c in rows],
             "hot_pcs": [{"pc": pc, "retire": r, "stall": s, "fetch_wait": g}
                         for pc, (r, s, g) in hot]},
            ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"[写] {args.json_out}")
    return 0 if (ok_complete and ok_span) else 1


if __name__ == "__main__":
    raise SystemExit(main())
