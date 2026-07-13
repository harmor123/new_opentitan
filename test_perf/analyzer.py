"""分析器：多版本横向对比 + 历史纵向对比 + 专业性能报告。"""

import json
from datetime import datetime
from db_manager import DBManager

C_HEAD = "\033[96m"
C_OK   = "\033[92m"
C_WARN = "\033[93m"
C_FAIL = "\033[91m"
C_BOLD = "\033[1m"
C_DIM  = "\033[2m"
C_END  = "\033[0m"
LABEL_W = 26   # 操作名列宽（终端显示宽度）
VAL_W   = 12   # 数值列宽
SEP_W   = 2 + LABEL_W + 2 * VAL_W * 3  # 2 缩进 + 标签 + 2列×3版本
SEP     = "─" * SEP_W

OP_LABELS = {
    "sha3": "SHA3/SHAKE Hash",  "hmac": "HMAC-SHA3-256",
    "hkdf": "HKDF-SHA3-256",    "p256": "P-256 ECDH",
    "mlkem_keypair": "ML-KEM KeyGen",  "mlkem_encap": "ML-KEM Encap",
    "mlkem_decap": "ML-KEM Decap",
}
OP_GROUPS = {
    "Hash": ["sha3", "hmac"],  "KDF": ["hkdf"],
    "ECDH": ["p256"],  "KEM": ["mlkem_keypair", "mlkem_encap", "mlkem_decap"],
}


def _dw(s: str) -> int:
    return sum(2 if ord(c) > 0x2fff else 1 for c in s)

def _pad(s: str, w: int) -> str:
    return s + " " * max(0, w - _dw(s))

def _label(op: str) -> str:
    return OP_LABELS.get(op, op)

def _fmt(n) -> str:
    if n is None or n <= 0:
        return " " * VAL_W + "—"
    return f"{n:>{VAL_W},}"

def _pct(a, total) -> str:
    if not total: return "     —"
    return f"{a/total*100:>5.1f}%"

def _delta(new, old) -> str:
    if not old or not new: return "     N/A"
    d = (new-old)/old*100
    if d <= -0.5: return f"{C_OK}▼{abs(d):4.1f}%{C_END}"
    elif d >= 0.5: return f"{C_FAIL}▲{d:4.1f}%{C_END}"
    return "  ~0.0%"

def _speedup(baseline, target) -> str:
    if not baseline or not target: return "   N/A"
    return f"{baseline/target:5.2f}x"


