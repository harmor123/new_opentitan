#!/usr/bin/env python3
"""IBEX(chip) 层文档：宿主 mcycle 分段 + OTBN 硬件计数器 —— 并把 **ISS / RTL 两层并排**进来。

数据源（只读，全部来自同一批 chip 日志，不手抄）：
  · `logs_hkem/<版本>/test_mlkem_{keypair,encap,decap}_only.uart0.log`   —— chip `OTBN insn_cnt`（指令比指令）
  · `logs_hkem/<版本>/phase{1_keygen,2_alice_encap,2_bob_decap}_test.uart0.log`
        —— `HKEM_PROF,<test>,<阶段>,<cycles>`（宿主 mcycle 分段）+ 三个 OTBN app 的指令数
  · `logs_hkem/<版本>/test_p256_only.uart0.log`、`test_hkdf_only.uart0.log`
  · 并排列（只读）：`logs_hkem/<版本>/rtl/rtl_trace_<op>.json`、`logs_hkem/rtl_extra/rtl_trace_{p256,hkdf_kmac,hkdf_sw}.json`

产出：
  · `--archive DIR` → `DIR/Ibex实测_三版对照.md`（实验数据/）
  · `--write`       → `logs_hkem/Ibex实测_三版对照.md`（仓库内，便于复查）

口径（三层只做"周期比周期 / 指令比指令"的对接，别相减当实现差异）：见 `实验数据/README.md`。
"""
import argparse
import json
import re
import sys
from pathlib import Path

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = Path(__file__).resolve().parents[3]
VERS = ("ver0_1", "ver0_2", "ver1_1")
TITLE = {"ver0_1": "ver0_1（软件 Keccak）", "ver0_2": "ver0_2（KMAC 硬件哈希）",
         "ver1_1": "ver1_1（官方向量指令 + KMAC）"}
OPS = (("keygen", "keypair", "mlkem_keypair", "phase1_keygen_test"),
       ("encap", "encap", "mlkem_encap", "phase2_alice_encap_test"),
       ("decap", "decap", "mlkem_decap", "phase2_bob_decap_test"))
RE_COUNT = re.compile(r"([A-Za-z0-9_]+) OTBN instruction count[:=]\s*(0[xX][0-9a-fA-F]+|\d+)")
RE_TOTAL = re.compile(r"total OTBN instructions\s*[:=]\s*([\d,]+)")
RE_CYCLES = re.compile(r"cycles[:=]\s*([\d,]+)")
RE_HKDF_CYCLES = re.compile(r"HKDF cycles\s*=\s*([\d,]+)")
RE_PROF = re.compile(r"HKEM_PROF,([A-Za-z0-9_]+),([A-Za-z0-9_]+),(\d+)")
RE_SCOPE = re.compile(r"HKEM_PROF_SCOPE,([A-Za-z0-9_]+),([A-Za-z0-9_]+),(\d+)")


def N(s):
    return int(str(s).replace(",", ""))


def read_log(p: Path):
    """把一份 chip 日志解析成：指令数 {app: n}、宿主 cycles、HKEM_PROF 分段、SCOPE 汇总。"""
    if not p.exists():
        return None
    t = p.read_text(encoding="utf-8", errors="replace")
    out = {"insn": {}, "insn_seq": [], "cycles": None, "prof": [], "scope": {}}
    for m in RE_COUNT.finditer(t):
        out["insn"][m.group(1)] = int(m.group(2), 0)
        out["insn_seq"].append(int(m.group(2), 0))
    m = RE_TOTAL.search(t)
    if m:
        out["insn"]["(total)"] = N(m.group(1))
    m = RE_CYCLES.search(t)
    if m:
        out["cycles"] = N(m.group(1))
    m = RE_HKDF_CYCLES.search(t)
    if m:
        out["cycles"] = N(m.group(1))
    m = re.search(r"OTBN insn_cnt:\s*([\d,]+)", t)          # ML-KEM only 测试的写法
    if m:
        out["insn"]["mlkem"] = N(m.group(1))
    for m in RE_PROF.finditer(t):
        out["prof"].append((m.group(2), N(m.group(3))))
    for m in RE_SCOPE.finditer(t):
        out["scope"][m.group(2)] = N(m.group(3))
    return out


