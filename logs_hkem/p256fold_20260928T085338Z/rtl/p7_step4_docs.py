#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 §8.10：Step 4 关键路径归属（A0 / L1 / B0 三列并列）——一次性；数值全部从报告文件读出。

追加到 `08_P7_PPA与CSA决策.md` 末尾，并同步 `13_合并影响` 的更新记录一行。
断言里编码的是**人工核对过的事实**（如 A0 首行起点归属 = `rf_bignum_predec`，与直接
`grep -A1` 的邻接关系一致）；报告若被重新生成而结论变化，本脚本会失败而不是写出陈旧文档。
用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step4_docs.py [--check]
"""
import argparse
import pathlib
import re

REPO = pathlib.Path(__file__).resolve().parents[3]
DOCS = REPO.parent / "md文档" / "p256方案20260927" / "new_contribution_2"
R = REPO / "logs_hkem/p256fold_20260928T085338Z/reports"
RUNS = ["A0", "L1", "B0"]
DESC = {"A0": "serial 常量化，含 fold", "L1": "`otbn_p256_fold` 单独作顶层", "B0": "基线 `2d87e79bee`，无 fold"}

GRP = re.compile(r"- \*\*(\w+)\*\*：(\d+) 条，最差 slack \*\*(-?[\d.]+) ns\*\*")
RNG = re.compile(r"^\| (\w+) \| (\d+) \| (-?[\d.]+) \| (-?[\d.]+) \|", re.M)
NAM = re.compile(r"^\| `([^`]+)` \| (\d+) \|", re.M)
WORST = re.compile(r"\| 1 \| `([^`]+)` \| `([^`]+)` \| `([^`]+)` \| `([^`]+)` \| \*\*(-?[\d.]+)\*\* \|")
MAPS = re.compile(r"(\d+) 组 `_NNNNN_` ↔ 原名（按\*\*相邻行\*\*配对，其中 (\d+) 组走上一行回退）")
FOLD_STATES = ("f_o", "wd_o", "h_o", "acc130_o", "ll_o", "k_o")


def parse(name):
    t = (R / ("p7_sta_%s.md" % name)).read_text(encoding="utf-8")
    d = {"groups": {}, "ranges": {}, "starts": [], "ends": [], "worst": None, "maps": None}
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
    assert m, "%s：最差路径表首行缺失" % name
    d["worst"] = (m.group(2), m.group(4), float(m.group(5)))
    m = MAPS.search(t)
    d["maps"] = (int(m.group(1)), int(m.group(2)))
    return d


def top(rows, n):
    return "；".join("`%s` %d" % (a, b) for a, b in rows[:n])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    D = {n: parse(n) for n in RUNS}

    # ---- 断言：人工核对过的事实（报告若变，必须重写文档而不是沿用旧结论）
    assert D["A0"]["worst"][0] == "rf_bignum_predec", "A0 首行起点归属变了：%s" % (D["A0"]["worst"],)
    assert D["A0"]["starts"][0] == ("rf_bignum_predec", 740), D["A0"]["starts"][:2]
    assert dict(D["A0"]["starts"])["u_otbn_controller.u_otbn_loop_controller.loop_info_stack.cnt_err"] == 260
    assert dict(D["A0"]["ends"])["u_otbn_mac_bignum.p256_fold_f"] == 248
    assert D["B0"]["starts"] == [("rf_bignum_predec", 1000)], D["B0"]["starts"]
    assert D["B0"]["ends"][0] == ("u_otbn_rf_bignum.gen_rf_bignum_ff.u_otbn_rf_bignum_inner.rf", 941)
    assert dict(D["L1"]["starts"])["cycle_q"] == 260 and dict(D["L1"]["starts"])["busy_o"] == 265
    assert D["L1"]["ends"][:5] == [("f_o", 260), ("wd_o", 256), ("h_o", 225), ("acc130_o", 130), ("ll_o", 120)]
    assert D["L1"]["worst"][:2] == ("cycle_q", "f_o"), D["L1"]["worst"]

    a0, l1, b0 = D["A0"]["groups"]["overall"][1], D["L1"]["groups"]["overall"][1], D["B0"]["groups"]["overall"][1]
    ra0, rb0 = D["A0"]["ranges"]["overall"], D["B0"]["ranges"]["overall"]

    L = []
    L.append("### 8.10 Step 4：关键路径归属（A0 / L1 / B0 三列并列，2026-09-30）")
    L.append("")
    L.append("**工具**：`run_dir/rtl/p7_sta_report.py` —— 直接读 `<run>/reports/timing/*.csv.rpt`"
             "（`起点,终点,slack`），再用 `<run>/generated/ys_translated_names` 把 ABC 生成的 `_NNNNN_` 归回原名。"
             "**不走 flow 自带翻译器**，两条实测理由：① 它第二段 `translate_timing_csv.py` 在 "
             "`flow_utils.py:61` 崩（对不含 `/` 的行做 `split('/',1)[1]`）；② 它**原地覆盖** csv"
             "（加表头 + 用 `generated_cell_re` 剥掉 pin 名），且它自称的「翻译」在本设计上不生效"
             "（`build_translated_names_dict` 把字典建成 `{原名: _NNNNN_}`，而查表用 `_NNNNN_`，永不命中）。"
             "**配对规则**：`ys_translated_names` 是**变长分组**（每次 `select -list` 打印 1–2 行），"
             "按「每两行一组」按索引配对会**大量错配** ⇒ 改为**按相邻行**配对（优先后一行、回退前一行），"
             "报告表头印出回退组数。")
    L.append("")
    L.append("| 运行 | 说明 | 映射组数（回退） | overall 最差 slack | overall 组 1000 条的范围（最差…最好） |")
    L.append("|---|---|---:|---:|---|")
    for n in RUNS:
        r = D[n]["ranges"]["overall"]
        L.append("| **%s** | %s | %d（%d） | **%.4f** | %.4f … %.4f |"
                 % (n, DESC[n], D[n]["maps"][0], D[n]["maps"][1], r[1], r[1], r[2]))
    L.append("")
    L.append("**A0 / L1 / B0 的 1000 条最差路径两端归属**：")
    L.append("")
    L.append("| 运行 | 起点归属（计数） | 终点归属（计数） |")
    L.append("|---|---|---|")
    for n in RUNS:
        L.append("| **%s** | %s | %s |" % (n, top(D[n]["starts"], 2), top(D[n]["ends"], 4)))
    L.append("")
    L.append("**五条必查路径逐条归属**（§3 Step 4；只给网名支持的结论，不给猜测）：")
    L.append("")
    L.append("| 必查 | 归属 | 证据 |")
    L.append("|---|---|---|")
    L.append("| **control** | **基线自有**（RF 预译码 + loop 栈） | B0 **1000/1000** 条起点 = `rf_bignum_predec`，"
             "终点 941 条 = RF bignum 内部 `…u_otbn_rf_bignum_inner.rf`；A0 同族仍 **740/1000**，"
             "另 260 条 = `u_otbn_controller.u_otbn_loop_controller.loop_info_stack.cnt_err` |")
    L.append("| **row mux → CPA** | **fold 内部**（L1 的限速族） | L1 **1000/1000** 条起点 = 相位计数器 "
             "`cycle_q`(%d) / `busy_o`(%d)，终点 = fold 全部状态寄存器（%s）⇒ 相位 → 行 mux/KD 选择 → "
             "260-bit CPA → 状态 D 端；mux 由相位控制，故发射点是相位计数器而非数据寄存器 |"
             % (dict(D["L1"]["starts"])["cycle_q"], dict(D["L1"]["starts"])["busy_o"], top(D["L1"]["ends"], 5)))
    L.append("| **correction path** | **平铺网表里不可再分（如实标）** | A0 的 248 条终点 = "
             "`u_otbn_mac_bignum.p256_fold_f`（fold 的 f 状态）、12 条 = `acc130_o`、1 条 = `mode_q`；"
             "标签只给两端寄存器，中间级（校正/折叠逻辑 vs CPA）**无法从网名区分** |")
    L.append("| **MAC tap 扇出** | 与上一条同一族 | 该族终点在 `u_otbn_mac_bignum` 内、起点仍是 RF 预译码寄存器 "
             "⇒ 路形是「RF 读 → MAC → fold 输入」 |")
    L.append("| **clock** | **本阶段不可测** | pre_syn 网表**无时钟树**（无 CTS），且 §8.2 已记 **ICG = 0** "
             "⇒ 时钟路径不在被测网表内；报告的 `in2reg`/`in2out` 最差均为正 slack（%+.4f / %+.4f），"
             "无时钟相关违例 |"
             % (D["A0"]["groups"]["in2reg"][1], D["A0"]["groups"]["in2out"][1]))
    L.append("")
    L.append("**三条判据级结论**：")
    L.append("")
    L.append("1. **芯片级限速路径是基线的**：B0（**无** fold）自己就是 **%.4f ns**，A0 仅比它差 "
             "**%.4f ns（%.1f%%）** ⇒ 本方案在芯片级只加这一小截，**没有制造新的限速路径**。"
             % (b0, abs(a0 - b0), 100 * abs(a0 - b0) / abs(b0)))
    L.append("2. **fold 内部比基线宽**：L1 = **%.4f ns**，比 B0 **好 %.4f ns** ⇒ **fold 不是限速者**。"
             % (l1, abs(b0 - l1)))
    L.append("3. **A0 的 1000 条里 %d 条终点落在 fold 状态上**（`p256_fold_f` %d + `acc130_o` %d + `mode_q` %d；"
             "B0 中为 0 条）⇒ fold 把自己的状态端纳入了同一量级，但没有压过基线那条。"
             % (dict(D["A0"]["ends"])["u_otbn_mac_bignum.p256_fold_f"] + dict(D["A0"]["ends"]).get("u_otbn_mac_bignum.u_otbn_p256_fold.acc130_o", 0) + dict(D["A0"]["ends"]).get("u_otbn_mac_bignum.u_otbn_p256_fold.mode_q", 0),
                dict(D["A0"]["ends"])["u_otbn_mac_bignum.p256_fold_f"],
                dict(D["A0"]["ends"]).get("u_otbn_mac_bignum.u_otbn_p256_fold.acc130_o", 0),
                dict(D["A0"]["ends"]).get("u_otbn_mac_bignum.u_otbn_p256_fold.mode_q", 0)))
    L.append("")
    L.append("**限制（必须与结论同读）**：")
    L.append("")
    L.append("1. 本流程是**单趟 ABC**（`abc -liberty -D 4000` 一次映射，无时序驱动迭代）、**buffer = 0**、**无 CTS** "
             "⇒ **绝对值不可当签核结论**，A0/B0/L1 的**相对比较**才有效。")
    L.append("2. B0 的 1000 条路径**同一起点、slack 挤在 %.2f ns 带宽内**（%.4f … %.4f）⇒ 典型**单源高扇出簇**；"
             "buffer=0 时高扇出网由弱驱动直带几百个 FF 使能 ⇒ 这个量级是**流程产物**，不是某条「最长组合链」的"
             "设计属性。" % (rb0[2] - rb0[1], rb0[1], rb0[2]))
    L.append("3. L1 有 **%d/1000** 条起点所属单元**没有 Q 网络**（其 `select -list` 只打印一行）⇒ 如实标"
             "「未在映射中」，不猜；终点侧 %d/1000 可归属。"
             % (dict(D["L1"]["starts"]).get("（未在映射中）", 0), 1000 - dict(D["L1"]["ends"]).get("（未在映射中）", 0)))
    L.append("")

    sec = "\n".join(L)
    p = DOCS / "08_P7_PPA与CSA决策.md"
    t = p.read_text(encoding="utf-8")
    assert "### 8.10 " not in t, "§8.10 已存在"

    q = DOCS / "13_合并影响与回归清单.md"
    t2 = q.read_text(encoding="utf-8")
    lines = t2.split("\n")
    i = next(k for k, l in enumerate(lines) if l.startswith("| 2026-09-30 | `5f24200748` |"))
    lines.insert(
        i + 1,
        "| 2026-09-30 | `11bddec189` | **P7 Step 4：关键路径归属（P7 §8.10）**。工具 `p7_sta_report.py` 直接读 "
        "`csv.rpt` + 用 `generated/ys_translated_names` 归属（绕开 vendored 翻译器：其第二段在 `flow_utils.py:61` "
        "崩、且**原地覆盖** csv；其「翻译」因字典方向反了而永不命中；映射是**变长分组**，按索引配对会错配）。"
        "**结论**：① 芯片级限速 = **基线自有**的 RF 预译码→RF 存储（B0 1000/1000 同一起点，A0 740/1000），"
        "**A0 仅比 B0 差 %.4f ns（%.1f%%）**；② fold 内部限速 = 相位计数器 → 行 mux/CPA → fold 状态"
        "（L1 1000/1000，终点 = f/wd/h/acc130/ll 全状态），**L1 = %.4f ns 比 B0 好 %.4f ns ⇒ fold 不是限速者**；"
        "③ clock 类**本阶段不可测**（pre_syn 无 CTS、ICG=0）；④ correction path 与 MAC tap 扇出**在平铺网表里"
        "不可再分**（如实标）。**限制**：单趟 ABC、buffer=0 ⇒ 绝对值不可签核；B0 的 1000 条为**单源高扇出簇**"
        "（带宽 %.2f ns）⇒ 属流程产物。见 `08_P7_*.md` §8.10。 |"
        % (abs(a0 - b0), 100 * abs(a0 - b0) / abs(b0), l1, abs(b0 - l1), rb0[2] - rb0[1]))
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
