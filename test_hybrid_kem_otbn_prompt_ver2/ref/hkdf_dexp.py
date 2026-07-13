"""hkdf_dexp.py — HKDF-SHA3-256 test vector generator.
Outputs .dexp files AND auto-generated .word data for hkdf_test.s.
info="" at KEM layer (no role binding — upper layer responsibility).
Edit the vectors below and re-run to regenerate everything."""

import hashlib
import hmac
import struct
import sys

# ============ Test vectors ============

salt = bytes(range(32))  # 0x00..0x1f

ss_e = bytes.fromhex(
    "5f33d746a326640a739a9490ec15c103"
    "72869f3de675b2e85742271d18c9eb82")
ss_m = bytes.fromhex(
    "3750ac4a8e656327c3d181fab002554b"
    "f6d2be0475dd28d5f31bef9f835f86ac")

ctx  = b"HybridKEM-v1-context-0123456789A"  # kCtx[32]
sid  = b"Session-042-run-XYZ9876543210fed"  # kSid[32]
info = bytes(range(1, 17))                   # kInfo[16] = 0x01..0x10

okm_len = int(sys.argv[1]) if len(sys.argv) > 1 else 32

# ============ IKM construction ============

def be16(val):
    return struct.pack('>H', val)

ikm  = be16(32) + ss_e
ikm += be16(32) + ss_m
ikm += ctx + sid

# ============ HKDF-SHA3-256 ============

prk = hmac.new(salt, ikm, 'sha3-256').digest()
okm = b''
T_prev = b''
for i in range(1, (okm_len + 31) // 32 + 1):
    T_i = hmac.new(prk, T_prev + info + bytes([i]), 'sha3-256').digest()
    okm += T_i
    T_prev = T_i
okm = okm[:okm_len]

# ============ Helpers ============

def bytes_to_words(data):
    padded = data + b'\x00' * ((4 - len(data) % 4) % 4)
    lines = []
    for i in range(0, len(padded), 4):
        word = struct.unpack('<I', padded[i:i+4])[0]
        lines.append(f"    .word 0x{word:08x}")
    return lines

def dmem_order(d):
    return d[::-1]

# ============ Output ============

print(f"# HKDF-SHA3-256 (okm_len={okm_len}, ikm_len={len(ikm)})")
print(f"# salt = {'(all zero)' if not any(salt) else salt.hex()}")
print(f"# info = '' (KEM layer, no role binding)")
print(f"# ss_e = {ss_e.hex()}")
print(f"# ss_m = {ss_m.hex()}")
print(f"# PRK  = {prk.hex()}")
print(f"# OKM  = {okm.hex()}")
print()

print("# ---- .dexp file ----")
print(f"output_okm: {dmem_order(okm).hex()}")
print()

print("# ---- .s data section ----")
print()
print(".balign 32")
print(".globl input_salt")
print("input_salt:")
for line in bytes_to_words(salt):
    print(line)

print()
print(".balign 32")
print(".globl ikm_prebuilt")
print("ikm_prebuilt:")
for line in bytes_to_words(ikm):
    print(line)

print()
print(".balign 32")
print(".globl input_info")
print("input_info:")
print("    .zero 32    /* info (32B, matches kInfo[16]) */")

print()
print(".balign 32")
print(".globl input_lengths")
print("input_lengths:")
print(f"    .word {len(ctx)}     /* ctx_len  */")
print(f"    .word {len(sid)}     /* sid_len  */")
print(f"    .word {len(info)}    /* info_len (0 = KEM layer) */")
print(f"    .word {okm_len}      /* okm_len  */")
print("    .zero 16              /* pad to 32B */")
