#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P5 目录归属修正：把 P-256 折叠的改动从 ver1_1 挪到新的 `test_hybrid_kem_otbn_prompt_ver1_2`。

背景（用户 2026-09-30 定）：**ver1_1 是固定基线，不做任何修改**；P-256 折叠要另立版本树。
本脚本只做"复制 + 路径改写 + 自称改口"，**不碰 ver1_1**（回基线由 git checkout/git rm 完成）。

改写规则（两条，都不靠人眼）：
 ① **包路径/标签**：`test_hybrid_kem_otbn_prompt_ver1_1` 后面紧跟 `/` 或 `:` 的，一律换成 `…_ver1_2`
    （覆盖 BUILD 的 `//…` 标签、注释里引用的标签、README 里的路径）。
 ② **本版自称**：只在新版"自己的"文件里，把"本版（ver1_1）"这类**自指**改成 ver1_2
    （P-256 / crypto / 顶层 BUILD 标题 / README 抬头）。
    ML-KEM、HKDF、ibex 等文件里裸写的 "ver1_1" **保留** —— 那些是**内核与出处**的称呼，
    ver1_2 的 ML-KEM 内核确实就是 ver1_1 那份（既有风格：ver1_1 的文件里也这么写 ver0_2）。

用法：
  python3 p5_make_ver1_2.py            # 生成/刷新 ver1_2
  python3 p5_make_ver1_2.py --check    # 只校验盘上 ver1_2 与生成结果一致
  python3 p5_make_ver1_2.py --provenance   # 除白名单外必须与基线逐字节相同

例外：`otbn/mlkem768/keygen_poly_gen_matrix_{shake,rejection,stub_overhead}_profiling.s`
由别的生成器产出（`test_perf/tools/gen/emit_stub_rows_ver1_1.py --out-dir <ver1_2>/otbn/mlkem768`），
本工具既不复制也不校验它们（见 EXTERNAL 的说明）。
"""
import argparse
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[3]
SRC = REPO / "test_hybrid_kem_otbn_prompt_ver1_1"
DST = REPO / "test_hybrid_kem_otbn_prompt_ver1_2"
SKIP_DIRS = {".git", "__pycache__", "bazel-bin", "bazel-out", "bazel-testlogs"}

VER_OLD = b"test_hybrid_kem_otbn_prompt_ver1_1"
VER_NEW = b"test_hybrid_kem_otbn_prompt_ver1_2"
# ① 只在后面紧跟 / 或 : 时改写（即包名出现在路径/标签里）
PATH_RE = re.compile(re.escape(VER_OLD) + rb"(?=[/:])")

# ② 定向自称改写：{相对路径: [(旧串, 新串), …]}（旧串必须恰好出现一次）
TARGETED = {
    "BUILD": [
        ("# BUILD — ver1_1（官方向量指令基线）chip sim 测试",
         "# BUILD — ver1_2（ver1_1 内核 + P-256 折叠指令）chip sim 测试"),
    ],
    "README.md": [
        ("| **ver1_1（本版）** |", "| **ver1_1（本版内核）** |"),
    ],
}

# 内容替换（同一文件里可出现多处，数量必须吻合）：把设备测试的 P-256 依赖

# 从**上游实现**换成本版实现 —— 基线 BUILD 里指的是 `//sw/device/lib/crypto/impl:ecc_p256`，
# ver1_2 要改成自己的 `crypto:ecc_p256_local`（4 处 = test_p256_only + 三个 phase 测试）。
REPLACE_ALL = {
    "BUILD": [(
        '        "//sw/device/lib/crypto/impl:ecc_p256",\n',
        '        "//test_hybrid_kem_otbn_prompt_ver1_2/crypto:ecc_p256_local",\n',
        4,
    )],
}

README_HEAD = """# Hybrid KEM — ver1_2（ver1_1 内核 + P-256 折叠指令）

> **本目录 = ver1_2**：由 ver1_1 的基线树（`2d87e79bee` 状态，位于
> `test_hybrid_kem_otbn_prompt_ver1_1/`）**逐字节复制**而来，唯一差别是 **P-256**：
> 域乘换成本版折叠指令实现（本目录 `otbn/p256/`，一条 `bn.p256mul`），设备侧
> 经本目录 `crypto/` 接线（cryptolib 源码仍以 label 引用上游，不复制）。
> ML-KEM / HKDF 的内核与 ver1_1 **完全相同** ⇒ 下文正文里仍称「ver1_1 内核」。

