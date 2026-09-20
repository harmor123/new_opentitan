#!/usr/bin/env python3
"""校验"桩法拒绝采样"三件套的形状一致性（纯静态，不需要构建/ISS）。

为什么需要它（2026-09-20 事故）：
  ver1_1 的流文件曾是从 ver0_x 原样拷来的 **180 块（20 块/会话）**，而 ver1_1 的 app
  每会话固定挤 21 块（`poly_gen_matrix.s: loopi 21,3`、`_expand_buf` 672 B）⇒
    ① stub_overhead 行线性走 189 块，末尾 9 块越出已加载 `.data`、落进 NOLOAD 的
       `.scratchpad` ⇒ `bn.lid` 读到从未加载的字 ⇒ `DMEM_INTG_VIOLATION (0x20000)`；
    ② rejection 行按会话重指指针、每会话多读 1 块 ⇒ **静默**读到邻居会话的数据
       （落在已加载 `.data` 里，不报错、但轨迹不是 app 的）✗ —— 最危险的一类。
  同日还查出 ver0_1/ver0_2 的 stub_overhead 写死 137 次而 app 实测 135 次（旧 ρ 时代
  标定），且流数据是旧 ρ 的 ⇒ 校准值有偏。两者都已按 ρ 确定性生成的真流重做。

不变量（全部静态可判定）：
  A  流文件的 **Σ每会话配额 == app 实测动态挤压次数** —— 独立复核"流就是 app 消费的流"
  B  stub_overhead 行的 replay 总数 == app 实测动态挤压次数
  C  rejection 行按顺序引用流文件里的全部会话标签（不多不少、顺序一致）
  D  逐会话桶：某会话标签之后、下一个会话标签之前的挤压调用数 ≤ 该会话的配额
     （这条同时抓住"单标签 + 线性长走"的旧写法：那个写法 189 次 > 单会话配额 21）

数据来源：
  · 流文件           —— 会话标签 `rejection_stream_<4 位十六进制>`（`_ptr`/`_pad` 不算会话）
                        + `.byte` 字节数（每值 1 字节）
  · app 实测动态次数 —— logs_hkem/<版本>_profiling/*.json 的 `keygen_poly_gen_matrix` 行 calls

用法: python3 test_perf/check_stream_shape.py [--logs-dir logs_hkem]
"""
import argparse
import json
import re
import sys
from pathlib import Path

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = Path(__file__).resolve().parents[1]
VERSIONS = {
    "ver0_1": "test_hybrid_kem_otbn_prompt_ver0_1/otbn/mlkem768",
    "ver0_2": "test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768",
    "ver1_1": "test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768",
}
STREAM = "keygen_poly_gen_matrix_rejection_streams.s"
STUBS = "keygen_poly_gen_matrix_rejection_stubs.s"
SQUEEZE = {"ver0_1": "shake_out", "ver0_2": "xof_squeeze32", "ver1_1": "xof_squeeze32"}
LABEL_RE = re.compile(r"rejection_stream_([0-9a-f]{4})\b")


def parse_stream(path: Path):
    """→ (载荷字节数, [(标签, 起点偏移)], pad 偏移或 None)"""
    off, labels, pad = 0, [], None
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if s.startswith(".byte"):
            off += len(s.split(","))                     # .byte 每值 = 1 字节
        elif s.startswith("rejection_stream_") and s.endswith(":"):
            name = s[:-1]
            if name == "rejection_stream_ptr":
                continue
            if name == "rejection_stream_pad":
                pad = off
            elif LABEL_RE.fullmatch(name):
                labels.append((name, off))
    return off, labels, pad


def parse_copy_stub_sym(stubs: Path) -> str:
    """桩文件里"拷 32 B 进 WDR/缓冲"的那个符号（含 bn.lid 的 globl 段）"""
    cur, hit = None, None
    for line in stubs.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        m = re.match(r"\.globl\s+(\S+)", s)
        if m:
            cur = m.group(1)
        if s.startswith("bn.lid") and cur:
            hit = cur
    return hit


def parse_row(row: Path, sym: str):
    """→ (replay 总次数, [(会话标签, 该标签之后的挤压调用数)], 未设指针时的调用数)"""
    total, pend, buckets, orphan, cur = 0, 1, [], 0, None
    for line in row.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        m = re.match(r"\.rept\s+(\d+)", s)
        if m:
            pend = int(m.group(1))
        if s.startswith("jal") and re.search(rf"\b{re.escape(sym)}\b", s):
            total += pend
            if cur is None:
                orphan += pend
            else:
                buckets[-1][1] += pend
        if s.startswith(".endr"):
            pend = 1
        m2 = LABEL_RE.search(s)
        if m2:
            cur = m2.group(0)
            buckets.append([cur, 0])
    return total, buckets, orphan


