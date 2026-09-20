#!/usr/bin/env python3
"""审计 + 修复 harness 的 control 程序：让 control **机械等于 profiling 去掉所有 `jal` 行**。

为什么必须这样（2026-09-20 审计发现）：Δ 法的地基是
    Δcycles = profiling − control = 只该剩下"被 jal 调走的那部分"
若 control 与 profiling 还差别的指令，Δ 就会把那些指令也算进去（或漏掉）：
    · control **缺**操作数准备指令（`la`/`li`/`add`）⇒ Δ **多算**；
    · control **多**了指令 ⇒ Δ **少算**。
2026-09-20 审计实测：121 对里 23 对有这种偏差（+1 ~ +510 条指令），其中小行相对误差可达
**+11%**（`decap_verify_cmov` 397 拍里多算 24 条、ver1_1 的 168 拍里多算 19 条）；
大行可忽略（`poly_gen_matrix_shake` +510 条 / 245,283 条 = 0.21%）。
⇒ **大结论不受影响，但小行会被高估**。本工具把 control 重新机械生成，Δ 即为"内核的净成本"。

用法:
    python3 test_perf/tools/gen/fix_controls.py --version ver0_1 [--apply]
    （不带 --apply 只报告；--apply 直接改写 control + BUILD）
"""
import argparse
import json
import re
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]   # 工具在 test_perf/tools/<类>/ 下 ⇒ 仓库根 = parents[3]


def insns(text: str):
    """取"会执行的指令行"（去注释/指令/directive/标签），用于比较代码内容。"""
    t = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    out = []
    for ln in t.splitlines():
        ln = ln.split("#")[0].strip()
        if not ln or ln.startswith(".") or ln.endswith(":"):
            continue
        out.append(re.sub(r"\s+", " ", ln))
    return out


def _is_insn(line: str) -> bool:
    t = line.split("#")[0].strip()
    return bool(t) and not t.startswith(".") and not t.endswith(":")


def _expand_len(line: str) -> int:
    """该行展开成几条机器指令：`la`=2；`li` 视立即数 1 或 2；其余 1。"""
    t = line.split("#")[0].strip()
    if not t:
        return 0
    op = t.split()[0].lower()
    if op == "la":
        return 2
    if op == "li":
        try:
            v = int(t.split()[2].rstrip(","), 0)
        except (IndexError, ValueError):
            return 1
        return 1 if -(1 << 11) <= v < (1 << 11) else 2
    return 1


def make_control(prof_text: str) -> str:
    """control := profiling 去掉所有含 `jal` 的行（保留注释与数据段）。

    ⚠ 若 `jal` 落在 `loopi/loop` 的**体内**，删掉它会让体长比声明短 ⇒ 循环会把
    体外的下一条指令吞进来。因此同时把该 `loopi` 的声明体长减去被删的条目数
    （`jal` 恰是 1 条机器指令）。2026-09-20 审计：ver0_1/ver0_2 的
    `keygen_poly_getnoise_eta_1`（体内 1 条 jal）与 ver1_1 的 `encap_unpack_pk`
    （两处各 1 条）属于这种情况。
    """
    lines = prof_text.splitlines()
    newsize = {}                      # loopi 行号 → 新声明体长
    for i, ln in enumerate(lines):
        m = re.match(r"\s*(loopi|LOOPI|loop|LOOP)\s+[^,]+,\s*(\d+)\s*$", ln.split("#")[0])
        if not m:
            continue
        declared = int(m.group(2))
        cnt, j, jals = 0, i + 1, 0
        while cnt < declared and j < len(lines):
            if _is_insn(lines[j]):
                if "jal" in lines[j].split("#")[0]:
                    jals += 1
                cnt += _expand_len(lines[j])
            j += 1
        if jals and cnt == declared:
            newsize[i] = declared - jals

    out = []
    for i, ln in enumerate(lines):
        if "jal" in ln.split("#")[0]:
            continue
        if i in newsize:
            op = re.match(r"\s*(\S+)\s+([^,]+),\s*(\d+)\s*$", ln)
            ln = f"  {op.group(1)} {op.group(2)}, {newsize[i]}"
        out.append(ln)
    return "\n".join(out) + "\n"


