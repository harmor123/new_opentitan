#!/usr/bin/env python3
"""把 ver0_1 / ver0_2 的 `keygen_poly_gen_matrix_shake` 行的挤压次数改成实测值（135）。

背景（2026-09-20）：这两行的 squeeze 次数还是**旧 ρ 时代**的逐会话计数
15/16/15/15/16/15/15/15/15 = **137**，而父行（阶段行，独立实测）是 **135** ⇒
  · ver0_1：多 2 次 `shake_out` ⇒ 多 2 次 `keccakf` ⇒ `shake+rejection−stub` 闭合差 **+10,732 拍**；
  · ver0_2：多 2 次 `xof_squeeze32` ⇒ 多 2 次 `_xof_rsp_valid_poll` ⇒ 闭合差 **+274 拍**。
判据（本次新增的审计规则）：桩法三行的调用次数必须与**父行相等**
（`test_perf/tools/check/audit_fidelity.py` 的 ②''）—— 修完必须让它全绿。

计数不写死：从流文件读每会话配额（`patch_stub_overhead_rows.parse_quotas`，现为 9 × 15 = 135），
与 app/父行的实测动态次数一致。ver0_1 是**展开**写法（每调用一组 5 行），ver0_2 是 `.rept` 写法。

用法: python3 test_perf/tools/gen/fix_shake_rows.py [--apply] [--version ver0_1] [--version ver0_2]
"""
import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]   # 工具在 test_perf/tools/<类>/ 下 ⇒ 仓库根 = parents[3]
sys.path.insert(0, str(Path(__file__).resolve().parent))
from patch_stub_overhead_rows import parse_quotas      # noqa: E402  同一个"标签步长 = 每会话配额"

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

PKG = {"ver0_1": "test_hybrid_kem_otbn_prompt_ver0_1/otbn/mlkem768",
       "ver0_2": "test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768"}
SQUEEZE = {"ver0_1": ("shake_out", "shake_xof"), "ver0_2": ("xof_squeeze32", "xof_process")}


def split_sessions(lines, session_sym):
    """按 `jal … <session_sym>` 切会话：返回 [(起始行号, 结束行号)]（结束 = 下一个会话起点）"""
    marks = [i for i, l in enumerate(lines)
             if re.match(rf"\s*jal\s+x\d+,\s*{session_sym}\b", l)]
    return [(s, e) for s, e in zip(marks, marks[1:] + [len(lines)])]


def fix_unrolled(text, squeeze_sym, session_sym, quotas):
    """ver0_1：展开写法 —— 每个多出的调用删掉整组（注释 + la/addi/li + jal），并把该会话注释的 /N 改对"""
    lines = text.splitlines()
    out, removed = list(lines), []
    for (s, e) in reversed(split_sessions(lines, session_sym)):     # 逆序改，行号不失效
        calls = [i for i in range(s, e) if re.match(rf"\s*jal\s+x\d+,\s*{squeeze_sym}\b", lines[i])]
        quota = quotas[0][1]        # 逐会话配额（现为 15；流文件已按会话给出）
        if len(calls) <= quota:
            continue
        for i in reversed(calls[quota:]):                            # 删尾部的多余调用
            g = i
            while g > s and not lines[g].lstrip().startswith("/* squeeze"):
                g -= 1
            # ⚠ 必须按**索引**判空：`if j in out` 是按值判（out 里是字符串）⇒ 永远为假、
            #   删除从不发生，而 removed 照样有记录（2026-09-20 踩过，计数 137→137 才暴露）
            for j in range(i, g - 1, -1):
                if 0 <= j < len(out) and out[j] is not None:
                    out[j] = None
            removed.append(lines[i].strip())
        # 该会话的 `/M` 注释统一改成 `/quota`
        for i in range(s, e):
            out[i] = re.sub(r"(/\* squeeze \d+)/\d+(\s*\*/)", rf"\g<1>/{quota}\g<2>", out[i]) \
                if isinstance(out[i], str) else out[i]
    return "\n".join([l for l in out if l is not None]) + "\n", removed


def fix_rept(text, squeeze_sym, quotas):
    """ver0_2：`.rept N { jal <squeeze> }` 写法 —— 把超过配额的 N 改成配额"""
    lines, out, changed = text.splitlines(), text.splitlines(), []
    q = quotas[0][1]
    for i, l in enumerate(lines):
        m = re.match(r"(\s*)\.rept\s+(\d+)\s*$", l)
        if m and i + 1 < len(lines) and re.match(rf"\s*jal\s+x\d+,\s*{squeeze_sym}\b", lines[i + 1]):
            n = int(m.group(2))
            if n > q:
                out[i] = f"{m.group(1)}.rept {q}"
                changed.append(f"`.rept {n}` → `.rept {q}`（行 {i+1}）")
    return "\n".join(out) + "\n", changed


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", action="append", choices=sorted(PKG))
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import fix_controls as F                                   # noqa: E402

    for v in (args.version or sorted(PKG)):
        d = REPO / PKG[v]
        sq, sess = SQUEEZE[v]
        quotas = parse_quotas(d / "keygen_poly_gen_matrix_rejection_streams.s")
        row = d / "keygen_poly_gen_matrix_shake_profiling.s"
        ctl = d / "keygen_poly_gen_matrix_shake_control.s"
        text = row.read_text(encoding="utf-8")

        def n_calls(t: str) -> int:
            """该文件里 `<squeeze>` 的实际调用次数（ver0_1 展开 / ver0_2 `.rept`）；
            ⚠ 空白容错：行里是 `jal  x1,`（两个空格）——固定字符串计数会数成 0。"""
            if v == "ver0_1":
                return len(re.findall(rf"jal\s+x\d+,\s*{sq}\b", t))
            return sum(int(m.group(1)) for m in
                       re.finditer(rf"\.rept\s+(\d+)\s*\n\s*jal\s+x\d+,\s*{sq}\b", t))

        before = n_calls(text)
        if v == "ver0_1":
            new, changed = fix_unrolled(text, sq, sess, quotas)
        else:
            new, changed = fix_rept(text, sq, quotas)
        after = n_calls(new)
        print(f"### {v}：每会话配额 {[n for _, n in quotas]}（Σ {sum(n for _, n in quotas)}）")
        print(f"    {sq} 调用数 {before} → {after}；改动: {changed or '（无需改）'}")
        if args.apply and before != after:
            row.write_text(new, encoding="utf-8")
            ctl.write_text(F.make_control(new), encoding="utf-8")
            print(f"    [写] {row.name} + {ctl.name}（control = 删 jal 机械派生）")
        elif not args.apply:
            print("    （干跑，未写；加 --apply 落盘）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
