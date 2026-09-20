#!/usr/bin/env python3
"""OTBN 链接预检：静态检查每个目标的符号闭包（在 bazel 之前抓出 undefined reference）。

背景：harness 法的每个剖面目标 = 调用段 .s + 被调内核 .s + 它需要的数据 .s。
少一个数据文件、或内核换了调用约定，都要等 bazel 链接时才报错（Linux 上）。
本工具在本地（Windows 也可以）把"链接期 undefined reference"提前变成静态报告。

用法:
    python3 test_perf/otbn_symbol_check.py --build <BUILD 路径> [--only 子串]
    python3 test_perf/otbn_symbol_check.py --files a.s b.s ...
    python3 test_perf/otbn_symbol_check.py --build <BUILD> --refs     # 顺带打印每文件的外部引用

原理:
    - 定义：行首标签 `name:`（含缩进为 0 的行首形式），以及 .set/.equ 的名字
    - 引用：注释剥离后出现在操作数位置的标识符
      （la / jal / jalr / lw / sw / bn.lid / bn.sid / .word sym / 其他指令的符号操作数）
    - 未定义引用 = 引用到的符号不在任何 srcs 文件里定义
    - 重定义     = 同一个符号在多个 srcs 文件里被定义

注意：Windows 上 .s 文件含中文注释，必须 PYTHONUTF8=1 运行（否则 open() 用 GBK 解码报错）。
"""

import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

# 指令助记符/寄存器/伪操作 —— 出现在操作数位置也不当符号看
REG_RE = re.compile(r"^(x[0-9]+|[0-9]+|w[0-9]+|fp|ra|sp|MOD|acc|RND|URND|FGM|0x[0-9a-fA-F]+|-?[0-9]+)$")
# CSR / 特殊寄存器名（不是内存符号）
CSR_RE = re.compile(r"^(FG[0-9]|KMAC_\w+|MOD|ACC|RND|URND|KEY_S[01]|EXT_CSR\w*)$")
SKIP_WORDS = {
    "bn", "add", "addi", "sub", "lui", "li", "la", "jal", "jalr", "j", "jr", "beq", "bne", "blt",
    "bge", "bltu", "bgeu", "lw", "sw", "lh", "sh", "lb", "sb", "lbu", "lhu", "slli", "srli",
    "srai", "sll", "srl", "sra", "and", "andi", "or", "ori", "xor", "xori", "mul", "mulh",
    "ecall", "loop", "loopi", "nop", "csrrw", "csrrs", "csrrc", "csrrwi", "csrrsi", "csrrci",
    "csrr", "ret", "word", "dword", "zero", "balign", "align", "byte", "half", "section",
    "globl", "global", "local", "set", "equ", "irp", "rept", "endr", "macro", "endm", "include",
    "text", "data", "bss", "scratchpad", "text.start", "org", "skip", "p2align", "file", "option",
    "attr", "type", "size", "string", "asciz", "float", "double", "comm", "extern", "hidden",
    "weak", "ifdef", "ifndef", "endif", "if", "else", "err", "warning", "req", "asrt",
    # 栈/局部伪指令常见形式
    "load", "store",
}
BRANCH_LOCAL = re.compile(r"^[0-9]+[fb]$")


def strip_comments(text: str) -> str:
    # 保留换行数，避免报错行号错位
    def _blank(m):
        return "".join(c if c == "\n" else " " for c in m.group(0))
    text = re.sub(r"/\*.*?\*/", _blank, text, flags=re.S)
    text = re.sub(r"//[^\n]*", " ", text)
    text = re.sub(r"#[^\n]*", " ", text)          # 行注释（OTBN asm 用 /* */ 与 //）
    return text


LABEL_RE = re.compile(r"^([A-Za-z_][A-Za-z_0-9]*):")
# 操作数里出现的标识符：la x2, sym / jal x1, sym / lw x1, 0(sym) / .word sym
SYM_OPERAND_RE = re.compile(r"(?:^|[\s,()])([A-Za-z_][A-Za-z_0-9]*)")


def scan(path: Path):
    """返回 (defined:set, referenced:set, globl:set)。"""
    raw = path.read_text(encoding="utf-8")
    src = strip_comments(raw)
    defined, referenced = set(), set()
    for line in src.splitlines():
        m = LABEL_RE.match(line)
        if m:
            defined.add(m.group(1))
            rest = line[m.end():].strip()
            if not rest:
                continue
            line = rest
        else:
            line = line.strip()
            if not line:
                continue
        toks = line.split(None, 1)
        mnem = toks[0]
        if mnem in (".globl", ".global"):
            for t in toks[1].split(","):
                t = t.strip()
                if t:
                    referenced.discard(t)
                    defined.add(t)          # 视为（外部）定义
            continue
        if mnem in (".set", ".equ"):
            parts = [p.strip() for p in toks[1].split(",")]
            if parts:
                defined.add(parts[0])
            continue
        if mnem.startswith("."):
            continue
        for t in SYM_OPERAND_RE.findall(toks[1] if len(toks) > 1 else ""):
            if REG_RE.match(t) or CSR_RE.match(t) or t in SKIP_WORDS or BRANCH_LOCAL.match(t):
                continue
            referenced.add(t)
    return defined, referenced, set()


