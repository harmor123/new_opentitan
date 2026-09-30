#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ver1_2 的 HKDF-SHA3-256 测试向量生成器（自校验 + 按字节改写；**只动 ver1_2**）。

格式变更（2026-09-30，与论文 (6) 式对齐）：
    新  IKM = ss_e(32) ‖ ss_m(32) ‖ ctx(32)                     =  96 B
    旧  IKM = be16(32) ‖ ss_e ‖ be16(32) ‖ ss_m ‖ ctx ‖ sid     = 132 B   ← ver1_1 冻结基线仍是这个，不动
    OTBN app 的 `input_lengths` 同步由 3 字 {ctx_len, sid_len, okm_len}
    改为 2 字 {ctx_len@+0, okm_len@+4}。

自校验（缺一不可）：先按**旧**格式重算两组向量，与仓库里现存的
`kExpectedPrk` / `kExpectedOkm`（三份 C）/ `hkdf_test.dexp` 逐个比对；全等才说明
"标准 hmac+hashlib" 这条工具链可信。改写后再断言新文本里记的正是新值、且已无 sid/长度前缀。

用法：
  python3 test_hybrid_kem_otbn_prompt_ver1_2/ref/hkdf_kat.py           # 只校验 + 打印新值
  python3 test_hybrid_kem_otbn_prompt_ver1_2/ref/hkdf_kat.py --apply   # 改写 6 个文件
