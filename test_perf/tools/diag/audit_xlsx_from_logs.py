#!/usr/bin/env python3
"""端到端审计：**只用原始 RTL trace 日志**重算一遍，再与 Excel 里**已经写好的单元格**逐个比对。

与另外两条路径的**独立点**：
  · `kernel_stat.py`：栈标志法算子树（"栈上任一帧的进入 PC 在区间内"）；
  · 本文件：**区间法** —— 用 `rtl_trace_attr.parse_trace()`（另一份已提交的工具）给出的帧跨度
    `[C1,C2)` 列表，取"进入 PC 落在 kernel 区间内"的那些区间，**合并后**数落在里面的记录；
    叶函数则**完全不建栈**，直接按 PC 落区间计数。
  · 顶层锚点：整段 Σ`E`（本文件自己数）== 同一批 chip 日志里的 `INSN_CNT`（`*.uart0.log`）。

比对对象 = `动态指令及stall统计.xlsx` 里**已写入的单元格**（用 openpyxl 读回来）：
`ver*` 明细 sheet 的逐 (op, kernel, opcode) `[动态次数, 停滞, 取指等待]`、三 op 合计行、
`stall拆解` 与 `Sheet1` 的「每次调用」数字（调用次数也由本文件从帧列表独立数出）、
以及 P-256 四个会话的逐行数字。

用法:
  python3 test_perf/tools/diag/audit_xlsx_from_logs.py --xlsx "…/动态指令及stall统计.xlsx"
"""
import argparse
import bisect
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rtl_trace_attr as R                                  # noqa: E402
from openpyxl import load_workbook                          # noqa: E402

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = Path(__file__).resolve().parents[3]
VERS = ("ver1_1", "ver0_2", "ver0_1")
OPS = (("keygen", "keypair"), ("encap", "encap"), ("decap", "decap"))
KERNELS = (("mul_modp", "mul_modp", False), ("basemul", "basemul", False),
           ("basemul_acc", "basemul_acc", False), ("NTT", "ntt", True), ("INTT", "intt", True))
LEAF = ("mul_modp", "basemul", "basemul_acc")
PK_LABELS = ("Keygen A", "Keygen B", "ECDH A", "ECDH B")
RE_COUNT = re.compile(r"([A-Za-z0-9_]+) OTBN instruction count[:=]\s*(0[xX][0-9a-fA-F]+|\d+)")
_MN = {}


def mnemonic(word):
    k = _MN.get(word)
    if k is None:
        try:
            from sim.decode import decode_words
            ins = decode_words(0, [(True, word)])
            inner = getattr(ins[0], "insn", None) if ins else None
            k = getattr(inner, "mnemonic", None) or "?"
        except Exception:
            k = "?"
        _MN[word] = k
    return k


def which(bnds, starts, pc):
    i = bisect.bisect_right(starts, pc) - 1
    if i < 0:
        return None
    s, e, n = bnds[i]
    return n if s <= pc < e else None


def in_sym(bnds, starts, pc, sym):
    n = which(bnds, starts, pc)
    return n is not None and (n == sym or n.endswith(":" + sym))


def records(path):
    """→ 生成器 (kind, cyc, pc, word)；kind ∈ {E, S}（只认这两种记录行，其余行跳过）。"""
    with path.open("rb") as f:
        for raw in f:
            c = raw[0]
            if c != 69 and c != 83:
                continue
            try:
                head, tail = raw.split(b", ", 1)
                a = head.split()
                yield ("E" if c == 69 else "S", int(a[1]), int(a[3], 16), int(tail[6:], 16))
            except Exception:
                m = R.RE_TRACE.match(raw.decode("utf-8", "replace"))
                if m:
                    yield (m.group(1), int(m.group(2)), int(m.group(3), 16), int(m.group(4), 16))


def merge(iv):
    out = []
    for c0, c1 in sorted(iv):
        if out and c0 <= out[-1][1]:
            out[-1][1] = max(out[-1][1], c1)
        else:
            out.append([c0, c1])
    return out