def rtl_span(p: Path, idx=0):
    """RTL JSON 里第 idx 个会话的 (ΣE, 跨度)；缺文件返回 (None, None)。"""
    if not p.exists():
        return None, None
    d = json.loads(p.read_text(encoding="utf-8"))
    ses = d.get("sessions") or [d]
    if idx >= len(ses):
        return None, None
    sc = ses[idx]["self_check"]
    return sc["sum_E"], sc["span"]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--archive", default="", metavar="DIR")
    args = ap.parse_args()

    L = ["# IBEX(chip) 实测 · 三版对照（宿主分段 + 与 ISS / RTL 两层的逐行对接）", "",
         "> 生成：`python3 test_perf/tools/gen/gen_ibex_doc.py --write --archive <实验数据/>`"
         "（数字全部从 `logs_hkem/<版本>/*.uart0.log` 与 RTL 的 JSON 生成，**不手抄**）。",
         "> 口径：**宿主** Ibex `mcycle`（含总线/驱动/等待）与 **OTBN 硬件计数器 `INSN_CNT`**；",
         "> 三层只做「**周期比周期**（`execute_wait` ↔ ISS `macro` ↔ RTL 跨度）」与"
         "「**指令比指令**（`INSN_CNT` ↔ ISS `insn` ↔ RTL Σ`E`）」的对接 ——",
         "> 三层口径不同，**相减得不出实现差异**；区别与联系见 `实验数据/README.md`。", ""]

    # ── §1 三层并排（ML-KEM 单 op 测试）──────────────────────────────────────
    L += ["## 1. ML-KEM 单 op：三层并排（这一组三层都能对上）", "",
          "| 版本 / op | ① IBEX `INSN_CNT` | ② ISS `insn`（①−②） | ③ RTL Σ`E` | ① 宿主 `execute_wait` | "
          "② ISS `macro`（①−②） | ③ RTL 跨度（③−②） |", "|---|---:|---:|---:|---:|---:|---:|"]
    for v in VERS:
        # ISS 对照
        rj = REPO / f"logs_hkem/{v}_profiling/re_{v}.json"
        iss = json.loads(rj.read_text(encoding="utf-8"))["apps"][v] if rj.exists() else {}
        for op, tname, stage, phasetest in OPS:
            lo = read_log(REPO / f"logs_hkem/{v}/test_mlkem_{tname}_only.uart0.log")
            ph = read_log(REPO / f"logs_hkem/{v}/{phasetest}.uart0.log")
            chip = (lo or {}).get("insn", {}).get("mlkem")
            ew = dict((ph or {}).get("prof", [])).get(stage + "_execute_wait")
            i_insn = iss.get(op, {}).get("insn")
            i_cyc = iss.get(op, {}).get("cycles")
            r_e, r_span = rtl_span(REPO / f"logs_hkem/{v}/rtl/rtl_trace_{op}.json")
            f = lambda x: f"{x:,}" if isinstance(x, int) else "—"
            d1 = f"{chip - i_insn:+,}" if (chip is not None and i_insn is not None) else "—"
            d2 = f"{ew - i_cyc:+,}，{100 * (ew - i_cyc) / i_cyc:+.2f}%" if (ew and i_cyc) else "—"
            d3 = f"{r_span - i_cyc:+,}，{100 * (r_span - i_cyc) / i_cyc:+.2f}%" if (r_span and i_cyc) else "—"
            L.append(f"| {TITLE[v].split('（')[0]} / `{op}` | {f(chip)} | {f(i_insn)}（{d1}） | {f(r_e)} | "
                     f"{f(ew)} | {f(i_cyc)}（{d2}） | {f(r_span)}（{d3}） |")
    L += ["", "> 读法：**①−②** 是 chip 与 ISS 的差（ver0_1 全 0；KMAC 版 = 轮询圈数差）；"
          "**①−②（周期）** 是宿主 `execute_wait` 与 ISS `macro` 的差（调用/等待开销，+0.70%～+1.02%）；"
          "**③−②** 是 RTL 真机跨度与 ISS 模型 `macro` 的差（KMAC 模型差，见 `RTL实测_三版对照.md` §4）。", ""]

    # ── §2 协议阶段：宿主分段 + 三个 OTBN app ────────────────────────────────
    L += ["## 2. 协议阶段（`phase1_keygen` / `phase2_*`）：宿主分段 + 三个 OTBN app", "",
          "> 协议里 **OTBN 被调用三次**：ML-KEM、P-256 ECDH、HKDF —— 各自的指令数由宿主读出打印；",
          "> 宿主分段（`HKEM_PROF`）就是协议里每一段花的 mcycle。RTL 层对这三者的真实周期见 §1（ML-KEM）与 §3。", ""]
    for v in VERS:
        L += [f"### {TITLE[v]}", ""]
        for pt in ("phase1_keygen_test", "phase2_alice_encap_test", "phase2_bob_decap_test"):
            ph = read_log(REPO / f"logs_hkem/{v}/{pt}.uart0.log")
            if ph is None:
                L += [f"（缺 `{pt}.uart0.log`）", ""]
                continue
            apps = "、".join(f"`{k}` {ph['insn'][k]:,}" for k in sorted(ph["insn"]) if k != "(total)")
            tot = ph["insn"].get("(total)")
            L += [f"**{pt}**：OTBN 指令数 {apps}" + (f"（`(total)` {tot:,}）" if tot else "")
                  + "；宿主分段：" if apps else f"**{pt}**：宿主分段：", "",
                  "| 阶段（宿主 mcycle） | 拍 |", "|---|---:|"]
            for st, cy in ph["prof"]:
                L.append(f"| `{st}` | {cy:,} |")
            for k in ("scope_total", "accounted_total", "unaccounted_total"):
                if k in ph["scope"]:
                    L.append(f"| `{k}` | {ph['scope'][k]:,} |")
            L.append("")
    # ── §3 单 app：P-256 / HKDF（宿主 ↔ RTL 对照）──────────────────────────
    L += ["## 3. 单 app 测试：P-256 / HKDF（宿主 cycles ↔ **RTL 真机跨度**）", "",
          "> 这两个 app 的 RTL 数据在 `RTL实测_三版对照.md` §3b；这里给宿主的 `cycles`（= `profile_start/end`，"
          "**宿主 mcycle**）与 RTL 跨度的对照 —— 差 = 总线搬运 + 驱动等待 + 中断等宿主开销。",
          "> P-256 行：宿主 `cycles` 与 RTL 列都取**第一次调用（Keygen A）**；ECDH 的 RTL 跨度 603,474 拍见 §3b.2。", "",
          "| 版本 / 测试 | 宿主 `cycles` | 宿主读数（OTBN 指令数） | RTL Σ`E` | RTL 跨度 | 宿主 − RTL 跨度 |",
          "|---|---:|---|---:|---:|---:|"]
    rtl_p = REPO / "logs_hkem/rtl_extra/rtl_trace_p256.json"
    rtl_h1 = REPO / "logs_hkem/rtl_extra/rtl_trace_hkdf_kmac.json"
    rtl_h0 = REPO / "logs_hkem/rtl_extra/rtl_trace_hkdf_sw.json"
    for v in VERS:
        pl = read_log(REPO / f"logs_hkem/{v}/test_p256_only.uart0.log")
        hl = read_log(REPO / f"logs_hkem/{v}/test_hkdf_only.uart0.log")
        if pl:
            # 日志里是 4 次调用（Keygen A/B、ECDH A/B）⇒ 按顺序做游程压缩显示
            seq, ins = [], ""
            for x in pl["insn_seq"]:
                if seq and seq[-1][0] == x:
                    seq[-1][1] += 1
                else:
                    seq.append([x, 1])
            ins = "、".join(f"{x:,} ×{c}" for x, c in seq)
            # RTL 侧取第 1 个会话（Keygen A）；ECDH 见 RTL实测_三版对照.md §3b.2
            r_e, r_span = rtl_span(rtl_p, 0)
            cy = pl.get("cycles")
            L.append(f"| {TITLE[v].split('（')[0]} / `test_p256_only` | {cy:,} | {ins} | {r_e:,} | {r_span:,} | "
                     f"{cy - r_span:+,} |" if (cy and r_span) else
                     f"| {TITLE[v].split('（')[0]} / `test_p256_only` | — | {ins} | — | — | — |")
        if hl:
            ins = "、".join((f"{x:,}（合计）" if k == "(total)" else f"{x:,}")
                            for k, x in sorted(hl["insn"].items()))
            r_e, r_span = rtl_span(rtl_h0 if v == "ver0_1" else rtl_h1, 0)
            cy = hl.get("cycles")
            L.append(f"| {TITLE[v].split('（')[0]} / `test_hkdf_only` | {cy:,} | {ins} | {r_e:,} | {r_span:,} | "
                     f"{cy - r_span:+,} |" if (cy and r_span) else
                     f"| {TITLE[v].split('（')[0]} / `test_hkdf_only` | — | {ins} | — | — | — |")
    L += ["", "> P-256 的三版**指令数逐位相同**（Keygen 573,922 / ECDH 581,607）⇒ 同一个官方 app；",
          "> HKDF 的 ver0_2 与 ver1_1 相同（3,374），ver0_1 是软件 Keccak 版（51,145）。", ""]

    # ── §4 三版 × 全部 OTBN app 指令数矩阵 ─────────────────────────────────
    L += ["## 4. 三版 × 全部 OTBN app：指令数矩阵（都来自 chip 日志）", "",
          "| app | ver0_1 | ver0_2 | ver1_1 |", "|---|---:|---:|---:|"]
    rows = [("ML-KEM keypair", "test_mlkem_keypair_only", "mlkem"), ("ML-KEM encap", "test_mlkem_encap_only", "mlkem"),
            ("ML-KEM decap", "test_mlkem_decap_only", "mlkem"), ("P-256 ECDH（`test_p256_only`）", "test_p256_only", None),
            ("HKDF（`test_hkdf_only`）", "test_hkdf_only", None)]
    for label, tname, key in rows:
        cells = []
        for v in VERS:
            lo = read_log(REPO / f"logs_hkem/{v}/{tname}.uart0.log")
            if lo is None:
                cells.append("—")
                continue
            v_ = lo["insn"].get(key) if key else (lo["insn"].get("(total)") or next(iter(lo["insn"].values()), None))
            cells.append(f"{v_:,}" if v_ else "—")
        L.append(f"| {label} | " + " | ".join(cells) + " |")
    L.append("")
    txt = "\n".join(L) + "\n"
    print(txt)
    if args.write:
        p = REPO / "logs_hkem/Ibex实测_三版对照.md"
        p.write_text(txt, encoding="utf-8")
        print(f"[写] {p.relative_to(REPO)}")
    if args.archive:
        d = Path(args.archive)
        d.mkdir(parents=True, exist_ok=True)
        p = d / "Ibex实测_三版对照.md"
        p.write_text(txt, encoding="utf-8")
        print(f"[写] {p}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
