"""kmac_kdf_kat_alice.py — Phase 2 Alice KMAC-KDF KAT generator.

KMAC-KDF (NIST SP 800-108r1):
  FixedInfo = Counter(4B) || Label || 0x00 || Context || [L]8
  OKM = SHAKE128(KDK || FixedInfo, L)

Where KDK = ss_e(32B) || ss_m(32B).
Alice OKM == Bob OKM (standard KEM correctness).
"""

import hashlib
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

kdk = ss_e + ss_m  # 64B

ctx    = b"HybridKEM-v1-context-0123456789A"
label  = b""
okm_len = int(sys.argv[1]) if len(sys.argv) > 1 else 32

# ============ FixedInfo ============

def be32(val):
    return struct.pack('>I', val)

counter = be32(0x00000001)
L_bits = be32(okm_len * 8)
fixed_info = counter + label + b'\x00' + ctx + L_bits

# ============ KMAC-KDF ============

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

print(f"// KMAC-KDF Phase2 Alice (okm_len={okm_len})")
print(f"// KDK = ss_e || ss_m (64B)")
print(f"// ss_e = {ss_e.hex()}")
print(f"// ss_m = {ss_m.hex()}")
print(f"// FixedInfo ({len(fixed_info)}B) = {fixed_info.hex()}")
print(f"// OKM = {okm.hex()} (Alice == Bob, standard KEM correctness)")
print()
print(bytes_to_c("kExpectedOkm", okm))
print()
print(f"// .dexp: {okm[::-1].hex()}")
