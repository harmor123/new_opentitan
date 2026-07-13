"""
ML-KEM-768 NIST ACVP → 汇编测试数据转换器

输入: ../ML-KEM-keyGen-FIPS203/{prompt,expectedResults}.json
      ../ML-KEM-encapDecap-FIPS203/{prompt,expectedResults}.json

输出: ../output/kat/tcId_NNN/ 每个 tcId 一个目录，包含:
        keypair.s    — coins + expected pk/sk
        encap.s      — coins + expected ct/ss
        decap.s      — input ct + expected ss

用法: cd assets/converters && python3 kat_to_asm.py [count]
"""

import json, os, sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.dirname(SCRIPT_DIR)

KG_PROMPT   = os.path.join(ASSETS_DIR, "ML-KEM-keyGen-FIPS203", "prompt.json")
KG_EXPECTED = os.path.join(ASSETS_DIR, "ML-KEM-keyGen-FIPS203", "expectedResults.json")
ED_PROMPT   = os.path.join(ASSETS_DIR, "ML-KEM-encapDecap-FIPS203", "prompt.json")
ED_EXPECTED = os.path.join(ASSETS_DIR, "ML-KEM-encapDecap-FIPS203", "expectedResults.json")
OUT_BASE    = os.path.join(ASSETS_DIR, "output", "kat")


def load_json(p): return json.load(open(p))

def get_by_param(d, ps):
    for tg in d["testGroups"]:
        if tg.get("parameterSet") == ps: return tg["tests"]
    return []

def get_by_param_func(d, ps, fn):
    for tg in d["testGroups"]:
        if tg.get("parameterSet") == ps and tg.get("function") == fn: return tg["tests"]
    return []

def get_by_tgid(d, tid):
    for tg in d["testGroups"]:
        if tg["tgId"] == tid: return tg["tests"]
    return []

def hw(h: str) -> list[str]:
    data = bytes.fromhex(h)
    w = []
    for i in range(0, len(data), 4):
        c = data[i:i+4]
        if len(c) < 4: c += b'\x00' * (4 - len(c))
        w.append(f"0x{int.from_bytes(c, 'little'):08x}")
    return w


def main():
    PARAM = "ML-KEM-768"
    kg_t  = get_by_param(load_json(KG_PROMPT), PARAM)
    kg_e  = {t["tcId"]: t for t in get_by_tgid(load_json(KG_EXPECTED), 2)}
    enc_t = get_by_param_func(load_json(ED_PROMPT), PARAM, "encapsulation")
    dec_t = get_by_param_func(load_json(ED_PROMPT), PARAM, "decapsulation")
    enc_e = {t["tcId"]: t for t in get_by_tgid(load_json(ED_EXPECTED), 2)}
    dec_e = {t["tcId"]: t for t in get_by_tgid(load_json(ED_EXPECTED), 5)}

    kg_m  = {t["tcId"]: t for t in kg_t}
    enc_m = {t["tcId"]: t for t in enc_t}
    dec_m = {t["tcId"]: t for t in dec_t}

    common = sorted(tc for tc in kg_m if tc in enc_m and (tc + 60) in dec_m
                    and tc in kg_e and tc in enc_e and (tc + 60) in dec_e)
    print(f"Matched {len(common)} triples")

    count_n = int(sys.argv[1]) if len(sys.argv) > 1 else 5
    selected = common[:count_n] if count_n > 0 else common

    for tc in selected:
        ddir = os.path.join(OUT_BASE, f"tcId_{tc:03d}")
        os.makedirs(ddir, exist_ok=True)

        d_hex = kg_m[tc]["d"]
        z_hex = kg_m[tc]["z"]
        m_hex = enc_m[tc]["m"]
        ct_h  = enc_e[tc]["c"]
        ss_h  = enc_e[tc]["k"]
        c_h   = dec_m[tc + 60]["c"]
        ss2_h = dec_e[tc + 60]["k"]

        # keypair.s
        with open(os.path.join(ddir, "keypair.s"), "w") as f:
            f.write(f"/* KAT tcId={tc} keypair: d={d_hex[:16]}... z={z_hex[:16]}... */\n")
            f.write(f"/* ek={len(kg_e[tc]['ek'])//2}B dk={len(kg_e[tc]['dk'])//2}B */\n\n")
            f.write(".globl coins\ncoins:\n")
            for w in hw(d_hex + z_hex): f.write(f"    .word {w}\n")
            f.write("\n.globl ek\nek:\n")
            for w in hw(kg_e[tc]["ek"]): f.write(f"    .word {w}\n")
            f.write("\n.globl dk\ndk:\n")
            for w in hw(kg_e[tc]["dk"]): f.write(f"    .word {w}\n")

        # keypair.dexp  (.dexp = DMEM byte order = reversed big-endian)
        with open(os.path.join(ddir, "keypair.dexp"), "w") as f:
            f.write(f"ek: {bytes.fromhex(kg_e[tc]['ek'])[::-1].hex()}\n")
            f.write(f"dk: {bytes.fromhex(kg_e[tc]['dk'])[::-1].hex()}\n")

        # encap.s  (ACVP encap uses its OWN ek from prompt, NOT keypair's ek)
        with open(os.path.join(ddir, "encap.s"), "w") as f:
            f.write(f"/* KAT tcId={tc} encap: m={m_hex[:16]}... */\n")
            f.write(f"/* ek={len(enc_m[tc]['ek'])//2}B ct={len(ct_h)//2}B ss={ss_h} */\n\n")
            f.write(".globl coins\ncoins:\n")
            for w in hw(m_hex): f.write(f"    .word {w}\n")
            f.write("\n.globl ek\nek:\n")
            for w in hw(enc_m[tc]["ek"]): f.write(f"    .word {w}\n")
            f.write("\n.globl ct\nct:\n")
            for w in hw(ct_h): f.write(f"    .word {w}\n")
            f.write("\n.globl ss\nss:\n")
            for w in hw(ss_h): f.write(f"    .word {w}\n")

        # encap.dexp
        with open(os.path.join(ddir, "encap.dexp"), "w") as f:
            f.write(f"ct: {bytes.fromhex(ct_h)[::-1].hex()}\n")
            f.write(f"ss: {bytes.fromhex(ss_h)[::-1].hex()}\n")

        # decap.s  (NOTE: ACVP decap prompt has no dk field.
        # dk is a tester-provided input, not recorded in prompt.json.
        # Using keypair expected dk — NOT guaranteed to match decap ct.)
        with open(os.path.join(ddir, "decap.s"), "w") as f:
            f.write(f"/* KAT tcId={tc} decap (WARNING: dk from keypair, may not match ct) */\n")
            f.write(f"/* ct={len(c_h)//2}B dk={len(kg_e[tc]['dk'])//2}B ss={ss2_h} */\n\n")
            f.write(".globl ct\nct:\n")
            for w in hw(c_h): f.write(f"    .word {w}\n")
            f.write("\n.globl dk\ndk:\n")
            for w in hw(kg_e[tc]["dk"]): f.write(f"    .word {w}\n")
            f.write("\n.globl ss\nss:\n")
            for w in hw(ss2_h): f.write(f"    .word {w}\n")

        # decap.dexp
        with open(os.path.join(ddir, "decap.dexp"), "w") as f:
            f.write(f"ss: {bytes.fromhex(ss2_h)[::-1].hex()}\n")


if __name__ == "__main__":
    main()
