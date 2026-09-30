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
import argparse
import pathlib
import re
import sys

try:
    from elftools.elf.elffile import ELFFile
except ImportError:
    sys.exit("需要 pyelftools（test_perf/harness.py 同款依赖；在 .venv 里跑）")

REPO = pathlib.Path(__file__).resolve().parents[3]
VERS = ["ver1_1", "ver1_2"]      # 可用 --vers 覆盖（例：--vers ver0_2 ver1_1）
PAT = re.compile(r"^_otbn_(local|remote)_app_(.+?)_(imem|dmem)_(compressed|uncompressed)_?"
                 r"(start|end|bytes)$")


def dump(ver: str, test: str):
    """取**所有** `_otbn_` 开头的符号（含 local/remote 两侧的压缩镜像标签）。

    ⚠ 只按 PAT 取会漏掉 `otbn_load_app` 真正读的那两个 local 压缩镜像标签
    （它们的命名是 `_otbn_local_app_<app>_imem_compressed_{start,end}`）—— 一律列全，别筛。
    ⚠ **ELF 里只链接该测试用到的 app**：phase1 只有 P-256 + ML-KEM keypair，
      HKDF 之类的要看 phase2 的 ELF ⇒ 用 --test 选（默认 phase1_keygen_test）。
    """
    elf = REPO / ("bazel-bin/test_hybrid_kem_otbn_prompt_%s/%s_sim_verilator.elf"
                  % (ver, test))
    if not elf.exists():
        sys.exit("找不到 %s（先 `bazel build //test_hybrid_kem_otbn_prompt_%s:%s_sim_verilator`）"
                 % (elf, ver, test))
    syms = {}
    with open(elf, "rb") as f:
        e = ELFFile(f)
        for sec in e.iter_sections():
            if sec.name != ".symtab":
                continue
            for s in sec.iter_symbols():
                if s.name.startswith("_otbn_") and s["st_value"]:
                    syms[s.name] = (s["st_value"], s["st_size"])
    return elf, syms


def main() -> int:
    global VERS
    ap = argparse.ArgumentParser()
    ap.add_argument("--vers", nargs=2, default=VERS, metavar=("A", "B"),
                    help="要对照的两个版本目录后缀（默认 ver1_1 ver1_2）")
    ap.add_argument("--quiet", action="store_true", help="只打摘要，不逐符号列")
    ap.add_argument("--test", default="phase1_keygen_test",
                    help="用哪个测试的 ELF（决定链入哪些 app；phase2 才有 HKDF）")
    args = ap.parse_args()
    VERS = list(args.vers)

    data = {}
    for v in VERS:
        elf, syms = dump(v, args.test)
        data[v] = syms
        print("== %s（%s）" % (v, elf.name))
        if not args.quiet:
            for name in sorted(syms):
                a, sz = syms[name]
                print("   0x%08x  size=%-7d %s" % (a, sz, name))

    print("\n== 嵌入镜像地址与大小（local 侧 = 固件里镜像的位置；remote 侧 = app 内部 OTBN 地址）")
    for app in sorted({m.group(2) for v in VERS for n in data[v]
                       if (m := PAT.match(n))}):
        for mem in ("imem", "dmem"):
            row = []
            for v in VERS:
                s = data[v]
                st = "_otbn_local_app_%s_%s_compressed_start" % (app, mem)
                en = "_otbn_local_app_%s_%s_compressed_end" % (app, mem)
                row.append("0x%08x+%d" % (s[st][0], s[en][0] - s[st][0]) if (st in s and en in s)
                           else "—")
            da = ""
            if len(VERS) == 2:
                s1, s2 = data[VERS[0]], data[VERS[1]]
                k = "_otbn_local_app_%s_%s_compressed_start" % (app, mem)
                if k in s1 and k in s2:
                    da = "  Δ地址=%+d" % (s2[k][0] - s1[k][0])
            if all(x != "—" for x in row):
                print("   %-22s %-4s %s%s" % (app, mem, "  →  ".join(row), da))

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
