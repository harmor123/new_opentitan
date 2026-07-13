#!/usr/bin/env python3
"""Hybrid KEM 性能测试。使用 StandaloneSim API 直接获取全量指标。"""

import argparse
import logging
import os
import re
import sys
import json
from datetime import datetime
from pathlib import Path

import yaml

OT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(OT_ROOT))

# 自动补全 __init__.py
for _d in [
    "hw", "hw/ip", "hw/ip/otbn", "hw/ip/otbn/dv",
    "hw/ip/otbn/dv/otbnsim", "hw/ip/otbn/dv/otbnsim/sim",
]:
    init = OT_ROOT / _d / "__init__.py"
    if not init.exists():
        init.touch()


from db_manager import DBManager
from analyzer import report_latest, report_history

C_OK = "\033[92m"
C_BOLD = "\033[1m"
C_END = "\033[0m"

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CONFIG = SCRIPT_DIR / "config.yaml"
# ver2 指令集 YAML
BNMULV_VER2_YAML = OT_ROOT / "hw/ip/otbn/data/bignum-insns-ver2.yml"

_RE_INST_CYC = re.compile(r"OTBN executed ([\d,]+) instructions in ([\d,]+) cycles")
_RE_STALL = re.compile(r"stalled for ([\d,]+) cycles \(([0-9.]+) percent\)")
_RE_INSTR_SEC = re.compile(
    r"Instruction frequencies\s*\n[- ]+\ninstruction\s+count\n[- ]+\n(.*?)(?=\n\n|\n\S|\Z)",
    re.DOTALL,
)
_RE_FUNC = re.compile(r"^Function\s+0x[0-9a-f]+\s+\(([^)]+)\)", re.MULTILINE)
_RE_FUNC_COUNT = re.compile(r"\*\s*(\d+)\s+times")

INSTR_CATEGORIES = {
    "BN MAC": ("bn.mulqacc", "bn.mulqacc.so", "bn.mulqacc.wo",
               "bn.mulqacc.z", "bn.mulqacc.so.z", "bn.mulqacc.wo.z",
               "bn.mulqacc.so.wo", "bn.mulqacc.so.wo.z"),
    "BN ALU": ("bn.add", "bn.addc", "bn.addi", "bn.addm",
               "bn.sub", "bn.subb", "bn.subi", "bn.subm",
               "bn.and", "bn.or", "bn.xor", "bn.not", "bn.cmp", "bn.cmpb"),
    "BN Shift": ("bn.rshi", "bn.sel", "bn.shv", "bn.pack", "bn.unpk",
                 "bn.trn", "bn.trn1", "bn.trn2"),
    "BN Vector": ("bn.addv", "bn.addvm", "bn.subv", "bn.subvm",
                  "bn.mulv", "bn.mulv.l", "bn.mulvl", "bn.mulvm", "bn.mulvml"),
    "BN Mem": ("bn.lid", "bn.sid", "bn.mov", "bn.movr", "bn.wsrr", "bn.wsrw"),
    "RISC-V ALU": ("add", "addi", "sub", "and", "andi", "or", "ori",
                   "xor", "xori", "sll", "slli", "srl", "srli", "sra", "srai", "lui"),
    "RISC-V Ctrl": ("beq", "bne", "jal", "jalr", "loop", "loopi", "ecall"),
    "RISC-V CSR": ("csrrs", "csrrw"),
    "RISC-V Mem": ("lw", "sw"),
    "RISC-V Other": ("li", "la", "mv", "ret", "nop", "unimp"),
}

# ── Phase Breakdown: 函数 → kernel 类别映射 ──

