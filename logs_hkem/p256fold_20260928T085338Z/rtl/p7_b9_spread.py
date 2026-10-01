#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""B-9 收口：设备侧跨度（cycles）的**重复测量抖动**（>5 个样本/op 型）。

背景：`09_测量与归因_§12` 的 B-9 问「§12.6 的『至少 5 次配对』起点是否适用于算术段」。
现成样本：三次 chip sim 运行（ver1_1 树、ver1_2 树、自包含化后复核）各含
Keygen A/B + ECDH A/B 四个会话 ⇒ **每个 op 型 6 个样本** ✓（>5）。

判据（写进输出，不成立即非零退出）：
  · 每型样本数 ≥ 5；
  · **指令数跨全部样本逐位相同**（`0x14ac7` / `0x166f5`）—— 这才是锚点 ✓；
  · 跨度为宿主侧量（含装 app/轮询/擦除），抖动以极差/% 给出，判收益一律用**同次配对差值** ✓。

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_b9_spread.py
产物：reports/p7_span_spread.md
"""
import pathlib
import re
import sys

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = pathlib.Path(__file__).resolve().parents[3]
RUN = REPO / "logs_hkem/p256fold_20260928T085338Z"
LOGS = [("ver1_1", RUN / "rtl/p5_device_evidence.ver1_1.txt"),
        ("ver1_2", RUN / "rtl/p5_device_evidence.ver1_2.txt"),
        ("recheck", RUN / "rtl/p5_device_recheck.ver1_2.txt")]
SESSIONS = ("Keygen A", "Keygen B", "ECDH A", "ECDH B")
OPTYPES = {"keygen": ("Keygen A", "Keygen B"), "ecdh": ("ECDH A", "ECDH B")}


def main() -> int:
    data = {s: [] for s in SESSIONS}          # 会话 → [(run, insn_hex, cycles)]
    for tag, p in LOGS:
        txt = p.read_text(encoding="utf-8", errors="replace")
        for s in SESSIONS:
            # 只取不带 "[folds so far" 前缀的那一行（另一份是同一行的重复渲染）
            m = re.search(r"^I\d+ test_p256_only\.c:\d+\] %s OTBN instruction count: 0x([0-9a-f]+), cycles: (\d+)$"
                          % re.escape(s), txt, re.M)
            assert m, ("缺 %s 的 %s 行" % (tag, s))
            data[s].append((tag, m.group(1), int(m.group(2))))

    L = []
    L.append("# B-9 收口：设备跨度的重复测量抖动（`09_测量与归因_§12` 的 B-9）")
    L.append("")
    L.append("样本单位 = **op 型**（Keygen / ECDH）：三次 chip sim 运行 × {A,B} 两侧 = **6 个样本/型**（>5 ✓）。"
             "A/B 只差一个随机标量，且实现是定长的 ⇒ 同一 op 的 A/B 是一次合法的**重复测量** ✓。")
    L.append("")
    L.append("| op 型 | 样本(cycles，按 运行×侧) | 极差 | %（相对最小值） | 指令数（全部样本） |")
    L.append("|---|---:|---:|---:|---|")
    ok = True
    for op, sess in OPTYPES.items():
        rows = []
        for s in sess:
            assert len(data[s]) == 3, (s, len(data[s]))
            rows += [(s + "/" + tag, i, c) for tag, i, c in data[s]]
        assert len(rows) >= 5, (op, len(rows))
        cyc = [c for _t, _i, c in rows]
        insn = {i for _t, i, _c in rows}
        assert len(insn) == 1, ("指令数跨样本不一致", op, sorted(insn))     # 锚点必须逐位相同
        lo, hi = min(cyc), max(cyc)
        L.append("| %s | %s | **%d** | **%.2f%%** | `0x%s`（%d 个样本全同 ✓）|"
                 % (op, " / ".join(format(c, ",") for c in cyc), hi - lo,
                    100.0 * (hi - lo) / lo, insn.pop(), len(cyc)))
    L.append("")
    spread = {op: 100.0 * (max(c for _t, _i, c in [(s2 + "/" + tg, i2, c2) for s2 in sess for tg, i2, c2 in data[s2]])
                           - min(c for _t, _i, c in [(s2 + "/" + tg, i2, c2) for s2 in sess for tg, i2, c2 in data[s2]]))
              / min(c for _t, _i, c in [(s2 + "/" + tg, i2, c2) for s2 in sess for tg, i2, c2 in data[s2]])
              for op, sess in OPTYPES.items()}
    L.append("**结论（B-9 收口）**：算术段（P-256 会话）**指令数是确定性锚点**（跨 6 个样本逐位相同 ✓），"
             "跨度含宿主固定开销与**实测抖动 %s（见上表）** ⇒ **收益判定用同次运行的配对差值**（如协议端到端 −57,560 拍，"
             "§8.16）**不用跨次相减** ✓；『≥5 次配对』在本表由 6 样本覆盖 ✓。"
             % (" / ".join("%.2f%%" % v for v in spread.values())))
    L.append("")
    out = RUN / "reports/p7_span_spread.md"
    out.write_text("\n".join(L) + "\n", encoding="utf-8")
    print("\n".join(L))
    print("[写] %s" % out)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
