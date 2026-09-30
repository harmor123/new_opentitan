#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从 `test_perf/harness_config.yaml` 的 ver1_1 条目**派生** ver1_2 条目。

依据：ver1_2 的 ML-KEM/HKDF 与 ver1_1 **逐字节相同**（版本树是 ver1_1 基线的副本，见
`p5_make_ver1_2.py --provenance`）⇒ 剖面阶段表、调用闭环、口径标签全部照 ver1_1，
只把 name/label/package/app_targets 与注释里的包路径换成 ver1_2。

幂等：已存在 ver1_2 条目时，先删掉旧条目（含其抬头注释）再按 ver1_1 重新派生；
ver1_1 及其它条目一字不动。

用法：
  python3 p5_add_ver1_2_config.py           # 生成/刷新
  python3 p5_add_ver1_2_config.py --check   # 只校验盘上内容与生成结果一致
"""
import argparse
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parents[3]
CFG = REPO / "test_perf/harness_config.yaml"
VER_OLD, VER_NEW = "ver1_1", "ver1_2"
MARK_NEW = "── ver1_2 ="          # 抬头注释的识别串
HEAD_NEW = """  # ── ver1_2 = ver1_1 内核 + P-256 折叠指令（由 ver1_1 条目派生，工具见 run_dir）──
  # ML-KEM/HKDF 内核与全部剖面目标与 ver1_1 **逐字节相同**（版本树是基线副本），因此阶段表、
  # 调用闭环、口径标签一律沿用；只有 package/app_targets 指向 ver1_2。
  # 本版真正新增的是 **P-256**（域乘 = 一条 bn.p256mul）；它不进本表（本表只覆盖 ML-KEM），
  # 数字见设备路径证据 p5_device_evidence.ver1_2.txt，对照基准取 ver0_1
  # （唯一同样自带本地 P-256 的版本）。
"""


def entry_range(lines, name):
    """返回 `  - name: <name>` 条目的 [start, end)：end 为下一条目起点或文件尾。"""
    start = next((i for i, l in enumerate(lines) if l.strip() == "- name: %s" % name), None)
    if start is None:
        return None
    end = len(lines)
    for i in range(start + 1, len(lines)):
        if lines[i].startswith("  - name: "):
            end = i
            break
    return start, end


def build(text: str) -> str:
    lines = text.split("\n")
    # ① 幂等：先删掉旧的 ver1_2 条目（连同它的抬头注释）
    r = entry_range(lines, VER_NEW)
    if r:
        head = r[0]
        while head > 0 and MARK_NEW not in lines[head]:
            head -= 1
        if MARK_NEW in lines[head]:
            h = head
            while h > 0 and lines[h - 1].strip() == "":   # 连着前面的空行一起删（否则每次多一行）
                h -= 1
            del lines[h:r[1]]
        else:
            del lines[r[0]:r[1]]
    # ② 从 ver1_1 条目派生
    r1 = entry_range(lines, VER_OLD)
    if not r1:
        sys.exit("ERROR 找不到 ver1_1 条目")
    start, end = r1
    block = [l for l in lines[start:end]]
    while block and block[-1].strip() == "":
        block.pop()
    out = [l.replace("test_hybrid_kem_otbn_prompt_%s/" % VER_OLD,
                     "test_hybrid_kem_otbn_prompt_%s/" % VER_NEW) for l in block]
    n = 0
    for i, l in enumerate(out):
        if l.strip() == "- name: %s" % VER_OLD:
            out[i], n = l.replace(VER_OLD, VER_NEW), n + 1
        elif 'label: "ver1_1（官方向量指令 + KMAC 硬件哈希）"' in l:
            out[i] = l.replace('label: "ver1_1（官方向量指令 + KMAC 硬件哈希）"',
                               'label: "ver1_2（ver1_1 内核 + P-256 折叠指令）"')
            n += 1
        elif "//test_hybrid_kem_otbn_prompt_%s/" % VER_NEW in l:
            n += 1                      # package / app_targets 三行（路径已换）
    if n < 5:
        sys.exit("ERROR 只改到 %d 处（应 ≥5：name + label + package + 3×app_targets）" % n)
    # ③ 追加在 ver1_1 条目之后：条目间**恰好一个空行**（首跑即收敛，幂等）
    head_part = lines[:end]
    while head_part and head_part[-1].strip() == "":
        head_part.pop()
    tail_part = lines[end:]
    while tail_part and tail_part[-1].strip() == "":
        tail_part.pop()
    if tail_part and tail_part[0].strip() != "":
        tail_part = [""] + tail_part
    res = "\n".join(head_part + [""] + [HEAD_NEW.rstrip("\n")] + out + tail_part)
    if text.endswith("\n") and not res.endswith("\n"):
        res += "\n"
    return res


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    raw = CFG.read_bytes()
    crlf = b"\r\n" in raw                       # 该文件的 blob 是 CRLF ⇒ 写回也要 CRLF，否则整文件 diff
    cur = raw.replace(b"\r\n", b"\n").decode("utf-8")
    want = build(cur)
    if args.check:
        if cur == want:
            print("OK  %s 的 ver1_2 条目与派生结果一致" % CFG.name)
            return 0
        sys.exit("MISMATCH  %s 与派生结果不同（跑一次不带 --check 刷新）" % CFG.name)
    out = want.encode("utf-8")
    if crlf:
        out = out.replace(b"\n", b"\r\n")
    CFG.write_bytes(out)
    print("写入 %s：ver1_2 条目已派生/刷新" % CFG)
    return 0


if __name__ == "__main__":
    sys.exit(main())
