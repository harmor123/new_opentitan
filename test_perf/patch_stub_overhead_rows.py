#!/usr/bin/env python3
"""把 ver0_1 / ver0_2 的 `keygen_poly_gen_matrix_stub_overhead` 行改成"按会话重指指针"。

为什么必须改（2026-09-20 定位）：
  · 旧行把流指针**设一次**、然后 `.rept 137 { jal 挤压桩 }` **线性走 137 块**，
    而 app 实测只有 **135** 次挤压 ⇒ ① 校准数陈旧（在 `shake+rejection−stub` 里残留偏差）；
    ② 线性游走跨过会话边界，语义上不对应"每会话各自从本会话的流开始"（app 的真实形态）。
  · ver1_1 的同名行已是"按会话重指 + 逐会话计数"，本脚本把 ver0_x 对齐到同一形态。

计数不写死：**从流文件读出每会话的块数**（标签步长），与 `gen_xof_stream_from_rho.py`
生成的"按需求块数"完全一致；改完再用 `test_perf/check_stream_shape.py` 复核
（不变量 B：replay 总数 == app 实测；C'：逐会话不越界）。

用法: python3 test_perf/patch_stub_overhead_rows.py [--apply] [--version ver0_1] [--version ver0_2]
"""
import argparse
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import fix_controls as F      # noqa: E402  用同一个"删 jal"规则派生 control

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

PKG = {"ver0_1": "test_hybrid_kem_otbn_prompt_ver0_1/otbn/mlkem768",
       "ver0_2": "test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768"}
SQUEEZE = {"ver0_1": "shake_out", "ver0_2": "xof_squeeze32"}


def parse_quotas(stream: Path):
    """→ [(标签, 块数)]，按文件中的出现顺序（标签步长 = 每会话配额）

    ⚠ 只认 `rejection_stream_<4 位十六进制>`：`_ptr`（指针变量）与 `_pad`（尾部补位块，
    `.zero` 不进 `.byte` 计数）都不是会话（2026-09-20 踩过：不滤会多数出一个"会话 10"）。
    """
    off, labels = 0, []
    for line in stream.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if s.startswith(".byte"):
            off += len(s.split(","))
        elif re.fullmatch(r"rejection_stream_[0-9a-f]{4}", s[:-1] or ""):
            labels.append([s[:-1], off, 0])
    for k in range(len(labels) - 1):
        labels[k][2] = (labels[k + 1][1] - labels[k][1]) // 32
    labels[-1][2] = (off - labels[-1][1]) // 32
    return [(l[0], l[2]) for l in labels]


def patch(text: str, sym: str, quotas):
    """删掉"设一次指针"的三行 + 把 `.rept N { jal 挤压桩 }` 换成按会话块"""
    lines = text.splitlines()
    # ① 找设一次指针的三行并删除
    reg_ptr = reg_lab = None
    for i, l in enumerate(lines):
        m = re.match(r"\s*la\s+(x\d+),\s*rejection_stream_ptr\b", l)
        if m:
            reg_ptr = m.group(1)
            m2 = re.match(r"\s*la\s+(x\d+),\s*rejection_stream_\w+", lines[i + 1])
            m3 = re.match(r"\s*sw\s+(x\d+),\s*0\((x\d+)\)", lines[i + 2])
            if m2 and m3:
                reg_lab = m2.group(1)
                del lines[i:i + 3]
            break
    if not (reg_ptr and reg_lab):
        raise SystemExit("✗ 找不到「设一次指针」的三行（行结构变了？）")
    # ② 找 `.rept N { jal <sym> }` 并替换
    out, i = [], 0
    done = False
    while i < len(lines):
        l = lines[i]
        m = re.match(r"\s*\.rept\s+(\d+)\s*$", l)
        if m and not done and i + 1 < len(lines) and re.match(rf"\s*jal\s+x\d+,\s*{sym}\b", lines[i + 1]):
            old_n = int(m.group(1))
            j = i + 1
            while j < len(lines) and not re.match(r"\s*\.endr", lines[j]):
                j += 1
            blk = []
            for lab, n in quotas:
                nonce = lab.rsplit("_", 1)[1]
                blk += [f"  /* 会话 nonce 0x{nonce}：本会话 {n} 块（= app 实测需求，与流文件配额一致） */",
                        f"  la   {reg_ptr}, rejection_stream_ptr",
                        f"  la   {reg_lab}, {lab}",
                        f"  sw   {reg_lab}, 0({reg_ptr})",
                        f"  .rept {n}",
                        f"    jal  x1, {sym}",
                        "  .endr"]
            out += blk
            print(f"    · `.rept {old_n}` → {len(quotas)} 个按会话块，合计 {sum(n for _, n in quotas)} 次")
            i = j + 1
            done = True
            continue
        out.append(l)
        i += 1
    if not done:
        raise SystemExit(f"✗ 找不到 `.rept N {{ jal {sym} }}` 块")
    return "\n".join(out) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", action="append", choices=sorted(PKG))
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()
    vers = args.version or sorted(PKG)

    for v in vers:
        d = REPO / PKG[v]
        row = d / "keygen_poly_gen_matrix_stub_overhead_profiling.s"
        ctl = d / "keygen_poly_gen_matrix_stub_overhead_control.s"
        stream = d / "keygen_poly_gen_matrix_rejection_streams.s"
        quotas = parse_quotas(stream)
        print(f"### {v}：流文件 {len(quotas)} 会话，配额 {[n for _, n in quotas]}，合计 {sum(n for _, n in quotas)}")
        new = patch(row.read_text(encoding="utf-8"), SQUEEZE[v], quotas)
        if args.apply:
            row.write_text(new, encoding="utf-8")
            ctl.write_text(F.make_control(new), encoding="utf-8")
            print(f"    [写] {row.name} + {ctl.name}（control = 删 jal 机械派生）")
        else:
            print("    （干跑，未写；加 --apply 落盘）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
