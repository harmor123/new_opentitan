#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 Step 9（路 B）：从 RTL 波形量 fold 的**实测活动窗口与逐信号翻转率**。

**能测到什么、测不到什么（写死在报告里）**
  ✓ 实测：fold 子树在「一次 fold 操作」窗口内，逐信号**逐 bit 的 0→1 翻转数** ⇒ 实测 α_bit
     （α 的定义即功耗公式所用：**每拍每 bit 的 0→1 次数**）
  ✗ 测不到：**门级**活动率 —— Nangate45 只有 .lib、无 Verilog 行为模型，门级仿真不可得
     ⇒ 门级 α 只能是「其驱动信号的活动率」这一**模型**；覆盖不到的门不得写成"实测" ✗

**计数口径（不做逐拍采样比较，那会漏掉周期内的组合翻转）**
  按**时间戳分组**推进：同一时间戳内每信号只取**最后一个值**，与上一时间戳的稳定值比较，
  统计逐 bit 的 0→1。⇒ 同时间戳内的 0→1→0 抖动（delta-cycle）自动不计 ✓，周期内真实翻转全算 ✓。
  窗口 = `busy_o` 高电平段；拍数 = 窗口内**时钟上升沿**数；`α_bit = 事件数 /(位宽×拍数)`。

**VCD 真实格式**（按实测样例，不做通用假设）：`$timescale 1ps`；层级用 `$scope/$upscope` 嵌套
（scope 名是**短名**，全路径需自拼）；`$var wire 1 ua busy_o $end` ⇒ **id 变长且任意字符**
⇒ 值区用「已知 id 集合」按最长前缀切分；多 bit 为 `b<bits> <id>`，1 bit 为 `<id><值>`。

用法（Linux 侧）：
  fst2vcd -f sim.fst -o fold.vcd
  python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_activity_vcd.py \
      --vcd fold.vcd --scope u_otbn_p256_fold --clk clk_i --busy busy_o \
      --names hw/ip/otbn/pre_syn/syn_out/<L1 run>/generated/ys_translated_names \
      --out logs_hkem/p256fold_20260928T085338Z/reports/p7_activity_L1.md
  # 自测（不需要真文件）：--selftest
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


def scan_header(vcd, scope_sub, clk_name, busy_name):
    """→ (track{id:(name,width)}, clk_id, busy_id, 值区起始字节偏移)"""
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
                if len(p) >= 5 and p[1] not in ("parameter", "real", "realtime", "string", "event"):
                    width, vid, name = p[2], p[3], p[4]
                    if scope_sub in ".".join(scope):
                        w = int(width.split("[")[0]) if width[0].isdigit() else 1
                        track[vid] = (name, w)
                        if name == clk_name and clk_id is None:
                            clk_id = vid
                        if name == busy_name and busy_id is None:
                            busy_id = vid
            elif s.startswith("#"):
                return track, clk_id, busy_id, pos


def split_line(s, ids, maxlen):
    """值区一行 → (id, 值)。**两种顺序都认**：

    * `fst2vcd` 实测是 **值在前**（scalar：`0uR#` ⇒ 值 `0`、id `uR#`）；
    * VCD 标准是 **id 在前**（scalar：`ua1` ⇒ id `ua`、值 `1`）。

    先按已知 id 集合试**行尾**（实测格式），再试行首（标准格式）⇒ 两种文件都能解析；
    多 bit 的 `b<bits> <id>` 由调用方用 split() 另行处理（那种写法本身就带空格，无歧义）。"""
    n = min(maxlen, len(s))
    for L in range(n, 0, -1):                       # 值在前：id 在行尾
        if s[-L:] in ids:
            return s[-L:], s[:-L]
    for L in range(n, 0, -1):                       # id 在前（标准）
        if s[:L] in ids:
            return s[:L], s[L:]
    return None, None