def count_insn(line: str) -> int:
    """一条源语句展开成几条机器指令（otbn_as: la 恒为 lui+addi = 2 条）。"""
    toks = line.split(None, 1)
    mnem = toks[0]
    if mnem == "la":
        return 2
    if mnem == "li":
        try:                                  # li rd, imm
            imm = int(toks[1].rsplit(",", 1)[1].strip(), 0)
            return 1 if -2048 <= imm <= 2047 else 2
        except Exception:
            return 2
    return 1


LOOPI_RE = re.compile(r"^loopi\s+(\d+)\s*,\s*(\d+)")


def check_loops(path: Path):
    """检查 loopi 的体长是否等于实际机器指令数。

    体范围用缩进界定（loopi 之后所有缩进更深的指令，含嵌套 loopi 的体内指令）；
    la 展开成 2 条（otbn_as: lui + addi），li 视立即数大小 1~2 条。
    注意：OTBN 的 loop 用 bodysize 界定循环体（last_addr = start + 4*body - 4），
    声明偏大就会把循环体后面的指令吞进来，声明偏小则提前跳回。

    ⚠️ 体长不符 **不等于功能 bug**：偏大 1 时，末次迭代 restarts_left==0 会 fall-through，
    被"跳过"的那条指令照常执行 ⇒ 循环后状态通常与正确写法相同（只是每次非末次迭代多跑
    1 条），且官方 check_loop.py 与硬件都不会报错。它只是"声明与源码不一致"的告警。
    """
    src = strip_comments(path.read_text(encoding="utf-8"))
    lines = src.splitlines()
    bad = []
    for i, raw in enumerate(lines):
        line = raw.strip()
        m = LOOPI_RE.match(line)
        if not m:
            continue
        indent = len(raw) - len(raw.lstrip())
        need = int(m.group(2))
        got = 0
        for l_raw in lines[i + 1:]:
            l = l_raw.strip()
            if not l:
                continue
            lm0 = LABEL_RE.match(l)
            if lm0 and not l[lm0.end():].strip():
                continue            # 纯标签行（常见于循环体内，缩进与循环体不同）
            l_indent = len(l_raw) - len(l_raw.lstrip())
            if l_indent <= indent:
                break
            if l.startswith("."):
                continue
            lm = LABEL_RE.match(l)
            if lm:
                l = l.split(":", 1)[1].strip()
                if not l:
                    continue
            if "/*" in l:
                l = l.split("/*", 1)[0].strip()
                if not l:
                    continue
            got += count_insn(l)
        if got != need:
            bad.append((i + 1, int(m.group(1)), need, got))
    return bad


def check(files, verbose=False):
    """files: [(label, path)] → (undefined, duplicates)"""
    defs, refs = {}, {}
    for label, p in files:
        if not p.is_file():
            print(f"  !! 文件不存在: {p}  (来自 {label})")
            continue
        d, r, _ = scan(p)
        for s in d:
            defs.setdefault(s, []).append(label)
        for s in r:
            refs.setdefault(s, set()).add(label)
    undefined = {s: v for s, v in refs.items() if s not in defs}
    duplicates = {s: v for s, v in defs.items() if len(v) > 1}
    loops = {}
    for label, p in files:
        if p.is_file():
            b = check_loops(p)
            if b:
                loops[p.name] = b
    if verbose:
        for s in sorted(undefined):
            print(f"      ref {s:34s} <- {', '.join(sorted(undefined[s]))}")
    return undefined, duplicates, loops


# ── BUILD 解析（只认 otbn_binary / otbn_sim_test 的 name/srcs/deps）──────────
def parse_build(build_path: Path):
    text = build_path.read_text(encoding="utf-8")
    pkg = build_path.parent.relative_to(REPO).as_posix()
    # BUILD 顶层的字符串变量（如 XOF = "//pkg:xof.s"）
    variables = dict(re.findall(r'^([A-Za-z_][A-Za-z_0-9]*)\s*=\s*"([^"]*)"',
                                text, flags=re.M))
    targets = []
    for m in re.finditer(r"otbn_(\w+)\s*\(", text):
        kind = m.group(1)
        start = m.end() - 1
        depth, i = 0, start
        while i < len(text):
            if text[i] == "(":
                depth += 1
            elif text[i] == ")":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        body = text[start + 1:i]
        name = re.search(r'name\s*=\s*"([^"]+)"', body)
        if not name:
            continue
        srcs = re.search(r"srcs\s*=\s*\[(.*?)\]", body, flags=re.S)
        files = []
        if srcs:
            for s in [a or variables.get(b, b) for a, b in
                      re.findall(r'"([^"]+)"|([A-Za-z_][A-Za-z_0-9]*)', srcs.group(1))]:
                if s.startswith("//"):
                    path = REPO / s[2:].replace(":", "/")
                else:
                    path = build_path.parent / s
                files.append((s, path))
        targets.append({"name": name.group(1), "kind": kind, "files": files})
    return pkg, targets