def patch_build(build_path: Path, pairs: dict) -> str:
    """把 control 目标的 srcs 改成 profiling 目标的 srcs（只换首行文件名）。

    ⚠ **必须保留 profiling 里的原始行文本**：BUILD 顶层可能有字符串变量
    （ver1_1 的 `XOF = "//…:xof.s"`），srcs 里写的是**裸变量名** `XOF,`。
    若统一加引号写成 `"XOF",`，bazel 会当成"包里一个叫 XOF 的文件"而报错
    （2026-09-20 踩过：9 个 control 目标被写坏，靠静态检查器 `otbn_symbol_check.py`
    的"文件不存在 …\mlkem768\XOF"告警抓回来）。所以这里只替换第一条（本目标的 .s），
    其余行**逐字照抄** profiling 的 srcs。
    """
    txt = build_path.read_text(encoding="utf-8")

    def grab_raw(name):
        m = re.search(r'name = "%s",\s*\n\s*srcs = \[(.*?)\]' % re.escape(name), txt, re.S)
        return None if not m else m.group(1)

    for row in pairs:
        raw = grab_raw(f"mlkem768_{row}_profiling")
        if raw is None:
            print(f"    ⚠ BUILD 里找不到 mlkem768_{row}_profiling 的 srcs")
            continue
        rest = [l for l in raw.splitlines() if l.strip()][1:]   # 去掉 profiling 自己的 .s
        body = "\n".join([f'        "{row}_control.s",'] + rest)
        pat = re.compile(r'(name = "%s_control",\s*\n\s*srcs = \[)(.*?)(\])' % re.escape(f"mlkem768_{row}"), re.S)
        txt, n = pat.subn(lambda m: m.group(1) + "\n" + body + "\n    " + m.group(3), txt)
        if n != 1:
            print(f"    ⚠ BUILD 里 mlkem768_{row}_control 的 srcs 未替换（匹配 {n} 次）")
    return txt


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    ver = args.version
    pkg = REPO / f"test_hybrid_kem_otbn_prompt_{ver}" / "otbn" / "mlkem768"
    jsonp = REPO / "logs_hkem" / f"{ver}_profiling" / f"re_{ver}.json"
    rows = [r["phase"] for r in json.loads(jsonp.read_text(encoding="utf-8"))["rows"]
            if not r.get("reused_from")]

    changed, label_only, same, missing, inline_skip = [], [], [], [], []
    for row in rows:
        p, c = pkg / f"{row}_profiling.s", pkg / f"{row}_control.s"
        if not (p.exists() and c.exists()):
            missing.append(row)
            continue
        pt = p.read_text(encoding="utf-8")
        # 护栏：**profiling 里 0 条 jal** ⇒ 这是"内联块"行（如 decap_verify_cmov，
        # app 里 verify/cmov 是内联在 crypto_dec 结尾的），它的 control 是"去掉那个
        # 内联块"的手写文件，**不能**按"删 jal 行"的规则机械重写（否则 control
        # 会变成 profiling 的副本 ⇒ Δ=0）。这里直接跳过。
        if not any("jal" in l.split("#")[0] for l in pt.splitlines()):
            inline_skip.append(row)
            continue
        want = make_control(pt)
        if insns(want) == insns(c.read_text(encoding="utf-8")):
            if insns(want) == insns(pt):        # 根本没用 jal（不该发生）
                same.append(row)
            else:
                label_only.append(row)           # 只差标签/注释 ⇒ 执行无差异
            continue
        cur, exp = insns(c.read_text(encoding="utf-8")), insns(want)
        miss = sum((Counter(exp) - Counter(cur)).values())
        extra = sum((Counter(cur) - Counter(exp)).values())
        changed.append((row, miss, extra, want))

    print(f"===== {ver}: {len(rows)} 对")
    print(f"  执行内容不同（需修）：{len(changed)} 对")
    for row, miss, extra, _w in changed:
        print(f"     · {row:34s} control 缺 {miss:>3d} 条 / 多 {extra:>3d} 条")
    print(f"  只差标签/注释（无需修）：{len(label_only)} 对")
    if inline_skip:
        print(f"  内联块行（profiling 无 jal，按设计跳过）：{inline_skip}")
    if missing:
        print(f"  ⚠ 文件缺失：{missing}")

    if not args.apply:
        print("\n（未加 --apply，仅报告；加 --apply 直接改写 control/BUILD）")
        return 0

    for row, _m, _e, want in changed:
        c = pkg / f"{row}_control.s"
        c.write_text(want, encoding="utf-8")
        print(f"  [改写] {row}_control.s")

    build = pkg / "BUILD"
    build.write_text(patch_build(build, [r for r, _m, _e, _w in changed]), encoding="utf-8")
    print(f"  [改写] {build.name}：{len(changed)} 个 control 目标的 srcs 已对齐 profiling")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