FUNC_CATEGORIES_COMMON = {
    # ML-KEM NTT / INTT
    "ntt":          "NTT",
    "intt":         "INTT",
    # ML-KEM Basemul
    "basemul":      "Basemul",
    "basemul_acc":  "Basemul",
    # ML-KEM Sampling
    "cbd2":                 "Sampling",
    "cbd3":                 "Sampling",
    "poly_getnoise_eta_1":  "Sampling",
    "poly_getnoise_eta_2":  "Sampling",
    # ML-KEM Packing
    "pack_pk":          "Packing",
    "pack_sk":          "Packing",
    "unpack_pk":        "Packing",
    "unpack_sk":        "Packing",
    "pack_ciphertext":  "Packing",
    "unpack_ciphertext":"Packing",
    # ML-KEM Poly arithmetic
    "poly_add":         "Poly",
    "poly_sub":         "Poly",
    "poly_tomont":      "Poly",
    "poly_reduce":      "Poly",
    "poly_frommsg":     "Poly",
    "poly_tomsg":       "Poly",
    "poly_gen_matrix":  "Poly",
    # P-256 Scalar Multiplication
    "p256_scalar_mult":             "P256-ScalarMult",
    "scalar_mult_int":              "P256-ScalarMult",
    "proj_add":                     "P256-ScalarMult",
    "proj_double":                  "P256-ScalarMult",
    "proj_to_affine":              "P256-ScalarMult",
    "mul_modp":                     "P256-ScalarMult",
    "setup_modp":                   "P256-ScalarMult",
    "p256_masked_scalar_reblind":   "P256-ScalarMult",
    "trigger_fault_if_fg0_z":       "P256-ScalarMult",
    "trigger_fault_if_fg0_not_z":   "P256-ScalarMult",
    # P-256 Curve-Point Check
    "p256_isoncurve_proj":  "P256-CurveCheck",
    # P-256 Shared Key Derivation
    "p256_shared_key":          "P256-SharedKey",
    "arithmetic_to_boolean_mod":"P256-SharedKey",
    "arithmetic_to_boolean":    "P256-SharedKey",
    # HKDF
    "hkdf_extract": "HKDF-Extract",
    "hkdf_expand":  "HKDF-Expand",
    "hmac_sha3_256": "HMAC-SHA3",
}

FUNC_CATEGORIES_VER0_SHA3 = {
    "sha3_init":    "SHA3/SHAKE",
    "sha3_update":  "SHA3/SHAKE",
    "sha3_final":   "SHA3/SHAKE",
    "shake_xof":    "SHA3/SHAKE",
    "shake_out":    "SHA3/SHAKE",
    "keccakf":      "SHA3/SHAKE",
}

FUNC_CATEGORIES_VER12_SHA3 = {
    "kmac_init":            "SHA3/SHAKE",
    "keccak_send_message":  "SHA3/SHAKE",
    "kmac_process":         "SHA3/SHAKE",
    "kmac_squeeze_32B":     "SHA3/SHAKE",
    "kmac_run":             "SHA3/SHAKE",
    "kmac_done":            "SHA3/SHAKE",
}


def _resolve_db(config: dict, db_arg: str = "") -> str:
    if db_arg:
        p = Path(db_arg)
    else:
        cfg_db = config.get("database", "db/perf_results.db")
        p = Path(cfg_db)
        if not p.is_absolute():
            p = SCRIPT_DIR / p
    p.parent.mkdir(parents=True, exist_ok=True)
    return str(p)


