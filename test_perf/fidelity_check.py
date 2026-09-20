#!/usr/bin/env python3
"""判定性实验：harness 每行的成本**是否与输入数据的具体取值无关**。

为什么需要它：harness 行的输入缓冲是 `.zero`（全 0），app 用的是真实数据。
如果某个内核的执行路径依赖数据，那这一行的 Δ 就不能代表 app 的真实成本 ——
这是"harness 法能不能反映真实情况"里**唯一不能靠读代码确定**的一条。

本工具的判定逻辑（对每一行给出是/否，不含"可能"）：
  ① Δ_base：现状跑一次（输入 = 全 0）
  ② 把该行的 profiling/control 两个 .s 里**所有 `.zero N` 缓冲区**换成
     **同长度、同对齐的伪随机 `.word`**（只改取值，不改长度/对齐/结构），再跑 ⇒ Δ_rand
  ③ **Δ_base == Δ_rand（cycles / insn / stalls 三项全等）** ⇒ 该行与数据无关
     —— 于是"用 0 测出来的成本" == "用 app 真实数据测出来的成本"（**确定**）
     **不等** ⇒ 该行对数据敏感；工具打印差值，且该行必须以 app 真实输入测量
     （已知唯一预期不等的是 `poly_gen_matrix` 的拒绝采样 —— 它已用 app 真实 ρ ✓）

用法（Linux）:
    python3 test_perf/fidelity_check.py --config test_perf/harness_config.yaml --version ver0_1
    python3 test_perf/fidelity_check.py --config ... --version ver1_1 --phase encap_noise_x7 [--seed 1234]

注意：会在原地改 .s 再**自动还原**（备份在内存里；异常退出时也会尝试还原）。
"""
import argparse
import random
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import harness as H          # noqa: E402


def randomize_zero_buffers(text: str, rng: random.Random) -> tuple:
    """把 `.zero N` 换成 N 字节的伪随机 `.word`（N 必须是 4 的倍数）。只改取值。"""
    out, changed = [], 0
    for line in text.splitlines():
        m = re.match(r"^(\s*)\.zero\s+(\d+)\s*$", line)
        if not m:
            out.append(line)
            continue
        ind, n = m.group(1), int(m.group(2))
        if n == 0:
            out.append(line)
            continue
        if n % 4:
            raise SystemExit(f".zero {n} 不是 4 的倍数，无法用 .word 替换（{n}）")
        for _ in range(n // 4):
            out.append(f"{ind}.word 0x{rng.getrandbits(32):08x}")
        changed += 1
    return "\n".join(out) + "\n", changed


def run_row(ver: dict, row: str):
    rows, _, _ = H.run_version(ver, {row})
    return next((r for r in rows if r["phase"] == row), None)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True)
    ap.add_argument("--version", required=True)
    ap.add_argument("--phase", action="append", default=[])
    ap.add_argument("--seed", type=int, default=20260920)
    args = ap.parse_args()

    import yaml
    cfg = yaml.safe_load(Path(args.config).read_text(encoding="utf-8"))
    ver = next(v for v in cfg["versions"] if v["name"] == args.version)
    pkg = REPO / ver["package"].lstrip("/")
    phases = args.phase or [p["name"] if isinstance(p, dict) else p for p in ver["phases"]]

    print(f"[判定实验] {args.version}：{len(phases)} 行；输入数据 全0 vs 伪随机（同长度/同对齐）")
    print(f"{'行':36s} {'Δ_base(cyc/insn/stall)':>28s} {'Δ_rand':>28s}  判定")
    verdict = {}
    for phase in phases:
        pr = pkg / f"{phase}_profiling.s"
        cr = pkg / f"{phase}_control.s"
        if not (pr.exists() and cr.exists()):
            print(f"  {phase:34s}  跳过（无 profiling/control 文件）")
            continue
        base = run_row(ver, phase)
        if base is None:
            print(f"  {phase:34s}  跳过（未测到）")
            continue
        rng = random.Random(args.seed + hash(phase) % 10000)
        saved = {p: p.read_text(encoding="utf-8") for p in (pr, cr)}
        try:
            for p in (pr, cr):
                new, n = randomize_zero_buffers(saved[p], rng)
                p.write_text(new, encoding="utf-8")
                if n == 0:
                    print(f"  !! {p.name} 里没有 .zero 缓冲区（这行可能本就没有输入数据）")
            rand = run_row(ver, phase)
        finally:
            for p, t in saved.items():
                p.write_text(t, encoding="utf-8")
        if rand is None:
            print(f"  {phase:34s}  随机化后未测到 ✗")
            continue
        same = (base["cycles"], base["insn"], base["stalls"]) == \
               (rand["cycles"], rand["insn"], rand["stalls"])
        verdict[phase] = same
        tag = "✓ 与数据无关（0 值即代表真实成本）" if same else "✗ 对数据敏感 ⇒ 必须以 app 真实输入测量"
        print(f"  {phase:34s} {base['cycles']:>8,}/{base['insn']:>7,}/{base['stalls']:>6,}"
              f" {rand['cycles']:>8,}/{rand['insn']:>7,}/{rand['stalls']:>6,}  {tag}")

    bad = [k for k, v in verdict.items() if not v]
    print(f"\n结论：{len(verdict)} 行判定完毕，与数据无关 {len(verdict)-len(bad)} 行"
          f"，对数据敏感 {len(bad)} 行 {bad if bad else ''}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
