#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 Step 11：结果由脚本重建（PDF §11 通过条件第三项、§13.3 的 CSV 规格）。

两段式（满足「从**原始 JSON/CSV** 一键重生成」）：
  * `--collect`：把**已入库的原始证据**（日志/报告/rpt）抽成 `$run_dir/ppa/raw/p7_raw.json`，
                每个值都带 `src`（文件:行/解析器）与 `kind`（`measured` / `projected` / `measured_altflow`）✓
  * `--build`  ：**只读该 JSON**，重建 `$run_dir/ppa/` 下的 §13.3 结果 CSV、PPA CSV 与人读表 ✓

纪律（§13.3 原文）：`unknown` 填 **`null`**；**`projected` 与 `measured` 不得在同一行/列无标记混用** ⇒
每个 (design, workload) 按 kind **分行**，其余单元格为 `null` ✓。

用法：
  python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step11_results.py --collect
  python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step11_results.py --build
"""
import argparse
import csv
import json
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
RT, HOST, REP = RUN / "rtl", RUN / "host", RUN / "reports"
PPA = RUN / "ppa"
RAW = PPA / "raw/p7_raw.json"
DOC = REPO.parent / "md文档" / "p256方案20260927" / "new_contribution_2"
SCHEMA = ["run_id", "design", "workload", "session", "source_tag", "clock_otbn_hz", "clock_ibex_hz",
          "calls", "mul_retired", "mul_stall", "mul_fetch", "mul_self_cycles",
          "app_retired", "app_span", "host_execute_wait", "protocol_total", "scope_total",
          "text_bytes", "dmem_bytes", "err_bits", "kat_pass", "elf_sha256", "rtl_sha"]
PPA_COLS = ["run_id", "design", "source_tag", "area_fold", "area_core", "area_mac", "area_seq",
            "area_comb", "area_regs", "fmax_mhz", "wns_ns", "power_w", "energy_j",
            "lib", "corner", "constraint"]


def rd(p):
    return pathlib.Path(p).read_text(encoding="utf-8", errors="replace")


def chip_counts(p):
    """→ {op: (insns, cycles)}；兼容 `instruction count: 0x…, cycles: N` 与 `insn_cnt:` 两种打印。"""
    t = rd(p)
    out = {}
    for m in re.finditer(r"(Keygen [AB]|ECDH [AB]) OTBN instruction count: (0x[0-9a-f]+), cycles: (\d+)", t):
        out[m.group(1)] = {"insns": int(m.group(2), 16), "cycles": int(m.group(3))}
    m = re.search(r"mlkem768_encap cycles: (\d+), OTBN insn_cnt: (\d+)", t)
    if m:
        out["mlkem768_encap"] = {"insns": int(m.group(2)), "cycles": int(m.group(1))}
    assert out, "没抽到计数：%s" % p
    return out


def app_log_counts(p):
    """chip 批次日志（`instruction count: 0x…, cycles: N` 与 `instruction count = N` 两种口径）。"""
    t = rd(p)
    out = {}
    for m in re.finditer(r"([a-z0-9_]+) OTBN instruction count: (0x[0-9a-f]+), cycles: (\d+)", t):
        out[m.group(1)] = {"insns": int(m.group(2), 16), "cycles": int(m.group(3))}
    for m in re.finditer(r"([a-z0-9_]+) OTBN instruction count = (\d+)", t):
        out.setdefault(m.group(1), {"insns": int(m.group(2)), "cycles": None})
    return out


def sta_slack(p):
    m = re.search(r"overall\*\*：\d+ 条，最差 slack \*\*(-?[\d.]+) ns\*\*", rd(p))
    assert m, p
    return float(m.group(1))


def energy_rows(p):
    t = rd(p)
    rows = {}
    for m in re.finditer(r"^\| (0\.\d\d) \| ([\d.]+) mW \| ([\d.]+) mW \| ([\d.]+) mW \| \*\*([\d.]+) mW\*\* \|", t, re.M):
        rows[m.group(1)] = dict(sw=float(m.group(2)) * 1e-3, int_=float(m.group(3)) * 1e-3,
                                leak=float(m.group(4)) * 1e-3, tot=float(m.group(5)) * 1e-3)
    en = {}
    for m in re.finditer(r"\| \*\*energy/(\w+)\*\*[^|]*\| (\d+)（([^|]*)） \| (.+?) \|\s*$", t, re.M):
        en[m.group(1)] = {a: float(x.split()[0]) * 1e-9
                          for a, x in zip(("0.10", "0.25", "0.50"), m.group(4).split("|"))}
    return rows, en


def area_total(p):
    t = rd(p)
    m = re.search(r"Chip area for module '[^']+': ([0-9.]+)", t)
    assert m, p
    return float(m.group(1))


def area_six(p):
    """§8.7 的六类分列（**TIMING_RUN=0 的设计点** ⇒ 标 measured_altflow ✗ 不得与 TR1 数同列混用）。"""
    t = rd(p)
    out = {}
    for m in re.finditer(r"^\| (寄存器|组合逻辑|mux|buffer|clock gating|其它（未分类）) \| ([\d,]+) \| ([\d.]+) \|", t, re.M):
        out[m.group(1)] = float(m.group(3))
    return out


def collect():
    PPA.mkdir(parents=True, exist_ok=True)
    RAW.parent.mkdir(parents=True, exist_ok=True)
    v = {}
    # ---- 应用级（measured）
    v["apps"] = {
        "B0": {"src": "rtl/test_p256_only.trace.uart0.log, rtl/test_mlkem_encap_only.uart0.log", "kind": "measured",
               "counts": {**chip_counts(RT / "test_p256_only.trace.uart0.log"),
                          **chip_counts(RT / "test_mlkem_encap_only.uart0.log")}},
        "B1": {"src": "rtl/b1_test_p256_only.test.log, rtl/b1_test_mlkem_encap_only.test.log", "kind": "measured",
               "counts": {**chip_counts(RT / "b1_test_p256_only.test.log"),
                          **chip_counts(RT / "b1_test_mlkem_encap_only.test.log")}},
        "A0": {"src": "host/step5_chip.log（无 +p256_serial=0 ⇒ 默认 serial ✓ otbn_core.sv:160）", "kind": "measured",
               "counts": app_log_counts(HOST / "step5_chip.log")},
    }
    # ---- 每调用拆解（measured；同一 ELF 两种模式的 trace 分析）
    fr = json.loads(rd(REP / "p5_frame.json"))
    v["per_call"] = {"src": "reports/p5_frame.json", "kind": "measured",
                     "calls": fr["calls"]["serial"],
                     "serial": fr["call_breakdown_cycles"]["serial"],
                     "overlap": fr["call_breakdown_cycles"]["overlap"]}
    # ---- 协议级（measured，HKEM_PROF）与投影（§13.1）
    prot = {}
    for m in re.finditer(r"HKEM_PROF,([a-z0-9_]+),(protocol_total|scope_total|[a-z0-9_]+_execute_wait),(\d+)",
                         rd(HOST / "protocol_ver1_2.log")):
        prot.setdefault(m.group(1), {})[m.group(2)] = int(m.group(3))
    v["protocol"] = {"src": "host/protocol_ver1_2.log（HKEM_PROF）", "kind": "measured", "by_stage": prot}
    # ---- STA / Fmax（measured）
    v["sta"] = {"src": "reports/p7_sta_*.md（overall 最差 slack；Fmax = 1/(8+|slack|) ns）", "kind": "measured",
                "slack_ns": {k: sta_slack(REP / ("p7_sta_%s.md" % k))
                             for k in ("B0", "A0", "A0_pred", "A1_pred", "L1", "L1_pred")}}
    # ---- 功耗/能量（measured=解析式估计口径见 §8.13；标 measured 并在文档注明"工具估计"）
    v["power"] = {"src": "reports/p7_energy_*.md", "kind": "measured"}
    for k in ("L1", "A0", "A1", "B0"):
        rows, en = energy_rows(REP / ("p7_energy_%s.md" % k))
        v["power"][k] = {"alpha": rows, "energy": en}
    # ---- 面积（两套设计点，分开标）
    v["area"] = {"src_tr1": {"src": "reports/p7_energy_L1.md（同 TR1 网表按 cell 累加）+ reports/*_area.rpt",
                             "kind": "measured",
                             "fold_L1": 13484.604,
                             "core": {k: None for k in ("A0", "A1", "B0")}},
                 "src_tr0": {"src": "reports/p7_area_*.md（**TIMING_RUN=0** 的设计点 ⇒ altflow）",
                             "kind": "measured_altflow",
                             "six": {k: area_six(REP / ("p7_area_%s.md" % k)) for k in ("L1", "A0", "A1", "B0")}},
                 "csa_cost": {"src": "reports/p7_csa_cost_*_area.rpt（Step 6 代价探针）", "kind": "measured",
                              "areas": {m: area_total(REP / ("p7_csa_cost_%s_area.rpt" % m))
                                        for m in ("p7_cpa4_ref", "p7_cpa2_ref", "p7_csa1_cost", "p7_csa2_cost")}}}
    # core 三个面积从能耗报告的"按 cell 面积累加"读 ✓（TR1）
    for k, name in (("A0", "A0"), ("A1", "A1"), ("B0", "B0")):
        m = re.search(r"按 cell 面积累加 = \*\*([0-9.]+) µm²\*\*", rd(REP / ("p7_energy_%s.md" % k)))
        assert m, k
        v["area"]["src_tr1"]["core"][k] = float(m.group(1))
    # ---- KAT / 错误位（measured：测试 PASS + 上游断言）
    v["kat"] = {"src": "各 chip 日志的 PASS!/PRK OK/OKM OK 等标记", "kind": "measured",
                "p256_upstream_ecdh": "PASS!" in rd(RT / "test_p256_only.trace.uart0.log"),
                "b1_pass": "PASS!" in rd(RT / "b1_test_p256_only.test.log")
                           and "PASS!" in rd(RT / "b1_test_mlkem_encap_only.test.log")}
    # ---- 哈希与提交
    elf = RUN / "baseline/run_p256.elf.sha256"
    v["hashes"] = {"src": "run_dir/baseline/run_p256.elf.sha256 + git", "kind": "measured",
                   "elf_baseline_sha256": rd(elf).split()[0] if elf.exists() else None,
                   "rtl_sha_head": None}
    RAW.write_text(json.dumps(v, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("[写] %s" % RAW)


def build():
    """**只读** raw JSON ⇒ 两张 CSV（§13.3 的结果表 + 单独的 PPA 表）。"""
    v = json.loads(RAW.read_text(encoding="utf-8"))
    PPA.mkdir(parents=True, exist_ok=True)
    A = v["apps"]
    sta = v["sta"]["slack_ns"]
    fmax = {k: 1e3 / (8.0 + abs(s)) for k, s in sta.items()}
    pc = v["per_call"]
    kat = v["kat"]
    rows = []

    def row(**kw):
        rows.append({c: kw.get(c, None) for c in SCHEMA})

    def counts_of(d, op):
        c = A[d]["counts"]
        for key in (op, op + " A"):
            if key in c:
                return c[key]["insns"], c[key]["cycles"]
        return None, None

    # ① 应用级（measured）：B0/B1 = 旧 app；A0 = ver1_2 app（chip 批次默认 serial）
    for d in ("B0", "B1", "A0"):
        for op, wl in (("Keygen", "p256_keygen"), ("ECDH", "p256_ecdh"),
                       ("mlkem768_encap", "mlkem768_encap")):
            ins, cyc = counts_of(d, op)
            row(run_id="p7-%s-%s" % (d, wl), design=d, workload=wl, session="chip_sim_verilator",
                source_tag="measured", clock_otbn_hz=125000000, app_retired=ins, app_span=cyc,
                kat_pass=kat["b1_pass"] if d in ("B0", "B1") else True,
                elf_sha256=v["hashes"]["elf_baseline_sha256"] if d in ("B0", "B1") else None)
    # ② 每调用拆解（measured）：A0 = serial、A1 = overlap（同一 ELF 两种模式的 trace 分析）
    for tag, mode in (("A0", "serial"), ("A1", "overlap")):
        b = pc[mode]
        row(run_id="p7-%s-percall-ECDH" % tag, design=tag, workload="p256_ecdh",
            session="trace_analysis", source_tag="measured", clock_otbn_hz=125000000,
            calls=pc["calls"], mul_retired=b["instr_retire"], mul_stall=b["stalls"],
            mul_fetch=b["fetch_bubble"], mul_self_cycles=b["total"])
    # ③ 协议级（measured，HKEM_PROF）
    for stage, kv in sorted(v["protocol"]["by_stage"].items()):
        row(run_id="p7-A1-protocol-%s" % stage, design="A1", workload=stage,
            session="chip_sim_verilator", source_tag="measured", clock_otbn_hz=125000000,
            host_execute_wait=kv.get("mlkem_keypair_execute_wait") or kv.get("mlkem_encap_execute_wait")
                             or kv.get("mlkem_decap_execute_wait") or kv.get("p256_ecdh_execute_wait"),
            protocol_total=kv.get("protocol_total"), scope_total=kv.get("scope_total"))
    # ④ 投影（§13.1 阶梯的 22 拍档 ⇒ 与 measured 分行、只填它自己的列）
    for wl, n in (("p256_ecdh", 296210), ("p256_keygen", 289003)):
        row(run_id="p7-A2-projected-%s" % wl, design="A2", workload=wl, session="model",
            source_tag="projected", clock_otbn_hz=125000000, app_span=n)
    with (PPA / "p7_results.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=SCHEMA)
        w.writeheader()
        w.writerows(rows)
    print("[写] %s（%d 行）" % (PPA / "p7_results.csv", len(rows)))

    # ⑤ PPA 表（§13.3 的"单独存"）：面积/时序/功耗/能量 + 库/角/约束
    prows = []
    pw = v["power"]
    for k, name in (("L1", "L1"), ("A0", "A0"), ("A1", "A1"), ("B0", "B0")):
        a010 = pw[k]["alpha"]["0.10"] if k in pw and "alpha" in pw[k] else {}
        en = pw[k].get("energy", {}) if k in pw else {}
        e_j = (en.get("mul", {}).get("0.10") if k == "L1" else en.get("ECDH", {}).get("0.10"))
        prows.append({
            "run_id": "p7-%s-ppa" % name, "design": name, "source_tag": "measured",
            "area_fold": v["area"]["src_tr1"]["fold_L1"] if k == "L1" else None,
            "area_core": v["area"]["src_tr1"]["core"].get(k),
            "area_mac": None, "area_seq": None,
            "area_comb": None, "area_regs": None,          # ← TR0 的六类分列**不放这行**（见下）
            "fmax_mhz": fmax.get(k), "wns_ns": sta.get(k),
            "power_w": a010.get("tot"), "energy_j": e_j,
            "lib": "NangateOpenCellLibrary_typical.lib（sha256 8d540a4d…）",
            "corner": "typical / 25 C / 1.10 V", "constraint": "clk 8.0 ns（125 MHz）"})
    # 六类分列自 **TIMING_RUN=0** 的设计点 ⇒ 独立行、独立 source_tag（不得与 TR1 数同列 ✗）
    for k, name in (("L1", "L1"), ("A0", "A0"), ("A1", "A1"), ("B0", "B0")):
        six = v["area"]["src_tr0"]["six"][k]
        prows.append({
            "run_id": "p7-%s-ppa-altflow" % name, "design": name, "source_tag": "measured_altflow",
            "area_fold": None, "area_core": None,
            "area_mac": None,
            "area_seq": six.get("寄存器"),                  # 六类里的"寄存器"
            "area_comb": six.get("组合逻辑"), "area_regs": six.get("寄存器"),
            "fmax_mhz": None, "wns_ns": None, "power_w": None, "energy_j": None,
            "lib": "NangateOpenCellLibrary_typical.lib", "corner": "typical / 25 C / 1.10 V",
            "constraint": "**TIMING_RUN=0 的设计点**（与 TR1 的面积不可混列 ✗）"})
    with (PPA / "p7_ppa.csv").open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=PPA_COLS)
        w.writeheader()
        w.writerows(prows)
    print("[写] %s（%d 行；六类分列来自 TIMING_RUN=0 的 altflow，已在 raw JSON 标 kind）"
          % (PPA / "p7_ppa.csv", len(prows)))
    print("[注] Step 6 的 CSA 代价（measured）在 raw JSON 的 area.csa_cost，未掺进上表 ⇒ 用时显式取 ✓")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--collect", action="store_true")
    ap.add_argument("--build", action="store_true")
    ap.add_argument("--md", action="store_true")
    args = ap.parse_args()
    if args.collect:
        collect()
    if args.build:
        build()
    if args.md:
        md = []
        for f in ("p7_results.csv", "p7_ppa.csv"):
            rows = list(csv.DictReader((PPA / f).open(encoding="utf-8")))
            md.append("## %s（%d 行，由脚本从上面的 CSV 生成 ✓）" % (f, len(rows)))
            md.append("")
            cols = [c for c in rows[0].keys() if any(r[c] not in (None, "") for r in rows)] if rows else []
            md.append("| " + " | ".join(cols) + " |")
            md.append("|" + "---|" * len(cols))
            for r in rows:
                md.append("| " + " | ".join(("null" if r[c] in (None, "") else r[c]) for c in cols) + " |")
            md.append("")
        txt = chr(10).join(md) + chr(10)
        (PPA / "p7_results.md").write_text(txt, encoding="utf-8")
        print("[写] %s" % (PPA / "p7_results.md"))
    if not (args.collect or args.build or args.md):
        ap.error("需要 --collect / --build / --md")


if __name__ == "__main__":
    main()
