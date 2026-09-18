#!/usr/bin/env python3
"""OTBN 应用逐函数周期/代码体积剖析器（ISS 口径）。

用法（仓库根目录）:
    python3 test_perf/func_profile.py <app.elf> [--json out.json] [--top N]

原理:
  * 用官方 ISS（hw/ip/otbn/dv/otbnsim）跑完整 app（输入已烧在 ELF 的 .data 里，
    不需要 hjson）；直接复刻 temp-cef4055 上 ver0_1 剖析的测量基准（ISS 周期）。
  * 官方 ISS 已采集 ExecutionStats.coverage[pc]（每个地址执行次数）；缺的是
    "停滞按 PC 归因"（官方只累加一个全局数）。本脚本在**运行期 monkey-patch**
    OTBNSim._on_stall 补上，**官方代码零修改**。
  * 函数周期 = 该函数区间内的指令数 + **该函数自己的停滞数**
    （test_perf/main.py:333 是"按指令数比例摊派停滞"的近似版，本脚本是精确归因；
     与 harness 法的 profiling−control 同源，可互验）。
  * 代码体积 = 函数区间字节数（IMEM）= 下一符号地址 − 本符号地址；
    注意 OTBN 汇编器不设 st_size（恒为 0），故不能用 st_size。
  * 边界算法与 test_perf/main.py:_get_func_boundaries 一致（只取 .text 段 GLOBAL 符号，
    避免 DMEM 标签与 IMEM 地址重叠把边界切碎）。

输出: 逐函数表（按周期降序）+ 按 ML-KEM 阶段汇总。阶段名与 test_perf 的对照:
      矩阵生成 + 多项式运算 = test_perf 的 Poly；噪声采样 = Sampling；
      NTT/INTT/BaseMul = NTT/INTT/Basemul；pack/unpack = Packing；
      KMAC/SHAKE = SHA3/SHAKE。指令数应与 DB 里 ver0/ver1 的对应行**精确相等**
      （算术文件逐字节相同的版本之间）。
"""

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "hw/ip/otbn/dv/otbnsim"))

from sim.load_elf import load_elf                     # noqa: E402
from sim.sim import OTBNSim                           # noqa: E402
from sim.standalonesim import StandaloneSim           # noqa: E402

from elftools.elf.elffile import ELFFile              # noqa: E402


# ── 阶段归类（按符号名前缀/子串；ver0_1/ver0_2/ver1_1 三套命名都覆盖）──
def categorize(name: str) -> str:
    n = name.lstrip("_")
    if n.startswith("poly_gen_matrix") or "rej_sample" in n or n.endswith("aligned"):
        return "矩阵生成"
    if n.startswith("cbd") or "getnoise" in n or n.startswith("poly_getnoise"):
        return "噪声采样"
    if n == "ntt" or n.endswith("_ntt") or n.startswith("ntt"):
        return "NTT"
    if n == "intt" or n.endswith("_intt") or n.startswith("intt") or "invntt" in n:
        return "INTT"
    if n.startswith("basemul") or "basemul" in n:
        return "BaseMul"
    if any(k in n for k in ("pack", "unpack", "tobytes", "frombytes",
                            "compress", "decompress")):
        return "pack/unpack"
    if n.startswith("xof") or "_xof" in n or n.startswith("kmac") or \
       n.startswith("sha3") or n.startswith("shake") or "keccak" in n:
        return "KMAC/SHAKE"
    if n.startswith(("poly_", "polyvec_")) and any(
            k in n for k in ("add", "sub", "reduce", "frommsg", "tomsg", "basemul")):
        return "多项式运算"
    if n.startswith(("indcpa", "crypto_kem", "mlkem")) or n in ("main", "_start"):
        return "顶层壳/入口"
    return "其他"


