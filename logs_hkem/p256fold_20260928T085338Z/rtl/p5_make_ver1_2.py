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
    "crypto/BUILD": [
        ("# 本版（ver1_1）设备侧的 P-256 接线", "# 本版（ver1_2）设备侧的 P-256 接线"),
        ("而 ver1_1 的设备测试", "而 ver1_2 的设备测试"),
    ],
    "otbn/p256/BUILD": [
        ("# ver1_1 本地的 P-256 域乘", "# ver1_2 本地的 P-256 域乘"),
    ],
    "otbn/p256/run_p256_local.s": [
        (" * ver1_1 本地版（P5）", " * ver1_2 本地版（P5）"),
        ("（ver1_1 的 test_p256_only", "（ver1_2 的 test_p256_only"),
    ],
    "otbn/p256/p256_base.s": [
        ("本版（ver1_1）的域乘用融合指令实现", "本版（ver1_2）的域乘用融合指令实现"),
    ],
    "README.md": [
        ("| **ver1_1（本版）** |", "| **ver1_1（本版内核）** |"),
    ],
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


def build_tree() -> dict:
    """返回 {相对路径: 目标内容 bytes}。"""
    out = {}
    if not SRC.is_dir():
        sys.exit("ERROR 源目录不存在：%s" % SRC)
    for p in sorted(SRC.rglob("*")):
        if p.is_dir() or any(part in SKIP_DIRS for part in p.parts):
            continue
        rel = p.relative_to(SRC)
        data = norm(p.read_bytes())
        data = PATH_RE.sub(VER_NEW, data)
        out[str(rel).replace("\\", "/")] = data

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

    # README 抬头：插在标题行之后
    r = out["README.md"]
    nl = r.index(b"\n")
    out["README.md"] = r[:nl + 1] + README_HEAD.encode("utf-8") + r[nl + 1:]
    hits += 1

    print("生成 %d 个文件（定向改写 %d 处；路径改写见下）" % (len(out), hits))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    want = build_tree()
    if args.check:
        bad = []
        for rel, data in want.items():
            p = DST / rel
            if not p.exists() or norm(p.read_bytes()) != data:
                bad.append(rel)
        extra = [str(q.relative_to(DST)).replace("\\", "/")
                 for q in DST.rglob("*") if q.is_file()
                 and str(q.relative_to(DST)).replace("\\", "/") not in want]
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
