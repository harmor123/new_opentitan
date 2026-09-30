#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 Step 9（路 B）：从 RTL 波形量 fold 的**实测活动窗口与逐信号翻转率**（重写版，两遍结构）。

**为什么要两遍**：早期版本"边解析边计数"（单遍流式）在"时钟沿与状态更新同一时间戳""同一时间戳多次变化"
这些边界上先后错了 4 次 ✗ ⇒ 改为：① 头部 → id 集合/时钟/窗口/值区偏移；② 值区 → 快照表
`[(t, {id: 值})]`（同一时间戳内每 id 只留最后值 ⇒ delta-cycle 抖动自动消失 ✓）；③ 纯数据上算窗口与翻转。

**格式判定（不逐行猜 ✗）**：scalar 行两种顺序各自只有一种自洽解释（值恒 1 字符）：
  * `fst2vcd` 实测 **值在前**（`1!`、`0ua`）⇒ 值=`s[0]`、id=`s[1:]`；* VCD 标准 **id 在前** ⇒ id=`s[:-1]`、值=`s[-1]`。
  先取值区前若干行**统计命中数**定一次格式，再全文一致使用；判定结果写进报告（可复核 ✓）。
  vector 一律 `b<bits> <id>`（带空格 ⇒ 无歧义 ✓）。**同一个网跨 scope 共用 id**（fold 的 `clk_i` ≡ 顶层
  `IO_CLK`）⇒ 层次只能按 `$scope` 路径判 ✓。

**能测/不能测（写死在报告里）**：RTL 信号级活动率**实测** ✓；**门级不可得**（Nangate45 无 Verilog 行为模型
⇒ 门级仿真做不了）⇒ 门级 α 只能是「其驱动信号的活动率」的**模型** ✗；绝对 nJ/µJ 仍是**工具估计**，不是硅测 ✗。

**自检（不过则非零退出、数值不得引用）**：逐信号 α_bit ≤ 1（物理上界 ✓）；各窗口拍数**唯一**（早退/漏拍即 ✗）。

用法：
  python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_activity_vcd.py \
      --vcd fold.vcd --scope u_otbn_p256_fold --clk clk_i --busy busy_o \
      --names <L1 run>/generated/ys_translated_names --design "L1（fold 子树）" \
      --out logs_hkem/p256fold_20260928T085338Z/reports/p7_activity_L1.md
  # 自测：--selftest
