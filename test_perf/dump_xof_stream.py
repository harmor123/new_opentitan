#!/usr/bin/env python3
"""抓取 app 真实消费的 XOF 流（供桩法"拒绝采样隔离"行使用）。

为什么不用 Python 复算：KMAC 硬件 `xof_squeeze32` 返回的字节序与标准 SHAKE128
实现**不一致**（2026-09-20 实测：拿 app 真实 ρ 用 `hashlib.shake_128(rho||j||i)`
复算，与 ver0_2 现有流文件的首块逐字节对不上 ✗）。所以只能**从 ISS 里原样抓**：
跑 app，钩住每次 `jal <hook_sym>`（= 采样函数入口），此时 `_expand_buf` 里就是
该会话刚 squeeze 出来的 672 字节 —— 直接按消费顺序落盘，零假设。

产出：一个 `.s` 数据文件，格式与 `keygen_poly_gen_matrix_rejection_streams.s` 相同
（`rejection_stream_ptr` + 每块一个 `rejection_stream_NNNN` 标签 + 32 B `.byte`），
并做一次自检：把抓到的字节按 FIPS 203 SampleNTT 跑一遍，报告每会话的拒绝次数。

用法（Linux）:
    python3 test_perf/dump_xof_stream.py --target //<pkg>:mlkem768_keypair \\
        --hook sample_ntt_poly --buf _expand_buf --sessions 9 --out <流文件路径>
"""
import argparse
import json
import sys
from itertools import cycle
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "hw/ip/otbn/dv/otbnsim"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from sim.load_elf import load_elf                  # noqa: E402
from sim.standalonesim import StandaloneSim        # noqa: E402
from elftools.elf.elffile import ELFFile           # noqa: E402

import harness as H                                # noqa: E402

Q = 3329


def dmem_sym(elf_path: str, name: str):
    """取符号在 **DMEM** 里的地址（OTBN 是哈佛结构，.text/.data 地址会重叠 ⇒
    必须按所在 section 区分；这里只要 .data/.scratchpad 里的）。"""
    with open(elf_path, "rb") as f:
        elf = ELFFile(f)
        want = {}
        for i, sec in enumerate(elf.iter_sections()):
            if sec.name in (".data", ".scratchpad", ".bss"):
                want[i] = sec.name
        for s in elf.get_section_by_name(".symtab").iter_symbols():
            if s.name == name and s.entry.st_shndx in want:
                return s.entry.st_value
    return None


def text_sym(elf_path: str, name: str):
    with open(elf_path, "rb") as f:
        elf = ELFFile(f)
        for i, sec in enumerate(elf.iter_sections()):
            if sec.name == ".text":
                ndx = i
                break
        for s in elf.get_section_by_name(".symtab").iter_symbols():
            if s.name == name and s.entry.st_shndx == ndx:
                return s.entry.st_value
    return None


