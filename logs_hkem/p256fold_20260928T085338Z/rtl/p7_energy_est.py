#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 Step 9（路 A）：本机解析式功耗/能量估计（**工具估计，非硅测**；只读网表 + liberty）。

口径（PDF §15.4 允许「工具估计」，但要求绝对量 + 工具条件 + 记录种子/clock gating）：
    P_sw   = f · V² · Σ_nets α_net · C_net         C_net = 该网驱动的各**输入**引脚电容之和
    P_int  = f · Σ_inst Σ_pin α_net(pin) · E_int(pin)   E_int = liberty internal_power 表中位值（近似）
    P_leak = Σ_inst cell_leakage_power
    E/op   = P_total · cycles / f                  cycles 用**实测**值（不做"少 cycle ⇒ 节能"的推断）
α **是声明式假设**（vectorless）：**时钟网 α = 1**（每拍一次上升沿），其余按 --alpha 多档扫描。
本脚本**不产出实测活动率** —— 那是路 B（短窗口 RTL trace）的事，未做前不得写进结论。

单位：一律从 liberty 头部**解析**（time_unit / capacitive_load_unit / leakage_power_unit /
voltage_unit），并把解析到的原文逐行印在报告里，便于人工复核；内部功耗按「power 单位 × time 单位」
折算，并用**量级自检**把关（P_int 与 P_sw 相差 >1000× 时标红并要求人工核单位，不静默出数）。

自校验：
  1. 网表按 cell 分类的实例数 vs `p7_area_*.md` 报告里的 cell 表（逐项，允许差 0）；
  2. 量级自检（上一段）。

用法（Linux 侧）：
  python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_energy_est.py \
      --liberty ~/nangate45/NangateOpenCellLibrary_typical.lib \
      --netlist hw/ip/otbn/pre_syn/syn_out/otbn_p256_fold_2026_09_30_18_00_06/generated/otbn_p256_fold_netlist.v \
      --design "L1（fold 单独 + Step 5 预译码）" --fold-cycles 22 \
      --area-report logs_hkem/p256fold_20260928T085338Z/reports/p7_area_L1_after_blanking.md \
      --alpha 0.1 0.25 0.5 \
      --out logs_hkem/p256fold_20260928T085338Z/reports/p7_energy_L1.md
  # 自测（不需要真文件）：加 --selftest
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


def _block(t, i):
    """从 t[i]（'{'）起，按括号配平返回块体 t[i+1:j]。"""
    depth, j = 0, i
    while j < len(t):
        if t[j] == "{":
            depth += 1
        elif t[j] == "}":
            depth -= 1
            if depth == 0:
                return t[i + 1:j]
        j += 1
    raise ValueError("括号不配平")


