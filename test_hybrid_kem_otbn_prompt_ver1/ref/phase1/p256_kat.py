"""p256_kat.py — P-256 KAT generator for Hybrid KEM.

Generates expected P-256 public key (Q = d*G) and shared key (Q.x).
Edit d_bytes at the top, re-run to update KAT values.

Note: .dexp x/y values depend on URND (from p256_shared_key A2B).
Run ISS once with new inputs, capture Actual(BE) for x and y,
then paste them into the dexp file.
"""

import struct

# ============ P-256 parameters ============

p = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF
a = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC
b_curve = 0x5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B
Gx = 0x6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296
Gy = 0x4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5
n = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551
# ============ Test vector (scalar d in LE bytes) ============

d_bytes = bytes([
    0x71, 0x10, 0x6d, 0xfe, 0x16, 0xa0, 0xd0, 0x21,
    0x81, 0xc7, 0xb2, 0xb0, 0x5d, 0xef, 0x90, 0x95,
    0x79, 0xa3, 0xdf, 0x3f, 0xe8, 0xeb, 0x76, 0x1b,
    0x63, 0x02, 0x21, 0x74, 0x41, 0xfc, 0x20, 0x14,
])
d = int.from_bytes(d_bytes, 'little')

# ============ Point arithmetic (pure Python, slow but correct) ============

def modinv(a, m):
    return pow(a, -1, m)

def point_double(P):
    if P is None:
        return None
    x1, y1 = P
    lam = (3 * x1 * x1 + a) * modinv(2 * y1, p) % p
    x3 = (lam * lam - 2 * x1) % p
    y3 = (lam * (x1 - x3) - y1) % p
    return (x3, y3)

def point_add(P, Q):
    if P is None:
        return Q
    if Q is None:
        return P
    x1, y1 = P
    x2, y2 = Q
    if x1 == x2 and y1 == y2:
        return point_double(P)
    lam = (y2 - y1) * modinv(x2 - x1, p) % p
    x3 = (lam * lam - x1 - x2) % p
    y3 = (lam * (x1 - x3) - y1) % p
    return (x3, y3)

def point_mul(k, P):
    R = None
    Q = P
    while k > 0:
        if k & 1:
            R = point_add(R, Q)
        Q = point_double(Q)
        k >>= 1
    return R

# ============ Computation ============

G = (Gx, Gy)
Q = point_mul(d, G)
qx, qy = Q

print(f"// P-256 KAT (scalar d = {hex(d)})")
print(f"// d < n: {d < n}")
print()

# DMEM byte order (LE)
qx_le = qx.to_bytes(32, 'little')
qy_le = qy.to_bytes(32, 'little')

def bytes_to_c(name, data):
    lines = [f"static const uint8_t {name}[{len(data)}] = {{"]
    for i in range(0, len(data), 16):
        chunk = data[i:i+16]
        lines.append("    " + ", ".join(f"0x{b:02x}" for b in chunk) + ",")
    lines.append("};")
    return "\n".join(lines)


# Shared key = Q.x
# Input scalar d (320-bit share)
d0_le = d_bytes + bytes(32)
print("// Private key share d0 (320-bit, upper bits zero)")
print(bytes_to_c("kInputD0", d0_le))
print()

# Base point G (LE for DMEM)
gx_le = Gx.to_bytes(32, 'little')
gy_le = Gy.to_bytes(32, 'little')
print(f"// Base point G (G.x = {hex(Gx)})")
print(bytes_to_c("kInputGx", gx_le))
print()
print(bytes_to_c("kInputGy", gy_le))
print()

print("// Public key Q = d*G")
print(bytes_to_c("kExpectedPkX", qx_le))
print()
print(bytes_to_c("kExpectedPkY", qy_le))
print()

print(f"// Shared key (ECDH) = Q.x = {hex(qx)}")
print(bytes_to_c("kExpectedSharedKey", qx_le))
print()

# .dexp format (BE byte order, as stored in dexp file)
print("// --- .dexp format (BE) ---")
print(f"// Shared key (BE): {qx.to_bytes(32, 'big').hex()}")
print(f"// x and y values below MUST come from an ISS run (depend on URND):")
print(f"//   1. Run: bazel test //test_hybrid_kem_otbn_prompt_ver1/otbn/test:p256_ecdh_test --test_output=all")
print(f"//   2. Capture Actual(BE) for x and y from mismatch output")
print(f"//   3. Paste below:")
print(f"// x: <x_Actual_BE>")
print(f"// y: <y_Actual_BE>")
print()
print("// Current known values (from ISS run):")
print("// x: d91e2d65b909c5050034b441e9749ba9426e1cd412d65f4bd1b15c0c04ba3bb3")
print("// y: 584c38c8c4dbba366b01307d5772d64bdb3e52091eabd896c0f6b65a84135cf9")
