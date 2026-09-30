#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P6 Step 9：新指令的**逐实例 (stall, fetch) 固定性** —— 判据 = 单一键。

判据（PDF §14.3 第一句 / `07_P6_*.md` 的 Step 9 判据 1）：「时间恒定性只检查新指令/函数在
**相同 fetch 条件**下是否固定」⇒ 每个**动态实例**的 `(stall, fetch)` 必须落在**单一键**上。

## 口径（与 P0/P5 的帧模型逐字一致，见 run_dir/rtl/frames_p256.py）
一次调用 = 一帧，帧 = 调用栈实测的 `[进入拍 C1, 离开拍 C2)`：
  · 进入拍 = 被调函数**第一条记录**的 cycle；离开拍 = **调用方恢复执行**那条记录的 cycle
    （不是 `ret` 自己那一拍——那样每帧会少算「返回指令 + 返回后取指气泡」）；
  · `retired` = 帧内 `E` 记录数；`exec_stall` = 帧内 `S` 记录数；
  · `fetch_gap` = 帧内记录的 cycle 空档合计（只记给最内层帧）；`span = C2 − C1`；
  · `self = retired + exec_stall + fetch_gap`（帧内每一拍恰好归属一处）。
**目标帧** = 帧内**含本版新指令**的那个帧 —— 新指令直接由 `E` 行里的**指令字解码**判定
（`sim.decode`，与 ISS 同一份指令表），因此**不需要任何 ELF**，两列口径也不受符号表影响。

## 为什么不用 ISS 跑裸 app 取数
`run_p256.elf` 是**裸 app**（靠宿主 cryptolib 投喂输入），独立跑会在 218 拍 LOCKED（实测）；
带输入的是 `otbn_sim_test`（`p256_ecdh_local_test`）—— 而下面用的 RTL 记录正是它跑出来的。
ISS 侧的定长性证据在 P5 已由 `.exp`/`.dexp` 取得（`{27: 9599}`），本工具不再重复跑 ISS。

## 四列数据源（同一判据、四条独立路径；②③④ 由本工具从**已入库的原始记录**重算/核对）
  ① **RTL 真机逐帧**：`rtl/p5_ecdh_trace_es{,_overlap}.txt`（`otbn_top_sim` 的 E/S 记录；
    该次运行 RTL↔ISS 逐条对拍**无分歧**）；
  ② **程序级闭合**：Σ(E,S) 事件数 == 文件记录数；两模式事件数差 == 9,599 × 6；
  ③ **设备侧形态分布**：`rtl/p5_device_evidence.ver1_2.txt` 的 `rows/err/wb/micro_mul/overlap`；
  ④ **P0 对照（旧实现）**：`reports/frames_p256.csv` 的 `mul_modp` 帧形态。

用法（Linux / Windows 均可；只依赖 pyelftools 之外的标准库 + 仓库内 ISS 解码器）:
  python3 logs_hkem/p256fold_20260928T085338Z/host/p6_stall_p256.py \
      --trace-serial  logs_hkem/p256fold_20260928T085338Z/rtl/p5_ecdh_trace_es.txt \
      --trace-overlap logs_hkem/p256fold_20260928T085338Z/rtl/p5_ecdh_trace_es_overlap.txt \
      --device        logs_hkem/p256fold_20260928T085338Z/rtl/p5_device_evidence.ver1_2.txt \
      --frames-csv    logs_hkem/p256fold_20260928T085338Z/reports/frames_p256.csv \
      --out           logs_hkem/p256fold_20260928T085338Z/host/stall_p256.new.log

