"""kmac_kdf_kat.py — KMAC-KDF KAT generator for Hybrid KEM (ver0 software).

KMAC-KDF (NIST SP 800-108r1):
  FixedInfo = Counter(4B) || Label || 0x00 || Context || L_bits(4B)
  OKM = SHAKE256(KDK || FixedInfo, L)

Where KDK = ss_e(32B) || ss_m(32B) for standalone KDF test.
Pure software SHAKE via sha3_shake.s — output matches ver1 hardware KMAC.

Usage:
  python kmac_kdf_kat.py [okm_len]
"""

import hashlib
import struct
import sys

# ============ Parameters ============

ss_e = bytes.fromhex(
    "5f33d746a326640a739a9490ec15c103"
    "72869f3de675b2e85742271d18c9eb82")
ss_m = bytes.fromhex(
    "3750ac4a8e656327c3d181fab002554b"
    "f6d2be0475dd28d5f31bef9f835f86ac")

kdk = ss_e + ss_m  # 64B

ctx    = b"HybridKEM-v1-context-0123456789A"       # kCtx[32]
label  = b""                                        # KEM layer: no label
okm_len = int(sys.argv[1]) if len(sys.argv) > 1 else 32

# ============ FixedInfo construction (NIST SP 800-108r1) ============

def be32(val):
    return struct.pack('>I', val)

counter = be32(0x00000001)
separator = b'\x00'
L_bits = be32(okm_len * 8)

fixed_info = counter + label + separator + ctx + L_bits

# ============ KMAC-KDF ============

# SHAKE256(KDK || FixedInfo, L)
shake = hashlib.shake_256()
shake.update(kdk)
shake.update(fixed_info)
okm = shake.digest(okm_len)

# ============ Output ============

def bytes_to_c(name, data):
    lines = [f"static const uint8_t {name}[{len(data)}] = {{"]
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        lines.append("    " + ", ".join(f"0x{b:02x}" for b in chunk) + ",")
    lines.append("};")
    return "\n".join(lines)

print(f"// KMAC-KDF (okm_len={okm_len})")
print(f"// KDK = ss_e(32B) || ss_m(32B)")
print(f"// ss_e = {ss_e.hex()}")
print(f"// ss_m = {ss_m.hex()}")
print(f"// label = '' (KEM layer: empty, no role binding)")
print(f"// ctx  = {ctx.hex()}")
print(f"// FixedInfo ({len(fixed_info)}B) = {fixed_info.hex()}")
print(f"// OKM = {okm.hex()} (Alice == Bob, standard KEM correctness)")
print()
print(bytes_to_c("kExpectedOkm", okm))
print()
print(f"// .dexp (LE reversed): {okm[::-1].hex()}")
