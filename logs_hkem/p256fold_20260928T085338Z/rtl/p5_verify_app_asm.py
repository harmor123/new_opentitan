#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P5（Ibex 侧）：校验本版 app 汇编相对上游的完整性（`run_p256_local.s` 与 `p256_base.s`）。

背景：`run_p256_local.s` 是"按行裁剪"出来的（只留 MODE_KEYGEN / MODE_ECDH / copy_share）。
裁剪曾把 `.bss` 段指令与 `.globl mode` 一起删掉 ⇒ `mode` 变成局部标签、且 dmem 符号全落进
`.text.start`（IMEM 空间），设备侧链接报 `undefined symbol: _otbn_remote_app_run_p256_mode`。
本脚本把"哪些行必须与上游逐字节一致"变成断言，避免下次裁剪再踩。

检查项
  1. 保留的例程（copy_share / random_keygen / shared_key）函数体与上游逐字节相同
  2. dmem 符号块（`.bss` … `.section .scratchpad` 之前）与上游逐字节相同
  3. 模式常量（.equ MODE_* / .globl MODE_* / HARDENED_BOOL_*）与上游逐字节相同
  4. 分发表中"保留下来的分支"与上游逐字节相同（`beq x2, x3, <保留下来的例程>`）
  5. `.globl` 名单：上游公开的每个内存符号在本地仍是 `.globl`（Ibex 要用）

用法：python3 p5_verify_app_asm.py
退出码：0 = 全过；1 = 有断言失败（逐条打印）
"""
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[3]
UP = REPO / "sw/otbn/crypto/run_p256.s"
LOC = REPO / "test_hybrid_kem_otbn_prompt_ver1_2/otbn/p256/run_p256_local.s"
UP_BASE = REPO / "sw/otbn/crypto/p256_base.s"
LOC_BASE = REPO / "test_hybrid_kem_otbn_prompt_ver1_2/otbn/p256/p256_base.s"

KEPT_ROUTINES = ["copy_share", "random_keygen", "shared_key"]
# 本地保留的分支目标（上游 start 里 beq 到这些标签的行必须原样在本地）
KEPT_BRANCHES = ["random_keygen", "shared_key"]


def read_norm(p: pathlib.Path) -> str:
    return p.read_bytes().replace(b"\r\n", b"\n").decode("utf-8")


def block(text: str, label: str) -> str:
    """取 `label:`（列 0）到下一个列 0 的 `xxx:`/`.directive` 之前的整块。"""
    m = re.search(r"^%s:\n" % re.escape(label), text, re.M)
    if not m:
        return ""
    rest = text[m.end():]
    nxt = re.search(r"^(?!\s)(?:\.[a-z]|[A-Za-z_][A-Za-z0-9_]*:|/\*)", rest, re.M)
    return text[m.start(): m.end() + (nxt.start() if nxt else len(rest))]


def main() -> int:
    up, loc = read_norm(UP), read_norm(LOC)
    bad = []

    for r in KEPT_ROUTINES:
        ub = block(up, r)
        ok = ub and ub in loc
        print("[%s] routine %-14s upstream %d bytes" % ("OK " if ok else "BAD", r, len(ub)))
        if not ok:
            bad.append("routine %s 与上游不一致或缺失" % r)

    # dmem 符号块：上游 `.bss` 行起，到 `.section .scratchpad` 前
    u_bss = up[up.index("\n.bss\n") + 1: up.index(".section .scratchpad")]
    l_bss = loc[loc.index("\n.bss\n") + 1: loc.index(".section .scratchpad")]
    ok = u_bss == l_bss
    print("[%s] dmem symbol block (`.bss` .. `.scratchpad`) identical, %d bytes"
          % ("OK " if ok else "BAD", len(u_bss)))
    if not ok:
        bad.append("dmem 符号块与上游不同")

    # 模式常量
    def equ_lines(t):
        return [l for l in t.splitlines()
                if l.startswith(".equ MODE_") or l.startswith(".globl MODE_")
                or l.startswith(".equ HARDENED_BOOL_")]
    ok = equ_lines(up) == equ_lines(loc)
    print("[%s] MODE_*/HARDENED_BOOL_* lines identical (%d lines)"
          % ("OK " if ok else "BAD", len(equ_lines(up))))
    if not ok:
        bad.append("模式常量行与上游不同")

    # 保留的分支行
    missed = []
    for b in KEPT_BRANCHES:
        line = "  beq   x2, x3, %s\n" % b
        if line not in up:
            missed.append("上游没有这条分支行？%s" % b)
        elif line not in loc:
            missed.append("本地缺分支行：%s" % b)
    print("[%s] dispatch branches kept: %s"
          % ("OK " if not missed else "BAD", ", ".join(KEPT_BRANCHES)))
    bad += missed

    # .globl 覆盖：上游公开的内存符号在本地仍公开
    mem_syms = [m.group(1) for m in re.finditer(
        r"^\.globl (\w+)$", u_bss, re.M)]
    loc_globl = set(re.findall(r"^\.globl (\w+)$", loc, re.M))
    missing = [s for s in mem_syms if s not in loc_globl]
    print("[%s] `.globl` 覆盖 dmem 符号 %d 个，缺 %d 个 %s"
          % ("OK " if not missing else "BAD", len(mem_syms), len(missing),
             missing if missing else ""))
    if missing:
        bad.append("缺 .globl：%s" % missing)

    # p256_base.s：上游的 [头部 + mul_modp 标签] + 新函数体 + [setup_modp 起全部]
    upb, locb = read_norm(UP_BASE), read_norm(LOC_BASE)
    i = upb.index("\nmul_modp:\n") + 1
    j = upb.index("\nsetup_modp:", i) + 1
    prefix, old_body, suffix = upb[:i], upb[i:j], upb[j:]
    ok_pre = locb.startswith(prefix)
    ok_suf = locb.endswith(suffix)
    mid = locb[len(prefix): len(locb) - len(suffix)] if (ok_pre and ok_suf) else ""
    has_new = "bn.p256mul w19, w24, w25" in mid
    has_ret = "\n  ret\n" in mid or mid.rstrip().endswith("ret")
    print("[%s] p256_base.s = 上游头 %d B + 新体 %d B + 上游尾 %d B；"
          "新体含 `bn.p256mul w19, w24, w25`=%s、`ret`=%s（旧体 %d B）"
          % ("OK " if (ok_pre and ok_suf and has_new and has_ret) else "BAD",
             len(prefix), len(mid), len(suffix), has_new, has_ret, len(old_body)))
    if not (ok_pre and ok_suf):
        bad.append("p256_base.s 的前缀/后缀与上游不一致")
    if not (has_new and has_ret):
        bad.append("p256_base.s 的新函数体不是 bn.p256mul + ret")

    if bad:
        print("\nFAIL")
        for b in bad:
            print("  - " + b)
        return 1
    print("\nPASS  本版 app 汇编与上游一致（除已删例程与 mul_modp 函数体外）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
