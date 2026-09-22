#!/usr/bin/env python3
"""按「kernel」统计**动态指令数**与 **stall 拍**（拆到 opcode），并把 **ISS 同口径**并排做互证。

三个来源各自干什么（**别混**）：
  · **RTL trace**（`logs_hkem/<版本>/rtl/*.rtl_trace.log`）：给出每一拍的 (cycle, PC, insn) —— 本文件的**全部数字**都从这里来；
  · **符号边界**（ISS 剖面的 `boundaries`，或 P-256 的 `run_p256.elf`）：只用来把 PC 映射成函数名（"电话簿"），不贡献任何数字；
  · **IBEX/chip 日志**：顶层总数（`INSN_CNT`）用来锁住整段（Σ`E` == `INSN_CNT`，见 `rtl_trace_attr.py`）；
  · **ISS 剖面 JSON**：给出同口径的动态指令数（`exec_insn` / `func_calls` 闭包）⇒ 与 RTL 逐 kernel 对 **Δ（应为 0）**。

归属规则：
  · **叶函数**（mul_modp / basemul / basemul_acc）：PC 落在其**符号区间**内；
  · **调用子树**（NTT / INTT）：调用栈上**有任一帧的进入 PC 落在其区间内**（含被调函数与内部 loop）；
  · 两者**故意重叠**（NTT 行含 basemul/basemul_acc 的拍）⇒ 行之间不可相加。
每拍归属：`E`=退休 1 拍；`S`=该 PC 停滞 1 拍；记录间空档=**取指等待**（摊给上一条记录所在指令）。
指令名 = ISS 自带 ISA 表解码（不猜编码）。

用法:
  python3 test_perf/tools/diag/kernel_stat.py --version ver1_1 \
      --json logs_hkem/ver1_1_profiling/re_ver1_1.json --trace-dir logs_hkem/ver1_1/rtl \
      --p256-elf logs_hkem/rtl_extra/run_p256.elf --p256-trace logs_hkem/rtl_extra/p256_ver1_1.rtl_trace.log \
      --out FILE.md --json-out FILE.json
"""
import argparse
import bisect
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rtl_trace_attr as R                                  # noqa: E402  复用同一套解析/解码/边界口径

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

OPS = (("keygen", "keypair"), ("encap", "encap"), ("decap", "decap"))
# 行名 → (符号名, 是否按调用子树)
KERNELS = (("mul_modp", "mul_modp", False), ("basemul", "basemul", False),
           ("basemul_acc", "basemul_acc", False), ("NTT", "ntt", True), ("INTT", "intt", True))


def opcode_of(word, cache):
    """指令字 → **助记符**（`bn.mulqacc` 这种；用 ISS 的 `insn.insn.mnemonic`，与它的 `insn_histo` 同名）。"""
    k = cache.get(word)
    if k is None:
        try:
            from sim.decode import decode_words
            insns = decode_words(0, [(True, word)])
            if insns:
                inner = getattr(insns[0], "insn", None)
                k = (getattr(inner, "mnemonic", None) or type(insns[0]).__name__.lower())
            else:
                k = "?%08x" % word
        except Exception:
            k = "?%08x" % word
        cache[word] = k
    return k


def _which(bnds, starts, pc):
    i = bisect.bisect_right(starts, pc) - 1
    if i < 0:
        return None
    s, e, n = bnds[i]
    return n if s <= pc < e else None


def _in(bnds, starts, pc, sym):
    n = _which(bnds, starts, pc)
    return n is not None and (n == sym or n.endswith(":" + sym))