def report_latest(db: DBManager) -> str:
    latest = db.get_latest_run_ids()
    if not latest:
        return f"{C_WARN}数据库无记录。{C_END}"

    lines = [f"\n{C_BOLD}═══ Hybrid KEM 多版本性能对比 (最新) ═══{C_END}",
             f"  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"]
    vers = sorted(latest.keys())

    all_ops, data = [], {}
    for ver in vers:
        metrics = db.get_metrics(latest[ver])
        data[ver] = {m["operation"]: m for m in metrics}
        for m in metrics:
            if m["operation"] not in all_ops:
                all_ops.append(m["operation"])

    totals = {v: {"cyc": 0, "ins": 0} for v in vers}

    # ── [1] ──
    lines.append(f"\n{C_BOLD}[1] 周期数 & 指令数{C_END}\n" + SEP)
    hdr = _pad("  操作", LABEL_W)
    for v in vers:
        hdr += f"{_pad(v+' Cycles', VAL_W)}{_pad(v+' Instr', VAL_W)}"
    lines.append(hdr + "\n" + "  " + "─" * (LABEL_W + 2 * VAL_W * len(vers)))
    for op in all_ops:
        row = _pad(f"  {_label(op)}", LABEL_W)
        for v in vers:
            m = data[v].get(op, {})
            row += f"{_fmt(m.get('cycles'))}{_fmt(m.get('instructions'))}"
            totals[v]["cyc"] += m.get("cycles") or 0
            totals[v]["ins"] += m.get("instructions") or 0
        lines.append(row)
    lines.append("  " + "─" * (LABEL_W + 2 * VAL_W * len(vers)))
    tr = _pad("  TOTAL", LABEL_W)
    for v in vers:
        tr += f"{_fmt(totals[v]['cyc'])}{_fmt(totals[v]['ins'])}"
    lines.append(tr)

    # ── [2] Stall & IPC ──
    lines.append(f"\n{C_BOLD}[2] Stall & IPC{C_END}\n" + SEP)
    hdr = _pad("  操作", LABEL_W)
    for v in vers:
        hdr += f"{_pad(v+' Stall', VAL_W)}{_pad(v+' St%', 8)}{_pad(v+' IPC', 7)}"
    lines.append(hdr)
    for op in all_ops:
        row = _pad(f"  {_label(op)}", LABEL_W)
        for v in vers:
            m = data[v].get(op, {})
            cyc = m.get("cycles") or 1
            ins = m.get("instructions") or 0
            stl = m.get("stalls") or 0
            sp  = m.get("stall_pct") or 0
            row += f"{_fmt(stl)}{sp:>6.1f}% {ins/cyc:>4.2f} "
        lines.append(row)

    # ── [2.5] ──
    lines.append(f"\n{C_BOLD}[2.5] 代码尺寸 (bytes){C_END}\n" + SEP)
    hdr = _pad("  操作", LABEL_W)
    for v in vers:
        hdr += f"{_pad(v+' IMEM', VAL_W)}{_pad(v+' DMEM', VAL_W)}"
    lines.append(hdr)
    for op in all_ops:
        row = _pad(f"  {_label(op)}", LABEL_W)
        for v in vers:
            m = data[v].get(op, {})
            row += f"{_fmt(m.get('imem'))}{_fmt(m.get('dmem'))}"
        lines.append(row)

    # ── [3] 占比 ──
    lines.append(f"\n{C_BOLD}[3] 各阶段周期占比{C_END}\n" + SEP)
    total_cyc = {v: totals[v]["cyc"] for v in vers}
    for op in all_ops:
        row = _pad(f"  {_label(op)}", LABEL_W)
        for v in vers:
            row += f"{_pct(data[v].get(op,{}).get('cycles') or 0, total_cyc[v]):>10}"
        lines.append(row)

    # ── [4] ──
    lines.append(f"\n{C_BOLD}[4] 分组汇总{C_END}\n" + SEP)
    for group, members in OP_GROUPS.items():
        row = _pad(f"  {group}", LABEL_W)
        for v in vers:
            gcyc = sum(data[v].get(op, {}).get("cycles") or 0 for op in members)
            row += f"{_fmt(gcyc)}{_pct(gcyc, total_cyc[v]):>8}"
        lines.append(row)

    # ── [5] 加速比（同掩码配置内，相邻版本对比） ──
    # 分组：unmasked（无 _masked 后缀） vs masked（有 _masked 后缀）
    vers_unmasked = [v for v in vers if not v.endswith("_masked")]
    vers_masked   = [v for v in vers if v.endswith("_masked")]
    for chain_label, chain in [("(unmasked)", vers_unmasked), ("(masked)", vers_masked)]:
        if len(chain) >= 2:
            for i in range(1, len(chain)):
                prev, curr = chain[i-1], chain[i]
                lines.append(f"\n{C_BOLD}[5] 加速比 {chain_label}: {curr} vs {prev}{C_END}\n" + SEP)
                for op in all_ops:
                    prev_c = data[prev].get(op, {}).get("cycles") or 1
                    curr_c = data[curr].get(op, {}).get("cycles") or 0
                    row = _pad(f"  {_label(op)}", LABEL_W)
                    row += f"  {_speedup(prev_c, curr_c)}  {_delta(curr_c, prev_c)}"
                    lines.append(row)
                pt = totals[prev]["cyc"]; ct = totals[curr]["cyc"]
                row = _pad("  TOTAL", LABEL_W)
                row += f"  {_speedup(pt, ct)}  {_delta(ct, pt)}"
                lines.append(row)

    # ── [6] 吞吐量 ──
    lines.append(f"\n{C_BOLD}[6] 吞吐量 @100MHz (ops/sec){C_END}\n" + SEP)
    for op in all_ops:
        row = _pad(f"  {_label(op)}", LABEL_W)
        for v in vers:
            cyc = data[v].get(op, {}).get("cycles") or 0
            row += f"  {100_000_000/cyc:>10.1f}" if cyc else "  " + " " * 10 + "—"
        lines.append(row)

    # ── [7] 指令明细 ──
    for ver in vers:
        lines.append(f"\n{C_BOLD}[7] 指令明细 — {ver}{C_END}\n" + SEP)
        for op in all_ops:
            m = data[ver].get(op, {})
            freqs_str = m.get("instr_freqs", "{}")
            freqs = json.loads(freqs_str) if isinstance(freqs_str, str) else (freqs_str or {})
            if not freqs: continue
            total = sum(freqs.values())
            lines.append(f"  {C_HEAD}▸ {_label(op)}  ({total:,} total){C_END}")
            top = sorted(freqs.items(), key=lambda x: -x[1])[:10]
            max_n = top[0][1] if top else 1
            for name, cnt in top:
                pct = cnt / total * 100 if total else 0
                bar = "█" * int(cnt / max_n * 20) + "░" * (20 - int(cnt / max_n * 20))
                lines.append(f"    {_pad(name, 22)} {cnt:>10,} {pct:>5.1f}%  {bar}")

    # ── [8] 指令分类（按版本汇总） ──
    lines.append(f"\n{C_BOLD}[8] 指令类别分布{C_END}\n" + SEP)
    for ver in vers:
        merged: dict[str, int] = {}
        for op in all_ops:
            m = data[ver].get(op, {})
            cats_str = m.get("instr_categories", "{}")
            cats = json.loads(cats_str) if isinstance(cats_str, str) else (cats_str or {})
            for cat, cnt in cats.items():
                merged[cat] = merged.get(cat, 0) + cnt
        total = sum(merged.values())
        if not total:
            continue
        lines.append(f"  {C_HEAD}▸ {ver}  ({total:,} total){C_END}")
        for cat, cnt in sorted(merged.items(), key=lambda x: -x[1]):
            pct = cnt / total * 100 if total else 0
            bar = "█" * int(pct / 5) + "░" * (20 - int(pct / 5))
            lines.append(f"    {_pad(cat, 16)} {cnt:>10,} {pct:>5.1f}%  {bar}")

    # ── [9] 函数调用热点 ──
    for ver in vers:
        lines.append(f"\n{C_BOLD}[9] 函数调用热点 — {ver}{C_END}\n" + SEP)
        for op in all_ops:
            m = data[ver].get(op, {})
            funcs_str = m.get("func_calls", "{}")
            funcs = json.loads(funcs_str) if isinstance(funcs_str, str) else (funcs_str or {})
            if not funcs:
                continue
            lines.append(f"  {C_HEAD}▸ {_label(op)}{C_END}")
            max_n = max(funcs.values()) if funcs else 1
            for name, cnt in funcs.items():
                short = name if len(name) <= 50 else name[:47] + "..."
                bar = "█" * int(cnt / max_n * 20) + "░" * (20 - int(cnt / max_n * 20))
                lines.append(f"    {_pad(short, 52)} {cnt:>6}×  {bar}")

    # ── [10] 掩码 vs 非掩码对比 ──
    _append_masked_comparison(lines, vers, data, all_ops, totals)

    # ── [11] Kernel Phase Breakdown ──
    _append_phase_breakdown(lines, vers, data, all_ops)

    return "\n".join(lines)


