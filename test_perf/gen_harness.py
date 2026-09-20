#!/usr/bin/env python3
"""harness 剖面目标生成器：把"某 op 的某阶段调用序列"变成一对 bazel 目标。

动机（用户 2026-09-20 明确）：**不要估算值，要逐项实测** —— 每个 reuse 行都要在
它所属的 op 里真实调用（次数 = 该 app 源码里的动态调用次数），**行名保持不变**。

用法:
    python3 test_perf/gen_harness.py --version ver1_1 --out-dir <包目录> --build-snippet
    python3 test_perf/gen_harness.py --version ver0_2 --out-dir <包目录> --dry-run

产出（每个 row 一对）:
    <op>_<row>_profiling.s   前奏 + 调用序列（.rept 直排，不写 loopi）
    <op>_<row>_control.s     同前奏，去掉所有 jal（Δcycles = profiling − control）
以及（--build-snippet）BUILD 目标条目。

约定：
  - 调用次数来自 app 源码的静态计数（`jal` × 所在 .rept / loopi 的迭代数连乘）。
  - 前奏/必带数据/附加 srcs 按版本查 harness_specs 里的表
    （ver0_2 内核用 fp 相对寻址，ver1_1 用 x31 栈指针 + MOD CSR）。
  - **control 与 profiling 用同一份 srcs**：control 保留操作数准备（`la` 等），
    因此同样会引用 twiddles/常量等符号；内核文件放着不执行，对 Δ 无影响。
"""

import argparse
import sys
from pathlib import Path

WDR_ZERO = "\n".join(f"  bn.xor w{i}, w{i}, w{i}" for i in range(31))

HEAD = """\
/*
 * {version} 剖面（实测行）：{op}_{row}_{kind}
 * {note}
 *
 * 本文件由 test_perf/gen_harness.py 生成（--version {version}）。
 * 与同 row 的另一个目标逐条对应，仅差调用 —— Δcycles = profiling − control。
 */
.section .text.start

.globl main
main:
  /* 与 app（{app}.s）一致的确定性 WDR 初始化 */
{zeros}

{prologue}
"""


def render(version: str, spec: dict, kind: str, tables: dict) -> str:
    pre = list(tables["PROLOGUE"][version]) + [""] + list(spec.get("prelude", []))
    body = HEAD.format(version=version, op=spec["op"], row=spec["row"], kind=kind,
                       note=spec["note"], app=spec["app"], zeros=WDR_ZERO,
                       prologue="".join(l + "\n" for l in pre))
    for rep, lines in spec["calls"]:
        keep = lines if kind == "profiling" else [l for l in lines if "jal" not in l]
        if not keep:
            continue
        if rep > 1:
            body += f"  .rept {rep}\n" + "".join("  " + l + "\n" for l in keep) + "  .endr\n\n"
        else:
            body += "".join("  " + l + "\n" for l in keep) + "\n"
    body += "  ecall\n\n\n.section .data\n.balign 32\n"
    data = list(spec["data"]) + list(tables["MANDATORY_DATA"][version])
    body += "".join(l + "\n" for l in data if l is not None)
    return body


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--build-snippet", action="store_true")
    args = ap.parse_args()

    sys.path.insert(0, str(Path(__file__).parent))
    import harness_specs as HS
    tables = {"PROLOGUE": HS.PROLOGUE, "MANDATORY_DATA": HS.MANDATORY_DATA,
              "DEFAULT_EXTRA": HS.DEFAULT_EXTRA}
    ver = args.version
    out = Path(args.out_dir)
    for spec in HS.SPECS[ver]:
        op, row = spec["op"], spec["row"]
        names = {}
        for kind in ("profiling", "control"):
            fn = f"{op}_{row}_{kind}.s"
            names[kind] = fn
            text = render(ver, spec, kind, tables)
            if args.dry_run:
                print(f"----- {fn} -----\n{text}")
            else:
                (out / fn).write_text(text, encoding="utf-8")
                print(f"[写] {fn}", file=sys.stderr)
        if args.build_snippet:
            srcs = spec["srcs"] + HS.DEFAULT_EXTRA[ver]
            body = ",\n".join(f'        "{s}"' for s in srcs)
            print(f"""
otbn_binary(
    name = "mlkem768_{op}_{row}_profiling",
    srcs = [
        "{names['profiling']}",
{body},
    ],
)

otbn_binary(
    name = "mlkem768_{op}_{row}_control",
    srcs = [
        "{names['control']}",
{body},
    ],
)""")
    return 0


if __name__ == "__main__":
    sys.exit(main())
