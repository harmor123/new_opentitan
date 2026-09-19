#!/usr/bin/env python3
"""harness 法剖面测量器（ver0_1 方式；输出对齐 ver0_1 数据文档的表格格式）。

与 `main.py` 的 coverage 归因不同，本工具**逐字复刻 ver0_1 的测量方法**：

    ① Macro      整 app 的 Instructions / Cycles / Stalls       （文档 §4）
    ② 阶段分解   C_net = C_profiling − C_control（也减 I/S）      （文档 §1.2）
    ③ 闭环       Σ(阶段) vs 整 app，残差 = outer wrapper          （文档 §5.13 等）
    ④ 指令归因   每阶段的 OTBN 指令家族直方图                      （文档 §7）
    ⑤ 代码体积   .text / .data / .bss（NOLOAD 不计），= riscv32-unknown-elf-size 口径

ISS 口径（与文档一致）：cycles = 已提交指令数 + 停滞周期数。

用法（仓库根目录）:
    python3 test_perf/harness.py --config test_perf/harness_config.yaml
    python3 test_perf/harness.py --config ... --version ver0_1 --phase keygen_ntt
    python3 test_perf/harness.py --config ... --csv out.csv --markdown out.md --json out.json

配置见 test_perf/harness_config.yaml。
"""

import argparse
import csv
import json
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "hw/ip/otbn/dv/otbnsim"))

from sim.load_elf import load_elf            # noqa: E402
from sim.standalonesim import StandaloneSim  # noqa: E402

from elftools.elf.elffile import ELFFile     # noqa: E402

MHZ = 100.0


# ── 符号边界（与 test_perf/main.py:_get_func_boundaries 同法）──────────────
def load_text_boundaries(elf_path: str):
    """返回 [(start, end, name), ...]：.text 段（IMEM）的 GLOBAL 符号边界。

    OTBN 汇编器不设 st_size（恒为 0）→ 边界用"下一个符号的地址"；
    只取 .text 段符号（DMEM 标签的地址与 IMEM 重叠，混入会切碎边界）。
    """
    with open(elf_path, "rb") as f:
        elf = ELFFile(f)
        text_ndx = None
        for i, sec in enumerate(elf.iter_sections()):
            if sec.name == ".text":
                text_ndx = i
                break
        if text_ndx is None:
            return []
        text_end = elf.get_section(text_ndx)["sh_addr"] + elf.get_section(text_ndx)["sh_size"]
        symtab = elf.get_section_by_name(".symtab")
        if symtab is None:
            return []
        syms = []
        for s in symtab.iter_symbols():
            e = s.entry
            if e.st_shndx == text_ndx and e.st_value:
                syms.append((e.st_value, s.name))
    syms.sort()
    out = []
    for i, (addr, name) in enumerate(syms):
        end = syms[i + 1][0] if i + 1 < len(syms) else text_end
        out.append((addr, end, name))
    return out


# ── ISS ────────────────────────────────────────────────────────────────────
def run_elf(elf_path: str):
    """跑一个 ELF → (iss_cycles, insn, stalls, insn_histo, func_calls, boundaries, coverage)。

    ISS 确定性 → 结果可复现。文档 §4 的 Cycles = insn + stalls；iss_cycles 是
    ISS 的 run() 总周期（另含 ~200 拍 wipe/初始化，不在 stats 内）。
    coverage = ISS 的逐 PC 执行计数（用于证明"某函数是否真的从未执行"）。
    """
    sim = StandaloneSim()
    load_elf(sim, str(elf_path))
    sim.state.ext_regs.commit()
    sim.start(collect_stats=True)
    cycles = sim.run(verbose=False, dump_file=None)
    st = sim.stats
    return (cycles, st.get_insn_count(), st.stall_count, dict(st.insn_histo),
            list(st.func_calls), load_text_boundaries(str(elf_path)),
            dict(st.coverage))