def _append_masked_comparison(lines, vers, data, all_ops, totals):
    """[10] 掩码 vs 非掩码对比：配对 unmasked/masked 版本并生成对比表。"""
    pairs = []
    for v in vers:
        if v.endswith("_masked"):
            base = v[:-7]  # "ver2_masked" → "ver2"
            if base in vers:
                pairs.append((base, v))
    if not pairs:
        return

    lines.append(f"\n{C_BOLD}[10] 掩码 vs 非掩码对比 (DOM 24→96 cy/Keccak-f){C_END}\n" + SEP)
    hdr = _pad("  操作", LABEL_W)
    for base, masked in pairs:
        hdr += f"{_pad(masked+' Δcyc', VAL_W)}{_pad(masked+' Δ%', 9)}"
    lines.append(hdr)

    for op in all_ops:
        row = _pad(f"  {_label(op)}", LABEL_W)
        for base, masked in pairs:
            base_c = data[base].get(op, {}).get("cycles") or 0
            mask_c = data[masked].get(op, {}).get("cycles") or 0
            if base_c:
                d = mask_c - base_c
                dpct = d / base_c * 100
                row += f"{_fmt(d)}{dpct:>+7.1f}%  "
            else:
                row += f"{_fmt(mask_c)}     —  "
        lines.append(row)

    # TOTAL 行
    tr = _pad("  TOTAL", LABEL_W)
    for base, masked in pairs:
        bc = totals[base]["cyc"]
        mc = totals[masked]["cyc"]
        if bc:
            d = mc - bc
            dpct = d / bc * 100
            tr += f"{_fmt(d)}{dpct:>+7.1f}%  "
        else:
            tr += f"{_fmt(mc)}     —  "
    lines.append(tr)


