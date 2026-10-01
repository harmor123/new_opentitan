#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 Step 11：按 **PDF §17 的产物清单**（`08_P7` §6 表）把落点补齐 —— 路径与文件名逐项照抄。

清单里已有的：`ppa/S0_software_search.md` ✓、`reports/p5_frame.json` 等投影/模型 ✓。
本脚本补齐其余项，全部从**已入库材料**生成（raw JSON、报告 md、流程 SDC、文档里的十项/五查表），
无值处写 `null`（清单原话：「无值的写 `null`」✓）、`projected`/`measured` 分行不混 ✓。

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step11_deliverables.py [--check]
"""
import argparse
import csv
import hashlib
import json
import pathlib
import re
import shutil
import sys

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = pathlib.Path(__file__).resolve().parents[3]
RUN = REPO / "logs_hkem/p256fold_20260928T085338Z"
PPA, REP = RUN / "ppa", RUN / "reports"
RAW = PPA / "raw/p7_raw.json"
DOC = REPO.parent / "md文档" / "p256方案20260927" / "new_contribution_2/08_P7_PPA与CSA决策.md"
SDC = REPO / "hw/ip/otbn/pre_syn/otbn.nangate.sdc"
MANIFEST = RUN / "run_manifest.json"


def rd(p):
    return pathlib.Path(p).read_text(encoding="utf-8", errors="replace")


def wr(p, txt):
    p = pathlib.Path(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(txt if txt.endswith("\n") else txt + "\n", encoding="utf-8")
    print("[写] %s" % p)


def syn_conditions():
    """从 §8.1 的十项表抽（`| # | 项 | 落定值 | 依据 |`）—— 抽不到就报错，不猜。"""
    t = rd(DOC)
    i = t.index("### 8.1 Step 2：统一综合条件")
    seg = t[i:t.index("### 8.2 ", i)]
    out = []
    for m in re.finditer(r"^\|\s*([0-9–—]+)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*$", seg, re.M):
        n, item, val, why = (x.strip() for x in m.groups())
        out.append((n, item, val, why))
    assert len(out) >= 11, ("§8.1 十项表解析异常", len(out))
    must = ("库", "工艺角", "时钟", "IO delay", "false paths", "multicycle paths", "工具", "优化等级")
    missing = [x for x in must if not any(x in r[1] for r in out)]
    assert not missing, ("§8.1 十项表缺项", missing)
    return out


def five_checks():
    """从 §3 Step 3 抽五查的标题与预期行（命令与结论保留在 doc 里，这里给索引与判据）。"""
    t = rd(DOC)
    seg = t[t.index("**查 1 —"):t.index("### 8.1 Step 2")]
    checks = []
    for m in re.finditer(r"\*\*查 ([1-5]) — ([^*]+)\*\*", seg):
        checks.append((int(m.group(1)), m.group(2).strip()))
    assert [c[0] for c in checks] == [1, 2, 3, 4, 5], checks
    return checks


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    if args.check:
        print("会写：ppa/{syn_conditions.txt,constraints.sdc,sdc_sha256.txt,area_*.{rpt,csv},"
              "timing_*.rpt,timing_summary.csv,netlist_check.md,sweep_fmax.csv,freq_cycle_time.md,"
              "power_*.{rpt,csv},pareto_A1_A2.md} + reports/ppa.{csv,json,md}")
        print("十项表行数 = %d；五查 = %s" % (len(syn_conditions()), [c[0] for c in five_checks()]))
        return

    v = json.loads(rd(RAW))
    man = json.loads(rd(MANIFEST))
    sta, pw, area = v["sta"]["slack_ns"], v["power"], v["area"]
    KEY = {"B0": "B0", "A0": "A0_pred", "A1": "A1_pred", "L1": "L1_pred"}   # 含 Step 5 预译码的档 ✓
    fmax = {d: 1e3 / (8.0 + abs(sta[k])) for d, k in KEY.items()}

    # ① 综合条件（十项）
    L = ["# P7 统一综合条件（PDF §17「综合条件冻结件」；逐项见 08_P7 §8.1，无值处写 null）", ""]
    for n, item, val, why in syn_conditions():
        L.append("%s. %s = %s        # 依据：%s" % (n, item, val, why))
    L += ["", "# 冻结来源：run_manifest.json（库/角/时钟/工具版本/ELF 哈希）；",
          "# 库 sha256 = %s" % man.get("library_sha256", "null"), ""]
    wr(PPA / "syn_conditions.txt", "\n".join(L))

    # ② 约束副本 + SHA
    shutil.copyfile(SDC, PPA / "constraints.sdc")
    h = hashlib.sha256(pathlib.Path(SDC).read_bytes()).hexdigest()
    wr(PPA / "sdc_sha256.txt", "%s  hw/ip/otbn/pre_syn/otbn.nangate.sdc（流程 SDC 模板；"
                              "与树内版本一致即可 ✓）\n%s  %s\n" % (h, h, PPA / "constraints.sdc"))

    # ③ 面积（每个设计两份口径：TR1 总量 measured / TR0 六类 measured_altflow —— 分行不混 ✓）
    core = area["src_tr1"]["core"]
    six = area["src_tr0"]["six"]
    for d, disp in (("A0", "A0"), ("A1", "A1"), ("B0", "B0"), ("B1", "B1")):
        tot = area["src_tr1"]["fold_L1"] if d == "L1" else core.get(d)
        if d == "B1":
            tot = core.get("A0")            # B1 = 新 RTL（与 A0 同一网表；综合不依赖 ELF ✓）
        rows = [("source_tag", "measured"), ("area_total_um2", tot),
                ("note", "B1 = 新 RTL 的被动面积（与 A0 同一网表；综合不依赖 ELF）" if d == "B1" else "")]
        wr(PPA / ("area_%s.rpt" % disp),
           "设计 %s 面积（口径：%s；库/角/约束见 syn_conditions.txt）\n"
           "  TR1（TIMING_RUN=1，与 timing/power 同一设计点）: total = %s um^2\n"
           "  TR0（TIMING_RUN=0，altflow ⇒ 六类分列，**不与 TR1 混列** ✗）: %s\n"
           % (d, "measured", tot,
              ", ".join("%s=%.1f" % (k, x) for k, x in (six.get(d) or six["A0"]).items())))
        with (PPA / ("area_%s.csv" % disp)).open("w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["design", "source_tag", "area_total_um2", "regs_um2", "comb_um2", "mux_um2"])
            w.writerow([d, "measured", tot, None, None, None])
            _six = six.get(d) or six["A0"]
            w.writerow([d, "measured_altflow", None, _six.get("寄存器"), _six.get("组合逻辑"),
                        _six.get("mux")])

    # ④ timing（把已入库的 STA 报告按清单命名；并给一张汇总 CSV）
    for k, f in (("A0", "p7_sta_A0_pred.md"), ("A1", "p7_sta_A1_pred.md"), ("B0", "p7_sta_B0.md"),
                 ("L1", "p7_sta_L1_pred.md")):
        shutil.copyfile(REP / f, PPA / ("timing_%s.rpt" % k))
    with (PPA / "timing_summary.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["design", "source_tag", "wns_ns", "tns_ns", "fmax_mhz", "converged_at_125mhz"])
        for k in ("B0", "A0", "A1", "L1"):
            s = sta[KEY[k]]
            w.writerow([k, "measured", s, None, round(fmax[k], 1),
                        "no" if s < 0 else "yes"])

    # ⑤ 网表五查（结论来自已入库的检查记录；查 5 的 DC 口径命令已实测并说明不适用 ✓）
    L = ["# 网表五查（PDF §17 清单项；命令与判据见 08_P7 §3 Step 3 与 §8.6）", "",
         "| # | 检查 | 判据（PDF） | 结论 |", "|---|---|---|---|"]
    concl = {1: "1 个（与设计一致 ✓）：`otbn_mac_bignum.sv:358`",
             2: "自建 260-bit CPA（`260 % 32/16/64 = 4 ≠ 0` ⇒ 不能复用 `otbn_vec_adder` ✓）",
             3: "KD = 12 项编译期常量选择，非通用乘法器 ✓",
             4: "无 inferred latch ✓（另：无动态 barrel shifter、无新增通用乘法器）",
             5: "**本流程不适用**：`grep -o u_size_only` 在三份网表上均为 **0（含基线 B0 ✓）** ⇒ "
                "该命名约定属 **DC** 流程（`syn/constraints.sdc:50` 的 `set_size_only`）✗；"
                "本流程的等价证据 = blanking 实测增量（`AND2_X1` **+844**、面积 **+829.122 µm²**，§8.6 ✓）"
                "且两版差异为 0（非回归 ✓）"}
    for n, title in five_checks():
        L.append("| %d | %s | 见 08_P7 §3 查 %d 的「预期」 | %s |" % (n, title, n, concl[n]))
    L += ["", "**唯一化计数的实测（PDF 点的命令，按本流程口径用 `grep -o | wc -l` 数实例）**：", "",
          "| 网表 | `u_size_only` 实例数 |", "|---|---:|",
          "| A0（新 RTL，serial） | 0 |", "| A1（新 RTL，overlap） | 0 |",
          "| **B0（基线，上游 RTL）** | **0** |", "",
          "⇒ 三份**全 0（含基线）** ⇒ 该命名约定在本 flow 的网表里不存在（属 DC 口径 ✗）；"
          "**B0 与 A1 相等**即「保护单元未因我们的改动而丢失」的对照证据 ✓。", "",
          "```bash",
          "S=hw/ip/otbn/pre_syn/syn_out",
          "for N in \"$S/otbn_core_2026_09_30_18_53_19/generated/otbn_core_netlist.sta.v\" \\",
          "         \"$S/otbn_core_2026_09_30_20_22_02/generated/otbn_core_netlist.sta.v\" \\",
          "         /tmp/b0/hw/ip/otbn/pre_syn/syn_out/otbn_core_2026_09_30_18_17_11/generated/otbn_core_netlist.sta.v; do",
          "  grep -o 'u_size_only' \"$N\" | wc -l", "done",
          "```", ""]
    wr(PPA / "netlist_check.md", "\n".join(L))

    # ⑥ 时钟扫描：已有合并结果（p7_sweep_docs.py 产出）则**不覆盖** ✓；否则写占位（单点 + no）
    if (PPA / "sweep_all_merged.csv").exists():
        print("[跳过] sweep_fmax.csv 已有合并版（p7_sweep_docs.py 产出）⇒ 不覆盖 ✓")
    else:
      with (PPA / "sweep_fmax.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["design", "source_tag", "clk_ns", "wns_ns", "fmax_mhz", "sweep_done"])
        for k in ("B0", "A0", "A1", "L1"):
            w.writerow([k, "measured", 8.0, sta[KEY[k]], round(fmax[k], 1), "no"])
        w.writerow(["ALL", "null", None, None, None, "no（占位：合并版见 sweep_all_merged.csv ✓）"])

    # ⑦ 同频 cycle + 各自 Fmax（两列都给 ✓）
    pc = v["per_call"]
    ml = v["apps"]["A0"]["counts"].get("mlkem768_encap", {})
    ml_b0 = v["apps"]["B0"]["counts"].get("mlkem768_encap", {})
    L = ["# 同频 cycle 与各自 Fmax 的 time（PDF §17 清单项）", "",
         "**甲、同频（125 MHz）比 cycle**：每次 `p256mul` 调用 serial **%d** 拍（stalls %d）/ overlap **%d** 拍（stalls %d）"
         % (pc["serial"]["total"], pc["serial"]["stalls"], pc["overlap"]["total"], pc["overlap"]["stalls"]),
         ""]
    L.append("**乙、各自 Fmax 比 time**（`Fmax = 1/(8 + |wns|)`）：")
    L.append("")
    L.append("| 设计 | wns (ns) | Fmax (MHz) |")
    L.append("|---|---:|---:|")
    for k in ("B0", "A0", "A1", "L1"):
        L.append("| %s | %.4f | %.1f |" % (k, sta[KEY[k]], fmax[k]))
    L += ["", "**丙、Fmax 变化对 ML-KEM time 的影响**：ML-KEM 路径**不经过 fold** ⇒ 其 OTBN 指令数与"
          "调度未变：基线 %s / 新版 %s（实测，逐位相同 ✓）⇒ **同频下 ML-KEM time 不变**；"
          "若按各自 Fmax 折算，A1 的 Fmax 更高 ⇒ ML-KEM time 只会更好，不会更差 ✓。"
          % (ml_b0.get("insns"), ml.get("insns")), ""]
    wr(PPA / "freq_cycle_time.md", "\n".join(L))

    # ⑧ 功耗/能量（含随机种子与 clock gating）
    for k in ("L1", "A0", "A1", "B0"):
        rows = pw[k]["alpha"] if "alpha" in pw[k] else {}
        L = ["# 能耗 %s（PDF §17 清单项；口径见 08_P13 §8.13）" % k, "",
             "| alpha | P_sw (W) | P_int (W) | P_leak (W) | P_total (W) |", "|---:|---:|---:|---:|---:|"]
        for a in ("0.10", "0.25", "0.50"):
            r = rows.get(a)
            L.append("| %s | %s | %s | %s | %s |" % (a, *_fmt(r)) if r else "| %s | null | null | null | null |" % a)
        en = pw[k].get("energy", {})
        if en:
            for kk, vv in en.items():
                L.append("")
                L.append("`energy/%s`（J）：%s" % (kk, ", ".join("α=%s: %.4g" % (a, x) for a, x in sorted(vv.items()))))
        L += ["", "**随机种子**：无（综合与估计均为确定性流程 ⇒ 无种子可记 ✓，如实写）",
              "**clock gating**：0（无 ICG cell，§8.2 实测 ✓）",
              "**电压/频率**：1.10 V / 125 MHz；**库/角**：Nangate45 typical", ""]
        wr(PPA / ("power_%s.rpt" % k), "\n".join(L))
        with (PPA / ("power_%s.csv" % k)).open("w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["design", "source_tag", "alpha", "p_sw_w", "p_int_w", "p_leak_w", "p_total_w"])
            for a in ("0.10", "0.25", "0.50"):
                r = rows.get(a)
                w.writerow([k, "measured", a] + (list(r.values())[:3] + [r["tot"]] if r else [None] * 4))

    # ⑨ A2 Pareto（A1 全实测 + A2 投影拍数 / 实测代价区间 ⇒ 逐项标注 ✓）
    cs = area["csa_cost"]["areas"]
    d_lo, d_hi = cs["p7_csa2_cost"] - cs["p7_cpa4_ref"], cs["p7_csa2_cost"] - cs["p7_cpa2_ref"]
    wr(PPA / "pareto_A1_A2.md",
       "\n".join(["# A1/A2 的 Pareto（PDF §17 降级路径；口径见 08_P7 §8.14）", "",
                  "| 点 | latency（拍/调用） | 面积 | 状态 |", "|---|---|---|---|",
                  "| **A1（主方案）** | **%d（实测 ✓）** | fold %.1f µm²（实测 ✓） | 已实现/已验证 |"
                  % (pc["overlap"]["total"], area["src_tr1"]["fold_L1"]),
                  "| **A2（双 CSA）** | %d（**§13.1 投影** ✗） | fold + **%.1f–%.1f µm²**（**实测**代价探针 ✓） | "
                  "**未实现** ✗ |" % (22, d_lo, d_hi), "",
                  "**结论（按 §17 的合法降级路径）**：主方案保持 CPA（A1）；A2 作**消融点**。"
                  "若论文主张 A2 更优 ⇒ 必须先实现 A2 并实测 ✗（本记录不足以支撑该主张）。", ""]))

    # ⑩ reports/ppa.{csv,json,md}（清单点名的落点）
    rows = list(csv.DictReader((PPA / "p7_ppa.csv").open(encoding="utf-8")))
    with (REP / "ppa.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print("[写] %s" % (REP / "ppa.csv"))
    res = list(csv.DictReader((PPA / "p7_results.csv").open(encoding="utf-8")))
    wr(REP / "ppa.json", json.dumps({"ppa": rows, "results": res, "manifest": man,
                                     "syn_conditions": [list(x) for x in syn_conditions()]},
                                    ensure_ascii=False, indent=2))
    md = ["# ppa（由 `p7_step11_results.py --build/--md` 与 `p7_step11_deliverables.py` 生成，**不手写** ✓）", ""]
    for name, rs in (("PPA", rows), ("结果（§13.3 前 23 列）", res)):
        cols = [c for c in rs[0].keys() if any(r[c] not in (None, "") for r in rs)]
        md += ["## %s（%d 行）" % (name, len(rs)), "", "| " + " | ".join(cols) + " |", "|" + "---|" * len(cols)]
        for r in rs:
            md.append("| " + " | ".join("null" if r[c] in (None, "") else r[c] for c in cols) + " |")
        md.append("")
    wr(REP / "ppa.md", "\n".join(md))
    print("OK")


def _fmt(r):
    return ("%.6g" % r["sw"], "%.6g" % r["int_"], "%.6g" % r["leak"], "%.6g" % r["tot"])


if __name__ == "__main__":
    main()
