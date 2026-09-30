#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P6：比对两版固件里**嵌入的 OTBN app 镜像**的地址与大小（判断宿主 I/O 段差异是否来自布局）。

背景：`otbn_load_app` 是纯 MMIO 写（`sw/device/lib/crypto/drivers/otbn.c:335-380` 的
`decompress_load`，无读、无内容依赖），写入字数取自 app 描述符 ⇒ 同一个 ML-KEM app 的
写入工作量在两版**必须相同**。但实测 `mlkem_keypair_load` 差 −17,233 且**对 P-256 的调度不敏感**
⇒ 唯一还剩的解释是**宿主侧读压缩镜像的成本变了** —— 本版 P-256 app 小 8,268 B，链接后
后续嵌入镜像的地址/对齐会平移。

本脚本给出**事实**：两版固件里每个嵌入 app 的
  `_otbn_local_app_<app>_imem_compressed_{start,end}` / `_dmem_compressed_{start,end}`
的地址与大小（pyelftools，与 test_perf/harness.py 同一套依赖）。

用法（Linux 构建机仓库根；前置：两版 phase1 测试都已构建过）：
  python3 logs_hkem/p256fold_20260928T085338Z/host/p6_elf_layout.py
"""
import pathlib
import re
import sys

try:
    from elftools.elf.elffile import ELFFile
except ImportError:
    sys.exit("需要 pyelftools（test_perf/harness.py 同款依赖；在 .venv 里跑）")

REPO = pathlib.Path(__file__).resolve().parents[3]
VERS = ["ver1_1", "ver1_2"]
PAT = re.compile(r"^_otbn_(local|remote)_app_(.+?)_(imem|dmem)_(compressed|uncompressed)_?"
                 r"(start|end|bytes)$")


def dump(ver: str):
    elf = REPO / ("bazel-bin/test_hybrid_kem_otbn_prompt_%s/"
                  "phase1_keygen_test_sim_verilator.elf" % ver)
    if not elf.exists():
        sys.exit("找不到 %s（先 bazel build/test 一次该版本）" % elf)
    syms = {}
    with open(elf, "rb") as f:
        e = ELFFile(f)
        for sec in e.iter_sections():
            if sec.name not in (".symtab",):
                continue
            for s in sec.iter_symbols():
                m = PAT.match(s.name)
                if m and s["st_value"]:
                    syms[s.name] = (s["st_value"], s["st_size"])
    return elf, syms


def main() -> int:
    data = {}
    for v in VERS:
        elf, syms = dump(v)
        data[v] = syms
        print("== %s（%s）" % (v, elf.name))
        for name in sorted(syms):
            a, sz = syms[name]
            print("   0x%08x  size=%-7d %s" % (a, sz, name))
    print("\n== 嵌入镜像大小（由 start/end 标签推出）")
    for v in VERS:
        s = data[v]
        print("   %s：" % v)
        for app in sorted({m.group(2) for n in s
                           if (m := PAT.match(n))}):
            for mem in ("imem", "dmem"):
                st = "_otbn_local_app_%s_%s_compressed_start" % (app, mem)
                en = "_otbn_local_app_%s_%s_compressed_end" % (app, mem)
                if st in s and en in s:
                    print("     %-22s %-4s compressed = %d B" % (app, mem, s[en][0] - s[st][0]))

    print("\n== 逐符号对照（地址 Δ / 大小 Δ；*_uncompressed_bytes 的 st_value 就是字数）")
    a, b = data[VERS[0]], data[VERS[1]]
    for name in sorted(set(a) | set(b)):
        if name not in a or name not in b:
            print("   仅一侧有：%s" % name)
            continue
        da = b[name][0] - a[name][0]
        flag = ""
        if "_bytes" in name:
            flag = "  ← 字数相同" if da == 0 else "  ← 字数不同！"
        print("   %-58s Δ=%+d%s" % (name, da, flag))
    return 0


if __name__ == "__main__":
    sys.exit(main())