def _append_phase_breakdown(lines, vers, data, all_ops):
    """[11] Kernel Phase Breakdown — 每个 OTBN App 内部 kernel 周期占比."""
    lines.append(f"\n{C_BOLD}[11] Kernel Phase Breakdown (周期占比){C_END}\n" + SEP)

    for ver in vers:
        lines.append(f"\n  {C_HEAD}── {ver} ──{C_END}")
        for op in all_ops:
            m = data[ver].get(op, {})
            pb_str = m.get("phase_breakdown", "{}")
            pb = json.loads(pb_str) if isinstance(pb_str, str) else (pb_str or {})
            if not pb:
                continue

            total_cycles = m.get("cycles") or 1
            label = _label(op)
            lines.append(f"  {C_HEAD}▸ {label}  ({total_cycles:,} cycles){C_END}")

            for cat, info in pb.items():
                insns = info.get("instructions", 0)
                cycles = info.get("cycles", 0)
                pct = info.get("pct", 0.0)
                bar_len = int(pct / 5)
                bar = "█" * bar_len + "░" * (20 - bar_len)
                lines.append(
                    f"    {_pad(cat, 20)} {insns:>8,} ins  "
                    f"{cycles:>8,} cyc  {pct:>5.1f}%  {bar}"
                )
            lines.append(f"    {'─' * 60}")

            total_insns = sum(info.get("instructions", 0) for info in pb.values())
            total_pct = sum(info.get("pct", 0) for info in pb.values())
            lines.append(
                f"    {_pad('TOTAL', 20)} {total_insns:>8,} ins  "
                f"{total_cycles:>8,} cyc  {total_pct:>5.1f}%"
            )


def report_history(db: DBManager, version: str) -> str:
    rows = db.get_history(version)
    if not rows:
        return f"{C_WARN}{version} 无历史记录{C_END}"
    lines = [f"\n{C_BOLD}▸ {version} 历史趋势{C_END}", SEP]
    by_op: dict[str, list] = {}
    for r in rows:
        op = r["operation"]
        if op not in by_op: by_op[op] = []
        by_op[op].append((r["timestamp"], r["cycles"] or 0, r["instructions"] or 0))
    for op, runs in by_op.items():
        lines.append(f"\n  {C_HEAD}{_label(op)}{C_END}  ({len(runs)} 次)")
        if len(runs) >= 2:
            lines.append(f"    首次: {_fmt(runs[0][1])}  最新: {_fmt(runs[-1][1])}  {_delta(runs[-1][1], runs[0][1])}")
        prev = 0
        for i, (ts, cyc, ins) in enumerate(runs):
            d = _delta(cyc, prev) if i > 0 else "  ———"
            lines.append(f"    #{i+1:<2} {ts}  {_fmt(cyc)} cyc  {_fmt(ins)} ins  {d}")
            prev = cyc
    return "\n".join(lines)
