#!/usr/bin/env python3
"""由 OTBN **RTL** trace 出「逐函数真实周期数」—— 方法 A：在真 RTL 上跑整程序、按 PC 归因。

两个口径（都来自 trace 实测，不做任何"推"）：
  · **自身拍**（self）  = 退役 + 停滞 + 取指等待 —— 每拍记在"正在执行/停滞的那个 PC"上，
                        取指等待摊给上一条记录所在函数（同 ISS `has_fetch_stall`）；
                        逐函数相加 **精确等于整段跨度**（100% 归属）。
  · **含被调拍**（incl）= 帧跨度 `[C1, C2)`：**C1** = 被调函数第一条记录的拍；**C2** = **调用方恢复
                        执行的那一拍**（该帧不再活跃的第一拍）⇒ 帧跨度 = C2 − C1。
                        **逐条指令解码**（ISS 自带 ISA 表）：`jal`/`jalr(rd=x1)` 压栈、
                        `ret`（`jalr x0, x1, 0`）出栈 ⇒ 每帧的 C1/C2 都是 trace 里读出来的，不摊派。
                        叶函数 ⇒ **含被调 == 自身拍**；父函数 ⇒ 自身拍 + 帧内兄弟标签 + Σ直接被调含被调。
                        帧之间会重复（被调会被父帧包含）⇒ **不能相加**（要"相加等于整段"用自身拍列）。

输入
  --trace  logs_hkem/<版本>/rtl/<测试>.rtl_trace.log   （`--otbn-trace-file` 的产物）
  --json   logs_hkem/<版本>_profiling/re_<版本>.json    （boundaries / exec_insn / insn / stalls）
  --op     keygen|encap|decap
  [--uart0 logs_hkem/<版本>/rtl/<测试>.uart0.log]       （取 chip `INSN_CNT` 做完整性判据）
  [--out FILE.md] [--json-out FILE.json] [--top N]

判据（硬判据，不通过就是数据错）
  · Σ`E` == 同一次运行的 chip `INSN_CNT`；Σ(`E`+`S`) + 空档 == trace 跨度。
  · **帧跨度 == 帧内记入拍**（逐符号全等）：前者由"开帧/关帧事件"算出，后者由"每一拍记给最内层帧"
    算出 ⇒ 两条独立算路必须相等。这是「含被调」列的正确性判据，同时保证 含被调 ≥ 自身拍。
  · 与 ISS 的差（信息列，**本就应有差**）：用 KMAC 的版本（ver0_2/ver1_1）ISS 的 KMAC 时序是粗粒度
    模型，轮询圈数与 RTL 不同；另外 ISS 的 `stalls` 含「取指等待」拍 ⇒ 比它时要用 `S`+空档。

用法:
  python3 test_perf/tools/diag/rtl_trace_attr.py --version ver0_1 --op keygen \
      --trace logs_hkem/ver0_1/rtl/test_mlkem_keypair_only.rtl_trace.log \
      --json  logs_hkem/ver0_1_profiling/re_ver0_1.json \
      --uart0 logs_hkem/ver0_1/test_mlkem_keypair_only.uart0.log \
      --out   logs_hkem/ver0_1/rtl/rtl_trace_keygen.md
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


def _flow_kind(word: int) -> str:
    """调用/返回识别 ⇒ `'call' | 'ret' | 'other'`。

    用 **ISS 自带的 ISA 解码器**（`hw/ip/otbn/dv/otbnsim/sim/decode.py`，与 ISS 同一份指令表，
    不是猜编码）：`jal`/`jalr` 且 rd=x1 ⇒ call；`jalr x0, x1, 0` ⇒ ret。同一指令字只解一次。
    """
    k = _FLOW_CACHE.get(word)
    if k is not None:
        return k
    k = "other"
    try:
        from sim.decode import decode_words          # 延迟 import（只在本函数里用）
        insns = decode_words(0, [(True, word)])
        if insns:
            i = insns[0]
            nm = type(i).__name__
            if nm == "JAL":
                k = "call" if getattr(i, "grd", 0) == 1 else "other"
            elif nm == "JALR":
                grd, grs1 = getattr(i, "grd", None), getattr(i, "grs1", None)
                k = "ret" if (grd == 0 and grs1 == 1) else ("call" if grd == 1 else "other")
    except Exception:
        k = "other"
    _FLOW_CACHE[word] = k
    return k


sys.path.insert(0, str(REPO / "hw/ip/otbn/dv/otbnsim"))
_FLOW_CACHE = {}


def name_at(pc, starts, bnds):
    i = bisect.bisect_right(starts, pc) - 1
    if i < 0:
        return "(无符号区间)"
    s, e, n = bnds[i]
    return n if s <= pc < e else "(无符号区间)"


def parse_trace(path: Path):
    """流式解析（trace 可到百 MB 级）。

    返回 `(per_pc, ΣE, ΣS, Σ取指等待, 跨度, 其它行数, frames, credit_pc, n_unclosed)`：
      · `per_pc[pc] = [退役, 停滞, 取指等待]`（自身拍口径，逐函数相加 == 跨度）
      · `frames = [(进入 PC, 进入拍, 离开拍), ...]` —— 调用栈实测的**帧跨度**：
        **进入拍 C1** = 被调函数第一条记录的 cycle；**离开拍 C2** = **调用方恢复执行的那条记录的
        cycle**（= 该帧不再活跃的第一拍）⇒ 帧跨度 = C2 − C1，即半开区间 `[C1, C2)`。
        （图上「进入 → C1；离开 → C2」的正确读法；**不是**取 ret 自己那一拍 —— 那样每帧会少算
        「返回指令 + 返回后取指气泡」1–3 拍，且会出现"含被调 < 自身拍"的假象。）
      · `credit_pc[entry_pc]` = 该帧**在栈上期间自己记入的拍**（每条记录 1 拍 + 其后空档，只记给最内层帧）
        ⇒ 它 + Σ**直接被调帧**的跨度 == 本帧跨度（帧内每一拍恰好归属一处）—— 这是硬判据③，
        逐帧在关帧时核对，不通过就记进 `bad_frames`。
      · `n_unclosed` = 结束时仍在栈上的帧数（顶层未闭合，不计入含被调；其记入拍也不参与判据）。
    """
    per, n_e, n_s, other = {}, 0, 0, 0
    first_c = last_c = last_pc = None
    # stack 项 = [进入 PC, 进入拍, 帧内自己记入的拍, 已闭合的被调帧跨度合计]
    stack, frames, bad_frames, credit_pc = [], [], [], {}
    pending_call, pending_ret = False, False
    with path.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            m = RE_TRACE.match(line)
            if not m:
                if line.startswith("!") or line.startswith(" "):
                    other += 1
                continue
            kind, cyc, pc, word = (m.group(1), int(m.group(2)), int(m.group(3), 16),
                                   int(m.group(4), 16))
            # ① 上一条记录之后的空档（fetch 未回）= 取指等待：记给**上一条记录**的 PC，同时记进
            #    当时最内层的帧（此刻尚未做本条的入/出栈 ⇒ ret 之后的空档算在「正在返回的那一帧」里）。
            if last_c is not None and cyc > last_c + 1:
                per.setdefault(last_pc, [0, 0, 0])[2] += cyc - last_c - 1
                if stack:
                    stack[-1][2] += cyc - last_c - 1
            # ② 上一拍是 ret ⇒ 本记录就是调用方恢复执行的那一拍：在这里关帧（离开拍 = 本记录 cycle）。
            if pending_ret:
                entry_pc, c0, cr, kids = stack.pop()
                sp = cyc - c0                    # 帧跨度 = 离开拍 − 进入拍
                if sp != cr + kids:              # 硬判据③（逐帧）：帧跨度 == 自己记入的拍 + Σ被调帧跨度
                    bad_frames.append((entry_pc, c0, cyc, sp, cr, kids))
                frames.append((entry_pc, c0, cyc))
                credit_pc[entry_pc] = credit_pc.get(entry_pc, 0) + cr
                if stack:
                    stack[-1][3] += sp           # 计入父帧的「被调帧跨度合计」
                pending_ret = False
            # ③ 上一拍是 call ⇒ 本记录是被调函数第一条指令：在这里开帧（进入拍 = 本记录 cycle）。
            #    ⚠ 必须先处理 pending_call：被调函数的第一条指令本身可能就是调用（递归），
            #    顺序反了会漏帧（2026-09-21 写错过一次）。
            if pending_call:
                stack.append([pc, cyc, 0, 0])
                pending_call = False
            # ④ 本记录自己的 1 拍：记给此刻最内层的帧（帧外则不计入任何帧）。
            if stack:
                stack[-1][2] += 1
            e = per.setdefault(pc, [0, 0, 0])
            if kind == "E":
                e[0] += 1
                n_e += 1
                fk = _flow_kind(word)
                if fk == "call":
                    pending_call = True
                elif fk == "ret" and stack:
                    pending_ret = True          # 下一拍关帧；若 trace 到此结束，见下面的收尾
            else:
                e[1] += 1
                n_s += 1
            if first_c is None:
                first_c = cyc
            last_c, last_pc = cyc, pc
    # 收尾：最后一条记录就是 ret（后面没有记录了）⇒ 该帧到 trace 末尾为止，离开拍 = 最后拍 + 1。
    if pending_ret and stack:
        entry_pc, c0, cr, kids = stack.pop()
        sp = last_c + 1 - c0
        if sp != cr + kids:
            bad_frames.append((entry_pc, c0, last_c + 1, sp, cr, kids))
        frames.append((entry_pc, c0, last_c + 1))
        credit_pc[entry_pc] = credit_pc.get(entry_pc, 0) + cr
    span = (last_c - first_c + 1) if first_c is not None else 0
    return (per, n_e, n_s, sum(v[2] for v in per.values()), span, other, frames, credit_pc,
            bad_frames, len(stack))


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

    (per, n_e, n_s, gaps, span, other, frames, credit_pc,
     bad_frames, n_unclosed) = parse_trace(Path(args.trace))

    # ── 自身拍聚合到符号（匿名区/框架容器口径与 stall_profile.py 一致）───────────
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

    # ── 含被调拍：**trace 实测帧跨度** `[进入拍, 离开拍)` ─────────────────────────
    # 离开拍 = 调用方恢复执行的那一拍（不是 ret 自己那一拍）⇒ 帧内每一拍恰好归属一处：
    #   帧跨度 == 帧内自己记入的拍 + Σ直接被调帧跨度    ← 硬判据③，在 parse_trace 关帧时逐帧核对
    # 叶函数 含被调 == 自身拍；父函数 = 自身拍 + 帧内兄弟标签 + Σ直接被调含被调。
    def disp(nm):        # 与自身拍表同一口径：框架容器加前缀
        return ("(框架容器) " + nm) if (nm != "(无符号区间)"
                                        and any(nm.startswith(p) for p in CONTAINER)) else nm
    incl, incl_disp, credit, n_frames = {}, {}, {}, len(frames)
    for entry_pc, c0, c1 in frames:
        nm = name_at(entry_pc, starts, bnds)
        incl[nm] = incl.get(nm, 0) + (c1 - c0)
        incl_disp[disp(nm)] = incl_disp.get(disp(nm), 0) + (c1 - c0)
    for entry_pc, cr in credit_pc.items():
        nm = name_at(entry_pc, starts, bnds)
        credit[nm] = credit.get(nm, 0) + cr
    ok_frames = not bad_frames

    def ic_of(n):        # 行名 → 含被调（框架容器用带前缀的名字）
        return incl_disp.get(n, incl.get(n))
    # 附加不变量：有帧的符号必须 含被调 ≥ 自身拍（叶函数相等）。
    bad_ge = [(n, ic_of(n), c) for n, _r, _s, _g, c in rows
              if ic_of(n) is not None and ic_of(n) < c]

    # ── 完整性判据（与**同一次运行**的 chip INSN_CNT 比；ISS 的差另列）───────────
    chip_insn = None
    if args.uart0 and Path(args.uart0).exists():
        m = re.search(r"OTBN insn_cnt:\s*([\d,]+)",
                      Path(args.uart0).read_text(encoding="utf-8", errors="replace"))
        if m:
            chip_insn = int(m.group(1).replace(",", ""))
    ok_complete = (chip_insn is None) or (n_e == chip_insn)
    ok_span = (n_e + n_s + gaps == span)
    d_insn = n_e - iss_insn
    d_stall = (n_s + gaps) - iss_stalls

    L = [f"# RTL trace 逐函数归因 · {args.version}/{args.op}", "",
         f"> 方法 A：同一份 app 在 **RTL**（Earlgrey chip sim，OTBN 连真 KMAC）上跑，"
         f"按 OTBN 指令级 trace 逐拍归因。",
         f"> 输入 trace：`{args.trace}`（{Path(args.trace).stat().st_size:,} B）。",
         f"> 对照口径：ISS 表来自 `{args.json}`（同一份 app）。", "",
         "## 自证（完整性）", "",
         "| 判据 | RTL trace | 参照 | 结论 |",
         "|---|---:|---:|---|",
         f"| Σ `E`（退休指令） == chip `INSN_CNT` | {n_e:,} | "
         + (f"{chip_insn:,}" if chip_insn is not None else "（未提供 --uart0）")
         + f" | {'✓' if ok_complete else '✗'} |",
         f"| Σ (`E`+`S`) + 空档 == trace 跨度 | {n_e + n_s:,} + {gaps:,} = {n_e + n_s + gaps:,} | "
         f"跨度 {span:,} | {'✓' if ok_span else '✗'} |",
         f"| 调用帧实测（`jal`/`jalr`/`ret` 解码建栈） | {n_frames:,} 帧（未闭合 {n_unclosed}），"
         f"Σ帧跨度 {sum(c1 - c0 for _p, c0, c1 in frames):,} | 含被调、帧间会重复；未闭合帧不计 | ✓ |",
         f"| **帧跨度 == 帧内记入 + Σ被调帧**（逐帧全等） | {n_frames:,} 帧全等（未闭合 {n_unclosed}） | "
         "帧内每拍恰好归属一处 | "
         + ("✓ |" if ok_frames else "✗ " + "；".join(
             f"0x{p:x} 跨 {s:,} ≠ {c:,}+{k:,}" for p, _a, _b, s, c, k in bad_frames[:3]) + " |"),
         f"| 含被调 ≥ 自身拍（叶函数取等） | " + ("全部满足 | 帧跨度定义 | ✓ |" if not bad_ge
            else "✗ " + "；".join(f"`{n}` 含被调 {a:,} < 自身拍 {b:,}" for n, a, b in bad_ge[:3]) + " | — | ✗ |"), "",
         "## 与 ISS 的差（**信息列**，不是错误）", "",
         "| 量 | RTL trace | ISS JSON | 差 |", "|---|---:|---:|---|",
         f"| 退休指令数 | {n_e:,} | {iss_insn:,} | {d_insn:+,}（{100 * d_insn / max(iss_insn, 1):+.2f}%） |",
         f"| 停滞拍（RTL 的 `S` + 空档 ↔ ISS `stalls`） | {n_s + gaps:,} | {iss_stalls:,} | "
         f"{d_stall:+,}（{100 * d_stall / max(iss_stalls, 1):+.2f}%） |", "",
         "> 两种口径都已知：① ISS 的 `stalls` 含「取指等待」拍，tracer 的 `S` 只在控制器进入 stall "
         "状态时记录 ⇒ 比对时用 `S`+空档；② 用 KMAC 的版本（ver0_2/ver1_1）ISS 的 KMAC 时序是粗粒度"
         "模型 ⇒ 轮询圈数与 RTL 不同，指令数与停滞拍**本就应当有差**。",
         f"> trace 里非 `E`/`S` 的行（擦除/寄存器流水账）：{other:,} 行；空档 {gaps:,} 拍"
         "（无任何记录的拍；按上一条口径，它们与 ISS 的 stalls 同源）。", ""]

    # ── 逐函数表（含被调 = 实测帧；自身拍 = 逐拍归属）──────────────────────────
    tot_c = max(span, 1)
    L += ["## 逐函数 RTL 真实周期数（含被调 = 图上 C2 − C1）", "",
          "| 函数 | **拍（含被调）** | 占 app | 自身拍 | 退役 | 停滞 | 取指等待¹ | CPI(含被调) |",
          "|---|---:|---:|---:|---:|---:|---:|---:|"]
    ranked = sorted(rows, key=lambda x: -(ic_of(x[0]) or 0))
    for n, r, s, g, c in ranked:
        ic = ic_of(n)
        if ic is None:                    # 不是被调函数（顶层/内联标号）⇒ 无帧 ⇒ 只给自身拍
            L.append(f"| `{n}` | —（非被调函数） | — | {c:,} | {r:,} | {s:,} | {g:,} | — |")
            continue
        L.append(f"| `{n}` | **{ic:,}** | {100 * ic / tot_c:.2f}% | {c:,} | {r:,} | {s:,} | "
                 f"{g:,} | {ic / max(r, 1):.3f} |")
    L += ["", "> ¹ **取指等待**=两条记录之间的空拍（fetch 未回），摊给上一条记录所在的函数 —— "
          "与 ISS 的 `has_fetch_stall` 同口径（跳转/循环多出的那一拍记在跳转指令上）。",
          f"> 「含被调」= trace 实测**帧跨度** `[C1, C2)`（{n_frames:,} 帧，`jal/jalr/ret` 解码建栈；"
          "C1 = 进入函数第一拍，C2 = **调用方恢复执行的那一拍**）：帧内每一拍恰好归属一处 ⇒ "
          "**叶函数 含被调 == 自身拍**、父函数 = 自身拍 + 帧内兄弟标签 + Σ直接被调含被调"
          f"（{n_frames:,} 帧逐帧核对 `帧跨度 == 帧内记入 + Σ被调帧` {'✓' if ok_frames else '✗'}）。"
          "帧之间仍会重复（被调被父帧包含）⇒ **不能相加**；要「相加等于整段」用自身拍列。", ""]

    # ── 与现有分解表逐行对照（ISS 行 ↔ RTL 含被调实测）────────────────────────
    iss_rows = [r for r in d["rows"]
                if r["phase"].startswith(args.op + "_") and r.get("closure", True)]
    if iss_rows:
        L += ["## 与现有分解表逐行对照（ISS 行 ↔ RTL 含被调实测）", "",
              f"| ISS 行（`{args.op}_…`） | ISS 拍 | RTL 对应函数 | RTL 拍（含被调） | 差 | 差% |",
              "|---|---:|---|---:|---:|---:|"]
        for r in sorted(iss_rows, key=lambda x: -x["cycles"]):
            fn = r["phase"][len(args.op) + 1:]
            ic = incl.get(fn)
            if ic is None:
                # 该阶段在 app 里不是"以调用进入的函数"（可能被内联/尾跳转，或阶段名是 harness 的
                # 组合名）⇒ 不给数，**绝不猜**归属。逐函数实测见上一张表。
                L.append(f"| `{r['phase']}` | {r['cycles']:,} | —（app 未以调用进入该函数） | — | — | — |")
                continue
            d_v = ic - r["cycles"]
            L.append(f"| `{r['phase']}` | {r['cycles']:,} | `{fn}` | {ic:,} | {d_v:+,} | "
                     f"{100 * d_v / max(r['cycles'], 1):+.2f}% |")
        L += ["", "> 读法：ISS 行的 `cycles` 是 harness 程序里该阶段的 Δ；RTL 列是该函数在**真机**上"
              "从进入跑到离开的整段（trace 实测帧，含被调）。两者口径一致 ⇒ 差就是**模型 vs RTL** 的差。",
              "> ⚠ 有些阶段行（如 `pack_pk`/`hash_h`）在 app 里**不是同名函数的调用**（内联/尾跳转，"
              "或该阶段名是 harness 的组合名，同一内核被多阶段共享）⇒ 这里**不给数**，避免猜归属；"
              "那些阶段的实测值请按上一张表的逐函数数据自行对应。", ""]

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
                            "ok_complete": ok_complete, "ok_span": ok_span,
                            "ok_frames": ok_frames, "n_frames": n_frames, "n_unclosed": n_unclosed,
                            "d_insn": d_insn, "d_stall": d_stall},
             "symbols": [{"name": n, "retire": r, "stall": s, "fetch_wait": g, "cycles": c,
                          "inclusive": ic_of(n), "frame_credit": credit.get(n)}
                         for n, r, s, g, c in rows],
             "hot_pcs": [{"pc": pc, "retire": r, "stall": s, "fetch_wait": g}
                         for pc, (r, s, g) in hot]},
            ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"[写] {args.json_out}")
    return 0 if (ok_complete and ok_span and ok_frames and not bad_ge) else 1


if __name__ == "__main__":
    raise SystemExit(main())