def read_dmem(sim, addr: int, n: int) -> bytes:
    out = bytearray()
    for k in range(n // 4):
        val = sim.state.dmem.data[(addr + 4 * k) // 4][0]
        out += (val & 0xFFFFFFFF).to_bytes(4, "little")
    return bytes(out)


def sample_ntt(b: bytes):
    """FIPS 203 SampleNTT：返回 (系数列表, 消耗的 3 字节块数, 拒绝次数)"""
    coeffs, i, rej = [], 0, 0
    while len(coeffs) < 256 and i + 3 <= len(b):
        d1 = b[i] | ((b[i + 1] & 0x0F) << 8)
        d2 = (b[i + 1] >> 4) | (b[i + 2] << 4)
        i += 3
        for d in (d1, d2):
            if len(coeffs) < 256:
                if d < Q:
                    coeffs.append(d)
                else:
                    rej += 1
    return coeffs, i // 3, rej


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--target", required=True)
    ap.add_argument("--hook", default="sample_ntt_poly")
    ap.add_argument("--buf", default="_expand_buf")
    ap.add_argument("--buflen", type=int, default=672)
    ap.add_argument("--sessions", type=int, default=9)
    ap.add_argument("--out", required=True)
    ap.add_argument("--label-prefix", default="rejection_stream_")
    args = ap.parse_args()

    H.bazel_build([args.target])
    elf = H.bazel_elf(args.target)
    hook = text_sym(elf, args.hook)
    buf = dmem_sym(elf, args.buf)
    if hook is None or buf is None:
        raise SystemExit(f"找不到符号：hook={args.hook}@{hook} buf={args.buf}@{buf}")

    sim = StandaloneSim()
    load_elf(sim, elf)
    sim.state.ext_regs.commit()
    sim.start(collect_stats=True)
    # 下面三块必须与 StandaloneSim.run() 一致，否则自建的单步循环跑不起来：
    #   ① 跳过初始 secure wipe（否则 sim.step 里的 assert 直接炸）
    #   ② 允许 wfi 立即返回
    #   ③ 主机服务：喂 RND/URND（ver1_1 是掩码 KMAC，不喂会一直等）
    sim.state.complete_init_sec_wipe()
    sim.state.wfi_enabled = True
    sim.state.wfi_auto_resume = True
    rnd = cycle([0xAAAAAAAA_99999999_AAAAAAAA_99999999_AAAAAAAA_99999999_AAAAAAAA_99999999,
                 0xCCCCCCCC_BBBBBBBB_CCCCCCCC_BBBBBBBB_CCCCCCCC_BBBBBBBB_CCCCCCCC_BBBBBBBB])
    urnd_seeds = [0x11111111, 0x22222222, 0x33333333, 0x44444444, 0x55555555, 0x66666666]
    k_urnd = 0

    caps, guards = [], []
    guard = 0
    prev_pc = None
    while len(caps) < args.sessions and guard < 20_000_000:
        if sim.state.ext_regs.read("RND_REQ", True):
            sim.state.wsrs.RND.set_unsigned(next(rnd), False, False)
        if sim.state.wsrs.URND.requesting:
            sim.state.wsrs.URND.set_seed(urnd_seeds[k_urnd])
            k_urnd = (k_urnd + 1) % len(urnd_seeds)
            if k_urnd == 0:
                sim.state.wsrs.URND.reseed_done = True
        sim.step(False)
        guard += 1
        # ⚠ 必须判"**跳入**"（prev_pc != hook）：跳转/调用后 pc 会在目标地址停留两拍
        #   （取指停滞），只判 pc == hook 会把同一次调用抓两次 ⇒ 9 次抓取只覆盖 5 个会话
        #   （2026-09-20 实测指纹：会话 0≡1、2≡3、4≡5、6≡7 ⇒ 正是这个 bug 的特征）
        pc = sim.state.pc
        if pc == hook and prev_pc != hook:
            caps.append(read_dmem(sim, buf, args.buflen))
            guards.append(guard)
        prev_pc = pc

    if len(caps) < args.sessions:
        raise SystemExit(f"只抓到 {len(caps)}/{args.sessions} 个会话（guard={guard}）")

    print(f"抓到 {len(caps)} 个会话 × {args.buflen} B（hook={args.hook}@{hook:#x}, buf={args.buf}@{buf:#x}）")
    # 自证 1：抓取间隔（相邻两次 hook 之间的步数）。若某间隔 ≈ 0 ⇒ 同一次调用被钩了两次
    gaps = [guards[0]] + [guards[i] - guards[i-1] for i in range(1, len(guards))]
    print("抓取间隔(步):", gaps)
    # 自证 2：每会话前 8 B 指纹 + 重复检测（不同 nonce 的输出不可能逐位相同）
    print("会话指纹(前 8 B):")
    dups = []
    for k, c in enumerate(caps):
        i, j = k // 3, k % 3
        for m in range(k):
            if caps[m] == c:
                dups.append((k, m))
        print(f"  会话 {k} (i={i},j={j},nonce=0x{(i<<8)+j:04x}): {c[:8].hex()}…")
    if dups:
        print(f"⚠⚠ 有 {len(dups)} 对会话逐字节相同 {dups} ⇒ **抓取有假**（正常情况不可能相同）")
    else:
        print("✓ 9 个会话两两不同")
    print("自检（FIPS 203 SampleNTT on 抓到的字节）：")
    for k, c in enumerate(caps):
        coeffs, used, rej = sample_ntt(c)
        ok = "✓" if len(coeffs) == 256 else "✗ 采样不足"
        print(f"  会话 {k}: 消耗 {used} 块(每块3B) 拒绝 {rej} 次 → 系数 {len(coeffs)} {ok}")

    text, nblk = emit_stream(caps, args.label_prefix)
    out = Path(args.out)
    if out.exists():
        bak = out.with_suffix(".bak.s")
        bak.write_text(out.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"[备份] {bak}（旧流文件，供回退）")
    out.write_text(text, encoding="utf-8")
    print(f"\n[写] {out}：{nblk} 块 × 32 B = {nblk*32} B（{len(caps)} 个会话，标签按 nonce 命名）")
    return 0


def emit_stream(caps, label_prefix="rejection_stream_"):
    """把抓到的会话字节渲染成流文件文本。

    布局与 ver0_2 的流文件一致：`rejection_stream_ptr` + 每会话首块一个
    `<prefix><nonce:04x>` 标签（nonce = (i<<8)+j，i 外 j 内），块连续排列。
    """
    lines = [".section .data", ".balign 32", "",
             ".globl rejection_stream_ptr", "rejection_stream_ptr:", "  .word 0", ""]
    idx = 0
    for k, c in enumerate(caps):
        i, j = k // 3, k % 3                  # app 是 i 外 j 内
        nonce = (i << 8) + j
        first = True
        for off in range(0, len(c), 32):
            blk = c[off:off + 32]
            lines.append(".balign 32")
            if first:
                lines += [f".globl {label_prefix}{nonce:04x}", f"{label_prefix}{nonce:04x}:"]
                first = False
            for row in range(0, 32, 16):
                lines.append("  .byte " + ", ".join(f"0x{x:02x}" for x in blk[row:row + 16]))
            idx += 1
    return "\n".join(lines) + "\n", idx


if __name__ == "__main__":
    raise SystemExit(main())