def load_config(path: str = "") -> dict:
    p = Path(path) if path else DEFAULT_CONFIG
    with open(p, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def bazel_build(target: str) -> Path | None:
    result = subprocess = __import__("subprocess")
    r = subprocess.run(
        ["./bazelisk.sh", "build", "--cache_test_results=no", target],
        cwd=str(OT_ROOT), capture_output=True, text=True, timeout=300,
    )
    if r.returncode != 0:
        logger.error("bazel build 失败: %s", target)
        return None
    t = target.lstrip("/")
    pkg, _, name = t.partition(":")
    elf = OT_ROOT / "bazel-bin" / pkg / (name + ".elf")
    return elf if elf.exists() else None


def _get_elf_sizes(elf_path: str) -> dict:
    import subprocess, shutil
    sizes = {"imem": 0, "dmem": 0}
    tool = None
    for name in ["riscv32-unknown-elf-readelf", "readelf"]:
        if shutil.which(name):
            tool = name; break
    if not tool:
        return sizes
    try:
        out = subprocess.check_output([tool, "-S", elf_path], text=True, stderr=subprocess.DEVNULL)
        for line in out.splitlines():
            parts = line.split()
            if len(parts) < 7 or not parts[1].rstrip("]").isdigit():
                continue
            name = parts[2]
            try:
                size = int(parts[6], 16)
            except ValueError:
                continue
            if name == ".text":
                sizes["imem"] = size
            elif name in (".data", ".bss"):
                sizes["dmem"] += size
    except Exception:
        pass
    return sizes


def _get_func_boundaries(elf_path: str, imem_bytes: int) -> list:
    """从 ELF .symtab 提取 STB_GLOBAL 函数符号及其 PC 范围."""
    from elftools.elf.elffile import ELFFile
    from elftools.elf.sections import SymbolTableSection

    elf = ELFFile(open(elf_path, 'rb'))
    symtab = elf.get_section_by_name('.symtab')
    logger.info("[phase] ELF=%s, imem_bytes=%d, symtab=%s, sections=%s",
                Path(elf_path).name, imem_bytes,
                type(symtab).__name__ if symtab else None,
                [s.name for s in elf.iter_sections()][:20])

    if not isinstance(symtab, SymbolTableSection):
        logger.warning("[phase] .symtab 不是 SymbolTableSection: %s", type(symtab))
        return []

    all_syms = list(symtab.iter_symbols())
    logger.info("[phase] symtab 共 %d 个符号", len(all_syms))

    # pyelftools: st_info.bind 可能是字符串 'STB_GLOBAL' 或整数 1
    sample = all_syms[0].entry.st_info.bind if all_syms else None
    if isinstance(sample, str):
        GLOBAL = 'STB_GLOBAL'; UNDEF = 'SHN_UNDEF'
    else:
        GLOBAL = 1; UNDEF = 0

    # OTBN 汇编器不设 st_size（始终为0），不能用 st_size>0 过滤。
    # 关键：只保留 .text 段（IMEM）的符号，排除 .data/.bss（DMEM）标签。
    # DMEM 标签的地址和 IMEM 函数地址在数值上重叠（如 d1 在 DMEM 0x40，
    # trigger_fault 在 IMEM 0x40），混在一起会把函数边界切碎。
    text_ndx = None
    for i, sec in enumerate(elf.iter_sections()):
        if sec.name == '.text':
            text_ndx = i
            break
    logger.info("[phase] .text section index = %s", text_ndx)

    symbols = []
    for sym in all_syms:
        entry = sym.entry
        if (entry.st_info.bind == GLOBAL
                and entry.st_shndx == text_ndx
                and entry.st_shndx != UNDEF):
            symbols.append((entry.st_value, sym.name))

    logger.info("[phase] 过滤后: %d 个 GLOBAL .text 符号", len(symbols))

    if not symbols:
        logger.warning("[phase] 无 GLOBAL .text 符号通过过滤")
        return []

    symbols.sort(key=lambda x: x[0])
    boundaries = []
    for i, (addr, name) in enumerate(symbols):
        end = symbols[i + 1][0] if i + 1 < len(symbols) else imem_bytes
        boundaries.append((addr, end, name))
    logger.info("[phase] 函数边界: %d 个, 范围 0x%x - 0x%x",
                len(boundaries), boundaries[0][0], boundaries[-1][1])
    return boundaries


def _compute_phase_breakdown(sim, elf_path: str) -> dict:
    """从 per-PC coverage + ELF symtab 计算 kernel phase 周期占比."""
    from collections import defaultdict

    stats = sim.stats
    coverage = stats.coverage
    total_insns = stats.get_insn_count()
    total_stalls = stats.stall_count
    imem_bytes = len(stats.program) * 4

    logger.info("[phase] coverage entries=%d  total_insns=%d  total_stalls=%d  imem_bytes=%d",
                len(coverage), total_insns, total_stalls, imem_bytes)

    if not coverage:
        logger.warning("[phase] coverage 为空，跳过")
        return {}

    boundaries = _get_func_boundaries(elf_path, imem_bytes)
    if not boundaries:
        logger.warning("[phase] func_boundaries 为空，跳过")
        return {}

    # 检查 coverage PC 范围是否在 boundaries 范围内
    pc_min, pc_max = min(coverage.keys()), max(coverage.keys())
    b_min, b_max = boundaries[0][0], boundaries[-1][1]
    logger.info("[phase] coverage PC 范围: 0x%x - 0x%x  boundary 范围: 0x%x - 0x%x",
                pc_min, pc_max, b_min, b_max)
    if pc_min < b_min or pc_max > b_max:
        logger.warning("[phase] coverage PC 超出函数边界范围！")

    all_names = {n for _, _, n in boundaries}
    sha3_cats = FUNC_CATEGORIES_VER0_SHA3 if "sha3_init" in all_names else FUNC_CATEGORIES_VER12_SHA3
    logger.info("[phase] SHA3 类别: %s", "ver0" if "sha3_init" in all_names else "ver12")

    full_categories = {}
    full_categories.update(FUNC_CATEGORIES_COMMON)
    full_categories.update(sha3_cats)

    cat_insns = defaultdict(int)
    pc_miss = 0

    for pc, count in coverage.items():
        func_name = None
        for start, end, name in boundaries:
            if start <= pc < end:
                func_name = name
                break
        if func_name:
            cat_insns[full_categories.get(func_name, "Other (glue)")] += count
        else:
            pc_miss += count

    logger.info("[phase] 归属完成: %d categories, pc_miss=%d", len(cat_insns), pc_miss)
    for cat, insns in sorted(cat_insns.items(), key=lambda x: -x[1]):
        logger.info("[phase]   %-25s %8d insns", cat, insns)

    if pc_miss > 0:
        cat_insns["Other (glue)"] += pc_miss

    sum_insns = sum(cat_insns.values())
    if sum_insns != total_insns:
        logger.warning(
            "[phase] 闭合性失败: sum=%d != total=%d (diff=%d, pc_miss=%d)",
            sum_insns, total_insns, total_insns - sum_insns, pc_miss)

    result = {}
    for cat, insns in sorted(cat_insns.items(), key=lambda x: -x[1]):
        cycles = insns + total_stalls * (insns / total_insns) if total_insns > 0 else insns
        pct = insns / total_insns * 100 if total_insns > 0 else 0.0
        result[cat] = {
            "instructions": insns,
            "cycles": round(cycles),
            "pct": round(pct, 1),
        }
    logger.info("[phase] 结果: %d categories, total_cycles=%d", len(result), sum(r["cycles"] for r in result.values()))
    return result


def run_iss(elf_path: str, test_name: str, bnmulv: str = "",
            env: dict | None = None) -> dict | None:
    """直接调用 StandaloneSim API，获取 ExecutionStatAnalyzer 全量指标。"""
    import importlib, sys
    if bnmulv:
        os.environ["BNMULV_VER"] = bnmulv
    else:
        os.environ.pop("BNMULV_VER", None)
    # 设置额外环境变量 (如 OTBN_EN_MASKING=1)，用完后恢复旧值
    env_backup = {}
    if env:
        for k, v in env.items():
            env_backup[k] = os.environ.get(k)
            os.environ[k] = v
    # 清除缓存，否则切换版本时 decode 模块不变。
    # 按模块文件路径匹配（而非 Python dotted name），覆盖 shared/serialize 等间接依赖。
    importlib.invalidate_caches()
    for name, mod in list(sys.modules.items()):
        f = getattr(mod, '__file__', '') or ''
        if any(x in f for x in ('otbn', 'otbnsim', 'shared', 'serialize')):
            sys.modules.pop(name, None)
    from hw.ip.otbn.dv.otbnsim.sim.standalonesim import StandaloneSim
    from hw.ip.otbn.dv.otbnsim.sim.load_elf import load_elf
    from hw.ip.otbn.dv.otbnsim.sim.stats import ExecutionStatAnalyzer
    sim = StandaloneSim()

    try:
        exp_end = load_elf(sim, elf_path)
    except Exception as e:
        logger.error("[%s] ELF 加载失败: %s", test_name, e)
        return None

    sim.start(True)
    sim.run(False, None)

    raw = {"operation": test_name, "imem": 0, "dmem": 0,
           "instr_freqs": {}, "instr_categories": {}, "func_calls": {}}
    raw.update(_get_elf_sizes(elf_path))

    dump_text = ""
    try:
        analyzer = ExecutionStatAnalyzer(sim.stats, elf_path)
        dump_text = analyzer.dump() or ""
        if dump_text:
            _parse_dump(dump_text, raw)
    except Exception as e:
        logger.warning("[%s] stat analyzer 失败: %s", test_name, e)
        if sim.stats:
            raw["instructions"] = getattr(sim.stats, "insn_count", 0)
            raw["stalls"] = getattr(sim.stats, "stall_count", 0)
            raw["cycles"] = raw["instructions"] + raw["stalls"]

    raw["dump_text"] = dump_text

    # Phase breakdown: per-PC coverage → 函数 → kernel 类别周期占比
    try:
        raw["phase_breakdown"] = _compute_phase_breakdown(sim, elf_path)
    except Exception as e:
        logger.warning("[%s] phase breakdown 失败: %s", test_name, e)

    logger.info("[%s] cycles=%s  ins=%s  stalls=%s  imem=%s  dmem=%s",
                test_name, raw.get("cycles", "?"), raw.get("instructions", "?"),
                raw.get("stalls", "?"), raw.get("imem", "?"), raw.get("dmem", "?"))
    # 恢复环境变量
    for k, v in (env or {}).items():
        if env_backup.get(k) is not None:
            os.environ[k] = env_backup[k]
        else:
            os.environ.pop(k, None)
    return raw


def _parse_dump(text: str, entry: dict):
    m = _RE_INST_CYC.search(text)
    if m:
        entry["instructions"] = int(m.group(1).replace(",", ""))
        entry["cycles"] = int(m.group(2).replace(",", ""))
    m = _RE_STALL.search(text)
    if m:
        entry["stalls"] = int(m.group(1).replace(",", ""))
        entry["stall_pct"] = float(m.group(2))

    # 指令频次——从 "Instruction frequencies" 到下一个空行
    idx = text.find("Instruction frequencies")
    if idx >= 0:
        block = text[idx:]
        lines_iter = iter(block.split("\n"))
        freqs = {}
        in_table = False
        for line in lines_iter:
            s = line.strip()
            if "instruction" in s.lower() and "count" in s.lower():
                in_table = True
                # skip dashes line
                try: next(lines_iter)
                except StopIteration: break
                continue
            if in_table:
                if not s:  # blank line = end
                    break
                parts = s.split()
                if len(parts) >= 2:
                    try:
                        freqs[parts[0]] = int(parts[-1].replace(",", ""))
                    except ValueError:
                        pass
        if freqs:
            entry["instr_freqs"] = freqs
        # 归类
        cats = {}
        unmapped = set(freqs.keys())
        for cat, members in INSTR_CATEGORIES.items():
            total = sum(freqs.get(m, 0) for m in members)
            if total:
                cats[cat] = total
                unmapped -= set(members)
        if unmapped:
            cats["Other"] = sum(freqs[k] for k in unmapped)
        entry["instr_categories"] = cats

    # 函数调用热点
    func_start = text.find("Function call statistics")
    if func_start > 0:
        func_text = text[func_start:]
        funcs = {}
        for fm in re.finditer(
            r"^Function 0x[0-9a-f]+ \(([^)]+)\)", func_text, re.MULTILINE
        ):
            fname = fm.group(1).strip()
            if "\n" in fname or len(fname) > 80:
                continue
            after = func_text[fm.end():fm.end() + 800]
            total = sum(int(m.group(1)) for m in re.finditer(r"\*\s*(\d+)\s+times", after))
            if total > 0:
                funcs[fname] = total
        entry["func_calls"] = dict(sorted(funcs.items(), key=lambda x: -x[1])[:10])


def run_single_test(ver: dict, test_name: str, timeout: int = 120) -> dict | None:
    targets = ver.get("targets", {})
    target = targets.get(test_name, "")
    if not target:
        logger.warning("[%s] 未知测试: %s", ver["name"], test_name)
        return None
    elf = bazel_build(target)
    if elf is None:
        return None
    bnv = "2" if "ver2" in ver["name"] else ""
    return run_iss(str(elf), test_name, bnmulv=bnv,
                   env=ver.get("env"))


def cmd_run(config, version_filter="", test_filter="", db_path=""):
    timeout = config.get("timeout", 120)
    db = DBManager(_resolve_db(config, db_path))
    log_dir = SCRIPT_DIR / "logs"
    log_dir.mkdir(parents=True, exist_ok=True)
    v_allow = set(v.strip() for v in version_filter.split(",") if v.strip()) if version_filter else None
    t_allow = set(t.strip() for t in test_filter.split(",") if t.strip()) if test_filter else None

    for ver in config["versions"]:
        ver_name = ver["name"]
        if v_allow and ver_name not in v_allow:
            continue
        print(f"\n{C_BOLD}═══ {ver_name} ({ver['label']}) ═══{C_END}")
        run_id = db.insert_run(ver_name, "")

        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_file = log_dir / f"bench_{ver_name}_{ts}.log"
        all_dumps: list[str] = []

        for test_name in ver.get("tests", []):
            if t_allow and test_name not in t_allow:
                continue
            metrics = run_single_test(ver, test_name, timeout)
            if metrics is None:
                logger.warning("[%s] %s: 无结果，跳过", ver_name, test_name)
                continue
            all_dumps.append(f">>> [{test_name}] {ver_name}\n{metrics.get('dump_text', '')}")
            db.insert_metric(
                run_id, test_name,
                cycles=metrics.get("cycles") or 0,
                instructions=metrics.get("instructions") or 0,
                stalls=metrics.get("stalls") or 0,
                stall_pct=metrics.get("stall_pct") or 0.0,
                imem=metrics.get("imem") or 0,
                dmem=metrics.get("dmem") or 0,
                instr_categories=metrics.get("instr_categories", {}),
                instr_freqs=metrics.get("instr_freqs", {}),
                func_calls=metrics.get("func_calls", {}),
                phase_breakdown=metrics.get("phase_breakdown", {}),
            )
        with open(log_file, "w", encoding="utf-8") as f:
            f.write("\n".join(all_dumps))
        print(f"  {ver_name}: {C_OK}DONE{C_END}  (log: {log_file})")

    print(f"\n{C_BOLD}═══ 报告 ═══{C_END}")
    print(report_latest(db))


def cmd_report(config, output="", db_path=""):
    import re as _re
    db = DBManager(_resolve_db(config, db_path))
    report = report_latest(db)
    print(report)
    out_dir = SCRIPT_DIR / "report"
    out_dir.mkdir(parents=True, exist_ok=True)
    if output:
        out_path = out_dir / Path(output).name
    else:
        out_path = out_dir / f"report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(_re.sub(r"\033\[[0-9;]*m", "", report))
    logger.info("报告已保存: %s", out_path)


def cmd_history(config, version, db_path=""):
    db = DBManager(_resolve_db(config, db_path))
    print(report_history(db, version))


def cmd_delete(config, run_id=0, version="", before="", db_path=""):
    db = DBManager(_resolve_db(config, db_path))
    if run_id:
        print(f"删除记录 ID={run_id}: {db.delete_run(run_id)} 条")
    elif version:
        print(f"删除 {version}: {db.delete_runs_by_version(version, before or None)} 条")
    else:
        print("请指定 --id 或 --version")


def main():
    parser = argparse.ArgumentParser(description="Hybrid KEM 性能测试框架")
    sub = parser.add_subparsers(dest="command")
    p_run = sub.add_parser("run"); p_run.add_argument("--config", default="")
    p_run.add_argument("--db", default=""); p_run.add_argument("--versions", "-V", default="")
    p_run.add_argument("--tests", "-t", default="")
    p_report = sub.add_parser("report"); p_report.add_argument("--config", default="")
    p_report.add_argument("--db", default=""); p_report.add_argument("--output", "-o", default="")
    p_hist = sub.add_parser("history"); p_hist.add_argument("--version", "-v", required=True)
    p_hist.add_argument("--db", default="")
    p_del = sub.add_parser("delete"); p_del.add_argument("--id", type=int, default=0)
    p_del.add_argument("--version", "-v", default=""); p_del.add_argument("--before", default="")
    p_del.add_argument("--db", default="")

    args = parser.parse_args()
    if args.command is None:
        parser.print_help(); return
    config = load_config(getattr(args, "config", "") or "")
    if args.command == "run":
        cmd_run(config, getattr(args, "versions", ""), getattr(args, "tests", ""), getattr(args, "db", ""))
    elif args.command == "report":
        cmd_report(config, getattr(args, "output", ""), getattr(args, "db", ""))
    elif args.command == "history":
        cmd_history(config, args.version, getattr(args, "db", ""))
    elif args.command == "delete":
        cmd_delete(config, args.id, args.version, getattr(args, "before", ""), getattr(args, "db", ""))


if __name__ == "__main__":
    main()