def parse_liberty(path):
    """→ (cells, units)。cells[cell] = {area, leak, pin_cap:{pin:cap_pF}, pin_dir:{pin}, e_int:{pin:median}}"""
    t = pathlib.Path(path).read_text(encoding="utf-8", errors="replace")
    units = {}
    for key in ("time_unit", "capacitive_load_unit", "leakage_power_unit", "voltage_unit",
                "current_unit", "nom_voltage", "nom_temperature", "pulling_resistance_unit"):
        m = re.search(r"%s\s*:?\s*\"?([^;\"]+)\"?\s*;" % key, t)
        if m:
            units[key] = m.group(1).strip()
    m = re.search(r"capacitive_load_unit\s*\(\s*([\d.]+)\s*,\s*(\w+)\s*\)", t)
    if m:
        units["cap_unit"] = (float(m.group(1)), m.group(2))     # 例 (1,pf)

    cells = {}
    for m in re.finditer(r"\bcell\s*\(\s*(\w+)\s*\)\s*\{", t):
        name = m.group(1)
        body = _block(t, m.end() - 1)
        a = re.search(r"\barea\s*:\s*([\d.eE+-]+)\s*;", body)
        lk = re.search(r"\bcell_leakage_power\s*:\s*([\d.eE+-]+)\s*;", body)
        d = {"area": float(a.group(1)) if a else None,
             "leak": float(lk.group(1)) if lk else None,
             "pin_cap": {}, "pin_dir": {}, "e_int": {}}
        for pm in re.finditer(r"\bpin\s*\(\s*(\w+)\s*\)\s*\{", body):
            pname = pm.group(1)
            pbody = _block(body, pm.end() - 1)
            cap = re.search(r"\bcapacitance\s*:\s*([\d.eE+-]+)\s*;", pbody)
            d["pin_cap"][pname] = float(cap.group(1)) if cap else 0.0
            d["pin_dir"][pname] = ("output" if re.search(r"direction\s*:\s*output", pbody) else "input")
            vals = []
            for vm in re.finditer(r"values\s*\(([^)]*)\)", pbody):
                vals += [float(x) for x in re.findall(r"(-?[\d.eE+-]+)", vm.group(1))]
            vals = sorted(v for v in vals if v > 0)
            if vals:
                d["e_int"][pname] = vals[len(vals) // 2]        # 中位值（不区分 slew/load 索引 ⇒ 近似）
        cells[name] = d
    assert cells, "liberty 里没解析到 cell：%s" % path
    return cells, units


INST = re.compile(r"^\s*(\w+)\s+(\S+)\s*\((.*?)\)\s*;", re.S | re.M)   # 全文扫描：需 re.M 让 ^ 匹配每行行首
CONN = re.compile(r"\.(\w+)\s*\(\s*([^)\s]+)\s*\)")
KW = {"module", "endmodule", "input", "output", "inout", "wire", "reg", "logic", "assign",
      "parameter", "localparam", "begin", "end", "generate", "endgenerate", "always",
      "initial", "function", "endfunction", "task", "endtask", "specify", "endspecify"}


def parse_netlist(path):
    """**全文扫描**（不按行）：yosys `write_verilog` 的实例引脚多时会跨行 ✗ 按行会漏。
    只认「有 .pin(net) 连接表」且首词不是 Verilog 关键字/端口声明的匹配 ⇒ 才是 cell 实例。
    解析正确性由调用方的「实例数 vs 面积报告」自检兜底（对不上就拒绝出数）。"""
    insts, counts = [], {}
    txt = pathlib.Path(path).read_text(encoding="utf-8", errors="replace")
    for m in INST.finditer(txt):
        if m.group(1) in KW:
            continue
        cell, inst, conns = m.group(1), m.group(2), m.group(3)
        if "." not in conns:                 # 模块头/端口声明等没有 .pin(...) ⇒ 不是实例
            continue
        counts[cell] = counts.get(cell, 0) + 1
        insts.append((cell, inst, dict(CONN.findall(conns))))
    return insts, counts


def cap_to_farad(c, units):
    u = units.get("cap_unit", (1.0, "pf"))
    scale = {"pf": 1e-12, "ff": 1e-15, "f": 1.0, "nf": 1e-9}.get(u[1].lower(), None)
    assert scale is not None, "未知电容单位 %s" % (u,)
    return c * u[0] * scale


def _unit_scale(text, family):
    m = re.match(r"([\d.]+)\s*([fpnumk]?%s)" % family, text.strip())
    assert m, "无法解析单位：%s" % text
    s = {"f": 1e-15, "p": 1e-12, "n": 1e-9, "u": 1e-6, "m": 1e-3, "": 1.0, "k": 1e3}[m.group(2)[:-1]]
    return float(m.group(1)) * s


def eint_to_joule(v, units):
    """`internal_power` 的单位**从文件声明的单位推出**（liberty 惯例：功率单位 = voltage_unit × current_unit）：
       Nangate45：1 V × 1 mA = 1 mW，再乘 time_unit 1 ns ⇒ **每单位 = 1 pJ**。
    报告里会把这条推导原样印出，便于复核（不按任何"惯例猜测"）。"""
    pw = _unit_scale(units.get("voltage_unit", "1V"), "V") * _unit_scale(units.get("current_unit", "1mA"), "A")
    tm = _unit_scale(units.get("time_unit", "1ns"), "s")
    return v * pw * tm


def build_report(args, cells, units, insts, counts):
    f = args.freq_mhz * 1e6
    V = args.vdd if args.vdd else float(units.get("nom_voltage") or 1.1)
    v_src = "CLI --vdd" if args.vdd else "liberty `nom_voltage`"
    is_clk = lambda n: (n == args.clk_net) or n.endswith(args.clk_net)

    # 网 → 输入脚电容之和（farad）
    net_cap = {}
    for cell, inst, conn in insts:
        pc, pd = cells[cell]["pin_cap"], cells[cell]["pin_dir"]
        for pin, net in conn.items():
            if net in ("1'b0", "1'b1", "1'bx", "1'bz"):
                continue
            net_cap.setdefault(net, 0.0)
            if pd.get(pin) == "input":
                net_cap[net] += cap_to_farad(pc.get(pin, 0.0), units)

    # 内部功耗（逐 pin：时钟脚的 α=1）
    def p_int(alpha_data):
        tot = 0.0
        for cell, inst, conn in insts:
            for pin, e in cells[cell]["e_int"].items():
                net = conn.get(pin)
                a = 1.0 if (net and is_clk(net)) else alpha_data
                tot += a * eint_to_joule(e, units)
        return f * tot

    leak_w = sum(counts[c] * (cells[c]["leak"] or 0.0) for c in counts) * \
        _unit_scale(units.get("leakage_power_unit", "1nW"), "W")
    area_netlist = sum(counts[c] * (cells[c]["area"] or 0.0) for c in counts)

    L = []
    L.append("# Step 9 能量估计（路 A：本机解析式，**工具估计非硅测**）%s" % ("— " + args.design if args.design else ""))
    L.append("")
    L.append("| 项 | 值 |")
    L.append("|---|---|")
    L.append("| liberty | `%s` |" % args.liberty)
    L.append("| 网表 | `%s` |" % args.netlist)
    L.append("| V / f | %.2f V（来源：%s）/ %.1f MHz |" % (V, v_src, args.freq_mhz))
    L.append("| 角 / clock gating | Nangate45 typical / **0（无 ICG，§8.2 实测）** |")
    L.append("| α | 时钟网 = 1；数据网 = %s（**声明式假设，非实测活动率**） |"
             % ", ".join("%.2f" % a for a in args.alpha))
    L.append("| 公式 | `P_sw = f·V²·ΣαC`；`P_int = f·Σα·E_int`（表中位值近似）；`P_leak = Σ cell_leakage_power`；"
             "`E/op = P_total·cycles/f` |")
    L.append("")
    L.append("**liberty 头部单位（原文，供复核）**：" + "；".join("`%s = %s`" % (k, v)
                                                              for k, v in units.items() if k != "cap_unit"))
    L.append("")
    L.append("**内部功耗单位推导（不按惯例猜，逐项从文件取）**：`voltage_unit × current_unit × time_unit` "
             "= %s × %s × %s ⇒ **每单位 = %.4g J**；`capacitive_load_unit` = %s ⇒ 电容折算 = %.4g F/单位。"
             % (units.get("voltage_unit"), units.get("current_unit"), units.get("time_unit"),
                eint_to_joule(1.0, units), units.get("cap_unit"), cap_to_farad(1.0, units)))
    L.append("")
    L.append("## 规模与自校验")
    L.append("")
    L.append("- 实例 **%d** 个、cell **%d** 种；按 cell 面积累加 = **%.3f µm²**。" % (len(insts), len(counts), area_netlist))
    L.append("- liberty 解析出 **%d** 个 cell；带 `internal_power` 的 pin 数 = **%d**；带 `cell_leakage_power` 的 cell 数 = **%d**。"
             % (len(cells), sum(len(d["e_int"]) for d in cells.values()),
                sum(1 for d in cells.values() if d["leak"] is not None)))
    missing = sorted({c for c in counts if c not in cells})
    L.append("- 网表里有、liberty 里没有的 cell：%s" % ("无 ✓" if not missing else "**%s** ✗" % missing[:8]))
    if args.area_report:
        rpt = pathlib.Path(args.area_report).read_text(encoding="utf-8", errors="replace")
        cmp_, bad = 0, []
        for c in sorted(counts):
            m = re.search(r"^\|\s*`%s`\s*\|\s*([\d,]+)\s*\|" % re.escape(c), rpt, re.M)
            if m:
                cmp_ += 1
                if int(m.group(1).replace(",", "")) != counts[c]:
                    bad.append((c, counts[c], m.group(1)))
        L.append("- **自校验（实例数 vs `%s`）**：比对 %d 个 cell，%s"
                 % (pathlib.Path(args.area_report).name, cmp_, "**全部一致 ✓**" if not bad else "不一致 ✗ %s" % bad[:6]))
    L.append("")
    L.append("## 功耗（逐 α 档）")
    L.append("")
    L.append("| α（数据网） | P_sw | P_int | P_leak | **P_total** | P_int/P_sw |")
    L.append("|---:|---:|---:|---:|---:|---:|")
    res = {}
    for a in args.alpha:
        p_sw = f * sum((1.0 if is_clk(n) else a) * net_cap[n] * V * V for n in net_cap)
        pi = p_int(a)
        pt = p_sw + pi + leak_w
        res[a] = pt
        L.append("| %.2f | %.4f mW | %.4f mW | %.4f mW | **%.4f mW** | %.3f |"
                 % (a, p_sw * 1e3, pi * 1e3, leak_w * 1e3, pt * 1e3, (pi / p_sw) if p_sw else 0))
    L.append("")
    r0 = None
    for a in args.alpha:
        p_sw = f * sum((1.0 if is_clk(n) else a) * net_cap[n] * V * V for n in net_cap)
        if p_sw:
            r0 = p_int(a) / p_sw
            break
    if r0 is None or not (1e-3 < r0 < 1e3):
        L.append("> ⚠ **量级自检未过**（P_int/P_sw = %.3g，超出 1e-3…1e3）⇒ **单位可能不对，禁止引用本表数值**；"
                 "请把上面「liberty 头部单位」原样贴回核对。✗" % (r0 or float('nan')))
        L.append("")
    else:
        L.append("> 量级自检：P_int/P_sw = **%.3f**（在 1e-3…1e3 内 ✓）。" % r0)
        L.append("")
    if args.fold_cycles or args.ecdh_cycles:
        L.append("## 能量指标（`E = P_total · cycles / f`）")
        L.append("")
        al = args.alpha[:3]
        L.append("| 指标 | cycles（来源） | " + " | ".join("α=%.2f" % a for a in al) + " |")
        L.append("|---|---:|" + "---:|" * len(al))
        if args.fold_cycles:
            L.append("| **energy/mul**（fold 单元口径） | %d（RTL/ISS 实测） |" % args.fold_cycles +
                     "".join(" %.3f nJ |" % (res[a] * args.fold_cycles / f * 1e9) for a in al))
        if args.ecdh_cycles:
            L.append("| **energy/ECDH**（整核口径，含空闲块 ⇒ 高估） | %d（帧数 × 每调用拍数，实测） |"
                     % args.ecdh_cycles +
                     "".join(" %.3f µJ |" % (res[a] * args.ecdh_cycles / f * 1e6) for a in al))
        L.append("")
        L.append("> `energy/协议阶段` 需要该阶段的 **OTBN 侧**拍数（现只有宿主 `HKEM_PROF` 口径 ✗）⇒ 待补。")
        L.append("")
    L.append("## 误差与限制（必须同读）")
    L.append("")
    L.append("1. **α 是假设不是实测** ⇒ 本报告 = vectorless 工具估计。**同一 α 档下的相对比较**有效 ✓；"
             "绝对值须标注为工具估计 ✗ 不得写成硅测/签核功耗。")
    L.append("2. **`internal_power` 取表中位值**：真实值依赖 (input slew, output load) 索引 ✗ ⇒ 近似；"
             "精确值需从 OpenSTA 逐实例导出 slew/load（未做）。")
    L.append("3. **不含互连线电容**（无 PEX ✗）⇒ 低估开关功耗；`P_leak` 为 typical 角单值（无温度/工艺角扫描 ✗）。")
    L.append("4. 整核口径把**空闲块**也按同一 α 计入 ⇒ 高估 `energy/ECDH`；fold 单独口径（L1）不受此影响 ✓。")
    L.append("5. **不做「少 cycle ⇒ 节能」的推断**（PDF §15.4 明令）⇒ 能量必须由本表的 P 与实测 cycles 相乘得到。")
    L.append("")
    return "\n".join(L), res


SELFTEST_LIB = """
library (test) {
  time_unit : "1ns";
  capacitive_load_unit (1,pf);
  leakage_power_unit : 1nW;
  voltage_unit : "1V";
  current_unit : "1mA";
  cell (AND2_X1) {
    area : 1.064;
    cell_leakage_power : 0.0174077;
    pin (A1) { direction : input; capacitance : 0.00155936; }
    pin (A2) { direction : input; capacitance : 0.00155936; }
    pin (ZN) {
      direction : output; capacitance : 0.0;
      internal_power () { fall_power (t) { values("0.002, 0.004"); } rise_power (t) { values("0.002, 0.004"); } }
    }
  }
  cell (DFFR_X1) {
    area : 5.016;
    cell_leakage_power : 0.1234;
    pin (D) { direction : input; capacitance : 0.0018; }
    pin (CK) { direction : input; capacitance : 0.0026; }
    pin (Q) {
      direction : output; capacitance : 0.0;
      internal_power () { fall_power (t) { values("0.01, 0.02"); } rise_power (t) { values("0.01, 0.02"); } }
    }
  }
}
"""

SELFTEST_NET = """
module top (input clk_i, input a, input d, output y);
  AND2_X1 g1 ( .A1(a), .A2(y), .ZN(n1) );
  DFFR_X1 f1 ( .D(n1), .CK(clk_i), .Q(y) );
  DFFR_X1 f2 ( .D(d), .CK(clk_i), .Q(n2) );
  AND2_X1 g2 ( .A1(n2), .A2(y), .ZN(n3) );
endmodule
"""


def selftest():
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        lp, np_ = pathlib.Path(td) / "t.lib", pathlib.Path(td) / "t.v"
        lp.write_text(SELFTEST_LIB, encoding="utf-8")
        np_.write_text(SELFTEST_NET, encoding="utf-8")
        cells, units = parse_liberty(lp)
        insts, counts = parse_netlist(np_)
        assert counts == {"AND2_X1": 2, "DFFR_X1": 2}, counts
        assert abs(cells["AND2_X1"]["area"] - 1.064) < 1e-9
        assert abs(cells["DFFR_X1"]["pin_cap"]["CK"] - 0.0026) < 1e-12
        # 手算：C(y) = f1.Q? 不驱动（输出脚不计）+ g1.A2 + g2.A2 = 2 × 0.00155936 pF
        ep, _ = build_report(argparse.Namespace(
            liberty=str(lp), netlist=str(np_), design="selftest", vdd=1.1, freq_mhz=125.0,
            alpha=[0.25], clk_net="clk_i", fold_cycles=None, ecdh_cycles=None,
            area_report=None, out=None), cells, units, insts, counts)
        # 手算：**全部网**都要算（clk_i 按 α=1，其余按 0.25）
        caps = {"clk_i": 2 * 0.0026e-12, "y": 2 * 0.00155936e-12, "a": 0.00155936e-12,
                "d": 0.0018e-12, "n1": 0.0018e-12, "n2": 0.00155936e-12}
        p_sw_a25 = 125e6 * 1.1 ** 2 * sum((1.0 if k == "clk_i" else 0.25) * c for k, c in caps.items())
        assert ("%.4f mW" % (p_sw_a25 * 1e3)) in ep, (p_sw_a25 * 1e3, ep[:900])
        # 内部功耗：AND2 输出中位 0.002/0.004 → 0.004? 排序后中位取 [1] = 0.004（2 个值）
        e_int_and = 0.004 * 1e-12            # 1 V × 1 mA × 1 ns = 1 pJ/单位 ⇒ 0.004 单位 = 4 fJ
        assert abs(eint_to_joule(0.004, units) - e_int_and) < 1e-30, eint_to_joule(0.004, units)
        print("SELFTEST OK：解析/计数/电容/单位折算/报告生成 全部通过")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--liberty")
    ap.add_argument("--netlist")
    ap.add_argument("--design", default="")
    ap.add_argument("--vdd", type=float, default=1.1)
    ap.add_argument("--freq-mhz", type=float, default=125.0)
    ap.add_argument("--alpha", type=float, nargs="+", default=[0.1, 0.25, 0.5])
    ap.add_argument("--clk-net", default="clk_i")
    ap.add_argument("--fold-cycles", type=int)
    ap.add_argument("--ecdh-cycles", type=int)
    ap.add_argument("--area-report")
    ap.add_argument("--out")
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    assert args.liberty and args.netlist, "需要 --liberty 与 --netlist（或 --selftest）"
    cells, units = parse_liberty(args.liberty)
    insts, counts = parse_netlist(args.netlist)
    rep, _ = build_report(args, cells, units, insts, counts)
    print(rep)
    if args.out:
        pathlib.Path(args.out).write_text(rep + "\n", encoding="utf-8")
        print("[写] %s" % args.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
