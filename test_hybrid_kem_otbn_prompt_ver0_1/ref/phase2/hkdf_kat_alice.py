"""hkdf_kat_alice.py — Phase 2 Alice HKDF KAT generator.

IKM = len_cls(2B) || ss_e(32B) || len_pqc(2B) || ss_m(32B) || ctx || sid
PRK = HMAC-SHA3-256(salt, IKM)
OKM = HKDF-Expand(PRK, info="", L)   (Alice KEM output, == Bob OKM)

Edit ss_e/ss_m at the top, re-run to update KAT values.
"""

import hashlib
import hmac
import struct
import sys

# ============ Phase 2 Alice Parameters ============

# ss_e from Alice ECDH: d_alice * Q_bob
ss_e = bytes.fromhex(
    "064cf1e6c03cfb667b49502837d4e73a"
    "a54c53d1884ef3925e6bf9d09a1c9926")
# ss_m from ML-KEM encap
ss_m = bytes.fromhex(
    "ac865f839fef1bf3d528dd7504bed2f6"
    "4b5502b0fa81d1c32763658e4aac5037")

salt   = bytes(range(32))                           # 0x00..0x1f
info   = bytes(range(1, 17))                        # kInfo[16] = 0x01..0x10
ctx    = b"HybridKEM-v1-context-0123456789A"       # kCtx[32]
sid    = b"Session-042-run-XYZ9876543210fed"       # kSid[32]
okm_len = int(sys.argv[1]) if len(sys.argv) > 1 else 32

# ============ IKM construction ============

def be16(val):
    return struct.pack('>H', val)

def build_ikm(ss_e, ss_m, ctx=b"", sid=b""):
    ikm  = be16(32) + ss_e
    ikm += be16(32) + ss_m
    ikm += ctx
    ikm += sid
    return ikm

# ============ HKDF-SHA3-256 ============

def hkdf_sha3_256(ss_e, ss_m, salt, info, ctx, sid, L):
    ikm = build_ikm(ss_e, ss_m, ctx, sid)
    prk = hmac.new(salt, ikm, 'sha3-256').digest()
    okm = b''
    T_prev = b''
    for i in range(1, (L + 31) // 32 + 1):
        T_i = hmac.new(prk, T_prev + info + bytes([i]), 'sha3-256').digest()
        okm += T_i
        T_prev = T_i
    return prk, okm[:L]

ikm = build_ikm(ss_e, ss_m, ctx, sid)
prk, okm = hkdf_sha3_256(ss_e, ss_m, salt, info, ctx, sid, okm_len)

# ============ Output ============

def bytes_to_c(name, data):
    lines = [f"static const uint8_t {name}[{len(data)}] = {{"]
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        lines.append("    " + ", ".join(f"0x{b:02x}" for b in chunk) + ",")
    lines.append("};")
    return "\n".join(lines)

print(f"// HKDF-SHA3-256 (okm_len={okm_len})")
print(f"// salt  = {salt.hex() if any(salt) else '(all zero)'}")
print(f"// info  = '' (KEM layer: no role binding, upper layer responsibility)")
print(f"// ctx   = {ctx.hex() if ctx else '(empty)'}")
print(f"// sid   = {sid.hex() if sid else '(empty)'}")
print(f"// ss_e  = {ss_e.hex()}")
print(f"// ss_m  = {ss_m.hex()}")
print(f"// IKM   = ({len(ikm)}B) {ikm.hex()}")
print(f"// PRK   = {prk.hex()}")
print(f"// OKM   = {okm.hex()} (Alice == Bob, standard KEM correctness)")
print()
print(bytes_to_c("kExpectedOkm", okm))
print()
print(f"// .dexp:  {okm[::-1].hex()}")
