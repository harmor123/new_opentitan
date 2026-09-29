#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P5（Ibex 侧）：按字节拼接生成本版 `p256.c` 副本。

来源（上游，逐字节）：sw/device/lib/crypto/impl/ecc/p256.c
产物：test_hybrid_kem_otbn_prompt_ver1_1/crypto/p256.c

为什么需要副本
--------------
本版 app（`//test_hybrid_kem_otbn_prompt_ver1_1/otbn/p256:run_p256`，域乘换成一条
`bn.p256mul`）退休的 OTBN 指令数与上游 app 不同，而 `p256.c` 里 `kMode*InsCnt` 不是
参考值，是**运行期断言**：`HARDENED_CHECK_EQ(otbn_instruction_count_get(), kMode*InsCnt)`。
不改这两处的常量，任何走 P-256 的设备测试都会在算完之后立刻被判定失败。
上游文件一字不动 ⇒ 复制到本版目录改（与本版 app 同一目录树，与 p256_base.s 同规矩）。

本脚本改动的全部内容（每一处都断言"锚点恰好出现一次"）
-------------------------------------------------------
 ① 头部插入说明块（SPDX 行之后）
 ② [measure] 加 `#include "sw/device/lib/runtime/log.h"`
 ③ [measure] keygen / ECDH 两处指令数判定 ⇒ 改成 LOG_INFO 只打印不判定
    [final]   两处恢复上游原文，只把 kModeKeygenInsCnt / kModeEcdhInsCnt 的值换成实测值

用法
----
  python3 p5_gen_p256_c.py --mode measure            # 测量版（先跑这一步拿数）
  python3 p5_gen_p256_c.py --mode final --keygen N --ecdh M   # 定稿版（写入实测值）
  python3 p5_gen_p256_c.py --mode final --keygen N --ecdh M --check   # 只校验盘上文件与生成结果一致
"""
import argparse
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parents[3]
SRC = REPO / "sw/device/lib/crypto/impl/ecc/p256.c"
DST = REPO / "test_hybrid_kem_otbn_prompt_ver1_1/crypto/p256.c"

HEADER = """// ---------------------------------------------------------------------------
// ver1_1 本地副本（P-256 Fold 项目 / contribution 2，P5「Ibex 侧」）
//
// 上游：sw/device/lib/crypto/impl/ecc/p256.c
// 本文件与上游**逐字节相同**，只有本说明块与下面列出的几处不同。
// 生成：logs_hkem/p256fold_20260928T085338Z/rtl/p5_gen_p256_c.py（可重跑，结果一致）
//
// 为什么要副本：本版 app（本目录树下的 `//test_hybrid_kem_otbn_prompt_ver1_1/otbn/p256:run_p256`）
// 把 P-256 的域乘换成一条 bn.p256mul，退休的 OTBN 指令数与上游 app 不同；而本文件里
// kMode*InsCnt 不是"参考值"而是**运行期断言**
// （HARDENED_CHECK_EQ(otbn_instruction_count_get(), kMode*InsCnt)）。
// 不更新这些常量，任何走 P-256 的设备测试都会在算完之后立刻被判定失败。
//
// 改动清单：
//   ① {K1}
//   ② 其余 kMode*InsCnt（sideload / sign / verify / point-on-curve / base-point-mult /
//      arith-share）保持上游原值、**未实测**：本版 app 已删签名与验签例程，
//      这几条路径在本项目的测试里不可达。将来若要跑，必须先重新实测再改。
//   ③ {K3}
//
// 实测口径：芯片仿真（Verilator）跑本目录的 test_p256_only / phase 测试，
// 打印的是 RTL 的 OTBN INSN_CNT（退休指令数），单位＝条。
// ---------------------------------------------------------------------------
"""

K1_MEASURE = (
    "kModeKeygenInsCnt / kModeEcdhInsCnt = 本版 app 的**实测**值（本步尚未取得，"
    "见下面 ③ 的测量版）"
)
K1_FINAL = (
    "kModeKeygenInsCnt = {kg} / kModeEcdhInsCnt = {ec}（本版 app 的实测值）"
)
K3_MEASURE = (
    "[测量版] keygen / ECDH 两处判定临时改为 LOG_INFO 打印实测值，不含判定。"
)
K3_FINAL = (
    "keygen / ECDH 两处判定恢复上游原文（HARDENED_CHECK_EQ），只有常量值不同。"
)

# --- 锚点（上游原文，逐字节） ---
A_SPDX = b"// SPDX-License-Identifier: Apache-2.0\n"
A_INC = b'#include "sw/device/lib/crypto/include/integrity.h"\n'
A_KEYGEN = (
    b"  HARDENED_CHECK_EQ(otbn_instruction_count_get(), kModeKeygenInsCnt);\n"
)
A_ECDH = b"""  // OTBN returned the status code OK, so check for the expected instr. count.
  uint32_t ins_cnt;
  ins_cnt = otbn_instruction_count_get();
  if (launder32(ins_cnt) == kModeEcdhSideloadInsCnt) {
    HARDENED_CHECK_EQ(ins_cnt, kModeEcdhSideloadInsCnt);
  } else {
    HARDENED_CHECK_EQ(ins_cnt, kModeEcdhInsCnt);
  }