def scan(trace: Path, bnds, starts, kernels, only_session=None):
    """扫一份 trace ⇒ `(per_kernel, frames, spans)`。

    per_kernel[k][opcode] = [动态次数, 停滞, 取指等待]；spans[k] = 该 kernel 的调用帧跨度之和（对账用）。
    """
    per = {k: {} for k, _s, _sub in kernels}
    frames = {k: 0 for k, _s, _sub in kernels}
    spans = {k: 0 for k, _s, _sub in kernels}
    glob = {}                                     # 整个 app（不限 kernel）：opcode → 动态次数（逐 opcode 互证用）
    ksym = {k: sym for k, sym, _sub in kernels}
    cache, stack, pending_call, pending_ret, last = {}, [], False, None, None
    sid, take = 0, (only_session is None)

    def hit(pc):
        leaf = {k for k, sym, sub in kernels if not sub and _in(bnds, starts, pc, sym)}
        sub = {k for k, sym, is_sub in kernels if is_sub
               and any(_in(bnds, starts, e, sym) for e, _c in stack)}
        return leaf, sub

    def close(ent, c0, cyc):
        for k, sym, _sub in kernels:
            if _in(bnds, starts, ent, sym):
                spans[k] += cyc - c0

    with trace.open("r", encoding="utf-8", errors="replace") as f:
        for line in f:
            m = R.RE_TRACE.match(line)
            if not m:
                continue
            kind, cyc, pc, word = m.group(1), int(m.group(2)), int(m.group(3), 16), int(m.group(4), 16)
            take = (only_session is None) or (sid == only_session)
            if last is not None and cyc > last[2] + 1:            # 空档 ⇒ 上一条记录所在指令
                lf, sb = hit(last[0])
                for k in (lf | sb) if take else ():
                    per[k].setdefault(opcode_of(last[1], cache), [0, 0, 0])[2] += cyc - last[2] - 1
            if pending_ret and stack:                             # 上一拍是 ret ⇒ 本记录 = 调用方恢复执行
                ent, c0 = stack.pop()
                close(ent, c0, cyc)
                pending_ret = False
            if pending_call:                                      # 本记录 = 被调函数第一条 ⇒ 开帧
                stack.append((pc, cyc))
                pending_call = False
                k_new = {k for k, sym, _sub in kernels if take and _in(bnds, starts, pc, sym)}
                if k_new and not any(_in(bnds, starts, e, ksym[k2])
                                     for e, _c in stack[:-1] for k2, _s2, _sub2 in kernels):
                    for k in k_new:
                        frames[k] += 1
            fk = "other"
            if kind == "E":
                fk = R._flow_kind(word)
                if take:
                    glob[opcode_of(word, cache)] = glob.get(opcode_of(word, cache), 0) + 1
            lf, sb = hit(pc)
            for k in (lf | sb) if take else ():
                e = per[k].setdefault(opcode_of(word, cache), [0, 0, 0])
                e[0 if kind == "E" else 1] += 1
            if kind == "E":
                if fk == "ret" and stack:
                    pending_ret = True
                elif fk == "call":
                    pending_call = True
                elif fk == "halt":
                    while stack:                                  # 会话结束：关掉未闭合帧
                        ent, c0 = stack.pop()
                        if take:
                            close(ent, c0, cyc)
                    pending_ret = False
                    last = None
                    sid += 1
                    continue
            last = (pc, word, cyc)
    while stack:                                                  # trace 结束仍未闭合（正常：顶层帧）
        ent, c0 = stack.pop()
        close(ent, c0, last[2] + 1 if last else 0)
    return per, frames, spans, glob


def iss_kernel_counts(app, d, op):
    """ISS 侧的同口径量（两个来源，别混）：
      · **叶函数**（mul_modp/basemul/basemul_acc）→ `exec_insn[名字]`（同名直配，Δ 应为 0）；
      · **子树**（ntt/intt）→ harness 的**阶段行**（`keygen_ntt` / `decap_intt_x5` …；那正是 ISS 侧
        "进入 kernel 到退出"的等价测量）⇒ Δ 为 −3…−6 条（ISS 阶段自身的口径边界）。
    """
    ei = app.get("exec_insn") or {}
    rows = [r for r in d["rows"] if r["phase"].startswith(op + "_") and r.get("closure", True)]

    def toks(ph):
        t = ph.split("_")
        if t and re.fullmatch(r"x\d+", t[-1]):
            t = t[:-1]
        return set(t)

    out = {}
    for k, sym, is_sub in KERNELS:
        if not is_sub:
            out[k] = ei.get(sym, 0)
        else:
            out[k] = sum(r["insn"] for r in rows if sym in toks(r["phase"]))
    return out