def measure(vcd, scope_sub, clk_name, busy_name, max_signal_rows=40):
    track, clk_id, busy_id, pos = scan_header(vcd, scope_sub, clk_name, busy_name)
    assert track, "scope %s 下没解析到任何信号（检查 --scope）" % scope_sub
    assert clk_id and busy_id, "缺少 clk(%s)/busy(%s)" % (clk_name, busy_name)
    ids = set(track) | {clk_id, busy_id}
    maxlen = max(len(i) for i in ids)

    stable = {}                 # 上一时间戳的稳定值
    pending = {}                # 本时间戳内的最后值
    events = {i: 0 for i in track}
    windows = []
    win_cycles = 0
    busy = '0'
    clk_prev = '0'
    win_start = None
    touched_win = False

    def commit(t_end):
        """结算一个时间戳：**先**结清窗口/时钟状态，**再**在窗口内统计逐 bit 0→1，最后提交 stable。

        顺序很重要：busy 的更新必须先于事件计数（否则窗口起点那一拍的事件会被漏/误计 ✗）；
        事件只在 `busy == '1'` 时统计（窗口外不计 —— 报告的分母就是窗口拍数 ✓）。"""
        nonlocal busy, clk_prev, win_cycles, win_start
        if not pending:
            return
        # (1) 窗口与时钟
        if busy_id in pending:
            nv = pending[busy_id][-1]
            if busy == '0' and nv == '1':
                win_start = t_end
            elif busy == '1' and nv == '0':
                windows.append((win_start, t_end, win_cycles))
                win_start, win_cycles = None, 0
            busy = nv
        if clk_id in pending:
            nv = pending[clk_id][-1]
            if clk_prev == '0' and nv == '1' and busy == '1':
                win_cycles += 1
            clk_prev = nv
        # (2) 事件（仅窗口内）
        if busy == '1':
            for vid, val in pending.items():
                if vid in track:
                    old = stable.get(vid)
                    if old is not None:
                        a2 = old.rjust(len(val), '0')
                        b2 = val.rjust(len(old), '0')
                        events[vid] += sum(1 for x, y in zip(a2, b2) if x == '0' and y == '1')
        # (3) 提交
        stable.update(pending)
        pending.clear()

    with open(vcd, "r", errors="replace") as f:
        f.seek(pos)
        cur_t = 0
        for ln in f:
            if ln.startswith("#"):
                new_t = int(ln[1:].strip())
                commit(cur_t)
                cur_t = new_t
                continue
            toks = ln.split()
            if len(toks) == 2 and toks[0][:1] in ("b", "r") and toks[1] in ids:
                vid, val = toks[1], toks[0][1:]
            else:
                vid, val = split_line(ln.rstrip("\n"), ids, maxlen)
                if vid is None:
                    continue
            if vid in track or vid in (clk_id, busy_id):
                pending[vid] = val
        commit(cur_t)

    return track, windows, events


