#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""静态检查：OTBN 汇编的**分节规则**（`otbn_binary`/`otbn_library`/`otbn_sim_test` 的 `srcs`）。

规则（2026-10-01 由一次实测缺陷立规）：
  `rules/otbn.bzl` 把**同一个目标**的 `srcs` 一次交给 `otbn_as.py`（单次调用、单趟汇编流），
  **分节状态在文件之间延续**：若前一个 `.s` 结尾停在 `.section .data`（`.bss` 同理），
  紧随其后、自身**没有** `.text`/`.section` 指示的文件，其**代码会被汇编进 `.data`**。后果三件套：
    ① 代码进 DMEM（IMEM 里没有它）—— 症状：该 ELF 的 data 段大小 = 数据 + 那个函数的字节数；
    ② 该函数的符号落进数据段（`load_text_boundaries` 之类的"可执行段"过滤器会把它滤掉）；
    ③ 对它的 `jal` 跳进 IMEM 里**别处的代码中间** ⇒ 拿垃圾值（典型：FI 自检故意触发 `ILLEGAL_INSN`）。
  实测案例：`test_hybrid_kem_otbn_prompt_ver0_1/otbn/p256`（`p256_isoncurve_proj.s` 缺 `.text`，
  其 ELF 的 data 段 684 B = 数据 480 B + 代码 204 B）。

因此本检查器的判据：**`srcs` 里含 ≥2 个 `.s` 的目标，每个 `.s` 都必须显式写出 `.text`/`.section`**
（在任何代码之前）；一文件一库（上游 `sw/otbn/crypto` 的惯例）天然满足 —— 单文件时汇编器默认段就是 `.text`。

用法：
  python3 test_perf/tools/check/check_asm_sections.py            # 扫 test_hybrid_kem_* 与 sw/otbn
  python3 test_perf/tools/check/check_asm_sections.py --path X   # 只扫指定目录（可多次）
只读检查，不改任何文件；发现违规则打印并**非零退出**。
"""
import argparse
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[3]
TARGET_RE = re.compile(r'\botbn_(?:binary|library|sim_test)\s*\(')
SRC_RE = re.compile(r'"([^"]+\.s)"')
CODE_LINE_RE = re.compile(r'^\s*(?:[A-Za-z_][A-Za-z0-9_]*:|'
                          r'(?:bn|jal|jalr|beq|bne|addi|li|la|lui|add|sub|xor|andi|lw|sw|csrrw|loopi|loop|ecall)\b)')
SECTION_RE = re.compile(r'^\s*\.(?:section|text)\b')


def block_after(text: str, open_paren: int) -> str:
    """取从 '(' 起的配平括号块。"""
    depth, i = 0, open_paren
    while i < len(text):
        if text[i] == '(':
            depth += 1
        elif text[i] == ')':
            depth -= 1
            if depth == 0:
                return text[open_paren:i + 1]
        i += 1
    return text[open_paren:]


def srcs_of(block: str):
    """块里的 `srcs = [ ... ]`（或单行 `srcs = ["x.s"]`）中的 .s（label 形式取冒号后半段）。"""
    m = re.search(r'srcs\s*=\s*\[', block)
    if m:
        seg = block[m.end() - 1:]
        seg = block_after(seg, 0)
    else:
        return []
    return [s.split(':')[-1] for s in SRC_RE.findall(seg)]


def file_sections(path: pathlib.Path):
    """返回 (本文件第一条 .text/.section 是否在代码之前, 本文件最后一条 section 名, 是否有代码)。

    注释按块剥掉（OTBN .s 用 /* */ 与 //）。section 名取 `.text`/`.text.start`/`.data`/…
    """
    try:
        txt = path.read_text(encoding='utf-8', errors='replace')
    except OSError:
        return None
    txt = re.sub(r'/\*.*?\*/', '', txt, flags=re.S)
    has_code = False
    first_dir_before_code = False
    seen_code = False
    last_section = None
    for line in txt.splitlines():
        line = re.sub(r'//.*', '', line)
        if not line.strip():
            continue
        m = re.match(r'^\s*\.section\s+([.\w]+)', line)
        if m:
            last_section = m.group(1)
            if not seen_code:
                first_dir_before_code = True
            continue
        if re.match(r'^\s*\.text\b', line):
            last_section = ".text"
            if not seen_code:
                first_dir_before_code = True
            continue
        if CODE_LINE_RE.match(line):
            seen_code = True
            has_code = True
    return first_dir_before_code, last_section, has_code


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--path", action="append",
                    help="限定扫描目录（相对仓库根，可给多次；默认 test_hybrid_kem_* 与 sw/otbn）")
    args = ap.parse_args()
    roots = [REPO / p for p in args.path] if args.path else \
        sorted(REPO.glob("test_hybrid_kem_*")) + [REPO / "sw/otbn"]

    n_targets = n_multi = n_bad = 0
    bad_files = []
    for root in roots:
        for build in sorted(root.rglob("BUILD")):
            try:
                text = build.read_text(encoding='utf-8', errors='replace')
            except OSError as e:                     # 个别文件在 Windows 上读不了（权限/链接）⇒ 跳过并报出
                print("（跳过 %s：%s）" % (build.relative_to(REPO), e.__class__.__name__), file=sys.stderr)
                continue
            for m in TARGET_RE.finditer(text):
                block = block_after(text, m.end() - 1)
                srcs = srcs_of(block)
                n_targets += 1
                if len(srcs) < 2:
                    continue                          # 单文件：默认段 = .text，安全 ✓
                n_multi += 1
                inherited = ".text"                  # 汇编流的初始段（单文件时汇编器默认 .text）
                for rel in srcs:
                    cands = [build.parent / rel, REPO / rel]
                    p = next((c for c in cands if c.exists()), None)
                    if p is None:
                        continue
                    got = file_sections(p)
                    if got is None:
                        continue
                    own_before_code, last_section, has_code = got
                    if has_code and not own_before_code and not inherited.startswith(".text"):
                        n_bad += 1
                        bad_files.append((build.relative_to(REPO), p.relative_to(REPO)))
                        print("✗ %s 的目标（%d 个 .s 合在一次汇编）里，%s 的代码前没有 .text/.section，"
                              "而它继承到的段是 `%s` ⇒ 代码会被汇编进该段（`.data`/`.bss` 就进 DMEM）"
                              % (build.relative_to(REPO), len(srcs), p.relative_to(REPO), inherited))
                    elif has_code and not own_before_code and inherited == ".text.start":
                        # 仍是可执行段（会进 IMEM，只是被放到起始段）⇒ 只提示，不算违规
                        print("· %s：%s 未显式声明段，继承 `.text.start`（可执行，非 DMEM；仅提示）"
                              % (build.relative_to(REPO), p.relative_to(REPO)))
                    if last_section:
                        inherited = last_section       # 分节状态延续到下一个文件
    print("[check_asm_sections] 扫描目标 %d 个（其中多文件 srcs %d 个）；违规文件 %d 个"
          % (n_targets, n_multi, n_bad))
    if n_bad:
        print("⇒ 修法二选一：① 给该 .s 在代码前加 `.text`；② 拆成“一文件一 otbn_library”"
              "（上游 sw/otbn/crypto 的惯例，分节状态不跨文件）。")
        return 1
    print("全部合规 ✓")
    return 0


if __name__ == "__main__":
    sys.exit(main())