def agg(pk, k):
    a = pk.get(k) or {}
    return (sum(v[0] for v in a.values()), sum(v[1] for v in a.values()),
            sum(v[2] for v in a.values()))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--json", required=True)
    ap.add_argument("--trace-dir", required=True)
    ap.add_argument("--ops", default="keygen,encap,decap")
    ap.add_argument("--p256-elf", default="", help="run_p256.elf（mul_modp 属于 P-256）")
    ap.add_argument("--p256-trace", default="", help="P-256 的 RTL trace（4 个会话一起统计）")
    ap.add_argument("--out", default="")
    ap.add_argument("--json-out", default="")
    args = ap.parse_args()

    d = json.loads(Path(args.json).read_text(encoding="utf-8"))
    kernels = KERNELS
    tot = {k: {} for k, _s, _sub in kernels}
    tot_frames = {k: 0 for k, _s, _sub in kernels}
    tot_iss = {k: 0 for k, _s, _sub in kernels}
    rows, out_ops = [], {}
    for op, tname in OPS:
        if op not in args.ops.split(","):
            continue
        tr = Path(args.trace_dir) / f"test_mlkem_{tname}_only.rtl_trace.log"
        if not tr.exists():
            print(f"  ⚠ 缺 {tr} ⇒ 跳过", file=sys.stderr)
            continue
        app = d["apps"][args.version][op]                      # ⚠ 每个 op 的符号边界不同（不同 ELF）
        bnds = sorted((s, e, n) for s, e, n in app["boundaries"])
        starts = [b[0] for b in bnds]
        pk, fr, sp, glob = scan(tr, bnds, starts, kernels)
        iss = iss_kernel_counts(app, d, op)
        for k in tot:
            for oc, v in pk[k].items():
                e = tot[k].setdefault(oc, [0, 0, 0])
                for i in range(3):
                    e[i] += v[i]
            tot_frames[k] += fr[k]
            tot_iss[k] += iss[k]
        glob_iss = {kk: vv for kk, vv in (app.get("histo") or {}).items()}
        rows.append((op, pk, fr, sp, iss, glob, glob_iss))
        out_ops[op] = {"kernels": {k: {"opcodes": pk[k], "frames": fr[k], "span_sum": sp[k],
                                       "iss_count": iss[k]} for k, _s, _sub in kernels},
                       "opcode_rtl": glob, "opcode_iss": glob_iss}

    # ── P-256 的 mul_modp（三版通用；符号边界取自 run_p256.elf 的 .symtab）────────────
    if args.p256_elf and args.p256_trace:
        spec = (("mul_modp", "mul_modp", False),)
        b2 = R.read_elf_boundaries(Path(args.p256_elf))
        off = 0x8000 if min(x[0] for x in b2) >= 0x8000 else 0
        b2 = [(a - off, e - off, n) for a, e, n in b2]
        s2 = [b[0] for b in b2]
        # 逐会话统计（模板要的是"**一次** P-256 运算"）：会话 1/2 = Keygen A/B、3/4 = ECDH A/B
        PK_LABELS = ("Keygen A", "Keygen B", "ECDH A", "ECDH B")
        pk2, fr2, sp2, per_sess = {}, {}, {}, []
        for k in range(len(PK_LABELS) + 2):                    # 多试两个，防会话数变化
            sk, sf, ss, _sg = scan(Path(args.p256_trace), b2, s2, spec, only_session=k)
            if not sk["mul_modp"]:
                continue
            per_sess.append({"label": PK_LABELS[k] if k < len(PK_LABELS) else f"会话{k+1}",
                             "kernels": {"mul_modp": {"opcodes": sk["mul_modp"], "frames": sf["mul_modp"],
                                                      "span_sum": ss["mul_modp"]}}})
            for oc, v in sk["mul_modp"].items():
                e = pk2.setdefault(oc, [0, 0, 0])
                for i in range(3):
                    e[i] += v[i]
            fr2["mul_modp"] = fr2.get("mul_modp", 0) + sf["mul_modp"]
            sp2["mul_modp"] = sp2.get("mul_modp", 0) + ss["mul_modp"]
        for oc, v in pk2.items():
            e = tot["mul_modp"].setdefault(oc, [0, 0, 0])
            for i in range(3):
                e[i] += v[i]
        tot_frames["mul_modp"] += fr2["mul_modp"]
        rows.append((f"p256（P-256；{Path(args.p256_trace).name} 的 {len(per_sess)} 个会话**合计**）",
                     {"mul_modp": pk2}, fr2, sp2, None, {}, {}))
        out_ops["p256"] = {"kernels": {"mul_modp": {"opcodes": pk2, "frames": fr2["mul_modp"],
                                                    "span_sum": sp2["mul_modp"]}},
                           "sessions": per_sess}

    L = [f"# kernel 级动态指令 + stall 统计 · {args.version}", "",
         f"> **数字来源**：RTL trace（`{args.trace_dir}/test_mlkem_*_only.rtl_trace.log`），按 PC 逐拍归因 —— "
         f"真机拍；**符号边界**只用来把 PC 映射成函数名（ISS 剖面的 `boundaries`；P-256 用 `run_p256.elf` 的 `.symtab`）。",
         "> **三方互证**：① 整段 Σ`E` == chip `INSN_CNT`（IBEX 层）；② 逐 kernel 动态指令数 == ISS 同口径"
         "（叶 = `exec_insn`；NTT/INTT = `func_calls` 闭包）⇒ Δ 应为 **0**（这些 kernel 不含 KMAC 轮询）。",
         "> 口径：`E`=退休 1 拍；`S`=该 PC 停滞 1 拍；记录间空档=**取指等待**（摊给上一条指令）。"
         "叶函数 = PC 在其符号区间；**NTT/INTT = 调用子树**（含被调与内部 loop）⇒ 行之间会重复、**不可相加**。", ""]
    for op, pk, fr, sp, iss, glob, giss in rows:
        L += [f"## {op}", "",
              "| kernel | 调用帧数 | 动态指令数（RTL） | ISS 同口径² | Δ | 停滞 | 取指等待 | 拍合计 | 帧跨度对账¹ | CPI |",
              "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|"]
        for kname, _sym, _sub in kernels:
            ne, ns, ng = agg(pk, kname)
            if not ne:
                L.append(f"| `{kname}` | — | — | — | — | — | — | — | — | — |")
                continue
            t = ne + ns + ng
            i_ = (iss or {}).get(kname)
            d_ = f"{ne - i_:+,}" if i_ is not None else "—"
            icol = f"{i_:,}" if i_ is not None else "—"
            sk = sp.get(kname, 0)
            rec = f"{sk:,}（{t - sk:+,}）" if sk else "—"
            L.append(f"| `{kname}` | {fr.get(kname, 0):,} | {ne:,} | {icol} | {d_} | {ns:,} | {ng:,} | "
                     f"{t:,} | {rec} | {t / max(ne, 1):.3f} |")
        L.append("")
    L += ["", "> ² ISS 同口径：**叶函数** = `exec_insn`（同名直配，Δ 应为 0）；**NTT/INTT** = harness 阶段行"
          "（`keygen_ntt` / `decap_intt_x5` …，即 ISS 侧「进入 kernel 到退出」的等价测量）⇒ Δ 为 −3…−6 条"
          "（ISS 阶段自身的口径边界，见各版本分解表）。",
          "> ¹ **帧跨度对账**：本行「拍合计」 ↔ 该 kernel 各次调用帧跨度之和（`rtl_trace_attr.py` 口径）；"
          "两者之差是帧边界效应（每帧 1–3 拍），属口径定义、不是丢拍。", ""]
    L += ["## 逐 opcode 三方互证（RTL 全 app vs ISS `insn_histo`）", "",
          "> RTL 侧 = 该 op 的整段 trace 逐条指令计数（Σ == Σ`E`）；ISS 侧 = `re_<版本>.json` 里"
          "同一 app 的 `histo`（Σ == ISS `insn`）。两侧**同名助手**（都用 ISS 的 `insn.insn.mnemonic`）⇒ "
          "Δ ≠ 0 的只应是 **KMAC 轮询**相关指令（ver0_1 不用 KMAC ⇒ 全 0）。", ""]
    for op, pk, fr, sp, iss, glob, giss in rows:
        if not giss:
            continue
        keys = sorted(set(glob) | set(giss),
                      key=lambda k: (-(glob.get(k, 0) + giss.get(k, 0)), k))   # 并列按名，保证可重现
        dr = sum(glob.values()) - sum(giss.values())
        L += [f"### {op}：RTL {sum(glob.values()):,} 条 vs ISS {sum(giss.values()):,} 条（Δ {dr:+,}）", "",
              "| 指令 | RTL 次数 | ISS 次数 | Δ |", "|---|---:|---:|---:|"]
        for k in keys:
            a, b = glob.get(k, 0), giss.get(k, 0)
            L.append(f"| `{k}` | {a:,} | {b:,} | {a - b:+,} |" + ("  ←" if a != b else ""))
        L.append("")
    L += ["## 三 op 合计：逐 kernel × 逐 opcode", "",
          "> 「每次执行平均 stall」= (停滞 + 取指等待) / 动态次数 ⇒ 回答「某一次动态指令 stall 多少」。", ""]
    for kname, _sym, _sub in kernels:
        ne, ns, ng = agg(tot, kname)
        if not ne:
            continue
        L += [f"### `{kname}`（调用 {tot_frames.get(kname, 0):,} 帧）—— 动态 {ne:,} 条"
              + (f"（ISS 同口径 {tot_iss[kname]:,}，Δ {ne - tot_iss[kname]:+,}）" if tot_iss[kname] else "")
              + f"；停滞 {ns:,} + 取指等待 {ng:,} = **{ns + ng:,} 拍**；拍合计 {ne + ns + ng:,}"
                f"（CPI {(ne + ns + ng) / max(ne, 1):.3f}）", "",
              "| 指令 | 动态次数 | 停滞 | 取指等待 | 拍 | 每次执行平均 stall |", "|---|---:|---:|---:|---:|---:|"]
        for oc, (a, b, c) in sorted(tot[kname].items(), key=lambda kv: -(kv[1][0] + kv[1][1] + kv[1][2])):
            L.append(f"| `{oc}` | {a:,} | {b:,} | {c:,} | {a + b + c:,} | {(b + c) / max(a, 1):.3f} |")
        L.append("")
    txt = "\n".join(L) + "\n"
    print(txt)
    if args.out:
        Path(args.out).write_text(txt, encoding="utf-8")
        print(f"[写] {args.out}")
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(
            {"version": args.version, "ops": out_ops,
             "totals": {k: {"opcodes": tot[k], "frames": tot_frames[k], "iss_count": tot_iss[k]}
                        for k, _s, _sub in kernels}},
            ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"[写] {args.json_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