"""
import argparse
import hashlib
import hmac
import pathlib
import re
import struct
import sys

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

ROOT = pathlib.Path(__file__).resolve().parents[1]        # test_hybrid_kem_otbn_prompt_ver1_2/
REPO = ROOT.parent

# ---------------------------------------------------------------- 参数
SALT = bytes(range(32))                                    # 0x00..0x1f
CTX = b"HybridKEM-v1-context-0123456789A"                  # kCtx[32]
SID = b"Session-042-run-XYZ9876543210fed"                  # kSid[32]（本次删除）
INFO = bytes(range(1, 17))                                 # kInfo[16] = 0x01..0x10
L = 32

# 向量 A：OTBN 单元测试 / HKDF-only 测试（hkdf_test.s、hkdf_test.dexp、test_hkdf_only.c）
A = dict(
    ss_e=bytes.fromhex("5f33d746a326640a739a9490ec15c103"
                       "72869f3de675b2e85742271d18c9eb82"),
    ss_m=bytes.fromhex("3750ac4a8e656327c3d181fab002554b"
                       "f6d2be0475dd28d5f31bef9f835f86ac"),
)
# 向量 B：phase2 端到端（phase2_alice_encap.c / phase2_bob_decap.c）
B = dict(
    ss_e=bytes.fromhex("064cf1e6c03cfb667b49502837d4e73a"
                       "a54c53d1884ef3925e6bf9d09a1c9926"),
    ss_m=bytes.fromhex("ac865f839fef1bf3d528dd7504bed2f6"
                       "4b5502b0fa81d1c32763658e4aac5037"),
)

F_HKDF = ROOT / "otbn/hkdf/hkdf_sha3_256.s"
F_TEST_S = ROOT / "otbn/test/hkdf_test.s"
F_DEXP = ROOT / "otbn/test/hkdf_test.dexp"
F_HKDF_ONLY = ROOT / "ibex/test_hkdf_only.c"
F_ALICE = ROOT / "ibex/phase2_encap_decap/phase2_alice_encap.c"
F_BOB = ROOT / "ibex/phase2_encap_decap/phase2_bob_decap.c"
FILES = [F_HKDF, F_TEST_S, F_DEXP, F_HKDF_ONLY, F_ALICE, F_BOB]


# ---------------------------------------------------------------- 工具
def be16(v):
    return struct.pack('>H', v)


def ikm_old(v):
    return be16(32) + v["ss_e"] + be16(32) + v["ss_m"] + CTX + SID


def ikm_new(v):
    return v["ss_e"] + v["ss_m"] + CTX


def hkdf(ikm):
    prk = hmac.new(SALT, ikm, 'sha3-256').digest()
    t1 = hmac.new(prk, INFO + b'\x01', 'sha3-256').digest()
    return prk, t1[:L]


NL = {}          # 每个文件的换行风格（Windows 上 git checkout 会写 CRLF）


def read_text(p):
    """读成 LF 归一文本，并记下原换行风格，写回时还原（避免整文件 diff）。"""
    b = p.read_bytes()
    crlf = b.count(b"\r\n")
    NL[p] = "\r\n" if crlf > (b.count(b"\n") - crlf) else "\n"
    return b.decode("utf-8").replace("\r\n", "\n")


def write_text(p, t):
    p.write_bytes(t.replace("\n", NL.get(p, "\n")).encode("utf-8"))


def sub_once(t, old, new, what):
    n = t.count(old)
    assert n == 1, "%s：期望 1 处，实际 %d 处" % (what, n)
    return t.replace(old, new, 1)


def sub_span(t, start, end, new, what):
    """把 [start 所在行的行首, end 所在行的行尾] 整段换成 new（含尾换行）。"""
    i = t.find(start)
    assert i >= 0 and t.count(start) == 1, "%s：起点锚不唯一/缺失" % what
    i = t.rfind("\n", 0, i) + 1
    j = t.find(end, i)
    assert j >= 0, "%s：终点锚缺失" % what
    j = t.find("\n", j) + 1
    return t[:i] + new + t[j:]


def delete_block(t, start, last_data, what, keep_blank=1):
    """删掉 [start 行 .. 其后的 `};` 行]，并按 keep_blank 保留空行。"""
    i = t.find(start)
    assert i >= 0 and t.count(start) == 1, "%s：起点锚不唯一/缺失" % what
    i = t.rfind("\n", 0, i) + 1
    j = t.find(last_data, i)
    assert j >= 0, "%s：数据末行缺失" % what
    j = t.find("\n", j) + 1
    e = t.find("};", j)
    assert e >= 0, "%s：缺 `};`" % what
    e = t.find("\n", e) + 1
    n = 0
    while n < keep_blank and t[e:e + 1] == "\n":
        e += 1
        n += 1
    return t[:i] + t[e:]


ARR = re.compile(r"static const uint8_t (kExpected\w+)\[32\] = \{(.*?)\};", re.S)


def parse_arrays(t):
    """{name: (data, 每行字节数, 原文本, 元素分隔符)}——分隔符沿用文件原风格，避免无谓 diff。"""
    out = {}
    for m in ARR.finditer(t):
        body = m.group(2)
        data = bytes(int(x, 16) for x in re.findall(r"0x([0-9a-fA-F]{2})", body))
        first = [ln for ln in body.split("\n") if "0x" in ln][0]
        toks = re.findall(r"0x[0-9a-fA-F]{2}", first)
        sep = ", " if ", " in first else ","
        out[m.group(1)] = (data, len(toks), m.group(0), sep)
    return out


def emit_array(name, data, per, sep=",", indent="    "):
    lines = [indent + sep.join("0x%02x" % b for b in data[i:i + per]) + ","
             for i in range(0, len(data), per)]
    return "static const uint8_t %s[32] = {\n%s\n};" % (name, "\n".join(lines))


def le_words(data, labels):
    out = []
    for i in range(0, len(data), 4):
        w = struct.unpack("<I", data[i:i + 4])[0]
        out.append("    .word 0x%08x    /* %s */" % (w, labels[i // 4]))
    return "\n".join(out) + "\n"


def hx(data):
    return "".join("%02x" % b for b in data)


# ---------------------------------------------------------------- 主流程
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="改写文件（默认只校验+打印）")
    args = ap.parse_args()

    old = {"A": hkdf(ikm_old(A)), "B": hkdf(ikm_old(B))}
    new = {"A": hkdf(ikm_new(A)), "B": hkdf(ikm_new(B))}

    # ---- 1. 自校验：旧值必须与仓库现存值逐个吻合
    t_only = read_text(F_HKDF_ONLY)
    arrs_only = parse_arrays(t_only)
    arrs_alice, arrs_bob = parse_arrays(read_text(F_ALICE)), parse_arrays(read_text(F_BOB))
    dexp_hex = re.search(r"output_okm:\s*([0-9a-f]+)", read_text(F_DEXP)).group(1)
    assert len(dexp_hex) == 64
    checks = [
        ("test_hkdf_only.c kExpectedPrk", arrs_only["kExpectedPrk"][0], old["A"][0]),
        ("test_hkdf_only.c kExpectedOkm", arrs_only["kExpectedOkm"][0], old["A"][1]),
        ("hkdf_test.dexp output_okm", bytes.fromhex(dexp_hex), old["A"][1][::-1]),
        ("alice kExpectedOkm", arrs_alice["kExpectedOkm"][0], old["B"][1]),
        ("bob kExpectedOkm", arrs_bob["kExpectedOkm"][0], old["B"][1]),
    ]
    for what, got, want in checks:
        assert got == want, "%s 不自洽:\n  库里 %s\n  复算 %s" % (what, hx(got), hx(want))
    print("== 自校验通过：旧格式（132B）复算与仓库现存值逐个吻合 ==")
    for what, _, _ in checks:
        print("   OK %s" % what)
    print("   旧 PRK(A) = %s" % hx(old["A"][0]))
    print("   旧 OKM(A) = %s" % hx(old["A"][1]))
    print("   旧 OKM(B) = %s" % hx(old["B"][1]))
    print()
    print("== 新格式（96B，无长度前缀、无 sid）==")
    for k, v in (("A", A), ("B", B)):
        print("   向量 %s: IKM = %s… (%dB)" % (k, hx(ikm_new(v))[:16], len(ikm_new(v))))
        print("            PRK = %s" % hx(new[k][0]))
        print("            OKM = %s" % hx(new[k][1]))
    print()

    # ---- 2. 逐个文件改写
    t = read_text(F_HKDF)
    t = sub_once(t, " *   be16(32) || ss_e || be16(32) || ss_m || ctx || sid\n",
                 " *   ss_e(32) || ss_m(32) || ctx\n", "hkdf.s 头注释 IKM")
    t = sub_once(t, " *   input_lengths   12B   {ctx_len, sid_len, okm_len}\n",
                 " *   input_lengths    8B   {ctx_len, okm_len}\n", "hkdf.s 头注释 input_lengths")
    t = sub_once(t,
                 "  /* ikm_len = 68 (two be16 lengths + two 32B secrets) + ctx_len + sid_len. */\n"
                 "  la    x8, input_lengths\n"
                 "  lw    x5, 0(x8)\n"
                 "  lw    x6, 4(x8)\n"
                 "  addi  x13, x5, 68\n"
                 "  add   x13, x13, x6\n",
                 "  /* ikm_len = 64 (two 32B secrets) + ctx_len. */\n"
                 "  la    x8, input_lengths\n"
                 "  lw    x5, 0(x8)\n"
                 "  addi  x13, x5, 64\n",
                 "hkdf.s extract 长度算术")
    t = sub_once(t, "  lw    x15, 8(x8)            /* L = okm_len */\n",
                 "  lw    x15, 4(x8)            /* L = okm_len */\n", "hkdf.s expand okm_len 偏移")
    assert "sid" not in t and "len_cls" not in t, "hkdf.s 仍有 sid/长度前缀残留"

    s = read_text(F_TEST_S)
    s = sub_once(s, " * Generated by hkdf_dexp.py\n",
                 " * Generated by ref/hkdf_kat.py\n", "hkdf_test.s 生成器署名")
    s = sub_once(s,
                 "/* ---- Pre-built IKM: len_cls(2B)||ss_e(32B)||len_pqc(2B)||ss_m(32B)||ctx||sid (no role) ---- */",
                 "/* ---- Pre-built IKM: ss_e(32B)||ss_m(32B)||ctx(32B) = 96B（无长度前缀、无 sid） ---- */",
                 "hkdf_test.s IKM 注释")
    lab = (["ss_e[%d:%d]" % (4 * i, 4 * i + 4) for i in range(8)] +
           ["ss_m[%d:%d]" % (4 * i, 4 * i + 4) for i in range(8)] +
           ['ctx[%d:%d]  "%s"' % (4 * i, 4 * i + 4, CTX[4 * i:4 * i + 4].decode()) for i in range(8)])
    s = sub_span(s, ".word 0x335f2000", "0x64656630", le_words(ikm_new(A), lab), "hkdf_test.s ikm 数据段")
    s = sub_span(s, "    .word 32    /* ctx_len  at +0 */", "/* okm_len  at +8 */",
                 "    .word 32    /* ctx_len  at +0 */\n"
                 "    .word 32    /* okm_len  at +4 */\n", "hkdf_test.s input_lengths")
    for mark in ("len_cls", "len_pqc", "sid_len", "ctx||sid"):
        assert mark not in s, "hkdf_test.s 仍有格式标记 %s 残留" % mark
    d = ("# HKDF-SHA3-256 (okm_len=%d, ikm_len=%dB)\n"
         "# salt=%s  info=%dB  ctx=%dB  (无长度前缀、无 sid)\n"
         "# ss_e=%s...  ss_m=%s...\n"
         "output_okm: %s\n"
         % (L, len(ikm_new(A)), hx(SALT), len(INFO), len(CTX),
            hx(A["ss_e"])[:16], hx(A["ss_m"])[:16], hx(new["A"][1][::-1])))

    only = read_text(F_HKDF_ONLY)
    only = sub_once(only, " * @brief Standalone HKDF-HMAC-SHA3-256 OTBN correctness test (ver1_1).\n",
                    " * @brief Standalone HKDF-HMAC-SHA3-256 OTBN correctness test (ver1_2).\n",
                    "test_hkdf_only 版本标注")
    only = sub_once(only,
                    " *   IKM  = be16(32)||ss_e||be16(32)||ss_m||ctx||sid\n"
                    " *        = 2+32+2+32+32+32 = 132 bytes\n",
                    " *   IKM  = ss_e||ss_m||ctx\n"
                    " *        = 32+32+32 = 96 bytes\n", "test_hkdf_only 头注释 IKM")
    only = delete_block(only, "/*\n * Fixed 32-byte session identifier:", "    0x30, 0x66, 0x65, 0x64,",
                        "test_hkdf_only kSid")
    only = sub_once(only, " *     be16(32)||ss_e||be16(32)||ss_m||ctx||sid\n",
                    " *     ss_e||ss_m||ctx\n", "test_hkdf_only PRK 注释")
    only = sub_once(only,
                    "   * IKM = be16(32) || ss_e || be16(32) || ss_m || ctx || sid\n"
                    "   *\n"
                    "   *       = 2+32+2+32+32+32 = 132B\n",
                    "   * IKM = ss_e || ss_m || ctx\n"
                    "   *\n"
                    "   *       = 32+32+32 = 96B\n", "test_hkdf_only IKM 块注释")
    only = sub_once(only,
                    "  uint8_t ikm[132];\n"
                    "\n"
                    "  ikm[0] = 0x00; ikm[1] = 0x20;   /* len_cls = 32 */\n"
                    "  memcpy(&ikm[2], kSsE, sizeof(kSsE));\n"
                    "  ikm[34] = 0x00; ikm[35] = 0x20; /* len_pqc = 32 */\n"
                    "  memcpy(&ikm[36], kSsM, sizeof(kSsM));\n"
                    "  memcpy(&ikm[68], kCtx, sizeof(kCtx));\n"
                    "  memcpy(&ikm[100], kSid, sizeof(kSid));\n",
                    "  uint8_t ikm[96];\n"
                    "\n"
                    "  memcpy(&ikm[0], kSsE, sizeof(kSsE));\n"
                    "  memcpy(&ikm[32], kSsM, sizeof(kSsM));\n"
                    "  memcpy(&ikm[64], kCtx, sizeof(kCtx));\n", "test_hkdf_only IKM 拼装")
    only = sub_once(only,
                    "   * input_lengths: +0=ctx_len, +4=sid_len, +8=okm_len\n",
                    "   * input_lengths: +0=ctx_len, +4=okm_len\n", "test_hkdf_only input_lengths 注释")
    only = sub_once(only, "  uint32_t lens[3] = {\n      sizeof(kCtx), sizeof(kSid), sizeof(kExpectedOkm),\n  };\n",
                    "  uint32_t lens[2] = {\n      sizeof(kCtx), sizeof(kExpectedOkm),\n  };\n",
                    "test_hkdf_only lens")
    only = sub_once(only, arrs_only["kExpectedPrk"][2],
                    emit_array("kExpectedPrk", new["A"][0], arrs_only["kExpectedPrk"][1], arrs_only["kExpectedPrk"][3]),
                    "test_hkdf_only kExpectedPrk 值")
    only = sub_once(only, arrs_only["kExpectedOkm"][2],
                    emit_array("kExpectedOkm", new["A"][1], arrs_only["kExpectedOkm"][1], arrs_only["kExpectedOkm"][3]),
                    "test_hkdf_only kExpectedOkm 值")
    assert "kSid" not in only, "test_hkdf_only 仍有 kSid"

    patched = {}
    for f, name, arrs, vec, ikm_start in (
            (F_ALICE, "alice", arrs_alice, "B",
             "  /* IKM = len_cls(2B)||ss_e(32B)||len_pqc(2B)||ss_m(32B)||ctx||sid */"),
            (F_BOB, "bob", arrs_bob, "B", "  uint8_t ikm[256] = {0};")):
        c = read_text(f)
        c = sub_once(c, " * IKM = len_cls(2B)||ss_e(32B)||len_pqc(2B)||ss_m(32B)||ctx||sid\n",
                     " * IKM = ss_e(32B)||ss_m(32B)||ctx(32B) = 96B\n", name + " 头注释 IKM")
        c = delete_block(c, "static const uint8_t kSid[32] = {",
                         "    0x34,0x33,0x32,0x31,0x30,0x66,0x65,0x64,", name + " kSid")
        c = sub_span(c,
                     ikm_start,
                     "    ikm_len = (off + 3) & ~(size_t)3;",
                     "  /* IKM = ss_e(32B)||ss_m(32B)||ctx(32B) = 96B */\n"
                     "  uint8_t ikm[256] = {0};\n"
                     "  size_t off = 0;\n"
                     "  size_t ikm_len = 0;\n"
                     '  HKEM_PROFILE("hkdf_assemble_ikm",\n'
                     "    memcpy(ikm + off, ss_e, 32); off += 32;\n"
                     "    memcpy(ikm + off, ss_m, 32); off += 32;\n"
                     "    memcpy(ikm + off, kCtx, sizeof(kCtx)); off += sizeof(kCtx);\n"
                     "    ikm_len = (off + 3) & ~(size_t)3;\n", name + " IKM 拼装")
        c = sub_once(c, "  uint32_t lens[3] = {\n      sizeof(kCtx), sizeof(kSid), sizeof(kExpectedOkm),\n  };\n",
                     "  uint32_t lens[2] = {\n      sizeof(kCtx), sizeof(kExpectedOkm),\n  };\n",
                     name + " lens")
        c = sub_once(c, arrs["kExpectedOkm"][2],
                     emit_array("kExpectedOkm", new[vec][1], arrs["kExpectedOkm"][1], arrs["kExpectedOkm"][3]),
                     name + " kExpectedOkm 值")
        assert "kSid" not in c and "len_cls" not in c, name + " 仍有 kSid/长度前缀"
        assert parse_arrays(c)["kExpectedOkm"][0] == new[vec][1], name + " 新值写错"
        patched[f] = c

    # ---- 3. 改写后自检
    assert parse_arrays(only)["kExpectedPrk"][0] == new["A"][0]
    assert parse_arrays(only)["kExpectedOkm"][0] == new["A"][1]
    assert re.search(r"output_okm: %s$" % hx(new["A"][1][::-1]), d, re.M)
    assert ".word 32    /* okm_len  at +4 */" in s

    if args.apply:
        write_text(F_HKDF, t)
        write_text(F_TEST_S, s)
        write_text(F_DEXP, d)
        write_text(F_HKDF_ONLY, only)
        write_text(F_ALICE, patched[F_ALICE])
        write_text(F_BOB, patched[F_BOB])
        print("== 已改写 %d 个文件 ==" % len(FILES))
        for f in FILES:
            print("   %s" % f.relative_to(REPO))
    else:
        print("（未改写；加 --apply 生效）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
