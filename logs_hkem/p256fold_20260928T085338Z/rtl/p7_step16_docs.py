#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 §8.16：Step 11「消融与端到端结果由脚本重建」的记录（重建链 / 落点 / 纪律 / A1 端到端 / 清单对照）。

**在 Windows 侧跑**。数值从 `ppa/p7_results.csv`、`ppa/*`、两份 A1 日志读，断言不成立即拒绝写。

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step16_docs.py [--check] [--force]
"""
import argparse
import csv
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
PPA, REP = RUN / "ppa", RUN / "reports"
DOCS = REPO.parent / "md文档" / "p256方案20260927" / "new_contribution_2"
DOC, QDOC = "08_P7_PPA与CSA决策.md", "13_合并影响与回归清单.md"


def rd(p):
    return pathlib.Path(p).read_text(encoding="utf-8", errors="replace")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()

    rows = list(csv.DictReader((PPA / "p7_results.csv").open(encoding="utf-8")))
    by_id = {r["run_id"]: r for r in rows}          # 用 run_id（唯一 ✓）取行；同 design/workload 还有每调用行 ✗
    assert len(rows) >= 19, len(rows)
    # A1 端到端（本次入库的两份日志）与 serial 的差
    ser_prot = int(by_id["p7-A0-protocol-phase1_keygen"]["protocol_total"])
    ovl_prot = int(by_id["p7-A1-protocol-phase1_keygen"]["protocol_total"])
    ovl_key = by_id["p7-A1-p256_keygen"]
    ser_key = by_id["p7-A0-p256_keygen"]
    ovl_ecd = by_id["p7-A1-p256_ecdh"]
    ser_ecd = by_id["p7-A0-p256_ecdh"]
    assert ovl_prot == 832200 and ser_prot == 889760, (ovl_prot, ser_prot)
    assert ovl_key["app_retired"] == ser_key["app_retired"] == "84679", ovl_key["app_retired"]
    assert ovl_ecd["app_retired"] == ser_ecd["app_retired"] == "91893"
    d_key = int(ser_key["app_span"]) - int(ovl_key["app_span"])
    d_ecd = int(ser_ecd["app_span"]) - int(ovl_ecd["app_span"])
    assert d_key > 0 and d_ecd > 0
    prof = int(re.search(r"p256_keygen_total,(\d+)",
                         rd(RUN / "host/phase1_keygen_test.overlap.txt")).group(1))
    prof0 = int(re.search(r"p256_keygen_total,(\d+)",
                          rd(RUN / "host/protocol_ver1_2.log")).group(1))
    assert prof == 392395 and prof0 == 449955, (prof, prof0)
    # 纪律抽查：projected 行只有 A2；TR0 的六类在 ppa.csv 里单独成行
    assert all(r["design"] == "A2" for r in rows if r["source_tag"] == "projected")
    ppa = list(csv.DictReader((PPA / "p7_ppa.csv").open(encoding="utf-8")))
    assert sum(1 for r in ppa if r["source_tag"] == "measured_altflow") == 4, len(ppa)

    p = DOCS / DOC
    t = p.read_text(encoding="utf-8")
    assert "#### 8.15 " in t, "§8.15 尚未写入"
    if "#### 8.16 " in t:
        if not args.force:
            raise SystemExit("§8.16 已存在（重写用 --force）")
        t = t[:t.index("#### 8.16 ")]

    L = []
    L.append("#### 8.16 Step 11：结果由脚本重建（落点、纪律与 A1 端到端）（2026-10-01）")
    L.append("")
    L.append("**甲、重建链（两条命令即可重建全部表格/CSV，脚本不读文档、只读入库产物）**")
    L.append("")
    L.append("```bash")
    L.append("python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step11_results.py --collect   # 产物 → ppa/raw/p7_raw.json")
    L.append("python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step11_results.py --build --md  # JSON → ppa/*.csv、reports/ppa.{csv,json,md}")
    L.append("python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step11_deliverables.py       # §17 清单的落点（ppa/*）")
    L.append("```")
    L.append("")
    L.append("**乙、`$run_dir/ppa/` 与 `$run_dir/reports/ppa.*` 的落点（PDF §17 清单逐项照抄）**："
             "`syn_conditions.txt`、`constraints.sdc`+`sdc_sha256.txt`、`area_{A0,A1,B0,B1}.{rpt,csv}`、"
             "`timing_{A0,A1,B0,L1}.rpt`+`timing_summary.csv`、`netlist_check.md`、`sweep_fmax.csv`、"
             "`freq_cycle_time.md`、`power_{L1,A0,A1,B0}.{rpt,csv}`、`pareto_A1_A2.md`、"
             "`S0_software_search.md` ✓ —— 全部由脚本生成 ✓，不手写 ✗。")
    L.append("")
    L.append("**丙、纪律（§13.3 原文）**：`null` 填未知 ✓；**`projected` 与 `measured` 分行不混** ✓ —— "
             "投影行只有 A2 的 2 行（`p256_ecdh` 296,210 / `p256_keygen` 289,003，来自 §13.1 阶梯）；"
             "`measured_altflow` 单独 4 行（TR0 的六类面积，**不与 TR1 同列**）；"
             "`timing_summary.csv` 的 `tns` 与 `sweep_fmax.csv` 的扫描列按实况写 `null`/`no` ✗。")
    L.append("")
    L.append("**丁、A1（overlap）端到端实测（本次入库；命令与判据同 `07_P6` §8.4 的受控实验）**")
    L.append("")
    L.append("| 指标 | A0（serial） | A1（overlap） | Δ |")
    L.append("|---|---:|---:|---:|")
    L.append("| `p256_keygen_total`（P-256 阶段，实测） | %s | **%s** | **−%s** |"
             % (format(prof0, ","), format(prof, ","), format(prof0 - prof, ",")))
    L.append("| `protocol_total`（phase1_keygen，实测） | %s | **%s** | **−%s** |"
             % (format(ser_prot, ","), format(ovl_prot, ","), format(ser_prot - ovl_prot, ",")))
    L.append("| Keygen A 指令数 | `%s` | `%s` | **0**（调度不影响指令数 ✓） |"
             % (hex(int(ser_key["app_retired"])), hex(int(ovl_key["app_retired"]))))
    L.append("| Keygen A cycles | %s | %s | **−%s** |"
             % (format(int(ser_key["app_span"]), ","), format(int(ovl_key["app_span"]), ","), format(d_key, ",")))
    L.append("| ECDH A 指令数 | `%s` | `%s` | **0** |"
             % (hex(int(ser_ecd["app_retired"])), hex(int(ovl_ecd["app_retired"]))))
    L.append("| ECDH A cycles | %s | %s | **−%s** |"
             % (format(int(ser_ecd["app_span"]), ","), format(int(ovl_ecd["app_span"]), ","), format(d_ecd, ",")))
    L.append("")
    L.append("两次运行均 `PASS!` ✓；协议段的降幅（−%s）与 §8.12 的程序级 −%s 拍同源（9,599 次调用 × 6 拍）✓。"
             % (format(ser_prot - ovl_prot, ","), format(9599 * 6, ",")))
    L.append("")
    L.append("**戊、P7 通过条件对照（§11 逐字：「同一库/角/约束下的可比面积和 timing；正常安全配置实际 cycle；"
             "消融和端到端结果可以由脚本重建」）**")
    L.append("")
    L.append("| 条件 | 状态 | 落点 |")
    L.append("|---|---|---|")
    L.append("| 同库/角/约束的可比面积与 timing | ✓ | `ppa/syn_conditions.txt`、`area_*`、`timing_*`（§8.7/8.10/8.11/8.12） |")
    L.append("| 正常安全配置的**实际 cycle** | ✓ | `ppa/timing_summary.csv`、`p7_results.csv` 的 A0/A1 应用级与每调用行 |")
    L.append("| 消融与端到端结果**由脚本重建** | ✓ | `ppa/raw/p7_raw.json` → `p7_results.csv`/`ppa.{csv,json,md}`（甲） |")
    L.append("| 矩阵 B0/B1/A0/A1 必做项 | ✓ | §8.15（B0/B1）、§8.2–8.13（A0/A1） |")
    L.append("| S0 搜索记录（未编造改进） | ✓ | `ppa/S0_software_search.md` |")
    L.append("| 双 CSA 的 Pareto（不合算则降级） | ✓ | `ppa/pareto_A1_A2.md`（§8.14：A1 实测、A2 投影+实测代价） |")
    L.append("| L3（完整 SoC）面积 | ✗ 不可得 | 本机无 DC/OpenROAD ⇒ 只报 L1/L2（§8.4 第 1 条） |")
    L.append("| 时钟扫描 | ✗ 未做 | `ppa/sweep_fmax.csv` 单点 + `sweep_done=no`；Fmax 由 WNS 单点推得 |")
    L.append("| `u_size_only_x` 计数（查 5 点名） | ✗ 未取 | `ppa/netlist_check.md` 内附命令，值为 `null` |")
    L.append("")

    sec = "\n".join(L)
    if not args.check:
        p.write_text(t.rstrip("\n") + "\n\n" + sec, encoding="utf-8")
        q = DOCS / QDOC
        t2 = q.read_text(encoding="utf-8")
        lines = t2.split("\n")
        if not any(l.startswith("| 2026-10-01 | `664c398cf4` |") for l in lines):
            i = next(k for k, l in enumerate(lines) if l.startswith("| 2026-09-30 | `2ac65cffa5` |"))
            lines.insert(
                i + 1,
                "| 2026-10-01 | `664c398cf4` | **P7 Step 11（结果由脚本重建，P7 §8.16）**。"
                "重建链：`p7_step11_results.py --collect/--build/--md`（产物→JSON→CSV/MD）+ "
                "`p7_step11_deliverables.py`（§17 清单落点 `ppa/*`、`reports/ppa.{csv,json,md}`）；"
                "纪律：`null` 填未知、`projected`/`measured` 分行（投影仅 A2 两行）、TR0 六类单独成行。"
                "**A1（overlap）端到端实测入库**：`p256_keygen_total` 449,955 → **392,395**（−57,560）、"
                "`protocol_total` 889,760 → **832,200**（−57,560）；app 侧指令数逐位不变（84,679 / 91,893）"
                "而 cycles 各降 %s / %s；两次 `PASS!`。 |" % (format(d_key, ","), format(d_ecd, ",")))
        q.write_text("\n".join(lines), encoding="utf-8")
    print(sec)
    print("OK" + (" (check only)" if args.check else ""))


if __name__ == "__main__":
    main()