"""
import argparse
import pathlib
import re
import sys

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

NET_KINDS = ("wire", "logic", "reg", "integer", "bit")
SAMPLE_LINES = 4000


def scan_header(vcd, scope_sub, clk_name, busy_name):
    """① → (track{id:(name,width)}, clk_id, busy_id, 值区起始字节偏移)"""
    scope, track = [], {}
    clk_id = busy_id = None
    with open(vcd, "r", errors="replace") as f:
        while True:
            pos = f.tell()
            ln = f.readline()
            if not ln:
                return track, clk_id, busy_id, None
            s = ln.strip()
            if s.startswith("$scope"):
                p = s.split()
                scope.append(p[2] if len(p) > 2 else "")
            elif s.startswith("$upscope"):
                if scope:
                    scope.pop()
            elif s.startswith("$var"):
                p = s.split()
                if len(p) >= 5 and p[1] in NET_KINDS and scope_sub in ".".join(scope):
                    track[p[3]] = (p[4], int(p[2]) if p[2][0].isdigit() else 1)
                    if p[4] == clk_name and clk_id is None:
                        clk_id = p[3]
                    if p[4] == busy_name and busy_id is None:
                        busy_id = p[3]
            elif s.startswith("#"):
                return track, clk_id, busy_id, pos


def detect_format(vcd, pos, ids):
    """取值区前 SAMPLE_LINES 行统计两种顺序的命中数 ⇒ (value_first, 说明)"""
    hvf = hif = 0
    with open(vcd, "r", errors="replace") as f:
        f.seek(pos)
        for n, ln in enumerate(f):
            if n > SAMPLE_LINES:
                break
            if ln.startswith("#"):
                continue
            toks = ln.split()
            if len(toks) == 2 and toks[0][:1] in ("b", "r") and toks[1] in ids:
                continue
            s = ln.rstrip("\n")
            if len(s) < 2:
                continue
            if s[1:] in ids:
                hvf += 1
            if s[:-1] in ids:
                hif += 1
    vf = hvf >= hif
    return vf, ("值在前（fst2vcd 实测）命中 %d" % hvf) if vf else ("id 在前（VCD 标准）命中 %d" % hif)


def read_snaps(vcd, pos, ids):
    """② → [(t, {id:值})]；同一时间戳内每 id 只留最后值 ✓"""
    vf, fmt = detect_format(vcd, pos, ids)
    snaps = []
    with open(vcd, "r", errors="replace") as f:
        f.seek(pos)
        t, cur = 0, {}
        for ln in f:
            if ln.startswith("#"):
                if cur:
                    snaps.append((t, cur))
                    cur = {}
                t = int(ln[1:].strip())
                continue
            toks = ln.split()
            if len(toks) == 2 and toks[0][:1] in ("b", "r") and toks[1] in ids:
                cur[toks[1]] = toks[0][1:]
                continue
            s = ln.rstrip("\n")
            if len(s) < 2:
                continue
            vid = s[1:] if vf else s[:-1]
            val = s[0] if vf else s[-1]
            if vid in ids:
                cur[vid] = val
        if cur:
            snaps.append((t, cur))
    return snaps, fmt


def measure(vcd, scope_sub, clk_name, busy_name):
    """③ 纯数据：窗口边界 + 窗口内时钟上升沿数 + 窗口内逐 bit 0→1"""
    track, clk_id, busy_id, pos = scan_header(vcd, scope_sub, clk_name, busy_name)
    assert track, "scope %s 下没解析到任何信号（检查 --scope）" % scope_sub
    assert clk_id and busy_id, "缺少 clk(%s)/busy(%s)" % (clk_name, busy_name)
    ids = set(track) | {clk_id, busy_id}
    snaps, fmt = read_snaps(vcd, pos, ids)

    events = {i: 0 for i in track}
    windows, prev = [], {}
    busy, clk_prev, win_start, win_cycles = '0', '0', None, 0
    for t, ch in snaps:
        if busy_id in ch:                                    # (1) 窗口边界先结清
            nv = ch[busy_id][-1]
            if busy == '0' and nv == '1':
                win_start = t
            elif busy == '1' and nv == '0':
                windows.append((win_start, t, win_cycles))
                win_start, win_cycles = None, 0
            busy = nv
        if clk_id in ch:                                     # (2) 窗口内时钟上升沿
            nv = ch[clk_id][-1]
            if clk_prev == '0' and nv == '1' and busy == '1':
                win_cycles += 1
            clk_prev = nv
        if busy == '1':                                      # (3) 窗口内逐 bit 0→1
            for vid, val in ch.items():
                if vid in track and vid in prev:
                    a, b = prev[vid], val
                    a2, b2 = a.rjust(len(b), '0'), b.rjust(len(a), '0')
                    events[vid] += sum(1 for x, y in zip(a2, b2) if x == '0' and y == '1')
        prev.update(ch)
    return track, windows, events, fmt


def report(track, windows, events, fmt, names_path, design):
    tot = sum(w[2] for w in windows)
    rows = []
    for vid, (name, w) in track.items():
        ev = events.get(vid, 0)
        rows.append((name, w, ev, (ev / (w * tot)) if (w and tot) else 0.0))
    rows.sort(key=lambda r: -r[3])
    fl = [r for r in rows if r[2] > 0]
    med = fl[len(fl) // 2][3] if fl else 0.0
    agg = (sum(r[2] for r in rows) / (sum(r[1] for r in rows) * tot)) if tot else 0.0
    over = [r for r in rows if r[3] > 1.0 + 1e-9]
    uniq = sorted(set(w[2] for w in windows))
    ok = bool(windows) and not over and len(uniq) == 1

    L = ["# Step 9（路 B）实测活动窗口与翻转率 %s" % ("— " + design if design else ""), ""]
    L.append("- **值区格式判定**：%s（两种顺序按全文/样本命中数定，随后全文一致使用 ✓）。" % fmt)
    L.append("- **窗口**：`%d` 个（= fold 操作次数）；逐窗口拍数 = %s；合计 **%d 拍**。"
             % (len(windows), ", ".join(str(w[2]) for w in windows[:20]) + ("…" if len(windows) > 20 else ""), tot))
    L.append("- **信号数**（fold 子树内、已排除 parameter）：**%d**；窗口内发生过翻转的 **%d** 个。" % (len(rows), len(fl)))
    L.append("- **实测 α_bit**（每拍每 bit 的 0→1）：**聚合 %.4f**；翻转信号**中位 %.4f**、最小 %.4f、最大 %.4f。"
             % (agg, med, fl[-1][3] if fl else 0.0, fl[0][3] if fl else 0.0))
    L.append("")
    if ok:
        L.append("- ✅ **自检通过**：所有 α_bit ≤ 1 ✓；各窗口拍数**唯一** = **%d** ⇒ 与 RTL 契约「完成周期固定、"
                 "无早退」一致 ✓。" % uniq[0])
    else:
        L.append("- ⛔ **自检未过 ⇒ 本报告数值不得引用**：%s%s%s"
                 % ("有 %d 个信号 α_bit > 1（物理上界被破）：%s；" % (len(over),
                    ", ".join("`%s`=%.3f" % (r[0], r[3]) for r in over[:6])) if over else "",
                    "窗口拍数不唯一（%s）⇒ 早退/漏拍；" % uniq if len(uniq) > 1 else "",
                    "没有任何窗口。" if not windows else ""))
    L.append("")
    L.append("> ⚠ **RTL 信号级**实测活动率；**门级活动率不可得**（Nangate45 无 Verilog 行为模型 ⇒ 门级仿真做不了）"
             "⇒ 门级 α 只能是「其驱动信号的活动率」的**模型** ✗。**绝对 nJ/µJ 仍是工具估计，不是硅测** ✗。")
    L.append("")
    L.append("## 翻转率最高的信号（top %d）" % min(20, len(rows)))
    L.append("")
    L.append("| 信号 | 位宽 | 0→1 事件数 | α_bit |")
    L.append("|---|---:|---:|---:|")
    for name, w, ev, a in rows[:20]:
        L.append("| `%s` | %d | %d | %.4f |" % (name, w, ev, a))
    L.append("")
    if names_path and pathlib.Path(names_path).exists():
        t = pathlib.Path(names_path).read_text(encoding="utf-8", errors="replace")
        pairs = re.findall(r"^(?:.*/)?(_\d+_)\s*\n(?:.*/)?(\S+)\s*$", t, re.M)
        by = {r[0]: r[3] for r in rows}
        hit = sum(1 for _, nm in pairs if nm.split("/")[-1].split(".")[-1] in by)
        L.append("- **门↔信号绑定覆盖**：映射共 **%d** 组，其中 **%d** 组（%.1f%%）能绑到实测 α。"
                 "**未绑定的门不得写成实测** ✗（该映射只覆盖出现在时序报告里的网 ✗）。"
                 % (len(pairs), hit, 100.0 * hit / len(pairs) if pairs else 0))
        L.append("")
    return "\n".join(L), ok


def _mk_vcd(value_first=True, cycles=28, n_windows=3, n_sig=60, tstep=1000):
    """合成波形：复刻真实结构（嵌套 scope、`!`/`ua`/`va` 变长 id、每拍上百信号同时变化、
    窗口内同时间戳抖动、窗口外一次 0→1）。"""
    def s(vid, val):
        return ("%s%s" % (val, vid)) if value_first else ("%s%s" % (vid, val))

    def b(vid, val):
        return "b%s %s" % (val, vid)

    sigs = ["u%d" % i for i in range(1, n_sig + 1)]
    wid = {v: (1 if int(v[1:]) % 3 else 4) for v in sigs}
    L = ["$timescale", " 1ps", "$end",
         "$scope module TOP $end", "$var wire 1 ! IO_CLK $end", "$var wire 1 q busy $end",
         "$scope module u_otbn_p256_fold $end",
         "$var wire 1 ! clk_i $end", "$var wire 1 ua busy_o $end",
         "$var wire 5 va cycle_o $end", "$var wire 1 ub spare_d $end",
         "$var parameter 260 >2! P260 $end"]
    L += ["$var wire %d %s sig%s $end" % (wid[v], v, v[1:]) for v in sigs]
    L += ["$upscope $end", "$upscope $end", "#0",
          s("!", "0"), s("q", "0"), s("ua", "0"), b("va", "00000"), s("ub", "0")]
    L += [b(v, "0" * wid[v]) for v in sigs]
    t = tstep
    for _w in range(n_windows):
        for c in range(cycles):
            L.append("#%d" % t)
            L += [s("!", "1"), b("va", "%05d" % ((c + 1) % 32)), s("ub", "1"), s("ub", "0")]
            if c == 0:
                L.append(s("ua", "1"))
            L += [b(v, "1" * wid[v]) for v in sigs]
            L += ["#%d" % (t + tstep // 2), s("!", "0")]
            L += [b(v, "0" * wid[v]) for v in sigs]
            t += tstep
        L += ["#%d" % t, s("ua", "0"), s("ub", "1")]        # 窗口外一次 0→1（不得计）
        t += tstep
    L.append("#%d" % t)
    return "\n".join(L) + "\n"


def selftest():
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        for vf in (True, False):
            p = pathlib.Path(td) / ("vf%d.vcd" % vf)
            p.write_text(_mk_vcd(vf), encoding="utf-8")
            track, windows, events, fmt = measure(str(p), "u_otbn_p256_fold", "clk_i", "busy_o")
            nm = {v[0]: k for k, v in track.items()}
            assert "P260" not in nm, "parameter 未排除"
            assert len(windows) == 3, windows
            assert all(w[2] == 28 for w in windows), windows               # 验收 1：每窗口 28 拍
            tot = sum(w[2] for w in windows)
            over = [n for n, (_, wd) in track.items() if events.get(n, 0) / (wd * tot) > 1.0 + 1e-9]
            assert not over, over                                          # 验收 2：α ≤ 1
            assert events[nm["spare_d"]] == 0, events[nm["spare_d"]]       # 窗口外不计
            assert events[nm["cycle_o"]] > 0
            print("SELFTEST OK（%s）：3 窗口 × 28 拍 ✓  α≤1 ✓  窗口外不计 ✓  fmt=%s"
                  % ("值在前" if vf else "id 在前", fmt))
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--vcd")
    ap.add_argument("--scope", default="u_otbn_p256_fold")
    ap.add_argument("--clk", default="clk_i")
    ap.add_argument("--busy", default="busy_o")
    ap.add_argument("--names")
    ap.add_argument("--design", default="")
    ap.add_argument("--out")
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    assert args.vcd, "需要 --vcd（或 --selftest）"
    track, windows, events, fmt = measure(args.vcd, args.scope, args.clk, args.busy)
    rep, ok = report(track, windows, events, fmt, args.names, args.design)
    print(rep)
    if args.out:
        pathlib.Path(args.out).write_text(rep + "\n", encoding="utf-8")
        print("[写] %s" % args.out)
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