def report(track, windows, events, names_path, design):
    tot_cycles = sum(w[2] for w in windows) or 0
    rows = []
    for vid, (name, w) in track.items():
        ev = events.get(vid, 0)
        a = ev / (w * tot_cycles) if (w and tot_cycles) else 0.0
        rows.append((name, w, ev, a))
    rows.sort(key=lambda r: -r[3])
    a_bits = [(r[0], r[3]) for r in rows if r[2] > 0]
    med = a_bits[len(a_bits) // 2][1] if a_bits else 0.0
    agg_num = sum(r[2] for r in rows)
    agg_den = sum(r[1] for r in rows) * tot_cycles
    agg = agg_num / agg_den if agg_den else 0.0

    L = ["# Step 9（路 B）实测活动窗口与翻转率 %s" % ("— " + design if design else ""), ""]
    L.append("- **窗口**：`%d` 个（= fold 操作次数），逐窗口拍数 = %s，合计 **%d 拍**。"
             % (len(windows), ", ".join(str(w[2]) for w in windows[:12]) + ("…" if len(windows) > 12 else ""),
                tot_cycles))
    L.append("- **信号数**（fold 子树内）：**%d**；其中窗口内发生过翻转的 **%d** 个。" % (len(rows), len(a_bits)))
    L.append("- **实测 α_bit**（每拍每 bit 的 0→1）：**聚合 %.4f**；翻转信号的**中位 %.4f**、"
             "最小 %.4f、最大 %.4f。" % (agg, med, a_bits[-1][1] if a_bits else 0.0, a_bits[0][1] if a_bits else 0.0))
    L.append("")
    L.append("> ⚠ 这是 **RTL 信号级**实测活动率；**门级活动率不可得**（Nangate45 无 Verilog 行为模型 ⇒ 门级仿真做不了）"
             "⇒ 门级 α 只能按「其驱动信号的活动率」建模 ✗。**绝对 nJ/µJ 的性质仍是工具估计，不是硅测** ✗。")
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
        by_name = {r[0]: r[3] for r in rows}
        hit = sum(1 for _, nm in pairs if nm.split(".")[-1] in by_name)
        L.append("- **门↔信号绑定覆盖**：`ys_translated_names` 共 **%d** 组，其中 **%d** 组"
                 "（%.1f%%）能绑到实测 α（按名字末段匹配）。**未绑定的门不得写成实测** ✗。"
                 % (len(pairs), hit, 100.0 * hit / len(pairs) if pairs else 0))
        L.append("")
    return "\n".join(L)


SELFTEST_VCD = """$timescale
        1ps
$end
$scope module TOP $end
$var wire 1 ! clk $end
$var wire 1 " busy $end
$scope module u_otbn_p256_fold $end
$var wire 1 q busy_o $end
$var wire 1 ua clk_i $end
$var wire 1 ub f_o $end
$var wire 4 uc wd_o $end
$var wire 1 ud spare_d $end
$end
$end
#0
!0
"0
q0
ua0
ub0
ud0
b0000 uc
#1000
ua1
#2000
ua0
q1
#3000
ua1
ub1
#4000
ua0
#5000
ua1
b0011 uc
#6000
ua0
q0
#7000
ua1
ub0
ud1
#8000
ua0
#9000
ub1
ub0
#10000
ua1
#11000
ud0
"""


def selftest():
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        p = pathlib.Path(td) / "t.vcd"
        p.write_text(SELFTEST_VCD, encoding="utf-8")
        track, windows, events = measure(str(p), "u_otbn_p256_fold", "clk_i", "busy_o")
        names = {v[0]: k for k, v in track.items()}
        assert "busy_o" in names and "f_o" in names and "wd_o" in names, names
        # 窗口：busy_o 在 #2000→#6000 之间为 1；窗口内 clk_i 上升沿 = #3000、#5000 ⇒ 2 拍
        assert len(windows) == 1 and windows[0][2] == 2, windows
        # f_o：窗口内 #3000 一次 0→1（#7000 在窗口外 ✗ 不计；#9000 是同时间戳内 1→0 ⇒ 最终 0 ⇒ 不计）
        assert events[names["f_o"]] == 1, events[names["f_o"]]
        # wd_o：窗口内 #5000 b0000→b0011 ⇒ 2 个 bit 的 0→1
        assert events[names["wd_o"]] == 2, events[names["wd_o"]]
        # spare_d：#7000 的 0→1 在窗口外 ⇒ 必须为 0（验证"只统计窗口内"的门控）
        assert events[names["spare_d"]] == 0, events[names["spare_d"]]
        print("SELFTEST OK（标准格式 id 在前）：窗口=%s，f_o=%d，wd_o=%d，spare_d=%d（窗口外不计 ✓）"
              % (windows, events[names["f_o"]], events[names["wd_o"]], events[names["spare_d"]]))
        # 同一份波形改成“值在前”（= fst2vcd 实测格式）⇒ 结果必须**逐项相同**
        suf = []
        for ln in SELFTEST_VCD.split("\n"):
            if ln and ln[0] in ("b", "r", "$", "#") or ln == "":
                suf.append(ln)
            elif len(ln) >= 2 and ln[-1] in ("0", "1"):
                suf.append(ln[-1] + ln[:-1])        # 值在前
            else:
                suf.append(ln)
        p2 = pathlib.Path(td) / "t_suffix.vcd"
        p2.write_text("\n".join(suf), encoding="utf-8")
        tr2, w2, ev2 = measure(str(p2), "u_otbn_p256_fold", "clk_i", "busy_o")
        n2 = {v[0]: k for k, v in tr2.items()}
        assert w2 == windows, (w2, windows)
        assert ev2[n2["f_o"]] == events[names["f_o"]], (ev2[n2["f_o"]], events[names["f_o"]])
        assert ev2[n2["wd_o"]] == events[names["wd_o"]]
        assert ev2[n2["spare_d"]] == events[names["spare_d"]]
        print("SELFTEST OK（值在前 fst2vcd 格式）：窗口=%s，事件数与标准格式逐项相同 ✓" % (w2,))
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--vcd")
    ap.add_argument("--scope", default="u_otbn_p256_fold")
    ap.add_argument("--clk", default="clk_i")
    ap.add_argument("--busy", default="busy_o")
    ap.add_argument("--names", help="ys_translated_names（门↔信号绑定覆盖率）")
    ap.add_argument("--design", default="")
    ap.add_argument("--out")
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    assert args.vcd, "需要 --vcd（或 --selftest）"
    track, windows, events = measure(args.vcd, args.scope, args.clk, args.busy)
    rep = report(track, windows, events, args.names, args.design)
    print(rep)
    if args.out:
        pathlib.Path(args.out).write_text(rep + "\n", encoding="utf-8")
        print("[写] %s" % args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