def exec_per_func(coverage, boundaries):
    """每函数"实际执行的指令数"（由 ISS 逐 PC 覆盖计数直方图汇总）。

    某函数为 0（或不在字典里）⇒ 它在本次运行中**从未执行** ⇒ 对该 app 是死代码
    （充分证据：不依赖任何静态推断，直接来自 ISS 的逐 PC 计数）。
    """
    import bisect
    bnds = sorted(boundaries)
    starts = [b[0] for b in bnds]
    out = {}
    for pc, cnt in (coverage or {}).items():
        i = bisect.bisect_right(starts, pc) - 1
        if i < 0:
            continue
        s, e, n = bnds[i]
        if s <= pc < e:
            out[n] = out.get(n, 0) + cnt
    return out


def _name_at(addr: int, boundaries) -> str:
    for start, end, name in boundaries:
        if start <= addr < end:
            return name
    return f"@{addr:#x}"


def _calls_by_name(func_calls, boundaries) -> dict:
    """把 func_calls（含 callee 地址）按被调函数名归组计数。"""
    m = {a: n for a, _e, n in boundaries}
    out = {}
    for c in func_calls or []:
        n = m.get(c.get("callee_func"))
        if n:
            out[n] = out.get(n, 0) + 1
    return out


def _count_calls(func_calls, boundaries, target: str):
    """数某个函数在整 app 里被调用的次数（找不到该符号则返回 None）。"""
    m = {n: a for a, _e, n in boundaries or []}
    if target not in m:
        return None
    return _calls_by_name(func_calls, boundaries).get(target, 0)


# ── 代码体积（= riscv32-unknown-elf-size 的 text/data/bss 口径）────────────
def elf_size(elf_path: str):
    text = data = bss = 0
    with open(elf_path, "rb") as f:
        for sec in ELFFile(f).iter_sections():
            flags = sec["sh_flags"]
            if not (flags & 0x2):                    # SHF_ALLOC
                continue
            if sec["sh_type"] == "SHT_NOBITS":
                bss += sec["sh_size"]
            elif sec["sh_type"] == "SHT_PROGBITS":
                if flags & 0x1:                      # SHF_WRITE
                    data += sec["sh_size"]
                else:
                    text += sec["sh_size"]
    return text, data, bss


# ── bazel ──────────────────────────────────────────────────────────────────
def bazel_build(targets):
    r = subprocess.run(["bazel", "build", *targets], cwd=REPO,
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr[-3000:], file=sys.stderr)
        raise SystemExit(f"bazel build 失败（{len(targets)} 个目标）")


def bazel_elf(target: str) -> str:
    r = subprocess.run(["bazel", "cquery", "--output=files", target],
                       cwd=REPO, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stderr[-2000:], file=sys.stderr)
        raise SystemExit(f"bazel cquery 失败: {target}")
    for line in r.stdout.splitlines():
        if line.endswith(".elf"):
            return str(REPO / line)
    raise SystemExit(f"目标 {target} 没有 .elf 产物")


def _norm_phase(p):
    """允许 phases 写成字符串或 {name: ..., fips: ..., evidence: ..., closure: bool}。"""
    if isinstance(p, str):
        return {"name": p, "closure": True}
    d = dict(p)
    d.setdefault("closure", True)
    return d


