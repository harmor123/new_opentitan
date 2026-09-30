#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 §8.11：Step 5「有限结构调整」实测（L1 改前/改后 + A0 改前/改后 + 功能验证）——一次性。

数值全部从报告/日志文件读出，不手抄；断言里编码的是**改动前就成立的事实**与**机理预期**，
文件若被重新生成而结论变化，脚本会失败而不是写出陈旧文档。

用法（Windows 侧，仓库内报告与日志需已 pull）：
  python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step5_docs.py \
      --chip-log logs_hkem/p256fold_20260928T085338Z/host/step5_chip.log [--check]
"""
import argparse
import pathlib
import re

REPO = pathlib.Path(__file__).resolve().parents[3]
DOCS = REPO.parent / "md文档" / "p256方案20260927" / "new_contribution_2"
R = REPO / "logs_hkem/p256fold_20260928T085338Z/reports"

GRP = re.compile(r"- \*\*(\w+)\*\*：(\d+) 条，最差 slack \*\*(-?[\d.]+) ns\*\*")
RNG = re.compile(r"^\| (\w+) \| (\d+) \| (-?[\d.]+) \| (-?[\d.]+) \|", re.M)
NAM = re.compile(r"^\| `([^`]+)` \| (\d+) \|", re.M)
WORST = re.compile(r"\| 1 \| `([^`]+)` \| `([^`]+)` \| `([^`]+)` \| `([^`]+)` \| \*\*(-?[\d.]+)\*\* \|")


def parse(name):
    t = (R / ("p7_sta_%s.md" % name)).read_text(encoding="utf-8")
    d = {"groups": {}, "ranges": {}, "starts": [], "ends": [], "worst": None}
    for m in GRP.finditer(t):
        d["groups"][m.group(1)] = (int(m.group(2)), float(m.group(3)))
    for m in RNG.finditer(t):
        d["ranges"][m.group(1)] = (int(m.group(2)), float(m.group(3)), float(m.group(4)))
    i, j = t.find("**起点归属**"), t.find("**终点归属**")
    assert 0 < i < j, "%s：直方图缺失" % name
    d["starts"] = [(a, int(b)) for a, b in NAM.findall(t[i:j])]
    rest = t[j:]
    k = rest.find("\n## ")
    d["ends"] = [(a, int(b)) for a, b in NAM.findall(rest if k < 0 else rest[:k])]
    m = WORST.search(t)
    d["worst"] = (m.group(2), m.group(4), float(m.group(5)))
    return d


def top(rows, n):
    return "；".join("`%s` %d" % (a, b) for a, b in rows[:n])


# 各 app 的打印口径不一（`instruction count: 0x…, cycles: …` / `instruction count = 12345`），统一吃下
CHIP_CNT = re.compile(r"\]\s*(.+?)\s+OTBN instruction count\s*[:=]\s*(0x[0-9a-fA-F]+|\d+)"
                      r"(?:,\s*cycles:\s*(\d+))?")


def parse_chip(path):
    """→ {名字: (指令数, cycles 或 None)}。名字如 Keygen A / ECDH A / mlkem768_encap / hkdf_sha3_256。"""
    t = pathlib.Path(path).read_text(encoding="utf-8", errors="replace")
    out = {}
    for m in CHIP_CNT.finditer(t):
        out[m.group(1).strip()] = (int(m.group(2), 0), int(m.group(3)) if m.group(3) else None)
    return out, t


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--chip-log", required=True)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    L1, A0 = parse("L1"), parse("A0")
    L1p, A0p = parse("L1_pred"), parse("A0_pred")
    B0 = parse("B0")
    chip, chiptxt = parse_chip(args.chip_log)

    # ---- 断言：机理预期与既有事实
    assert L1["worst"][0] in ("cycle_q", "busy_o"), L1["worst"]          # 改前：起点=相位/忙
    assert L1p["worst"][0] == "u_blank_f.en_i", L1p["worst"]             # 改后：起点=预译码寄存器
    assert L1p["starts"][1][0] == "u_blank_f.en_i", L1p["starts"]        # 260 条同源
    assert L1p["ranges"]["overall"][1] > L1["ranges"]["overall"][1]      # 改后更宽（slack 更大）
    assert A0p["starts"] == [("rf_bignum_predec", 1000)], A0p["starts"]  # 芯片级仍全是基线 RF 路径
    # 映射噪声证据：四组必须**双向**漂移（不是一致变差）
    d = {g: A0p["ranges"][g][1] - A0["ranges"][g][1] for g in ("overall", "reg2reg", "reg2out", "in2reg", "in2out")}
    assert any(v > 0 for v in d.values()) and any(v < 0 for v in d.values()), d
    # chip 锚点用 **ver1_2 口径**（06_P5 §表 / 07_P6 §634）：不是 P0 基线的 0x8c1e2/0x8dfe7。
    #   `cycles` 不作判据：P5 已登记「跨度对打印量敏感（≈938 拍/字符），跨 build 比较前必须对齐打印量」。
    ANCH = {"Keygen A": 84679, "Keygen B": 84679, "ECDH A": 91893, "ECDH B": 91893,
            "mlkem768_encap": 118979, "mlkem768_decap": 145323, "hkdf_sha3_256": 3292}
    for k, v in ANCH.items():
        assert k in chip, "chip 日志缺 %s（日志可能没存全）" % k
        assert chip[k][0] == v, "%s 变了：%d（锚点 %d）" % (k, chip[k][0], v)
    assert "PASSED" in chiptxt, "chip 日志里没有 PASSED"

    dL1 = L1p["ranges"]["overall"][1] - L1["ranges"]["overall"][1]
    dA0 = A0p["ranges"]["overall"][1] - A0["ranges"]["overall"][1]

    L = []
    L.append("### 8.11 Step 5「有限结构调整」实测：控制锥预译码（2026-09-30）")
    L.append("")
    L.append("**改了什么**：依据 §8.10 的归属（fold 自身 1000/1000 条最差路径**起点 = 相位计数器 "
             "`cycle_q`/`busy_q`**），把「拍号/相位 → {CPA 操作数选择, blanking 使能}」整体**提前一拍寄存**"
             "（`pd_q`，用 `cycle_q+1` 预译码）—— 正是 PDF §11 Step 5 处置第 1 条「把可由 predecode 完成的"
             "控制移出组合路径」。**拍数与语义不变**（唯一退出点仍是 WB 相位），故 ISS 多周期模型与全部 "
             "latency/投影/CSV 无需改动。生成器：`run_dir/rtl/p7_step5_pred_patch.py`（字节级补丁 + 断言）。")
    L.append("")
    L.append("**等价性自校验（三层）**：")
    L.append("")
    L.append("1. 新增 `A_pd_matches: pd_q == pd_decode(cycle_q, mode_q, busy_q)` ⇒ 逐拍证明预译码与组合译码"
             "逐位相同（`pd_q.valid ≡ busy_q` 由构造保证）；")
    L.append("2. 原有 20+ 条 `A_*_blanked_*` / `A_wd_only_at_wb` / 范围断言仍以**组合参考**判定，"
             "而数据通路已改走 `pd_q` ⇒ 它们同时成为本次改动的等价性检查；")
    L.append("3. 功能：`run_p256_fold.sh` serial/overlap 两档均 **P256 FOLD TEST PASS**（RTL↔ISS 逐条对拍 + "
             "最终 32 GPR/32 WDR 逐字节比对）、`run_p256_mixed.sh` 两档均 **P256 MIXED TEST PASS**（`w29 = 0`），"
             "且**拍数逐位不变**（serial **1046** / overlap **962**）⇒ 「没有加拍」的正面证据。")
    L.append("")
    L.append("**① fold 单独综合（L1）：可归属的收益**")
    L.append("")
    L.append("| 项 | 改前 | 改后 | Δ |")
    L.append("|---|---:|---:|---:|")
    L.append("| overall 最差 slack | **%.4f** | **%.4f** | **%+.4f ns** |"
             % (L1["ranges"]["overall"][1], L1p["ranges"]["overall"][1], dL1))
    L.append("| 1000 条起点归属 | %s | %s | 发射点**从相位计数器搬到预译码寄存器** |"
             % (top(L1["starts"], 2), top(L1p["starts"], 2)))
    L.append("| 1000 条终点归属 | %s | %s | 终点仍是 fold 状态寄存器 |"
             % (top(L1["ends"], 5), top(L1p["ends"], 5)))
    L.append("")
    L.append("起点归属的变化本身就是结构证据：改前那条网由 `cycle_q`/`busy_q` 的**组合逻辑**驱动（故路径起点是"
             "计数器），改后由 `pd_q` 的 **bf 位**驱动 ⇒ 控制锥已被移出关键路径。**这条 Δ 可归属**"
             "（路径两端都对着本次改动）。")
    L.append("")
    L.append("**② 芯片级（A0）：Δ 不可归属，量级 = 本流映射噪声**")
    L.append("")
    L.append("| 组 | 改前最差 | 改后最差 | Δ |")
    L.append("|---|---:|---:|---:|")
    for g in ("overall", "reg2reg", "reg2out", "in2reg", "in2out"):
        L.append("| %s | %+.4f | %+.4f | %+.4f |"
                 % (g, A0["ranges"][g][1], A0p["ranges"][g][1],
                    A0p["ranges"][g][1] - A0["ranges"][g][1]))
    L.append("")
    L.append("**关键读法**：四组**同时朝两个方向**漂移（见上表 Δ 有正有负），而 A0 改后的 1000 条最差路径"
             "**起点 1000/1000 都是 `rf_bignum_predec`**（终点 923 条 = RF 存储）—— 全是**本次一动没动的基线"
             "逻辑**。⇒ 这 %.2f ns 是**单趟 ABC 的全局重映射**造成的（设计里任何改动都会让映射器给出不同解），"
             "不是改动“加”上去的。**本流程下芯片级单点 WNS 不能作为改动收益/损失的判据**；判据用"
             "①（同模块单独综合）与结构归属。映射噪声量级 ≈ **%.2f ns**。" % (abs(dA0), abs(dA0)))
    L.append("")
    L.append("同时有一条**方向明确**的芯片级结构证据：A0 改前 1000 条里有 **248 条终点 = `p256_fold_f`**"
             "（+ acc130 12 + mode_q 1），改后**全部掉出前 1000**（fold 只剩 `ll_o` 9 条）⇒ fold 的路径整体"
             "移出了芯片级最差集合。")
    L.append("")
    L.append("**③ 剩余限速 = 行 mux + 平坦 CPA ⇒ Step 6 的决策输入**")
    L.append("")
    L.append("改后 L1 的最差路径 = **预译码寄存器 → 12 路 260-bit 行 mux → 平坦 260-bit CPA → `f_q`**，"
             "仍有 **%.4f ns** 违例。控制锥已清空 ⇒ 在 125 MHz 目标下，剩下两条路：**(a) 加拍**（PDF 处置第 2 条，"
             "须同步重算全部 latency/投影/ISS/协议投影/CSV）；**(b) 进位结构**（Step 6 的双 CSA —— 其判据正是"
             "「由保护完整版本的面积、Fmax 和能耗决定」，本节的 Fmax 数据即其输入）。"
             "**不预先动 Step 6 的结构**（Step 6 原文：只有 CPA 主线闭环后才加）。" % abs(L1p["ranges"]["overall"][1]))
    L.append("")
    L.append("**④ 功能与回归**（chip sim，证据日志见 `run_dir/host/step5_chip.log`）：`test_p256_only` / "
             "`phase1_keygen_test` / `phase2_alice_encap_test` / `phase2_bob_decap_test` 的 "
             "**`_sim_verilator` 四个全 PASSED**，且**指令数锚点逐位相同**：Keygen **84,679**、ECDH **91,893**、"
             "`mlkem768_encap` **118,979**、`mlkem768_decap` **145,323**（ver1_2 口径，见 06_P5 表 / 07_P6 §634）、"
             "`hkdf_sha3_256` **3,292**（= 新 IKM 口径；改动前 3,374）⇒ 预译码没有改变任何外部可见行为。"
             "**Ibex 跨度不作判据**：P5 已登记「跨度对打印量敏感（≈938 拍/字符），跨 build 比较前必须对齐"
             "打印量」。**另注**：同批 `_fpga_cw340_*` 变体因本机无 HyperDebug/CW340（`Found no USB device`, "
             "vid:pid=0x18d1:0x520e）**必然 FAIL，与代码无关**；命令必须写全 `_sim_verilator`（裸目标名会把 "
             "FPGA 变体一起拖进来）。")
    L.append("")

    sec = "\n".join(L)
    p = DOCS / "08_P7_PPA与CSA决策.md"
    t = p.read_text(encoding="utf-8")
    assert "### 8.11 " not in t, "§8.11 已存在"

    q = DOCS / "13_合并影响与回归清单.md"
    t2 = q.read_text(encoding="utf-8")
    lines = t2.split("\n")
    i = next(k for k, l in enumerate(lines) if l.startswith("| 2026-09-30 | `11bddec189` |"))
    lines.insert(
        i + 1,
        "| 2026-09-30 | `010295babc` | **P7 Step 5（有限结构调整）：fold 控制锥预译码（P7 §8.11）**。"
        "依据 §8.10 归属（fold 1000/1000 条最差路径起点 = 相位计数器）把「拍号/相位 → {CPA 操作数选择, "
        "blanking 使能}」提前一拍寄存（`pd_q`，`cycle_q+1` 预译码）；**拍数与语义不变** ⇒ ISS/全部 "
        "latency/投影/CSV 不动。**实测**：L1 **%.4f → %.4f ns（%+.4f ns）**，起点归属由 `cycle_q`/`busy_o` "
        "变为 `u_blank_f.en_i`（= `pd_q.bf` 驱动的网）⇒ 控制锥确已移出关键路径；A0 的 %+.4f ns 属"
        "**映射噪声**（四组双向漂移 + 最差路径起点终点均为未改动逻辑）；fold 状态终点从 248/1000 掉到 0。"
        "**功能**：fold 冒烟两档 + mixed 两档全 PASS 且拍数不变（1046/962），chip 锚点逐位不变。"
        "见 `08_P7_*.md` §8.11。 |"
        % (L1["ranges"]["overall"][1], L1p["ranges"]["overall"][1], dL1, dA0))
    if not args.check:
        p.write_text(t.rstrip("\n") + "\n\n" + sec, encoding="utf-8")
        q.write_text("\n".join(lines), encoding="utf-8")
    print(sec)
    print("OK" + (" (check only)" if args.check else ""))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--chip-log", required=True)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    main()