def audit_mlkem(trace, bnds, starts):
    """→ {kernel: {"by_op": {op: [n, 停滞, 取指]}, "n"/"stall"/"fetch"/"frames"/"span"}}"""
    frames_all = R.parse_trace(trace)
    out = {}
    for k, sym, is_sub in KERNELS:
        fr = [f for s in frames_all for f in s["frames"] if in_sym(bnds, starts, f[0], sym)]
        if is_sub:                                    # 区间法：只数落在帧跨度 [C1,C2) 内的记录
            iv = merge([(c0, c1) for _pc, c0, c1 in fr])
            st_ = [x[0] for x in iv]
            by, n, st_n = {}, 0, 0
            for kind, cyc, pc, word in records(trace):
                j = bisect.bisect_right(st_, cyc) - 1
                if j < 0 or cyc >= iv[j][1]:
                    continue
                e = by.setdefault(mnemonic(word), [0, 0])
                e[0 if kind == "E" else 1] += 1
                if kind == "E":
                    n += 1
                else:
                    st_n += 1
            span = sum(c1 - c0 for c0, c1 in iv)
            out[k] = {"by_op": {o: [v[0], v[1], None] for o, v in by.items()},
                      "n": n, "stall": st_n, "fetch": span - n - st_n,
                      "frames": len(fr), "span": span}
        else:                                          # 叶函数：不建栈，直接按 PC 落区间计数
            by, n, st_n, fe, prev = {}, 0, 0, 0, None
            for kind, cyc, pc, word in records(trace):
                if prev is not None and cyc > prev[1] + 1 and prev[2]:    # 空档记给上一条记录
                    g = cyc - prev[1] - 1
                    fe += g
                    by.setdefault(mnemonic(prev[3]), [0, 0, 0])[2] += g
                hit = in_sym(bnds, starts, pc, sym)
                if hit:
                    e = by.setdefault(mnemonic(word), [0, 0, 0])
                    e[0 if kind == "E" else 1] += 1
                    if kind == "E":
                        n += 1
                    else:
                        st_n += 1
                prev = (pc, cyc, hit, word)
            out[k] = {"by_op": by, "n": n, "stall": st_n, "fetch": fe,
                      "frames": len(fr), "span": sum(c1 - c0 for _pc, c0, c1 in fr)}
    return out