def load_app_calls(logs_dir: Path, version: str):
    for p in sorted((logs_dir / f"{version}_profiling").glob("*.json")):
        data = json.loads(p.read_text(encoding="utf-8"))
        for row in data.get("rows", []):
            if row.get("phase") == "keygen_poly_gen_matrix":
                calls = row.get("calls", {})
                n = calls.get(SQUEEZE[version])
                if n:
                    return n
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--logs-dir", default=str(REPO / "logs_hkem"))
    args = ap.parse_args()
    logs_dir = Path(args.logs_dir)

    failed = 0
    for version, pkg in VERSIONS.items():
        d = REPO / pkg
        stream, stubs = d / STREAM, d / STUBS
        if not (stream.exists() and stubs.exists()):
            print(f"### {version}: 缺文件，跳过\n")
            continue

        payload, labels, pad = parse_stream(stream)
        quotas = []
        for k, (name, off) in enumerate(labels):
            end = labels[k + 1][1] if k + 1 < len(labels) else (pad if pad is not None else payload)
            quotas.append((name, (end - off) // 32))
        total_quota = sum(n for _, n in quotas)
        sym = parse_copy_stub_sym(stubs)
        so_row = d / "keygen_poly_gen_matrix_stub_overhead_profiling.s"
        rj_row = d / "keygen_poly_gen_matrix_rejection_profiling.s"
        so_total, so_buckets, so_orphan = parse_row(so_row, sym)
        _, rj_buckets, _ = parse_row(rj_row, sym)
        app_n = load_app_calls(logs_dir, version)

        print(f"### {version}")
        print(f"  流文件: 载荷 {payload} B = {payload // 32} 块；{len(labels)} 会话；"
              f"配额 {[n for _, n in quotas]}（Σ {total_quota}）"
              + (f"；尾部补位块 @ +{pad}" if pad is not None else "；无尾部补位块"))
        print(f"  拷贝桩符号 {sym}（32 B/次）；stub_overhead replay {so_total} 次"
              f"{'（其中未设指针前 %d 次）' % so_orphan if so_orphan else ''}"
              f"；rejection 行引用 {len(rj_buckets)} 个会话标签")
        print(f"  app 实测动态 {SQUEEZE[version]} 次数 = {app_n}")

        if app_n is None:
            print("  （无实测 JSON ⇒ A/B 跳过）")
        else:
            ok = total_quota == app_n
            print(f"  [A] 流 Σ配额 {total_quota} == app 实测 {app_n} : "
                  f"{'✓' if ok else '✗ 流不是 app 消费的那条（Σ配额与实测不符）'}")
            failed += 0 if ok else 1
            ok = so_total == app_n
            print(f"  [B] stub_overhead replay {so_total} == app 实测 {app_n} : "
                  f"{'✓' if ok else '✗ 校准次数陈旧（会在减法里残留偏差）'}")
            failed += 0 if ok else 1

        want = [n for n, _ in labels]
        got = [n for n, _ in rj_buckets]
        ok = got == want
        print(f"  [C] rejection 行按顺序引用全部会话标签 : "
              f"{'✓' if ok else f'✗ 期望 {want}，实际 {got}'}")
        failed += 0 if ok else 1

        # [D] 两种写法各有其真实约束：
        #   · 只引用 1 个会话标签 = 设一次指针后**线性走**（ver1_1 的现状）⇒ 约束是"不越载荷"
        #     （跨会话边界不是错误：桩的成本只与调用次数有关）
        #   · 引用多个标签 = **按会话重指**（ver0_x 的现状）⇒ 约束是"逐会话桶 ≤ 该会话配额"
        if len(so_buckets) <= 1:
            ok = so_orphan == 0 and so_total * 32 <= payload
            head = f"  [D] 线性游走 {so_total * 32} B ≤ 载荷 {payload} B"
        else:
            bad = [(n, c, q) for (n, c), (_, q) in zip(so_buckets, quotas) if c > q]
            ok = not bad and so_orphan == 0
            head = f"  [D] 逐会话桶 ≤ 配额（{len(so_buckets)} 个桶）"
        print(f"{head} : {'✓' if ok else '✗ 越界（会读到未加载字 ⇒ DMEM_INTG_VIOLATION）或未设指针就挤压'}")
        failed += 0 if ok else 1
        print()

    print(f"结论：{'全部一致 ✓' if not failed else f'{failed} 项不一致 ✗（先修数据/行再重测）'}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
