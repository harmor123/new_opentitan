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


# ── ISS ────────────────────────────────────────────────────────────────────
def run_elf(elf_path: str):
    """跑一个 ELF → (cycles, insn, stalls, insn_histo)。ISS 确定性 → 可复现。"""
    sim = StandaloneSim()
    load_elf(sim, str(elf_path))
    sim.state.ext_regs.commit()
    sim.start(collect_stats=True)
    cycles = sim.run(verbose=False, dump_file=None)
    st = sim.stats
    return cycles, st.get_insn_count(), st.stall_count, dict(st.insn_histo)


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
        c, i, s, _ = run_elf(elf)
        t, d, b = elf_size(elf)
        apps[op] = {"cycles": c, "insn": i, "stalls": s,
                    "text": t, "data": d, "bss": b, "source": "measured"}
        print(f"  [macro] {op:8s} cycles={c:>9,}  insn={i:>9,}  "
              f"stalls={s:>7,}  {c / MHZ / 1000:.2f} ms")

    # ② 阶段
    prof_t = [f"{pkg}:{prefix}{p['name']}_profiling" for p in phases]
    ctrl_t = [f"{pkg}:{prefix}{p['name']}_control" for p in phases]
    bazel_build(prof_t + ctrl_t)

    rows = []
    for p in phases:
        name = p["name"]
        p_elf = bazel_elf(f"{pkg}:{prefix}{name}_profiling")
        c_elf = bazel_elf(f"{pkg}:{prefix}{name}_control")
        pc, pi, ps, ph = run_elf(p_elf)
        cc, ci, cs, _ = run_elf(c_elf)
        t, d, b = elf_size(p_elf)
        rows.append({
            "version": ver["name"],
            "phase": name,
            "cycles": pc - cc, "prof_cycles": pc, "ctrl_cycles": cc,
            "insn": pi - ci, "stalls": ps - cs,
            "text": t, "data": d, "bss": b, "image": t + d,
            "fips": p.get("fips", ""), "evidence": p.get("evidence", ""),
            "closure": bool(p.get("closure", True)),
            "insn_histo": ph,
        })
        print(f"  {name:44s} Δcycles={pc - cc:>9,}  Δinsn={pi - ci:>9,}  "
              f"Δstall={ps - cs:>6,}  image={t + d:>6,} B")

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

    # ④ 汇总表（文档 §5.13 格式：Stage | Cycles | % | FIPS | 口径）
    for vname, apps in all_apps.items():
        vrows = [r for r in all_rows if r["version"] == vname]
        for op, a in apps.items():
            sub = [r for r in vrows if r["phase"].startswith(op + "_")
                   and r["closure"]]
            if not sub:
                continue
            print(f"\n## {vname} / {op} 分解（分母 = Σclosure 阶段）")
            print("| Stage | Cycles | % | FIPS | 口径 |")
            print("|---|---:|---:|---|---|")
            tot = sum(r["cycles"] for r in sub)
            for r in sorted(sub, key=lambda x: -x["cycles"]):
                print(f"| `{r['phase']}` | {r['cycles']:,} | "
                      f"{100.0 * r['cycles'] / max(tot, 1):.2f}% | "
                      f"{r['fips'] or '—'} | {r['evidence'] or 'Direct'} |")
            print(f"| **Σ 阶段** | **{tot:,}** | | | |")
            print(f"| 整 app | {a['cycles']:,} | | | |")

    # ⑤ 指令归因（每阶段 Top 指令）
    print("\n## 指令归因（Δ 后 Top 5）")
    for r in all_rows:
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
