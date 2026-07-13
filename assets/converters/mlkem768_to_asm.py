"""
ML-KEM-768 已知数据 → 汇编测试向量（多组）

输入: ../ML-KEM-768 (多组 d, z, pk, sk, m, ct, ss，空行分隔)

用法: cd assets/converters && python3 mlkem768_to_asm.py [count]
输出: ../output/mlkem768/test_NNN/ 每组一个目录
"""

import os, sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.dirname(SCRIPT_DIR)
DATA_FILE = os.path.join(ASSETS_DIR, "ML-KEM-768")
OUT_BASE  = os.path.join(ASSETS_DIR, "output", "mlkem768")


def parse_all(path: str) -> list[dict]:
    """解析多组 key=value 格式文件，空行分隔每组"""
    groups = []
    cur = {}
    for line in open(path):
        line = line.strip()
        if not line:
            if cur:
                groups.append(cur)
                cur = {}
            continue
        if line.startswith("#"):
            continue
        if "=" in line:
            k, v = line.split("=", 1)
            cur[k.strip()] = v.strip()
    if cur:
        groups.append(cur)
    return groups


def hw(h: str) -> list[str]:
    """hex → 32-bit little-endian .word"""
    d = bytes.fromhex(h)
    w = []
    for i in range(0, len(d), 4):
        c = d[i:i+4]
        if len(c) < 4:
            c += b'\x00' * (4 - len(c))
        w.append(f"0x{int.from_bytes(c, 'little'):08x}")
    return w


def dexp_hex(h: str) -> str:
    """hex → DMEM byte order (.dexp format)"""
    return bytes.fromhex(h)[::-1].hex()


def write_set(ddir: str, data: dict, idx: int):
    d_hex = data["d"]
    z_hex = data["z"]
    pk_hex = data["pk"]
    sk_hex = data["sk"]
    m_hex = data.get("m", "")
    ct_hex = data.get("ct", "")
    ss_hex = data.get("ss", "")
    c_hex = data.get("c", ct_hex)

    os.makedirs(ddir, exist_ok=True)

    # ── keypair ──
    coins_kp = d_hex + z_hex
    with open(os.path.join(ddir, "keypair.s"), "w") as f:
        f.write(f"/* set {idx}: d={d_hex[:16]}... z={z_hex[:16]}... */\n")
        f.write(f"/* ek={len(pk_hex)//2}B dk={len(sk_hex)//2}B */\n\n")
        f.write(".globl coins\ncoins:\n")
        for w in hw(coins_kp): f.write(f"    .word {w}\n")
        f.write("\n.globl ek\nek:\n")
        for w in hw(pk_hex): f.write(f"    .word {w}\n")
        f.write("\n.globl dk\ndk:\n")
        for w in hw(sk_hex): f.write(f"    .word {w}\n")
    with open(os.path.join(ddir, "keypair.dexp"), "w") as f:
        f.write(f"ek: {dexp_hex(pk_hex)}\n")
        f.write(f"dk: {dexp_hex(sk_hex)}\n")

    # ── encap ──
    if m_hex:
        with open(os.path.join(ddir, "encap.s"), "w") as f:
            f.write(f"/* set {idx}: m={m_hex[:16]}... */\n")
            f.write(f"/* ek={len(pk_hex)//2}B ct={len(ct_hex)//2}B ss={len(ss_hex)//2}B */\n\n")
            f.write(".globl coins\ncoins:\n")
            for w in hw(m_hex): f.write(f"    .word {w}\n")
            f.write("\n.globl ek\nek:\n")
            for w in hw(pk_hex): f.write(f"    .word {w}\n")
            f.write("\n.globl ct\nct:\n")
            for w in hw(ct_hex): f.write(f"    .word {w}\n")
            f.write("\n.globl ss\nss:\n")
            for w in hw(ss_hex): f.write(f"    .word {w}\n")
        with open(os.path.join(ddir, "encap.dexp"), "w") as f:
            f.write(f"ct: {dexp_hex(ct_hex)}\n")
            f.write(f"ss: {dexp_hex(ss_hex)}\n")

    # ── decap ──
    if c_hex:
        with open(os.path.join(ddir, "decap.s"), "w") as f:
            f.write(f"/* set {idx}: ct={len(c_hex)//2}B dk={len(sk_hex)//2}B ss={len(ss_hex)//2}B */\n\n")
            f.write(".globl ct\nct:\n")
            for w in hw(c_hex): f.write(f"    .word {w}\n")
            f.write("\n.globl dk\ndk:\n")
            for w in hw(sk_hex): f.write(f"    .word {w}\n")
            f.write("\n.globl ss\nss:\n")
            for w in hw(ss_hex): f.write(f"    .word {w}\n")
        with open(os.path.join(ddir, "decap.dexp"), "w") as f:
            f.write(f"ss: {dexp_hex(ss_hex)}\n")


def main():
    groups = parse_all(DATA_FILE)
    print(f"Parsed {len(groups)} sets")

    count_n = int(sys.argv[1]) if len(sys.argv) > 1 else len(groups)
    selected = groups[:count_n] if count_n > 0 else groups

    for i, data in enumerate(selected):
        ddir = os.path.join(OUT_BASE, f"test_{i:03d}")
        write_set(ddir, data, i)

    print(f"Output: {OUT_BASE}/test_XXX/ ({len(selected)} directories)")


if __name__ == "__main__":
    main()