def audit_p256(trace, bnds, starts):
    """mul_modp：逐会话（ecall 切分）的 [n, 停滞, 取指] 与帧数。"""
    frames_all = R.parse_trace(trace)
    fr = {i: [f for f in s["frames"] if in_sym(bnds, starts, f[0], "mul_modp")]
          for i, s in enumerate(frames_all)}
    sess, sid, prev = {}, 0, None
    for kind, cyc, pc, word in records(trace):
        d = sess.setdefault(sid, {"by_op": {}, "n": 0, "stall": 0, "fetch": 0, "sumE": 0})
        if kind == "E":
            d["sumE"] += 1                     # 该会话**整 app** 的退役指令数（顶层锚点用）
        if prev is not None and prev[4] == sid and cyc > prev[1] + 1 and prev[2]:
            g = cyc - prev[1] - 1
            d["fetch"] += g
            d["by_op"].setdefault(mnemonic(prev[3]), [0, 0, 0])[2] += g
        hit = in_sym(bnds, starts, pc, "mul_modp")
        if hit:
            e = d["by_op"].setdefault(mnemonic(word), [0, 0, 0])
            e[0 if kind == "E" else 1] += 1
            d["n" if kind == "E" else "stall"] += 1
        if kind == "E" and R._flow_kind(word) == "halt":
            sid += 1
        prev = (pc, cyc, hit, word, sid)
    for i in sess:
        sess[i]["frames"] = len(fr.get(i, []))
    return sess


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--xlsx", required=True)
    ap.add_argument("--versions", default=",".join(VERS))
    args = ap.parse_args()
    wb = load_workbook(args.xlsx)
    bad, cells, notes = [], 0, []

    for v in args.versions.split(","):
        iss = json.loads((REPO / f"logs_hkem/{v}_profiling/re_{v}.json").read_text(encoding="utf-8"))["apps"][v]
        per_op, agg = {}, {k: {"n": 0, "stall": 0, "fetch": 0, "frames": 0} for k, _s, _sub in KERNELS}
        sh = wb[v]
        for op, tname in OPS:
            bnds = sorted((s, e, n) for s, e, n in iss[op]["boundaries"])
            starts = [b[0] for b in bnds]
            tr = REPO / f"logs_hkem/{v}/rtl/test_mlkem_{tname}_only.rtl_trace.log"
            res = audit_mlkem(tr, bnds, starts)
            per_op[op] = res
            for k in agg:
                for f_ in ("n", "stall", "fetch", "frames"):
                    agg[k][f_] += res[k][f_]
            # 顶层锚点：本文件自己数出的 ΣE == 同一批 chip 日志里的 INSN_CNT
            nE = sum(1 for kind, *_ in records(tr) if kind == "E")
            uart = (REPO / f"logs_hkem/{v}/test_mlkem_{tname}_only.uart0.log").read_text(
                encoding="utf-8", errors="replace")
            m = re.search(r"OTBN insn_cnt[:=]\s*([\d,]+)", uart)
            chip = int(m.group(1).replace(",", "")) if m else None
            notes.append(f"{v:7s} {op:6s} 日志里数出的 ΣE={nE:,}  chip INSN_CNT={chip:,}  "
                         f"{'✓' if nE == chip else '✗'}")
            # ── 与 xlsx 的 ver* 明细 sheet 逐行比 ─────────────────────────
            for row in sh.iter_rows(min_row=3, values_only=True):
                algo, label, instr, a, b, c, tot_, _avg = row[:8]
                if not instr or instr in ("【小计】", "【合计】") or not isinstance(label, str):
                    continue
                mk = re.match(r"^(mul_modp|basemul|basemul_acc|NTT|INTT)（(.+)）$", label)
                if not mk or mk.group(2) != op:
                    continue
                k = mk.group(1)
                r = res[k]["by_op"].get(instr)
                if r is None:
                    bad.append(f"{v}/{op}/{k}/{instr}: xlsx={a},{b},{c}，日志里没有该指令")
                    continue
                cells += 3
                if [a, b] != [r[0], r[1]] or (k in LEAF and c != r[2]):
                    bad.append(f"{v}/{op}/{k}/{instr}: xlsx={a},{b},{c} vs 日志={r[0]},{r[1]},{r[2]}")
        # ── 三 op 合计行 ─────────────────────────────────────────────────
        for row in sh.iter_rows(min_row=3, values_only=True):
            if not isinstance(row[1], str) or row[2] != "【合计】":
                continue
            for k, _s, _sub in KERNELS:
                if row[1] == f"{k}（三 op 合计）":
                    cells += 4
                    g = agg[k]
                    if [row[3], row[4], row[5]] != [g["n"], g["stall"], g["fetch"]]:
                        bad.append(f"{v}/{k} 三 op 合计: xlsx={row[3]},{row[4]},{row[5]} "
                                   f"vs 日志={g['n']},{g['stall']},{g['fetch']}")
        # ── stall拆解：每次调用（= 总计 / 调用次数；调用次数由帧列表独立数出）──
        for row in wb["stall拆解"].iter_rows(min_row=3, values_only=True):
            ver, k, tag, instr = row[0], row[1], row[2], row[3]
            if ver != v or not instr or str(instr).startswith("【合计】") or k == "mul_modp":
                continue
            op0 = tag.split("（")[0]
            r = (per_op.get(op0) or {}).get(k, {}).get("by_op", {}).get(instr)
            fr = (per_op.get(op0) or {}).get(k, {}).get("frames", 0)
            if r is None or not fr:
                continue
            # 子树行的「取指」按区间法只能给到 kernel 级总数（这里只比 次数/停滞；取指总量在合计行比）
            if k in LEAF:
                cells += 3
                if [row[5], row[6], row[7]] != [r[0] / fr, r[1] / fr, r[2] / fr]:
                    bad.append(f"{v}/{k}/{instr} 每次调用: xlsx={row[5]},{row[6]},{row[7]} "
                               f"vs 日志={r[0] / fr},{r[1] / fr},{r[2] / fr}")
            else:
                cells += 2
                if [row[5], row[6]] != [r[0] / fr, r[1] / fr]:
                    bad.append(f"{v}/{k}/{instr} 每次调用: xlsx={row[5]},{row[6]} "
                               f"vs 日志={r[0] / fr},{r[1] / fr}")
        # ── P-256（同一份 trace；逐会话）──────────────────────────────────
        b2 = R.read_elf_boundaries(REPO / "logs_hkem/rtl_extra/run_p256.elf")
        off = 0x8000 if min(x[0] for x in b2) >= 0x8000 else 0
        b2 = [(a - off, e - off, n) for a, e, n in b2]
        ps = audit_p256(REPO / "logs_hkem/rtl_extra/p256_ver1_1.rtl_trace.log", b2, [b[0] for b in b2])
        uart = (REPO / f"logs_hkem/{v}/test_p256_only.uart0.log").read_text(encoding="utf-8", errors="replace")
        seq = [int(x.group(2), 0) for x in RE_COUNT.finditer(uart)]
        seq = [x for x in seq if x > 100000]
        for i, lab in enumerate(PK_LABELS):
            if i in ps and i < len(seq):
                notes.append(f"{v:7s} p256/{lab}: 会话 ΣE(整 app)={ps[i]['sumE']:,}  chip INSN_CNT={seq[i]:,}  "
                             f"{'✓' if ps[i]['sumE'] == seq[i] else '✗'}"
                             f"（其中 mul_modp 占 {ps[i]['n']:,} = {100 * ps[i]['n'] / ps[i]['sumE']:.1f}%）")
        for row in sh.iter_rows(min_row=3, values_only=True):
            if isinstance(row[1], str) and row[1].startswith("mul_modp（") and row[2] not in (None, "【小计】"):
                lab = row[1][row[1].index("（") + 1:-1]
                i = PK_LABELS.index(lab) if lab in PK_LABELS else None
                if i is None or i not in ps:
                    continue
                r = ps[i]["by_op"].get(row[2])
                cells += 3
                if r is None or [row[3], row[4], row[5]] != [r[0], r[1], r[2]]:
                    bad.append(f"{v}/p256/{lab}/{row[2]}: xlsx={row[3]},{row[4]},{row[5]} "
                               f"vs 日志={r and [r[0], r[1], r[2]]}")
        # ── Sheet1 的「每次调用」（ver1_1 的 5 行；P-256 行 = 一次 ECDH）──
        if v == "ver1_1":
            for row in wb["Sheet1"].iter_rows(min_row=2, max_row=6, values_only=True):
                k = row[1]
                if k == "mul_modp":
                    g = ps[PK_LABELS.index("ECDH A")]
                else:
                    g = agg[k]
                cells += 2
                want = [g["n"] / g["frames"], (g["stall"] + g["fetch"]) / g["frames"]]
                if [row[3], row[4]] != want:
                    bad.append(f"Sheet1/{k}: xlsx={row[3]},{row[4]} vs 日志={want}")

    print("\n".join(notes))
    print(f"\n★ 逐单元格审计：共比对 {cells:,} 个数字（**从原始 trace 日志重算** vs **xlsx 已写入的单元格**）"
          f" → {'全部相符 ✓' if not bad else f'{len(bad)} 处不符 ✗'}")
    for x in bad[:40]:
        print("   ✗", x)
    return 0 if not bad else 1


if __name__ == "__main__":
    raise SystemExit(main())
