"""指标采集器：解析 standalone.py --verbose trace 输出 + ELF 尺寸。"""

import logging
import re
import shutil
import subprocess
from collections import defaultdict
from pathlib import Path

# ── otbn_sim_test.py --verbose 输出 ──
RE_INST_CYC = re.compile(r"OTBN executed ([\d,]+) instructions in ([\d,]+) cycles")
RE_STALL_SUMMARY = re.compile(r"stalled for ([\d,]+) cycles \(([0-9.]+) percent\)")

# ── 指令频次 ──
RE_INSTR_FREQ_HDR = re.compile(r"Instruction\s+frequencies", re.IGNORECASE)
RE_INSTR_FREQ_LINE = re.compile(r"^(\S+)\s+([\d,]+)\s*$")
# 完整 OTBN 指令分类（来自 hw/ip/otbn/data/*-insns.yml）
INSTR_CATEGORIES = {
    "BN MAC":      ("bn.mulqacc", "bn.mulqacc.so", "bn.mulqacc.wo",
                    "bn.mulqacc.z", "bn.mulqacc.so.z", "bn.mulqacc.wo.z",
                    "bn.mulqacc.so.wo", "bn.mulqacc.so.wo.z"),
    "BN ALU":      ("bn.add", "bn.addc", "bn.addi", "bn.addm",
                    "bn.sub", "bn.subb", "bn.subi", "bn.subm",
                    "bn.and", "bn.or", "bn.xor", "bn.not",
                    "bn.cmp", "bn.cmpb"),
    "BN Shift":    ("bn.rshi", "bn.sel", "bn.shv",
                    "bn.pack", "bn.unpk",
                    "bn.trn", "bn.trn1", "bn.trn2"),
    "BN Vector":   ("bn.addv", "bn.addvm", "bn.subv", "bn.subvm",
                    "bn.mulv", "bn.mulv.l", "bn.mulvl", "bn.mulvm", "bn.mulvml"),
    "BN Mem":      ("bn.lid", "bn.sid", "bn.mov", "bn.movr",
                    "bn.wsrr", "bn.wsrw"),
    "RISC-V ALU":  ("add", "addi", "sub", "and", "andi", "or", "ori",
                    "xor", "xori", "sll", "slli", "srl", "srli",
                    "sra", "srai", "lui"),
    "RISC-V Ctrl": ("beq", "bne", "jal", "jalr", "loop", "loopi",
                    "ecall"),
    "RISC-V CSR":  ("csrrs", "csrrw"),
    "RISC-V Mem":  ("lw", "sw"),
    "RISC-V Other":("li", "la", "mv", "ret", "nop", "unimp"),
}



def parse_iss_output(text: str, test_name: str = "") -> dict:
    """从 otbn_sim_test.py --verbose 输出提取指标。"""
    entry: dict = {
        "operation": test_name,
        "cycles": None,
        "instructions": None,
        "stalls": None,
        "stall_pct": None,
        "instr_freqs": {},
        "instr_categories": {},
    }

    m = RE_INST_CYC.search(text)
    if m:
        entry["instructions"] = int(m.group(1).replace(",", ""))
        entry["cycles"] = int(m.group(2).replace(",", ""))
    m = RE_STALL_SUMMARY.search(text)
    if m:
        entry["stalls"] = int(m.group(1).replace(",", ""))
        entry["stall_pct"] = float(m.group(2))

    # ── 指令频次（otbn_sim_test --verbose 输出 "Instruction frequencies" 表格） ──
    freq_start = RE_INSTR_FREQ_HDR.search(text)
    if freq_start:
        freq_text = text[freq_start.end():]
        freqs: dict[str, int] = {}
        for line in freq_text.splitlines():
            s = line.strip()
            if not s:
                if freqs: break
                continue
            if s.startswith("-") or s.lower().startswith("instruction"):
                continue
            if s.startswith("Basic") or s.startswith("Number") or s.startswith("Function"):
                break
            fm = RE_INSTR_FREQ_LINE.match(s)
            if fm:
                freqs[fm.group(1)] = int(fm.group(2).replace(",", ""))
        entry["instr_freqs"] = dict(freqs)

    # 归类
    cats: dict[str, int] = defaultdict(int)
    freqs = entry.get("instr_freqs", {})
    unmapped = set(freqs.keys())
    for cat, members in INSTR_CATEGORIES.items():
        for mbr in members:
            if mbr in freqs:
                cats[cat] += freqs[mbr]
                unmapped.discard(mbr)
    if unmapped:
        cats["Other"] = sum(freqs[k] for k in unmapped)
    entry["instr_categories"] = dict(cats)

    return entry


def _find_readelf() -> str | None:
    # 先查 PATH，再查常见工具链路径
    for name in [
        "riscv32-unknown-elf-readelf",
        "readelf",
        "/usr/bin/readelf",
    ]:
        if shutil.which(name):
            return name
    # 最后尝试 bazel 缓存
    import glob as _glob
    for p in _glob.glob("/home/*/.cache/bazel/**/riscv32-unknown-elf-readelf", recursive=True):
        return p
    return None


def add_sizes_to_entry(entry: dict, elf_path: str):
    """用 readelf 提取 IMEM/DMEM 尺寸。"""
    tool = _find_readelf()
    if not tool:
        logging.warning("readelf 未找到(PATH=%s)", __import__('os').environ.get('PATH', '?'))
        return
    if not Path(elf_path).exists():
        logging.warning("ELF 不存在: %s", elf_path)
        return
    logging.info("readelf=%s elf=%s", tool, elf_path)
    sizes = {"imem": 0, "dmem": 0}
    try:
        out = subprocess.check_output(
            [tool, "-S", elf_path], text=True, stderr=subprocess.PIPE,
        )
        for line in out.splitlines():
            parts = line.split()
            if len(parts) < 7 or not parts[1].rstrip("]").isdigit():
                continue
            # readelf -S 输出格式: [Nr] Name Type Addr Off Size ES Flg ...
            # 实际行:    [ 1] .text PROGBITS 00000000 001000 000828 00 AX ...
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
    entry["imem"] = sizes["imem"]
    entry["dmem"] = sizes["dmem"]
