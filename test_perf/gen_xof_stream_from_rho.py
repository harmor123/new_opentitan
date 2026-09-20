#!/usr/bin/env python3
"""由 ρ 确定性生成"拒绝采样隔离"用的 XOF 流（ver0_1 / ver0_2 的按需补挤模型）。

为什么可以不用抓取（2026-09-20 实测确证）：
  · ver1_1 的真流是从 ISS 里原样抓的（`dump_xof_stream.py`），把它的 189 个 32 B 块
    与 Python 的 `shake_128(ρ‖j‖i)` **逐字节**比对 —— **9/9 会话完全相同** ⇒
    KMAC 硬件 XOF 的输出就是标准 SHAKE128（此前"字节序与标准不同"的说法是被**旧 ρ**误导）。
  · ver0_1 的软件 Keccak 更是标准 SHAKE（`sha3_shake.s`：`shake_xof` 不写任何字节，
    只做 padding+keccakf 并把 pt 置 0；`shake_out` 按 `x12` 指定的长度输出）。

模型（ver0_x 是**按需补挤**，不是 ver1_1 的一次填满 672 B）：
  每会话 = `shake_128(ρ‖j‖i)` 的连续字节流，采样器按 32 B 一块地要；
  每 3 字节出 2 个候选（FIPS 203 SampleNTT），凑满 256 个系数需要 N 组 ⇒ **需要 ceil(3N/32) 块**。

自证（本脚本的核心判据）：
  Σ 各会话块数 **必须等于** app 在 ISS 上实测的动态挤压次数（ver0_1 `shake_out` ×135、
  ver0_2 `xof_squeeze32` ×135，见 logs_hkem/<版本>_profiling/*.json）。
  这个数**随数据变化**（拒绝次数变 ⇒ 需求变），所以它能一次性确证：ρ 用对了、
  nonce 字节序（ρ‖j‖i）用对了、分块模型对。

用法:
    python3 test_perf/gen_xof_stream_from_rho.py --version ver0_2            # 干跑：只打印校验表
    python3 test_perf/gen_xof_stream_from_rho.py --version ver0_2 --write    # 写回包内流文件（备份为 .bak.s）
    python3 test_perf/gen_xof_stream_from_rho.py --version ver0_1 --nonce-order i,j   # 反序试算
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = Path(__file__).resolve().parents[1]
PKG = {"ver0_1": "test_hybrid_kem_otbn_prompt_ver0_1/otbn/mlkem768",
       "ver0_2": "test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768",
       "ver1_1": "test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768"}
API = {"ver0_1": "shake_out", "ver0_2": "xof_squeeze32", "ver1_1": "xof_squeeze32"}
# app 真实 ρ 的**字节串**（行里的 `.word 0x98c02e16 …` 是它的 LE 字面量）
RHO = bytes.fromhex("162ec098a900b12dd8fabbfb3fe8cb1dc4e8315f2af0d32f0017ae136e19f028")
Q = 3329


def sample_ntt_demand(stream: bytes):
    """FIPS 203 SampleNTT：返回 (消耗的 3 B 组数, 拒绝次数, 系数个数)"""
    coeffs, groups, rej, i = 0, 0, 0, 0
    while coeffs < 256 and i + 3 <= len(stream):
        d1 = stream[i] | ((stream[i + 1] & 0x0F) << 8)
        d2 = (stream[i + 1] >> 4) | (stream[i + 2] << 4)
        i += 3
        groups += 1
        for d in (d1, d2):
            if coeffs < 256:
                if d < Q:
                    coeffs += 1
                else:
                    rej += 1
    return groups, rej, coeffs


def measured_total(version: str, logs_dir: Path):
    for p in sorted((logs_dir / f"{version}_profiling").glob("*.json")):
        d = json.loads(p.read_text(encoding="utf-8"))
        for r in d.get("rows", []):
            if r.get("phase") == "keygen_poly_gen_matrix":
                return (r.get("calls") or {}).get(API[version]), r.get("cycles")
    return None, None


def build_sessions(nonce_order: str):
    """→ [(nonce, stream_bytes, 组数, 拒绝数, 需求块数)]"""
    out = []
    for i in range(3):
        for j in range(3):
            nonce = (i << 8) + j
            nc = bytes([j, i]) if nonce_order == "j,i" else bytes([i, j])
            stream = hashlib.shake_128(RHO + nc).digest(672 + 32)   # 多挤 1 块做余量
            groups, rej, coeffs = sample_ntt_demand(stream)
            need = -(-3 * groups // 32)                              # ceil(3N/32)
            out.append((nonce, stream, groups, rej, coeffs, need))
    return out


def emit(sessions, label_prefix="rejection_stream_"):
    lines = [".section .data", ".balign 32", "",
             ".globl rejection_stream_ptr", "rejection_stream_ptr:", "  .word 0", ""]
    nblk = 0
    for nonce, stream, _, _, _, need in sessions:
        lines += [".balign 32", f".globl {label_prefix}{nonce:04x}", f"{label_prefix}{nonce:04x}:"]
        for b in range(need):
            blk = stream[32 * b:32 * b + 32]
            for row in range(0, 32, 16):
                lines.append("  .byte " + ", ".join(f"0x{x:02x}" for x in blk[row:row + 16]))
            nblk += 1
    # 尾部补一块：线性游走的行会读到"载荷末尾恰好"的位置，补一块保证不越进 NOLOAD 区
    lines += ["", "/* 尾部补位块：仅供线性游走的桩行(若用)读到最后不越出已加载镜像 */",
              ".balign 32", ".globl rejection_stream_pad", "rejection_stream_pad:", "  .zero 32"]
    return "\n".join(lines) + "\n", nblk


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True, choices=sorted(PKG))
    ap.add_argument("--nonce-order", default="j,i", choices=["j,i", "i,j"])
    ap.add_argument("--logs-dir", default=str(REPO / "logs_hkem"))
    ap.add_argument("--write", action="store_true", help="写回包内流文件（默认只干跑校验）")
    args = ap.parse_args()

    sessions = build_sessions(args.nonce_order)
    total = sum(s[5] for s in sessions)
    meas, cyc = measured_total(args.version, Path(args.logs_dir))

    print(f"### {args.version}  非序 {args.nonce_order}   ρ={RHO.hex()[:16]}…")
    print(f"{'会话(nonce)':<16}{'消耗3B组':>9}{'拒绝':>6}{'系数':>6}{'需求块':>7}")
    for nonce, _, groups, rej, coeffs, need in sessions:
        print(f"  {nonce:#06x}       {groups:>8}{rej:>6}{coeffs:>6}{need:>7}")
    print(f"{'合计':<16}{'':>9}{'':>6}{'':>6}{total:>7}")
    print(f"\napp 实测动态 {API[args.version]} 次数 = {meas}   （整 app 该阶段 cycles={cyc:,}）")

    ok = meas is not None and total == meas
    print(f"判据：Σ需求块 {total} == app 实测 {meas} → {'✓ 一致（ρ、nonce 序、分块模型全对）' if ok else '✗ 不一致 ⇒ 模型或数据源有问题，先别写'}")
    if not ok:
        return 1

    if args.write:
        p = REPO / PKG[args.version] / "keygen_poly_gen_matrix_rejection_streams.s"
        text, nblk = emit(sessions)
        if p.exists():
            bak = p.with_suffix(".bak.s")
            p.replace(bak)
            print(f"[备份] {bak}")
        p.write_text(text, encoding="utf-8")
        print(f"[写] {p}：{nblk} 块（每会话按需求）+ 1 块尾部补位，共 {nblk + 1} 块 × 32 B")
    else:
        print("（干跑模式：未写文件；确认 ✓ 后加 --write）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