# ── 主流程 ─────────────────────────────────────────────────────────────────
def run_version(ver: dict, phases_filter=None):
    pkg = ver["package"].rstrip("/")
    prefix = ver.get("target_prefix", "")
    phases = [_norm_phase(p) for p in ver["phases"]]
    if phases_filter:
        phases = [p for p in phases if p["name"] in phases_filter]

    print(f"\n===== {ver['name']}：{len(phases)} 个阶段 =====")

    # ① Macro：逐个 app 单独构建/测量；装不下的（老版本内存布局）跳过，
    #    不填任何替代值（周期只来自实测）。
    apps = {}
    for op, target in (ver.get("app_targets") or {}).items():
        try:
            bazel_build([target])
        except SystemExit:
            print(f"  [macro] {op:8s} 跳过：app 在当前内存布局下装不下", file=sys.stderr)
            continue
        elf = bazel_elf(target)
        c, i, s, histo, fcs, bounds, cov = run_elf(elf)
        t, d, b = elf_size(elf)
        # 口径与 ver0_1 文档一致：Cycles = insn + stalls（ISS 的 run() 另含
        # ~200 拍的 wipe/初始化，不在 stats 里，故单列 iss_cycles）
        # exec_insn：每函数实际执行的指令数（=0 即从未执行 ⇒ 死代码证据）
        apps[op] = {"cycles": i + s, "insn": i, "stalls": s,
                    "iss_cycles": c, "text": t, "data": d, "bss": b,
                    "histo": histo, "func_calls": fcs, "boundaries": bounds,
                    "exec_insn": exec_per_func(cov, bounds),
                    "source": "measured"}
        print(f"  [macro] {op:8s} cycles={i + s:>9,} (insn {i:,} + stalls {s:,})"
              f"  iss_cycles={c:,}  {(i + s) / MHZ / 1000:.2f} ms")

    # ② 阶段
    prof_t = [f"{pkg}:{prefix}{p['name']}_profiling" for p in phases]
    ctrl_t = [f"{pkg}:{prefix}{p['name']}_control" for p in phases]
    bazel_build(prof_t + ctrl_t)

    rows = []
    for p in phases:
        name = p["name"]
        p_elf = bazel_elf(f"{pkg}:{prefix}{name}_profiling")
        c_elf = bazel_elf(f"{pkg}:{prefix}{name}_control")
        pc, pi, ps, ph, pfc, pb, _pcov = run_elf(p_elf)
        cc, ci, cs, ch, cfc, cb, _ccov = run_elf(c_elf)
        t, d, b = elf_size(p_elf)

        # 指令直方图差值（control 的调用在这里被减掉）
        histo_delta = {k: ph.get(k, 0) - ch.get(k, 0) for k in set(ph) | set(ch)}
        # 调用计数差值：按**被调函数名**归组（profiling − control）
        calls_p = _calls_by_name(pfc, pb)
        calls_c = _calls_by_name(cfc, cb)
        calls_delta = {k: calls_p.get(k, 0) - calls_c.get(k, 0)
                       for k in set(calls_p) | set(calls_c)}
        rows.append({
            "version": ver["name"],
            "phase": name,
            "cycles": pc - cc, "prof_cycles": pc, "ctrl_cycles": cc,
            "insn": pi - ci, "stalls": ps - cs,
            "text": t, "data": d, "bss": b, "image": t + d,
            "fips": p.get("fips", ""), "evidence": p.get("evidence", ""),
            "closure": bool(p.get("closure", True)),
            "insn_histo": histo_delta,
            "mulqacc": histo_delta.get("bn.mulqacc.wo", 0),
            "calls": calls_delta,
        })
        print(f"  {name:44s} Δcycles={pc - cc:>9,}  Δinsn={pi - ci:>9,}  "
              f"Δstall={ps - cs:>6,}  image={t + d:>6,} B")

    # ③' 复用行（文档口径 Reuse-fixed / Estimated）：按调用次数从已测阶段换算，
    #     不是独立测量，但参与 Σ 闭环（文档 §6.11/§7.11 就是这么算的）。
    for r in ver.get("reuse", []):
        base = next((x for x in rows if x["phase"] == r["from"]), None)
        if base is None:
            print(f"  [reuse] 跳过 {r['phase']}：基准 {r['from']} 未测到", file=sys.stderr)
            continue
        num, den = (str(r.get("factor", "1/1")).split("/") + ["1"])[:2]
        f = float(num) / float(den)
        rows.append({
            "version": ver["name"],
            "phase": r["phase"],
            "cycles": round(base["cycles"] * f), "prof_cycles": None, "ctrl_cycles": None,
            "insn": round(base["insn"] * f), "stalls": round(base["stalls"] * f),
            "text": 0, "data": 0, "bss": 0, "image": 0,
            "fips": r.get("fips", ""),
            "evidence": r.get("evidence", f"Reuse({r['from']}×{r.get('factor', '1')})"),
            "closure": True, "insn_histo": {},
            "reused_from": r["from"], "factor": f,
        })
        print(f"  {r['phase']:44s} Δcycles={round(base['cycles'] * f):>9,}  "
              f"(reuse {r['from']} × {r.get('factor', '1')})")

    # ③ 闭环：按操作前缀分组，Σ(closure 阶段) vs 整 app
    #    closure_ops 可限制只核对部分操作（其余因"复用已测 kernel"本就不闭合，见文档口径）
    closure = {}
    if apps:
        want = ver.get("closure_ops") or list(apps.keys())
        groups = defaultdict(int)
        for r in rows:
            if not r["closure"]:
                continue
            op = r["phase"].split("_", 1)[0]
            if op in want:
                groups[op] += r["cycles"]
        print("\n  [closure]")
        for op in sorted(groups):
            app_c = apps.get(op, {}).get("cycles")
            if app_c:
                res = app_c - groups[op]
                pct = 100.0 * res / app_c
                closure[op] = {"sum": groups[op], "app": app_c,
                               "residual": res, "residual_pct": round(pct, 3)}
                print(f"    {op:8s} Σ阶段={groups[op]:>9,}  整app={app_c:>9,}  "
                      f"残差={res:>7,} ({pct:.3f}%)")
    return rows, apps, closure


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True)
    ap.add_argument("--version", action="append")
    ap.add_argument("--phase", action="append")
    ap.add_argument("--csv"), ap.add_argument("--json")
    ap.add_argument("--markdown")
    args = ap.parse_args()

    import yaml
    cfg = yaml.safe_load(Path(args.config).read_text(encoding="utf-8"))

    all_rows, all_apps, all_closure = [], {}, {}
    for ver in cfg["versions"]:
        if args.version and ver["name"] not in args.version:
            continue
        rows, apps, clos = run_version(ver, set(args.phase) if args.phase else None)
        all_rows += rows
        all_apps[ver["name"]] = apps
        all_closure[ver["name"]] = clos

    if not all_rows:
        return 1

    # ④ 总表（严格照文档 §5.13/§6.11/§7.11：Stage | Cycles | % | FIPS | 口径；
    #    % 的分母 = **整 app**；随后是 Σ、残差、attribution coverage 与两个闭环）
    def _row_metric(r, key, vrows):
        """取某行的指标；reuse 行按 factor 从基准换算（字典指标逐键换算）。"""
        if r.get("reused_from"):
            base = next((x for x in vrows if x["phase"] == r["reused_from"]), None)
            if base is None:
                return None
            v = base.get(key)
            f = r.get("factor", 1.0)
            if isinstance(v, dict):
                return {k: x * f for k, x in v.items()}
            return None if v is None else v * f
        return r.get(key)

    for ver in cfg["versions"]:
        vname = ver["name"]
        if vname not in all_apps:
            continue
        apps = all_apps[vname]
        vrows = [r for r in all_rows if r["version"] == vname]
        marker = ver.get("call_closure")          # 形如 {func: keccak_f, label: Keccak-f}

        for op, a in apps.items():
            sub = [r for r in vrows if r["phase"].startswith(op + "_") and r["closure"]]
            if not sub:
                continue
            app_c = a["cycles"]
            print(f"\n## {vname} / {op} 分解（分母 = 整 app {app_c:,} cycles）")
            print("| Stage | Cycles | % | FIPS | 口径 |")
            print("|---|---:|---:|---|---|")
            for r in sorted(sub, key=lambda x: -x["cycles"]):
                print(f"| `{r['phase']}` | {r['cycles']:,} | "
                      f"{100.0 * r['cycles'] / max(app_c, 1):.2f}% | "
                      f"{r['fips'] or '—'} | {r['evidence'] or 'Direct'} |")
            tot = sum(r["cycles"] for r in sub)
            res = app_c - tot
            print(f"| **Σ 阶段** | **{tot:,}** | {100.0 * tot / max(app_c, 1):.2f}% | | |")
            print(f"| 整 app | {app_c:,} | 100% | | |")
            print(f"\n残差 = **{res:,} cycles**（{100.0 * res / max(app_c, 1):.3f}%）→ "
                  f"**attribution coverage ≈ {100.0 - 100.0 * res / max(app_c, 1):.2f}%**")

            # 函数调用闭环（文档 §5.13 的 Keccak-f 闭环）；
            # 支持多个函数（ver0_2 用整套 KMAC 驱动 API 作闭环标记）
            if marker:
                m = marker if isinstance(marker, dict) else {"func": marker}
                ffuncs = m.get("funcs") or [m.get("func")]
                label = m.get("label", "/".join(ffuncs))
                app_n, ok = 0, True
                for f in ffuncs:
                    n = _count_calls(a.get("func_calls"), a.get("boundaries"), f)
                    if n is None:
                        ok = False
                        break
                    app_n += n
                if ok:
                    print(f"\n### {label} 调用闭环")
                    print("| Stage | 调用次数 |")
                    print("|---|---:|")
                    s = 0
                    for r in sorted(sub, key=lambda x: -x["cycles"]):
                        d = _row_metric(r, "calls", vrows) or {}
                        n = sum(d.get(f, 0) for f in ffuncs) if isinstance(d, dict) else (d or 0)
                        if not n:
                            continue
                        s += n
                        print(f"| `{r['phase']}` | {n:,.0f} |")
                    print(f"| **Σ 阶段** | **{s:,.0f}** |")
                    print(f"| 整 app | {app_n:,} |")
                    print(f"| 差异 | {app_n - s:+,.0f} |")

            # bn.mulqacc.wo 闭环（文档 §5.13）
            app_m = (a.get("histo") or {}).get("bn.mulqacc.wo")
            if app_m:
                print(f"\n### `bn.mulqacc.wo` 闭环")
                print("| Stage | bn.mulqacc.wo |")
                print("|---|---:|")
                s = 0
                for r in sorted(sub, key=lambda x: -x["cycles"]):
                    n = _row_metric(r, "mulqacc", vrows)
                    if n is None:
                        continue
                    s += n
                    print(f"| `{r['phase']}` | {n:,.0f} |")
                print(f"| **Σ 阶段** | **{s:,.0f}** |")
                print(f"| 整 app | {app_m:,} |")
                print(f"| 差异 | {app_m - s:+,.0f} |")

    # ④' Static memory footprint（文档 §3.2：Operation | IMEM | DMEM | Total）
    if all_apps:
        print("\n## Static memory footprint（文档 §3.2）")
        print("| Operation | IMEM | DMEM | Total |")
        print("|---|---:|---:|---:|")
        for vname, apps in all_apps.items():
            for op, a in apps.items():
                if a.get("text") is None or a.get("source") != "measured":
                    continue
                dm = (a.get("data") or 0) + (a.get("bss") or 0)
                print(f"| {vname} {op} | {a['text']:,} B | {dm:,} B | "
                      f"{a['text'] + dm:,} B |")

    # ⑤ 指令归因（每阶段 Top 指令）
    print("\n## 指令归因（Δ 后 Top 5）")
    for r in all_rows:
        if r.get("reused_from"):        # 复用行不是独立测量，没有直方图
            continue
        top = sorted(r["insn_histo"].items(), key=lambda x: -x[1])[:5]
        s = "  ".join(f"{k}={v:,}" for k, v in top)
        print(f"- `{r['version']}/{r['phase']}`: {s}")

    if args.csv:
        Path(args.csv).parent.mkdir(parents=True, exist_ok=True)
        with open(args.csv, "w", newline="", encoding="utf-8") as f:
            keys = [k for k in all_rows[0] if k != "insn_histo"]
            w = csv.DictWriter(f, fieldnames=keys, extrasaction="ignore")
            w.writeheader()
            w.writerows(all_rows)
        print(f"\n(CSV → {args.csv})")

    if args.json:
        Path(args.json).parent.mkdir(parents=True, exist_ok=True)
        Path(args.json).write_text(json.dumps(
            {"rows": all_rows, "apps": all_apps, "closure": all_closure},
            ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"(JSON → {args.json})")

    if args.markdown:
        Path(args.markdown).parent.mkdir(parents=True, exist_ok=True)
        L = ["| 版本 | 阶段 | 周期 | 指令 | 停滞 | text(B) | data(B) | 镜像(B) | FIPS | 口径 |",
             "|---|---|---:|---:|---:|---:|---:|---:|---|---|"]
        for r in all_rows:
            L.append(f"| {r['version']} | {r['phase']} | {r['cycles']:,} | "
                     f"{r['insn']:,} | {r['stalls']:,} | {r['text']:,} | "
                     f"{r['data']:,} | {r['image']:,} | {r['fips'] or '—'} | "
                     f"{r['evidence'] or 'Direct'} |")
        Path(args.markdown).write_text("\n".join(L) + "\n", encoding="utf-8")
        print(f"(Markdown → {args.markdown})")

    return 0


if __name__ == "__main__":
    sys.exit(main())
