"""
PQCkemKAT_2400.rsp → 汇编测试数据转换器

NIST SP 800-90A AES-256-CTR DRBG: seed → coins

输出: ../output/rsp/count_NNN/ 每个 count 一个目录，包含:
        keypair.s    — coins + expected pk/sk
        encap.s      — coins + expected ct/ss
        decap.s      — ct + expected ss

用法: cd assets/converters && python3 rsp_to_asm.py [count]
"""

import os, sys
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS_DIR = os.path.dirname(SCRIPT_DIR)
RSP_FILE  = os.path.join(ASSETS_DIR, "PQCkemKAT_2400.rsp")
OUT_BASE  = os.path.join(ASSETS_DIR, "output", "rsp")

from Crypto.Cipher import AES

def _xor(a, b): return bytes(x ^ y for x, y in zip(a, b))

class AES256_CTR_DRBG:
    def __init__(self, seed=None):
        self.key, self.V = bytes(32), bytes(16)
        if seed is None: seed = os.urandom(48)
        elif len(seed) != 48: raise ValueError(f"seed must be 48B")
        self.__update(_xor(seed, bytes(48)))
        self.reseed_ctr = 1
    def __inc(self):
        self.V = ((int.from_bytes(self.V, "big") + 1) % 2**128).to_bytes(16, "big")
    def __update(self, data):
        tmp, c = b"", AES.new(self.key, AES.MODE_ECB)
        while len(tmp) != 48: self.__inc(); tmp += c.encrypt(self.V)
        tmp = _xor(tmp[:48], data)
        self.key, self.V = tmp[:32], tmp[32:]
    def random_bytes(self, n):
        tmp, c = b"", AES.new(self.key, AES.MODE_ECB)
        while len(tmp) < n: self.__inc(); tmp += c.encrypt(self.V)
        out = tmp[:n]; self.__update(bytes(48)); self.reseed_ctr += 1
        return out


def parse(path):
    vecs, cur = [], {}
    for line in open(path):
        line = line.strip()
        if not line: continue
        if "=" in line:
            k, v = line.split("=", 1)
            cur[k.strip()] = v.strip()
            if k.strip() == "ss": vecs.append(dict(cur))
    return vecs


def hw(h):
    data = bytes.fromhex(h)
    w = []
    for i in range(0, len(data), 4):
        c = data[i:i+4]
        if len(c) < 4: c += b'\x00' * (4 - len(c))
        w.append(f"0x{int.from_bytes(c, 'little'):08x}")
    return w


def main():
    count_n = int(sys.argv[1]) if len(sys.argv) > 1 else 5
    vectors = parse(RSP_FILE)
    print(f"Parsed {len(vectors)} vectors")

    if count_n < 0 or count_n > len(vectors):
        selected = list(enumerate(vectors))
    else:
        selected = [(i, vectors[i]) for i in range(count_n)]

    for idx, v in selected:
        cnt = int(v["count"])
        ddir = os.path.join(OUT_BASE, f"count_{cnt:03d}")
        os.makedirs(ddir, exist_ok=True)

        seed = bytes.fromhex(v["seed"])
        drbg = AES256_CTR_DRBG(seed=seed)
        z = drbg.random_bytes(32)  # ML-KEM KAT: z first, then d
        d = drbg.random_bytes(32)
        m = drbg.random_bytes(32)

        # keypair.s
        with open(os.path.join(ddir, "keypair.s"), "w") as f:
            f.write(f"/* RSP count={cnt} seed={v['seed'][:32]}... */\n")
            f.write(f"/* d={d.hex()[:16]}... z={z.hex()[:16]}... */\n")
            f.write(f"/* ek={len(v['pk'])//2}B dk={len(v['sk'])//2}B */\n\n")
            f.write(".globl coins\ncoins:\n")
            for w in hw((d + z).hex()): f.write(f"    .word {w}\n")
            f.write("\n.globl ek\nek:\n")
            for w in hw(v["pk"]): f.write(f"    .word {w}\n")
            f.write("\n.globl dk\ndk:\n")
            for w in hw(v["sk"]): f.write(f"    .word {w}\n")

        # keypair.dexp  (.dexp needs DMEM byte order = reversed .rsp big-endian)
        with open(os.path.join(ddir, "keypair.dexp"), "w") as f:
            f.write(f"ek: {bytes.fromhex(v['pk'])[::-1].hex()}\n")
            f.write(f"dk: {bytes.fromhex(v['sk'])[::-1].hex()}\n")

        # encap.s
        with open(os.path.join(ddir, "encap.s"), "w") as f:
            f.write(f"/* RSP count={cnt} m={m.hex()[:16]}... */\n")
            f.write(f"/* ek={len(v['pk'])//2}B ct={len(v['ct'])//2}B ss={v['ss']} */\n\n")
            f.write(".globl coins\ncoins:\n")
            for w in hw(m.hex()): f.write(f"    .word {w}\n")
            f.write("\n.globl ek\nek:\n")
            for w in hw(v["pk"]): f.write(f"    .word {w}\n")
            f.write("\n.globl ct\nct:\n")
            for w in hw(v["ct"]): f.write(f"    .word {w}\n")
            f.write("\n.globl ss\nss:\n")
            for w in hw(v["ss"]): f.write(f"    .word {w}\n")

        # encap.dexp
        with open(os.path.join(ddir, "encap.dexp"), "w") as f:
            f.write(f"ct: {bytes.fromhex(v['ct'])[::-1].hex()}\n")
            f.write(f"ss: {bytes.fromhex(v['ss'])[::-1].hex()}\n")

        # decap.s
        with open(os.path.join(ddir, "decap.s"), "w") as f:
            f.write(f"/* RSP count={cnt} */\n")
            f.write(f"/* ct={len(v['ct'])//2}B dk={len(v['sk'])//2}B ss={v['ss']} */\n\n")
            f.write(".globl ct\nct:\n")
            for w in hw(v["ct"]): f.write(f"    .word {w}\n")
            f.write("\n.globl dk\ndk:\n")
            for w in hw(v["sk"]): f.write(f"    .word {w}\n")
            f.write("\n.globl ss\nss:\n")
            for w in hw(v["ss"]): f.write(f"    .word {w}\n")

        # decap.dexp
        with open(os.path.join(ddir, "decap.dexp"), "w") as f:
            f.write(f"ss: {bytes.fromhex(v['ss'])[::-1].hex()}\n")

    print(f"Output: {OUT_BASE}/count_XXX/ (keypair.s, encap.s, decap.s) × {len(selected)}")


if __name__ == "__main__":
    main()
