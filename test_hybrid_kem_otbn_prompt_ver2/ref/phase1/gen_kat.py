#!/usr/bin/env python3
"""Generate C KAT arrays from OTBN .dexp test files."""

import sys
import os

# Test vectors from assets (pre-verified ML-KEM KATs)
MLKEM_DIR = os.path.join(os.path.dirname(__file__),
    "../../assets/output/mlkem768/test_000")
# P-256 KAT from OTBN test
P256_DEXP = os.path.join(os.path.dirname(__file__),
    "../../test_hybrid_kem_otbn_prompt_ver2/otbn/test/p256_ecdh_shared_key_test.dexp")

def dexp_to_bytes(dexp_path, label):
    """Read .dexp file, extract hex for label, return bytes in DMEM order.
    .dexp hex is word-concatenated MSB-first; DMEM stores it fully reversed."""
    with open(dexp_path) as f:
        lines = f.read().splitlines()
    for line in lines:
        if line.strip().startswith(label + ":"):
            hexstr = line.split(":", 1)[1].strip()
            return bytes.fromhex(hexstr)[::-1]  # full reversal for DMEM order
    return None

def bytes_to_c_array(name, data):
    """Format bytes as C array initializer."""
    lines = []
    lines.append(f"static const uint8_t {name}[{len(data)}] = {{")
    if len(data) == 0:
        lines.append("    0x00,  /* placeholder */")
    else:
        for i in range(0, len(data), 16):
            chunk = data[i:i+16]
            hexvals = ", ".join(f"0x{b:02x}" for b in chunk)
            lines.append(f"    {hexvals},")
    lines.append("};")
    return "\n".join(lines)

def asm_to_bytes(asm_path, label, byte_len):
    """Parse .s file, extract .word data for a label, return bytes (LE)."""
    import struct
    with open(asm_path) as f:
        lines = f.read().splitlines()
    words = []
    in_label = False
    for line in lines:
        stripped = line.strip()
        in_label_set = False
        if f'.globl {label}' in stripped or stripped == f'{label}:' or stripped.startswith(f'{label}:'):
            in_label = True
            in_label_set = True
        if in_label and not in_label_set:
            if '.word' in stripped:
                for p in stripped.replace('.word', '').split(','):
                    p = p.strip()
                    if p.startswith('0x'):
                        words.append(int(p, 16))
            elif stripped.endswith(':') and not stripped.startswith('.'):
                break
            elif stripped.startswith('.globl') and label not in stripped:
                break
    data = b''
    for w in words:
        data += struct.pack('<I', w)
    return data[:byte_len] if byte_len else data

def main():
    # P-256 KAT: boolean shares x, y. Actual result = x XOR y
    x = dexp_to_bytes(P256_DEXP, "x")
    y = dexp_to_bytes(P256_DEXP, "y")
    if x and y and len(x) == 32 and len(y) == 32:
        result = bytes(a ^ b for a, b in zip(x, y))
        pk_e = result + b'\x00' * 32  # upper 32B = Y coordinate (zeroed)
        print(f"/* P-256: x XOR y = {len(result)}B (pk_e = 64B uncompressed) */")
        print(bytes_to_c_array("kKatPkE", pk_e))

    # ML-KEM keypair inputs + outputs
    kp_s = os.path.join(MLKEM_DIR, "keypair.s")
    coins_kp = asm_to_bytes(kp_s, "coins", 64)
    ek = dexp_to_bytes(os.path.join(MLKEM_DIR, "keypair.dexp"), "ek")
    dk = dexp_to_bytes(os.path.join(MLKEM_DIR, "keypair.dexp"), "dk")
    if coins_kp:
        print(f"/* keypair coins(64B) */")
        print(bytes_to_c_array("kInputCoinsKp", coins_kp))
    if ek and dk:
        print(f"/* keypair output: ek={len(ek)}B dk={len(dk)}B */")
        print(bytes_to_c_array("kExpectedPkM", ek))
        print(bytes_to_c_array("kExpectedSkM", dk))

    # ML-KEM encap inputs + outputs
    enc_s = os.path.join(MLKEM_DIR, "encap.s")
    coins_enc = asm_to_bytes(enc_s, "coins", 32)
    pk_enc = asm_to_bytes(enc_s, "ek", 1184)
    ct = dexp_to_bytes(os.path.join(MLKEM_DIR, "encap.dexp"), "ct")
    ss_e = dexp_to_bytes(os.path.join(MLKEM_DIR, "encap.dexp"), "ss")
    if coins_enc:
        print(f"/* encap coins(32B) */")
        print(bytes_to_c_array("kInputCoinsEnc", coins_enc))
    if pk_enc:
        print(f"/* encap pk(1184B) */")
        print(bytes_to_c_array("kInputPkEnc", pk_enc))
    if ct and ss_e:
        print(f"/* encap output: ct={len(ct)}B ss={len(ss_e)}B */")
        print(bytes_to_c_array("kExpectedCt", ct))
        print(bytes_to_c_array("kExpectedSs", ss_e))

    # ML-KEM decap inputs + outputs
    dec_s = os.path.join(MLKEM_DIR, "decap.s")
    ct_dec = asm_to_bytes(dec_s, "ct", 1088)
    dk_dec = asm_to_bytes(dec_s, "dk", 2400)
    ss_d = dexp_to_bytes(os.path.join(MLKEM_DIR, "decap.dexp"), "ss")
    if ct_dec:
        print(f"/* decap ct(1088B) */")
        print(bytes_to_c_array("kInputCtDec", ct_dec))
    if dk_dec:
        print(f"/* decap dk(2400B) */")
        print(bytes_to_c_array("kInputDkDec", dk_dec))
    if ss_d:
        print(f"/* decap output: ss={len(ss_d)}B */")
        print(bytes_to_c_array("kExpectedSs", ss_d))

    # HKDF: run with custom parameters for our use case
    print("/* HKDF: run ISS with hybrid KEM parameters to generate */")

if __name__ == "__main__":
    main()