"""


def norm(data: bytes) -> bytes:
    data = data.replace(b"\r\n", b"\n")
    if b"\r" in data:
        sys.exit("ERROR stray CR")
    return data


# 定向插入（幂等：以 MARK 判断已存在则跳过）：P6 诊断用的"上游 P-256 对照"测试目标。
# 它与本包的 :phase1_keygen_test 同一份 src，deps 逐项照 ver1_1 的 phase1（P-256 用上游实现）
# ⇒ 它的 HKEM_PROF 分段应与 ver1_1 的基线日志逐位相同（用来把阶段差异钉到 P-256 app 上）。
CONTRAST_TARGET = '''# ---- P6 诊断对照：同一测试 + **上游 P-256**（deps 逐项照 ver1_1 的 phase1）----
# 目的：把"阶段差异只来自 P-256 app"做成可判定实验。本目标与 :phase1_keygen_test 同一份 src，
# 唯一差别是 P-256 一侧用上游实现（//sw/device/lib/crypto/impl:ecc_p256，即 ver1_1 的用法）。
# 预测：它的 HKEM_PROF 分段应与 ver1_1 的基线日志**逐位相同**。
opentitan_test(
    name = "phase1_keygen_test_baselinep256",
    srcs = ["ibex/phase1_keygen/phase1_keygen_test.c"],
    exec_env = EARLGREY_TEST_ENVS,
    deps = [
        "//hw/top_earlgrey/sw/autogen:top_earlgrey",
        "//sw/device/lib/dif:otbn",
        "//sw/device/lib/runtime:log",
        "//sw/device/lib/testing:otbn_testutils",
        "//sw/device/lib/testing:profile",
        "//sw/device/lib/testing/test_framework:check",
        "//sw/device/lib/testing/test_framework:ottf_main",
        "//sw/device/lib/crypto/impl:config",
        "//sw/device/lib/crypto/impl:ecc_p256",
        "//sw/device/lib/crypto/impl:entropy_src",
        "//sw/device/lib/testing:entropy_testutils",
        "//test_hybrid_kem_otbn_prompt_{VER}/otbn/mlkem768:mlkem768_keypair",
    ],
)

'''
INSERT_BEFORE = {
    "BUILD": [("# ---- Phase 1: Key Generation（端到端）----",
               CONTRAST_TARGET, "phase1_keygen_test_baselinep256")],
}


def build_tree() -> dict:
    """返回 {相对路径: 目标内容 bytes}。"""
    out = {}
    if not SRC.is_dir():
        sys.exit("ERROR 源目录不存在：%s" % SRC)
    for p in sorted(SRC.rglob("*")):
        if p.is_dir() or any(part in SKIP_DIRS for part in p.parts):
            continue
        rel = str(p.relative_to(SRC)).replace("\\", "/")
        if rel in EXTERNAL:
            continue                        # 由 emit_stub_rows_ver1_1.py 生成，本工具不碰
        if rel.startswith(NEW_PREFIXES):
            continue                        # P-256 文件由 ver1_2 自己拥有（见下面说明）
        data = norm(p.read_bytes())
        data = PATH_RE.sub(VER_NEW, data)
        out[rel] = data

    hits = 0
    for rel, edits in TARGETED.items():
        if rel not in out:
            sys.exit("ERROR 定向改写目标缺失：%s" % rel)
        d = out[rel]
        for old, new in edits:
            ob, nb = old.encode("utf-8"), new.encode("utf-8")
            n = d.count(ob)
            if n != 1:
                sys.exit("ERROR %s：锚点出现 %d 次（应为 1）：%s" % (rel, n, old[:40]))
            d = d.replace(ob, nb, 1)
            hits += 1
        out[rel] = d
    for rel, edits in REPLACE_ALL.items():
        if rel not in out:
            sys.exit("ERROR 替换目标缺失：%s" % rel)
        d = out[rel]
        for old, new, cnt in edits:
            ob, nb = old.encode("utf-8"), new.encode("utf-8")
            n = d.count(ob)
            if n != cnt:
                sys.exit("ERROR %s：锚点出现 %d 次（应为 %d）：%s" % (rel, n, cnt, old[:50]))
            d = d.replace(ob, nb)
            hits += n
        out[rel] = d
    for rel, items in INSERT_BEFORE.items():
        if rel not in out:
            sys.exit("ERROR 插入目标缺失：%s" % rel)
        d = out[rel]
        for anchor, block, mark in items:
            if mark.encode("utf-8") in d:       # 幂等
                continue
            ab = anchor.encode("utf-8")
            if d.count(ab) != 1:
                sys.exit("ERROR %s：插入锚点出现 %d 次（应为 1）" % (rel, d.count(ab)))
            d = d.replace(ab, block.format(VER=VER_NEW.decode()).encode("utf-8") + ab, 1)
            hits += 1
        out[rel] = d

    # README 抬头：插在标题行之后
    r = out["README.md"]
    nl = r.index(b"\n")
    out["README.md"] = r[:nl + 1] + README_HEAD.encode("utf-8") + r[nl + 1:]
    hits += 1

    print("生成 %d 个文件（定向改写 %d 处；路径改写见下）" % (len(out), hits))
    return out


BASE_COMMIT = "2d87e79bee"
BASE_TREE = "test_hybrid_kem_otbn_prompt_ver1_1"
# 基线里没有、由 ver1_2 **自己拥有**的目录（创建时从当时的 ver1_1 迁移而来，此后归 ver1_2）：
#   crypto/p256.c      —— 由 p5_gen_p256_c.py 生成（--check 可复核）
#   otbn/p256/*.s      —— 由 p5_verify_app_asm.py 校验其与上游的拼接边界
# ver1_1 在 2026-09-30 已退回基线 ⇒ 这些文件**只存在于 ver1_2**，本工具既不复制也不校验它们。
NEW_PREFIXES = ("crypto/", "otbn/p256/")
# 由**别的生成器**产出、本工具不复制也不校验的文件：
# `test_perf/tools/gen/emit_stub_rows_ver1_1.py --out-dir <ver1_2>/otbn/mlkem768` 的产物。
# 采纳工具的新输出而非基线副本，因为基线副本里写的是**旧工具路径**
# （`test_perf/emit_stub_rows_ver1_1.py`，工具已归置到 test_perf/tools/gen/）——
# ver1_1 作为基线保持原样，ver1_2 用正确路径，且这样工具在 ver1_2 目录是不动点。
EXTERNAL = {
    "otbn/mlkem768/keygen_poly_gen_matrix_shake_profiling.s",
    "otbn/mlkem768/keygen_poly_gen_matrix_rejection_profiling.s",
    "otbn/mlkem768/keygen_poly_gen_matrix_stub_overhead_profiling.s",
}
# 允许与基线不同的文件（路径改写 + 新版自称 + 上面那三个工具产物；逐条列出，多一个就 FAIL）
ALLOW_DIFF = {
    "BUILD", "README.md",
    "otbn/hkdf/BUILD", "otbn/mlkem768/BUILD", "otbn/test/BUILD",
    "otbn/kmac_official/README.md",
    "ibex/phase1_keygen/phase1_keygen_test.c",
} | EXTERNAL


def provenance() -> int:
    """逐文件比对 ver1_2 与基线：不在 NEW_PREFIXES 且不在 ALLOW_DIFF 的，必须逐字节相同。"""
    import subprocess
    bad, changed, added = [], [], []
    for p in sorted(DST.rglob("*")):
        if p.is_dir() or any(part in SKIP_DIRS for part in p.parts):
            continue
        rel = str(p.relative_to(DST)).replace("\\", "/")
        if rel.startswith(NEW_PREFIXES):
            added.append(rel)
            continue
        r = subprocess.run(["git", "cat-file", "blob",
                            "%s:%s/%s" % (BASE_COMMIT, BASE_TREE, rel)],
                           cwd=REPO, capture_output=True)
        if r.returncode != 0:
            bad.append("%s（基线里没有，但也不在新增目录）" % rel)
            continue
        base = r.stdout.replace(b"\r\n", b"\n")
        cur = norm(p.read_bytes())
        if base != cur:
            changed.append(rel)
            if rel not in ALLOW_DIFF:
                bad.append("%s（与基线不同但不在白名单）" % rel)
    miss = sorted(ALLOW_DIFF - set(changed))
    print("新增（基线没有）：%d 个 %s" % (len(added), added))
    print("与基线不同：%d 个 %s" % (len(changed), changed))
    if miss:
        bad.append("白名单里列了但实际未变：%s" % miss)
    if bad:
        print("\nFAIL")
        for b in bad:
            print("  - " + b)
        return 1
    print("\nPASS  除上列 %d 个文件外，ver1_2 与基线（%s 的 ver1_1）逐字节相同"
          % (len(changed), BASE_COMMIT))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--provenance", action="store_true",
                    help="断言 ver1_2 的每个文件都与基线（2d87e79bee 的 ver1_1）逐字节相同，"
                         "除非它属于「应改」或「新增」两类")
    args = ap.parse_args()

    if args.provenance:
        return provenance()

    want = build_tree()
    if args.check:
        bad = []
        for rel, data in want.items():
            p = DST / rel
            if not p.exists() or norm(p.read_bytes()) != data:
                bad.append(rel)
        extra = [str(q.relative_to(DST)).replace("\\", "/")
                 for q in DST.rglob("*") if q.is_file()
                 and str(q.relative_to(DST)).replace("\\", "/") not in want
                 and str(q.relative_to(DST)).replace("\\", "/") not in EXTERNAL
                 and not str(q.relative_to(DST)).replace("\\", "/").startswith(NEW_PREFIXES)
                 and not any(part in SKIP_DIRS for part in q.parts)]
        if bad or extra:
            sys.exit("MISMATCH：内容不同 %d 个 %s；多余文件 %d 个 %s"
                     % (len(bad), bad[:5], len(extra), extra[:5]))
        print("OK  %s 与生成结果逐字节一致（%d 文件）" % (DST.name, len(want)))
        return 0

    n = 0
    for rel, data in want.items():
        p = DST / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        if not p.exists() or norm(p.read_bytes()) != data:
            p.write_bytes(data)
            n += 1
    print("写入 %s：%d 个文件（其中 %d 个是新写/有改动）" % (DST.name, len(want), n))

    # 摘要：仍有 ver1_1 字样的文件（应当只剩下"内核/出处"性质的裸版本名）
    rest = []
    for rel, data in want.items():
        if VER_OLD.decode() in data.decode("utf-8", "replace"):
            rest.append(rel)
    print("仍出现包路径 %s 的文件：%s" % (VER_OLD.decode(), rest or "（无）"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
