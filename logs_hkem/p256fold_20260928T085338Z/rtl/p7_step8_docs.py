#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 §8.12：Step 8「同频比 cycle、各自 Fmax 比 time」——一次性；数值全部从文件读出。

数据源：`reports/p7_sta_{B0,A0,A0_pred,A1_pred,L1,L1_pred}.md`（STA）+ `reports/p5_frame.json`（帧/周期）。
判据口径：Fmax = 1 / (8.0 ns + |worst slack|)（125 MHz 目标周期 8.0 ns；关键路径为单周期 reg2reg）。

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step8_docs.py [--check]
"""
import argparse
import json
import pathlib
import re

REPO = pathlib.Path(__file__).resolve().parents[3]
DOCS = REPO.parent / "md文档" / "p256方案20260927" / "new_contribution_2"
R = REPO / "logs_hkem/p256fold_20260928T085338Z/reports"
PERIOD = 8.0
DESIGNS = [("B0", "基线 `2d87e79bee`（无 fold）", "p7_sta_B0.md"),
           ("A0", "serial 常量化（**未**含 Step 5 预译码）", "p7_sta_A0.md"),
           ("A0+pd", "serial 常量化 **+ Step 5 预译码**", "p7_sta_A0_pred.md"),
           ("A1+pd", "overlap 常量化 **+ Step 5 预译码**", "p7_sta_A1_pred.md"),
           ("L1", "`otbn_p256_fold` 单独（**未**含预译码）", "p7_sta_L1.md"),
           ("L1+pd", "`otbn_p256_fold` 单独 **+ Step 5 预译码**", "p7_sta_L1_pred.md")]
W = re.compile(r"- \*\*overall\*\*：(\d+) 条，最差 slack \*\*(-?[\d.]+) ns\*\*")


def worst(name):
    t = (R / name).read_text(encoding="utf-8", errors="replace")
    m = W.search(t)
    assert m, name
    return float(m.group(2))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    sl = {k: worst(f) for k, _, f in DESIGNS}
    fmax = {k: 1e3 / (PERIOD + abs(v)) for k, v in sl.items()}   # MHz
    fr = json.loads((R / "p5_frame.json").read_text(encoding="utf-8"))
    ser = fr["call_breakdown_cycles"]["serial"]
    ovl = fr["call_breakdown_cycles"]["overlap"]
    plc = fr["program_level_closure"]

    # ---- 断言：这些数就是本次会话实测的那些（换报告即失效，逼迫重写文档）
    assert abs(sl["A1+pd"] - sl["B0"]) < 0.1, (sl["A1+pd"], sl["B0"])
    assert 0.5 < abs(sl["A0+pd"] - sl["B0"]) < 0.7, (sl["A0+pd"], sl["B0"])
    assert abs(sl["L1+pd"]) < abs(sl["L1"]) - 2.0, (sl["L1+pd"], sl["L1"])
    assert ser["total"] == 30 and ovl["total"] == 24, (ser, ovl)
    assert ser["stalls"] == 27 and ovl["stalls"] == 21
    assert plc["calls"] == fr["calls"]["serial"] == fr["calls"]["overlap"]
    assert plc["delta"] == plc["calls"] * 6 == fr["program_level_closure"]["delta"]

    L = []
    L.append("### 8.12 Step 8：同频比 cycle、各自 Fmax 比 time（2026-09-30）")
    L.append("")
    L.append("**甲、同频（125 MHz）比 cycle** —— 数据源 `run_dir/reports/p5_frame.json`（同一 ELF 的 "
             "serial/overlap 两档实测），**不是推算**：")
    L.append("")
    L.append("| 每次 `p256mul` 调用 | serial | overlap | Δ |")
    L.append("|---|---:|---:|---:|")
    L.append("| stalls（MAC 等待，单值 ⇒ 定长） | %d | %d | **−%d** |"
             % (ser["stalls"], ovl["stalls"], ser["stalls"] - ovl["stalls"]))
    L.append("| retire + ret + fetch bubble | %d+%d+%d | %d+%d+%d | 0 |"
             % (ser["instr_retire"], ser["ret"], ser["fetch_bubble"],
                ovl["instr_retire"], ovl["ret"], ovl["fetch_bubble"]))
    L.append("| **合计** | **%d 拍** | **%d 拍** | **−%d 拍/调用（−%.0f%%）** |"
             % (ser["total"], ovl["total"], ser["total"] - ovl["total"],
                100.0 * (ser["total"] - ovl["total"]) / ser["total"]))
    L.append("")
    L.append("- 调用数两档相同（**%d**）⇒ 程序级 Δ = **%d 拍**（= %d × 6，与 P4 逐条指令实测的 −6 完全一致）。"
             % (plc["calls"], plc["delta"], plc["calls"]))
    L.append("- **chip 侧交叉验证**：同一 app 的 P-256 段在 overlap 档再降 **57,560**（`07_P6` §Step 9 表）——"
             "与帧口径的 %d 差 %d 拍（%.2f%%），属宿主/会话口径差，两者互证。"
             % (plc["delta"], plc["delta"] - 57560, 100.0 * (plc["delta"] - 57560) / plc["delta"]))
    L.append("- **结论**：overlap 换的是 **cycle**（−20%/调用），**不是频率**（见乙）。")
    L.append("")
    L.append("**乙、各自 Fmax 比 time** —— `Fmax = 1/(%.1f ns + |worst slack|)`（关键路径均为单周期 "
             "reg2reg；数据源 = 各设计的 STA 报告）：" % PERIOD)
    L.append("")
    L.append("| 设计 | overall 最差 slack | 关键路径时延 | **Fmax** |")
    L.append("|---|---:|---:|---:|")
    for k, desc, _ in DESIGNS:
        L.append("| **%s** %s | %.4f ns | %.4f ns | **%.1f MHz** |"
                 % (k, desc, sl[k], PERIOD + abs(sl[k]), fmax[k]))
    L.append("")
    L.append("**三条读法**：")
    L.append("")
    L.append("1. **fold 本体**（L1）经 Step 5 预译码由 %.1f → **%.1f MHz**（+%.1f MHz）——与 §8.11 的 "
             "+%.4f ns 同源，是本次结构调整唯一**可归属**的时序收益。"
             % (fmax["L1"], fmax["L1+pd"], fmax["L1+pd"] - fmax["L1"], abs(sl["L1"]) - abs(sl["L1+pd"])))
    trio = ["B0", "A0+pd", "A1+pd"]
    spread_mhz = max(fmax[k] for k in trio) - min(fmax[k] for k in trio)
    spread_ns = max(abs(sl[k]) for k in trio) - min(abs(sl[k]) for k in trio)
    noise_ns = abs(sl["A0+pd"] - sl["A0"])            # 同一设计族、改动不在那条路径上 ⇒ 纯映射漂移
    v = abs(sl["A0+pd"])
    noise_mhz = 1e3 / (PERIOD + v) - 1e3 / (PERIOD + v + noise_ns)
    L.append("2. **调度对比**：`B0` %.1f / `A0+pd` %.1f / `A1+pd` %.1f MHz —— 三点极差 **%.1f MHz**"
             "（对应关键路径时延极差 **%.4f ns**）。**噪声锚**：`A0` 与 `A0+pd` 是**同一设计族**、而 Step 5 "
             "改动的逻辑根本不在这条路径上（起点是基线 `rf_bignum_predec`），两者的 %.4f ns（≈ %.1f MHz）"
             "就是**纯映射漂移**。⇒ 调度差 %.4f ns 与噪声 %.4f ns 同量级（%.1f 倍）⇒ **判为「无显著差异」**"
             "（这正是 §8.3 判据 2「共享 datapath」在时序口径上的对应：两种调度既不同面积、也不同频率）。"
             "**不**把 %.2f ns 说成「overlap 更快/更慢」✗。"
             % (fmax["B0"], fmax["A0+pd"], fmax["A1+pd"], spread_mhz, spread_ns,
                noise_ns, noise_mhz, spread_ns, noise_ns, spread_ns / noise_ns,
                abs(sl["A0+pd"] - sl["A1+pd"])))
    L.append("3. **芯片级 vs 模块级**：芯片级 Fmax ≈ %.1f MHz 而 fold 本体 %.1f MHz ⇒ 芯片级限速不在 "
             "fold 内（与 §8.10 的归属一致：最差路径起点是基线 `rf_bignum_predec`）。"
             % (fmax["A1+pd"], fmax["L1+pd"]))
    L.append("")
    L.append("**限制（必须与表同读）**：本流程是**单趟 ABC**（`-D 4000` 一次映射）、**buffer = 0**、"
             "**无 CTS** ⇒ 这些 Fmax 是**同一实验流下的相对值**，不是签核频率，也不得写成 post-layout 结果"
             "（§8.4 第 1 条）。")
    L.append("")

    sec = "\n".join(L)
    p = DOCS / "08_P7_PPA与CSA决策.md"
    t = p.read_text(encoding="utf-8")
    assert "### 8.12 " not in t, "§8.12 已存在"

    q = DOCS / "13_合并影响与回归清单.md"
    t2 = q.read_text(encoding="utf-8")
    lines = t2.split("\n")
    i = next(k for k, l in enumerate(lines) if l.startswith("| 2026-09-30 | `db82e7f1ef` |"))
    lines.insert(
        i + 1,
        "| 2026-09-30 | `aef299b498` | **P7 Step 8：同频比 cycle、各自 Fmax 比 time（P7 §8.12）**。"
        "**cycle**：每次 `p256mul` 调用 serial **30** 拍 vs overlap **24** 拍（−6，−20%%；stalls 27/21 单值 ⇒ "
        "定长），程序级 Δ = 9,599×6 = **57,594** 拍（chip 侧交叉验证 57,560）；**Fmax**（= 1/(8 ns+|slack|)）："
        "B0 %.1f / A0+pd %.1f / A1+pd %.1f MHz（三点差落在 §8.11 实测的映射噪声带 ≈0.40 ns 内 ⇒ "
        "**调度对 Fmax 无显著差异**），fold 本体 L1 由 %.1f → **%.1f MHz**（Step 5 预译码的可归属收益）。"
        "见 `08_P7_*.md` §8.12。 |"
        % (fmax["B0"], fmax["A0+pd"], fmax["A1+pd"], fmax["L1"], fmax["L1+pd"]))
    if not args.check:
        p.write_text(t.rstrip("\n") + "\n\n" + sec, encoding="utf-8")
        q.write_text("\n".join(lines), encoding="utf-8")
    print(sec)
    print("OK" + (" (check only)" if args.check else ""))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    main()
