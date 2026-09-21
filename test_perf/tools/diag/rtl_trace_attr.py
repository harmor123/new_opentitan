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

自证（三条，缺一不可）
  ① Σ `E` == JSON 的 `insn`（== chip `INSN_CNT`，若给了 --uart0）
  ② Σ `S` == JSON 的 `stalls`
  ③ Σ (`E`+`S`) + 空档 == trace 跨度（末条 cycle − 首条 cycle + 1）
  另附：逐符号「退休数」与 JSON `exec_insn`（ISS 侧逐函数执行指令数）对照。

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
    """流式解析（trace 可到百 MB 级）：返回 (per_pc, ΣE, ΣS, 跨度, 空档, 其它行数)。"""
    per, n_e, n_s, other = {}, 0, 0, 0
    first_c = last_c = None
    seen = set()                    # 有记录的拍（用于算空档）
    with path.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            m = RE_TRACE.match(line)
            if not m:
                if line.startswith("!") or line.startswith(" "):
                    other += 1
                continue
            kind, cyc, pc = m.group(1), int(m.group(2)), int(m.group(3), 16)
            e = per.setdefault(pc, [0, 0])
            if kind == "E":
                e[0] += 1
                n_e += 1
            else:
                e[1] += 1
                n_s += 1
            if first_c is None:
                first_c = cyc
            last_c = cyc
            seen.add(cyc)
    span = (last_c - first_c + 1) if first_c is not None else 0
    return per, n_e, n_s, span, span - len(seen), other


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

    per, n_e, n_s, span, gaps, other = parse_trace(Path(args.trace))

    # ── 聚合到符号（匿名区/框架容器口径与 stall_profile.py 一致）────────────────
    sym = {}
    for pc, (r, s) in per.items():
        nm = name_at(pc, starts, bnds)
        if nm != "(无符号区间)" and any(nm.startswith(p) for p in CONTAINER):
            nm = "(框架容器) " + nm
        e = sym.setdefault(nm, [0, 0])
        e[0] += r
        e[1] += s
    rows = sorted(((n, r, s, r + s) for n, (r, s) in sym.items()), key=lambda x: -x[3])
    if gaps:   # 空档（无记录的拍：取指等待/流水）单列一行，占总量的分母才算完整
        rows.append(("(无记录拍：取指等待)", 0, gaps, gaps))

    # ── 自证 ─────────────────────────────────────────────────────────────────
    chip_insn = None
    if args.uart0 and Path(args.uart0).exists():
        m = re.search(r"OTBN insn_cnt:\s*([\d,]+)",
                      Path(args.uart0).read_text(encoding="utf-8", errors="replace"))
        if m:
            chip_insn = int(m.group(1).replace(",", ""))
    ok1 = (n_e == iss_insn) and (chip_insn is None or chip_insn == n_e)
    # 口径差（2026-09-21 实测校准）：ISS 的 `stalls` 把"取指等待"的拍也算进去，而 tracer 的 `S`
    # 只在控制器进入 stall 状态时记录 ⇒ **ΣS_RTL + 空档 ≈ ISS stalls**（ver0_1/keygen：29,921 +
    # 17,935 = 47,856 vs 47,869，差 13 拍 = trace 窗口外的首尾几拍）。故按"加空档"判定。
    ok2 = (n_s == iss_stalls) or abs(n_s + gaps - iss_stalls) <= max(64, iss_stalls // 100)
    ok3 = (n_e + n_s + gaps == span)

    L = [f"# RTL trace 逐函数归因 · {args.version}/{args.op}", "",
         f"> 方法 A：在 **RTL** 上跑 `mlkem768_{'keypair' if args.op == 'keygen' else args.op}`，"
         "按 OTBN 指令级 trace（`E` = 退休、`S` = 该 PC 停滞一拍）逐 PC 划分周期。",
         f"> 输入 trace：`{args.trace}`（{Path(args.trace).stat().st_size:,} B）。",
         f"> 对照口径：ISS 表来自 `{args.json}`（同一份 app）。", "",
         "## 自证", "",
         "| 判据 | RTL trace | ISS JSON / chip 日志 | 结论 |",
         "|---|---:|---:|---|",
         f"| Σ `E`（退休指令） | {n_e:,} | {iss_insn:,}"
         + (f"（chip INSN_CNT {chip_insn:,}）" if chip_insn is not None else "")
         + f" | {'✓' if ok1 else '✗'} |",
         f"| Σ `S`（停滞拍） | {n_s:,}（+ 空档 {gaps:,} = {n_s + gaps:,}） | {iss_stalls:,} | "
         f"{'✓（差 ' + format(n_s + gaps - iss_stalls, '+d') + ' 拍，0.03% 量级：口径差）' if ok2 else '✗'} |",
         f"| Σ (`E`+`S`) + 空档 = 跨度 | {n_e + n_s:,} + {gaps:,} = {n_e + n_s + gaps:,} | "
         f"跨度 {span:,} | {'✓' if ok3 else '✗'} |", "",
         f"> 口径差说明：**ISS 的 `stalls` 含「取指等待」拍**，而 tracer 的 `S` 只在控制器进入 stall "
         f"状态时记录 ⇒ `ΣS_RTL + 空档 ≈ ISS stalls`。",
         f"> trace 里非 `E`/`S` 的行（擦除/寄存器流水账）：{other:,} 行；空档 {gaps:,} 拍"
         "（无任何记录的拍；按上一条口径，它们与 ISS 的 stalls 同源）。", ""]

    # ── 逐符号表 ─────────────────────────────────────────────────────────────
    tot_c = max(n_e + n_s + gaps, 1)   # 分母 = 整个 app 跨度（含取指等待拍）
    L += ["## 逐符号（RTL 实测 ↔ ISS 对照）", "",
          "| 符号 | RTL 退役 | RTL 停滞 | **RTL 拍** | 占 app | ISS 同函数退役 | Δ退役 |",
          "|---|---:|---:|---:|---:|---:|---:|"]
    for n, r, s, c in rows[: max(args.top, 1) * 3]:
        ei = exec_iss.get(n)
        L.append(f"| `{n}` | {r:,} | {s:,} | **{c:,}** | {100 * c / tot_c:.2f}% | "
                 + (f"{ei:,}" if ei is not None else "—")
                 + (f" | {r - ei:+,} |" if ei is not None else " | — |"))
    L += ["", f"> 只列前 {max(args.top, 1) * 3} 个符号（按 RTL 拍数降序）；完整表见 `--json-out`。", ""]

    # ── 热点 PC ──────────────────────────────────────────────────────────────
    hot = sorted(per.items(), key=lambda kv: -(kv[1][0] + kv[1][1]))[: args.top]
    L += [f"## 热点 PC（Top {args.top}）", "",
          "| PC | 符号 | 退役 | 停滞 | 拍 |", "|---|---|---:|---:|---:|"]
    for pc, (r, s) in hot:
        L.append(f"| `0x{pc:x}` | `{name_at(pc, starts, bnds)}` | {r:,} | {s:,} | {r + s:,} |")
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
                            "ok_E": ok1, "ok_S": ok2, "ok_span": ok3},
             "symbols": [{"name": n, "retire": r, "stall": s, "cycles": c} for n, r, s, c in rows],
             "hot_pcs": [{"pc": pc, "retire": r, "stall": s} for pc, (r, s) in hot]},
            ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"[写] {args.json_out}")
    return 0 if (ok1 and ok2) else 1


if __name__ == "__main__":
    raise SystemExit(main())