"""
A_KEYGEN_VAL = b"  kModeKeygenInsCnt = 573922,\n"
A_ECDH_VAL = b"  kModeEcdhInsCnt = 581607,\n"

# --- 替换（测量版） ---
M_KEYGEN = (
    b"  // [ver1_1 \xe6\xb5\x8b\xe9\x87\x8f\xe7\x89\x88] \xe4\xb8\x8a\xe6\xb8\xb8\xe5\x8e\x9f"
    b"\xe6\x96\x87\xef\xbc\x9a\xe4\xb8\x8e kModeKeygenInsCnt \xe5\x81\x9a "
    b"HARDENED_CHECK_EQ\xef\xbc\x9b\xe6\x9c\xac\xe7\x89\x88 app \xe7\x9a\x84\xe6\x8c\x87"
    b"\xe4\xbb\xa4\xe6\x95\xb0\xe5\xb0\x9a\xe6\x9c\xaa\xe5\xae\x9e\xe6\xb5\x8b"
    b"\xef\xbc\x8c\xe5\x85\x88\xe5\x8f\xaa\xe8\xae\xb0\xe5\xbd\x95\xe3\x80\x82\n"
    b'  LOG_INFO("ver1_1 MEASURE keygen insn_cnt = %u (0x%08x)",\n'
    b"           otbn_instruction_count_get(), otbn_instruction_count_get());\n"
)
M_ECDH = (
    b"  // OTBN returned the status code OK. [ver1_1 \xe6\xb5\x8b\xe9\x87\x8f\xe7\x89\x88] "
    b"\xe4\xb8\x8a\xe6\xb8\xb8\xe6\xad\xa4\xe5\xa4\x84\xe4\xb8\x8e kModeEcdhInsCnt / "
    b"kModeEcdhSideloadInsCnt \xe5\x81\x9a HARDENED_CHECK_EQ\xef\xbc\x9b\n"
    b"  // \xe6\x9c\xac\xe7\x89\x88 app \xe7\x9a\x84\xe6\x8c\x87\xe4\xbb\xa4\xe6\x95\xb0"
    b"\xe5\xb0\x9a\xe6\x9c\xaa\xe5\xae\x9e\xe6\xb5\x8b \xe2\x87\x92 "
    b"\xe5\x8f\xaa\xe6\x89\x93\xe5\x8d\xb0\xe4\xb8\x8d\xe5\x88\xa4\xe5\xae\x9a\xe3\x80\x82\n"
    b"  uint32_t ins_cnt;\n"
    b"  ins_cnt = otbn_instruction_count_get();\n"
    b'  LOG_INFO("ver1_1 MEASURE ecdh insn_cnt = %u (0x%08x)", ins_cnt, ins_cnt);\n'
)
M_INC = (
    b'#include "sw/device/lib/crypto/include/integrity.h"\n'
    b'#include "sw/device/lib/runtime/log.h"  // [ver1_1] \xe4\xbb\x85\xe6\xb5\x8b\xe9\x87\x8f'
    b"\xe7\x89\x88\xe9\x9c\x80\xe8\xa6\x81\n"
)


def read_normalized(path: pathlib.Path) -> bytes:
    """读文件并把 CRLF 归一成 LF。

    Windows 工作区（core.autocrlf）里上游文件是 CRLF，而 git 里存的是 LF；
    锚点全部按 LF 写，故先归一化。生成的产物一律以 LF 落盘。
    """
    data = path.read_bytes().replace(b"\r\n", b"\n")
    if b"\r" in data:
        sys.exit("ERROR stray CR in %s" % path)
    return data


def sub_once(data: bytes, anchor: bytes, repl: bytes, what: str) -> bytes:
    n = data.count(anchor)
    if n != 1:
        sys.exit("ERROR anchor appears %d times (expected 1): %s" % (n, what))
    return data.replace(anchor, repl, 1)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=["measure", "final"], required=True)
    ap.add_argument("--keygen", type=int, default=None)
    ap.add_argument("--ecdh", type=int, default=None)
    ap.add_argument("--check", action="store_true",
                    help="不写文件，只校验盘上文件与生成结果一致")
    args = ap.parse_args()

    src = read_normalized(SRC)
    if args.mode == "measure":
        k1, k3 = K1_MEASURE, K3_MEASURE
    else:
        if args.keygen is None or args.ecdh is None:
            sys.exit("ERROR --mode final needs --keygen N --ecdh M")
        k1 = K1_FINAL.format(kg=args.keygen, ec=args.ecdh)
        k3 = K3_FINAL

    out = sub_once(src, A_SPDX, A_SPDX + HEADER.format(K1=k1, K3=k3).encode("utf-8"),
                   "header block")

    if args.mode == "measure":
        out = sub_once(out, A_INC, M_INC, "add log.h include")
        out = sub_once(out, A_KEYGEN, M_KEYGEN, "keygen insn-count check")
        out = sub_once(out, A_ECDH, M_ECDH, "ecdh insn-count check")
    else:
        out = sub_once(out, A_KEYGEN_VAL,
                       ("  kModeKeygenInsCnt = %d,\n" % args.keygen).encode(),
                       "kModeKeygenInsCnt")
        out = sub_once(out, A_ECDH_VAL,
                       ("  kModeEcdhInsCnt = %d,\n" % args.ecdh).encode(),
                       "kModeEcdhInsCnt")

    # 尾字节必须与上游一致（拼接没有吃掉结尾）
    if out[-64:] != src[-64:]:
        sys.exit("ERROR last 64 bytes differ from upstream")
    out.decode("utf-8")  # 必须仍是合法 UTF-8
    if b"\r" in out:
        sys.exit("ERROR output contains CR")

    if args.check:
        cur = read_normalized(DST) if DST.exists() else b""
        if cur == out:
            print("OK  %s is byte-identical to generator output (%d bytes)"
                  % (DST, len(out)))
            return 0
        sys.exit("MISMATCH  %s differs from generator output" % DST)

    DST.parent.mkdir(parents=True, exist_ok=True)
    DST.write_bytes(out)
    print("wrote %s (%d bytes, mode=%s)" % (DST, len(out), args.mode))
    return 0


if __name__ == "__main__":
    sys.exit(main())