def resolve_deps(pkg, targets, build_path):
    """把 deps 里的 :target 展开成该包的 BUILD 里对应目标的 srcs。"""
    by_name = {t["name"]: t for t in targets}
    text = build_path.read_text(encoding="utf-8")
    out = {}
    for t in targets:
        files = list(t["files"])
        body = None
        for m in re.finditer(r"otbn_\w+\s*\(", text):
            start = m.end() - 1
            depth, i = 0, start
            while i < len(text):
                if text[i] == "(":
                    depth += 1
                elif text[i] == ")":
                    depth -= 1
                    if depth == 0:
                        break
                i += 1
            if f'name = "{t["name"]}"' in text[start:i]:
                body = text[start:i]
                break
        if body:
            dep = re.search(r"deps\s*=\s*\[(.*?)\]", body, flags=re.S)
            if dep:
                for d in re.findall(r'"([^"]+)"', dep.group(1)):
                    short = d.split(":")[-1]
                    if short in by_name:
                        files += by_name[short]["files"]
                    else:
                        # 其他包的依赖：只提示，不解析
                        print(f"  [info] {t['name']} 依赖外部包 {d}（未解析，可能带来符号）")
        out[t["name"]] = files
    return out


def check_config(cfg_path: Path):
    """跨版本核对 harness_config.yaml ↔ 各包 BUILD：阶段数、reuse 行、差集。

    用途：改配置时最容易误伤别的版本（批量替换不带锚点就会这样），
    改完跑一次这个，三版的"配置阶段数 / 已接线 / reuse 行 / 差集"一眼可见。
    """
    import yaml
    cfg = yaml.safe_load(cfg_path.read_text(encoding="utf-8"))
    bad = 0
    print(f"{'版本':10s} {'配置阶段':>8s} {'已接线':>7s} {'reuse':>6s}  差集")
    for v in cfg.get("versions", []):
        if "package" not in v:
            continue
        pkg = Path(v["package"].lstrip("/")).resolve()
        build = pkg / "BUILD"
        if not build.is_file():
            print(f"{v['name']:10s}  !! 找不到 BUILD: {build}")
            bad += 1
            continue
        _, targets = parse_build(build)
        pre = v.get("target_prefix", "")
        wired = {t["name"][len(pre):-len("_profiling")]
                 for t in targets if t.get("kind") == "binary"
                 and t["name"].startswith(pre) and t["name"].endswith("_profiling")}
        phases = {p["name"] if isinstance(p, dict) else p for p in v["phases"]}
        missing = sorted(phases - wired)      # 配置有、BUILD 没接线
        extra = sorted(wired - phases)        # BUILD 有、配置没列
        reuse = len(v.get("reuse", []))
        flag = "" if not missing and not extra else "   <== 需要处理"
        if missing or extra:
            bad += 1
        print(f"{v['name']:10s} {len(phases):>8d} {len(wired):>7d} {reuse:>6d}"
              f"  配置-only={missing or '[]'} BUILD-only={extra or '[]'}{flag}")
        # reuse 基准必须存在
        for r in v.get("reuse", []):
            if r["from"] not in phases:
                print(f"           reuse 基准缺失: {r['phase']} <- {r['from']}")
                bad += 1
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", help="harness_config.yaml：跨版本核对阶段/接线/reuse")
    ap.add_argument("--build")
    ap.add_argument("--files", nargs="*")
    ap.add_argument("--only", help="只检查名字含该子串的目标")
    ap.add_argument("--refs", action="store_true", help="打印每个未定义符号的引用来源")
    args = ap.parse_args()

    if args.config:
        return check_config(Path(args.config).resolve())

    bad = 0
    if args.build:
        build_path = Path(args.build).resolve()
        pkg, targets = parse_build(build_path)
        files_by_target = resolve_deps(pkg, targets, build_path)
        kinds = {t["name"]: t.get("kind") for t in targets}
        for name in sorted(files_by_target):
            if args.only and args.only not in name:
                continue
            if kinds.get(name) == "library":
                continue        # otbn_library 不是链接单元（不含跨文件符号）
            files = files_by_target[name]
            undef, dup, loops = check(files, verbose=args.refs)
            flag = "OK  " if not undef and not dup and not loops else "FAIL"
            if undef or dup or loops:
                bad += 1
            print(f"[{flag}] {pkg}:{name}")
            if dup:
                for s, v in sorted(dup.items()):
                    print(f"      重定义 {s}: {', '.join(v)}")
            for fn, b in loops.items():
                for ln, n, need, got in b:
                    print(f"      loopi 体长不符 {fn}:{ln}: 声明 {need}，实际 {got}")
            if undef:
                print(f"      未定义 {len(undef)} 个: "
                      f"{', '.join(sorted(undef))[:400]}")
                if args.refs:
                    for s in sorted(undef):
                        print(f"        {s:34s} <- {', '.join(sorted(undef[s]))}")
    else:
        files = [(f, Path(f)) for f in args.files]
        undef, dup, loops = check(files, verbose=args.refs)
        print("未定义:", ", ".join(sorted(undef)) or "（无）")
        if dup:
            print("重定义:", ", ".join(sorted(dup)))
        bad = 1 if undef else 0
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