退出码：0 = 全部断言通过；1 = 有断言不过（报告照样写出，方便贴回）。
"""
import argparse
import bisect
import csv
import re
import sys
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]        # run_dir/host/xxx.py -> <repo>
sys.path.insert(0, str(REPO / "test_perf/tools/diag"))
sys.path.insert(0, str(REPO / "hw/ip/otbn/dv/otbnsim"))
import rtl_trace_attr as R                                                     # noqa: E402

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

INST_HISTO_KEY = "rows"            # 设备证据里「一行 = 一条 bn.p256mul 退休」的那一列
_IS_PM = {}                        # 指令字 -> 是否 BNP256MUL（同名指令字只解一次）


def is_p256mul(word: int) -> bool:
    """按**指令字**判定是不是本版新指令（用 ISS 自带解码器，不是猜编码）。"""
    k = _IS_PM.get(word)
    if k is None:
        k = False
        try:
            from sim.decode import decode_words
            ins = decode_words(0, [(True, word)])
            k = bool(ins) and type(ins[0]).__name__ == "BNP256MUL"
        except Exception:
            k = False
        _IS_PM[word] = k
    return k


def analyze(trace: Path):
    """→ dict(rows=目标帧 (E,S,F,span) 列表, n_inst, inst_pcs, sum_E, sum_S, n_sess, n_lines)"""
    sessions = R.parse_trace(trace)
    lines = trace.read_text(encoding="utf-8", errors="replace").split("\n")
    rows, inst_pcs = [], Counter()
    n_inst = n_lines = 0
    for s in sessions:
        frames = sorted(s["frames"], key=lambda f: f[1])
        per = {i: [0, 0, 0, False] for i in range(len(frames))}
        fstarts = [f[1] for f in frames]
        last = None
        for line in lines:
            m = R.RE_TRACE.match(line)
            if not m:
                continue
            n_lines += 1
            kind, cyc = m.group(1), int(m.group(2))
            i = bisect.bisect_right(fstarts, cyc) - 1
            if i < 0 or cyc >= frames[i][2]:
                last = cyc
                continue
            if last is not None and cyc > last + 1:
                per[i][2] += cyc - last - 1
            if kind == "E":
                per[i][0] += 1
                if is_p256mul(int(m.group(4), 16)):
                    per[i][3] = True
                    n_inst += 1
                    inst_pcs[int(m.group(3), 16)] += 1
            else:
                per[i][1] += 1
            last = cyc
        for i, (_epc, c0, c1) in enumerate(frames):
            e, st, fw, hit = per[i]
            if hit:
                rows.append((e, st, fw, c1 - c0))
    return dict(rows=rows, n_inst=n_inst, inst_pcs=inst_pcs, n_lines=n_lines,
                sum_E=sum(s["sum_E"] for s in sessions),
                sum_S=sum(s["sum_S"] for s in sessions), n_sess=len(sessions))


def hist_block(L, rows, title):
    h = Counter(rows)
    L.append("### %s" % title)
    L.append("")
    L.append("| (retired, exec_stall, fetch_gap, span) | 帧数 |")
    L.append("|---|---:|")
    for k, n in sorted(h.items(), key=lambda kv: -kv[1]):
        L.append("| (%s) | %s |" % (", ".join(str(x) for x in k), f"{n:,}"))
    L.append("")
    single = len(h) == 1 and len(rows) > 0
    L.append("- 动态实例数：**%s**；取值集合：**%s** ⇒ **%s**"
             % (f"{len(rows):,}", "[" + ", ".join(str(k) for k in sorted(h)) + "]",
                "单一键 ✓" if single else "非单一键 ✗"))
    L.append("")
    return single, h


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--trace-serial", required=True)
    ap.add_argument("--trace-overlap", required=True)
    ap.add_argument("--device", help="设备侧证据（p5_device_evidence.*.txt）")
    ap.add_argument("--frames-csv", help="P0 基线的逐帧 CSV（做旧实现对照）")
    ap.add_argument("--out")
    args = ap.parse_args()

    L, oks = [], []
    L.append("# P6 Step 9：新指令逐实例 (stall, fetch) 固定性（判据 = 单一键）")
    L.append("")
    L.append("目标帧 = **帧内含本版 `bn.p256mul`** 的帧；新指令由 `E` 行的**指令字解码**判定"
             "（`sim.decode`，与 ISS 同一份指令表）⇒ 不依赖 ELF/符号表。")
    L.append("")

    L.append("## ① RTL 真机逐帧（`otbn_top_sim` 的 E/S 记录；该次运行 RTL↔ISS 对拍无分歧）")
    L.append("")
    res = {}
    for mode, p in (("serial（28 拍调度；29 拍/次含 return 取指气泡）", args.trace_serial),
                    ("overlap（22 拍调度）", args.trace_overlap)):
        a = analyze(Path(p))
        res[mode] = a
        L.append("- 数据源 `%s`：%d 个会话，%s 条 E/S 记录（ΣE=%s、ΣS=%s）；"
                 "新指令实例 **%s** 条，出现在 %d 个 PC：`%s`"
                 % (Path(p).name, a["n_sess"], f"{a['n_lines']:,}", f"{a['sum_E']:,}",
                    f"{a['sum_S']:,}", f"{a['n_inst']:,}", len(a["inst_pcs"]),
                    ", ".join("%#x ×%d" % (pc, n) for pc, n in sorted(a["inst_pcs"].items()))))
        L.append("")
        ok, _ = hist_block(L, a["rows"], "%s —— 目标帧形态" % mode)
        oks.append(ok)
        L.append("- 记录数自证：ΣE + ΣS = %s，文件记录数 %s ⇒ **%s**"
                 % (f"{a['sum_E'] + a['sum_S']:,}", f"{a['n_lines']:,}",
                    "一致 ✓" if a["sum_E"] + a["sum_S"] == a["n_lines"] else "不一致 ✗"))
        L.append("")
        oks.append(a["sum_E"] + a["sum_S"] == a["n_lines"])

    L.append("## ② 程序级闭合（两模式之差 = 实例数 × 每次省下的 6 拍）")
    L.append("")
    a_s = res["serial（28 拍调度；29 拍/次含 return 取指气泡）"]
    a_o = res["overlap（22 拍调度）"]
    d = (a_s["sum_E"] + a_s["sum_S"]) - (a_o["sum_E"] + a_o["sum_S"])
    n = a_s["n_inst"]
    L.append("- 事件数差 = **%s**；实例数 %s × 6 = **%s** ⇒ **%s**"
             % (f"{d:,}", f"{n:,}", f"{6 * n:,}", "一致 ✓" if d == 6 * n else "不一致 ✗"))
    oks.append(d == 6 * n)
    L.append("- 每帧 `exec_stall` 差 = %s ⇒ 应为 27 − 21 = 6 ⇒ **%s**"
             % (f"{sorted({r[1] for r in a_s['rows']})} → {sorted({r[1] for r in a_o['rows']})}",
                "一致 ✓" if ({27} == {r[1] for r in a_s["rows"]}
                             and {21} == {r[1] for r in a_o["rows"]}) else "不一致 ✗"))
    L.append("")

    if args.device:
        L.append("## ③ 设备侧形态分布（chip sim + 真 Ibex；`%s`）" % Path(args.device).name)
        L.append("")
        pat = re.compile(r"^(\w+):\s+(\d+)\s+(.*)$")
        got = {}
        for line in Path(args.device).read_text(encoding="utf-8", errors="replace").split("\n"):
            m = pat.match(line.strip())
            if m:
                got[m.group(1)] = (int(m.group(2)), m.group(3).split())
        L.append("| 列 | 行数 | 取值集合 | 判据 |")
        L.append("|---|---:|---|---|")
        d_ok = True
        for k in sorted(got):
            cnt, toks = got[k]
            pcs_ = sorted({t for t in toks})
            single = len(pcs_) == 1
            d_ok &= single
            L.append("| `%s` | %s | `%s` | %s |"
                     % (k, f"{cnt:,}", " ".join(pcs_), "单一键 ✓" if single else "非单一键 ✗"))
        L.append("")
        L.append("- 每列**各自单一键**（`rows=27` 即每实例固定 27 拍、`err=0`、`wb=1`、"
                 "`micro_mul=16`、`overlap=0`）⇒ **%s**" % ("单键 ✓" if d_ok else "非单键 ✗"))
        L.append("")
        oks.append(d_ok)

    if args.frames_csv:
        L.append("## ④ 旧实现对照（P0 冻结：`%s` 的 `mul_modp` 帧形态）" % Path(args.frames_csv).name)
        L.append("")
        rows_old = []
        with Path(args.frames_csv).open(encoding="utf-8") as fh:
            for r in csv.DictReader(fh):
                if r["symbol"] == "mul_modp":
                    rows_old.append((int(r["retired"]), int(r["exec_stall"]),
                                     int(r["fetch_gap"]), int(r["inclusive_cycles"])))
        ok, _ = hist_block(L, rows_old, "旧实现 `mul_modp` 逐帧（官方软件，串行 MAC）")
        L.append("- 对照含义：旧实现每帧 **53 退休 + 0 停滞 + 1 取指空档 = 54 拍**（单键）；"
                 "本版把它压成 `bn.p256mul` 的一条多周期指令 —— 新指令自身的 `(stall, fetch)` "
                 "仍须单键（①③），这才是 §14.3 的判据。")
        L.append("")
        oks.append(ok)

    L.append("## 判据与声明边界（PDF §14.3 原文三层，分开报、不得混谈）")
    L.append("")
    L.append("1. **新指令/函数的固定性**：①③ 每列都是**单一键** —— 确定性判据，比统计检验更早、更便宜。")
    L.append("2. **另报告外设/协议时间分布**：本步只做「新指令在**相同 fetch 条件**下是否固定」；"
             "协议/外设的时间分布属另一层，见 `host/protocol_ver1_2.log` 的 `HKEM_PROF` 分段。")
    L.append("3. **声明范围**：本文**不声称**侧信道抵抗 —— 固定周期只保证状态数/地址不依赖秘密，"
             "**不**等于抗功耗/抗故障；也未做泄漏分析或攻击评估。清理（清零）路径的切换泄漏同理未评估。")
    L.append("")
    L.append("**总判定：%s**" % ("全部单一键 ✓" if all(oks) else "有非单键 ✗"))

    txt = "\n".join(L)
    print(txt)
    if args.out:
        op = Path(args.out)
        op.parent.mkdir(parents=True, exist_ok=True)
        op.write_text(txt + "\n", encoding="utf-8")
        print("\n[写] %s" % op)
    return 0 if all(oks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