def load_text_boundaries(elf_path: str):
    """返回 [(start, end, name), ...]：.text 段（IMEM）的 GLOBAL 符号边界。

    与 test_perf/main.py:_get_func_boundaries 完全一致：
      * **OTBN 汇编器不设 st_size（恒为 0）**，所以边界用"下一个符号的地址"；
      * 只取 .text 段符号 —— DMEM 标签的地址与 IMEM 重叠（如 d1@0x40 与
        trigger_fault@0x40），混入会把函数边界切碎。
    函数大小 = end - start（IMEM 字节）。
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
        text_addr = elf.get_section(text_ndx)["sh_addr"]
        text_end = text_addr + elf.get_section(text_ndx)["sh_size"]
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


def attr_to_func(pc: int, boundaries) -> str:
    """把 PC 归到 [start, end) 区间所属函数（边界由"下一符号地址"切分）。"""
    for start, end, name in boundaries:
        if start <= pc < end:
            return name
    return f"@{pc:#x}(未知)"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("elf")
    ap.add_argument("--json", metavar="FILE", help="把逐函数数据写为 JSON")
    ap.add_argument("--top", type=int, default=0, help="只打印前 N 个函数（0=全部）")
    args = ap.parse_args()

    # ── monkey-patch: 停滞按 PC 归因（官方树零修改）──
    stall_by_pc: Counter = Counter()
    orig_on_stall = OTBNSim._on_stall

    def _on_stall(self, verbose, fetch_next):
        if self.stats is not None and not self.state.wiping():
            stall_by_pc[self.state.pc] += 1
        return orig_on_stall(self, verbose, fetch_next)

    OTBNSim._on_stall = _on_stall

    sim = StandaloneSim()
    load_elf(sim, args.elf)
    sim.state.ext_regs.commit()
    sim.start(collect_stats=True)
    cycles = sim.run(verbose=False, dump_file=None)

    stats = sim.stats
    insn_by_pc, cover_by_pc = Counter(), stats.coverage
    # 指令数：coverage 已按 PC 计数
    insn_by_pc.update(cover_by_pc)
    total_insn = sum(insn_by_pc.values())
    total_stall = sum(stall_by_pc.values())

    boundaries = load_text_boundaries(args.elf)
    if not boundaries:
        print("错误：ELF 里没有 .text 段 GLOBAL 符号，无法归因", file=sys.stderr)
        return 1

    f_insn, f_stall = Counter(), Counter()
    for pc, cnt in insn_by_pc.items():
        f_insn[attr_to_func(pc, boundaries)] += cnt
    for pc, cnt in stall_by_pc.items():
        f_stall[attr_to_func(pc, boundaries)] += cnt

    # 函数代码体积（IMEM 字节）= 下一符号地址 − 本符号地址（st_size 恒为 0）
    size = {name: end - start for start, end, name in boundaries}

    print(f"# {Path(args.elf).name}")
    print(f"总计: 指令 {total_insn:,} / 停滞 {total_stall:,} / 周期 {cycles:,} "
          f"(停滞率 {100.0 * total_stall / max(cycles, 1):.1f}%)\n")

    rows = []
    for name in set(f_insn) | set(f_stall):
        insn, st = f_insn[name], f_stall[name]
        rows.append({
            "func": name,
            "category": categorize(name),
            "insn": insn,
            "stall": st,
            "cycles": insn + st,
            "size_bytes": size.get(name, 0),
        })
    rows.sort(key=lambda r: -r["cycles"])

    if args.top:
        shown = rows[:args.top]
    else:
        shown = rows

    print("## 逐函数")
    print("| 函数 | 阶段 | 指令 | 停滞 | 周期 | 占比 | 代码(B) |")
    print("|---|---|---:|---:|---:|---:|---:|")
    for r in shown:
        pct = 100.0 * r["cycles"] / max(cycles, 1)
        print(f"| `{r['func']}` | {r['category']} | {r['insn']:,} | {r['stall']:,} | "
              f"{r['cycles']:,} | {pct:.2f}% | {r['size_bytes']:,} |")

    print("\n## 按阶段汇总")
    agg = defaultdict(lambda: {"insn": 0, "stall": 0, "cycles": 0, "size": 0, "funcs": 0})
    for r in rows:
        a = agg[r["category"]]
        a["insn"] += r["insn"]
        a["stall"] += r["stall"]
        a["cycles"] += r["cycles"]
        a["size"] += r["size_bytes"]
        a["funcs"] += 1
    print("| 阶段 | 指令 | 停滞 | 周期 | 占比 | 代码(B) | 函数数 |")
    print("|---|---:|---:|---:|---:|---:|---:|")
    order = ["矩阵生成", "噪声采样", "NTT", "INTT", "BaseMul", "pack/unpack",
             "KMAC/SHAKE", "多项式运算", "顶层壳/入口", "其他"]
    for cat in order:
        if cat not in agg:
            continue
        a = agg[cat]
        pct = 100.0 * a["cycles"] / max(cycles, 1)
        print(f"| {cat} | {a['insn']:,} | {a['stall']:,} | {a['cycles']:,} | "
              f"{pct:.2f}% | {a['size']:,} | {a['funcs']} |")

    if args.json:
        Path(args.json).write_text(json.dumps(
            {"elf": args.elf, "cycles": cycles, "insn": total_insn,
             "stall": total_stall, "functions": rows,
             "categories": {k: v for k, v in agg.items()}},
            ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"\n(JSON 已写入 {args.json})")

    return 0


if __name__ == "__main__":
    sys.exit(main())
