"""kmac_kdf_dexp.py — KMAC-KDF .dexp + .word generator for test wrapper.

KMAC-KDF (NIST SP 800-108r1):
  FixedInfo = Counter(4B) || Label || 0x00 || Context || [L]8
  OKM = SHAKE256(KDK || FixedInfo, L)

Usage:
  python kmac_kdf_dexp.py [okm_len]
"""

import hashlib
import struct
import sys

# ============ Test vectors ============

ss_e = bytes.fromhex(
    "5f33d746a326640a739a9490ec15c103"
    "72869f3de675b2e85742271d18c9eb82")
ss_m = bytes.fromhex(
    "3750ac4a8e656327c3d181fab002554b"
    "f6d2be0475dd28d5f31bef9f835f86ac")

kdk = ss_e + ss_m  # 64B
ctx  = b"HybridKEM-v1-context-0123456789A"
label = b""
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

# ============ Helpers ============

def bytes_to_words_le(data):
    padded = data + b'\x00' * ((4 - len(data) % 4) % 4)
    lines = []
    for i in range(0, len(padded), 4):
        word = struct.unpack('<I', padded[i:i+4])[0]
        lines.append(f"    .word 0x{word:08x}")
    return lines

def dmem_order(d):
    return d[::-1]

# ============ Output ============

print(f"# KMAC-KDF (okm_len={okm_len})")
print(f"# KDK = ss_e || ss_m (64B)")
print(f"# FixedInfo ({len(fixed_info)}B) = {fixed_info.hex()}")
print(f"# OKM = {okm.hex()}")
print()

print("# ---- .dexp file ----")
print(f"output_okm: {dmem_order(okm).hex()}")
print()

print("# ---- kdk_input ----")
print(".balign 32")
print(".globl kdk_input")
print("kdk_input:")
for line in bytes_to_words_le(kdk):
    print(line)

print()
print("# ---- fixed_info ----")
print(".balign 32")
print(".globl fixed_info")
print("fixed_info:")
for line in bytes_to_words_le(fixed_info):
    print(line)
