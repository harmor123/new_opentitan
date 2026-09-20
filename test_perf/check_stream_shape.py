#!/usr/bin/env python3
"""校验"桩法拒绝采样"三件套的形状一致性（纯静态，不需要构建/ISS）。

为什么需要它（2026-09-20 事故）：
  ver1_1 的流文件是从 ver0_x 原样拷来的 **180 块（20 块/会话）**，而 ver1_1 的 app
  每会话固定挤 21 块（`poly_gen_matrix.s: loopi 21,3`、`_expand_buf` 672 B）⇒
    ① stub_overhead 行线性走 189 块，末尾 9 块越出已加载的 `.data`、落进 NOLOAD 的
       `.scratchpad` ⇒ `bn.lid` 读到从未加载的字 ⇒ `DMEM_INTG_VIOLATION (0x20000)`
       （dmem.py: load_u256 全 8 字有效才算有效；.scratchpad 是 NOLOAD）
    ② rejection 行按会话重指指针，每会话多读 1 块 ⇒ **静默**读到邻居会话的数据
       （落在已加载的 .data 里，不报错、不中止，但轨迹不是 app 的）✗ 最危险的一类

四条不变量（全部静态可判定）：
  A  每会话消费块数 ≤ 流文件每会话配额（标签步长）—— 抓 ver1_1 的 ② 静默错
  B  stub_overhead 行的 replay 次数 == app 实测动态挤压次数 —— 抓校准行陈旧
  C  rejection 行引用的每个会话标签都存在，且该会话消费不越过自己的配额 —— 同 A 的行级版
  D  stub_overhead 行的线性游走总量 ≤ 载荷块数 —— 抓 ver1_1 的 ① 越界

数据来源：
  · 流文件            —— 标签与载荷字节数（.byte 每值 = 1 字节）
  · app 的静态模型    —— poly_gen_matrix.s 的挤压循环（信息性打印）
  · app 的实测动态数  —— logs_hkem/<版本>_profiling/*.json 的
                        `keygen_poly_gen_matrix` 行 calls（真值来源；缺数据则跳过该检查）

用法: python3 test_perf/check_stream_shape.py [--logs-dir logs_hkem]
"""
import argparse
import json
import re
import sys
from pathlib import Path

# Windows 控制台默认 GBK，`⇒`/`✓` 这类字符会直接抛 UnicodeEncodeError ⇒ 强制 UTF-8
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = Path(__file__).resolve().parents[1]

VERSIONS = {                                   # 版本 → (包目录, 拷贝桩符号候选)
    "ver0_1": "test_hybrid_kem_otbn_prompt_ver0_1/otbn/mlkem768",
    "ver0_2": "test_hybrid_kem_otbn_prompt_ver0_2/otbn/mlkem768",
    "ver1_1": "test_hybrid_kem_otbn_prompt_ver1_1/otbn/mlkem768",
}
STREAM = "keygen_poly_gen_matrix_rejection_streams.s"
STUBS = "keygen_poly_gen_matrix_rejection_stubs.s"
CALLERS = {                                    # app 挤压 API 名（取其一）
    "ver0_1": "shake_out",
    "ver0_2": "xof_squeeze32",
    "ver1_1": "xof_squeeze32",
}


def parse_stream(path: Path):
    """→ (载荷字节数, {标签: 距载荷起点字节偏移})

    ⚠ 首块标签出现在**任何 .byte 之前**（偏移 0）⇒ 不能用"见过 .byte 吗"做条件，
    否则 9 个会话只数到 8 个（2026-09-20 踩过：stride 被算成 720 块）。
    ptr 变量（rejection_stream_ptr）靠名字排除。
    """
    off, labels = 0, {}
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if s.startswith(".byte"):
            off += len(s.split(","))                    # .byte 每值 = 1 字节
        elif s.startswith("rejection_stream_") and s.endswith(":") and "_ptr" not in s:
            labels[s[:-1]] = off
    return off, labels


def parse_copy_stub_sym(stubs: Path) -> str:
    """桩文件里"拷 32 B 进 WDR"的那个符号（含 bn.lid 的 globl 段）"""
    cur, hit = None, None
    for line in stubs.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        m = re.match(r"\.globl\s+(\S+)", s)
        if m:
            cur = m.group(1)
        if s.startswith("bn.lid") and cur:
            hit = cur
    return hit


def count_replays(row: Path, sym: str):
    """→ (replay 总次数, 引用的会话标签出现顺序)"""
    total, pend, labels = 0, 1, []
    for line in row.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        m = re.match(r"\.rept\s+(\d+)", s)
        if m:
            pend = int(m.group(1))
        if s.startswith("jal") and sym in s:
            total += pend
        if s.startswith(".endr"):
            pend = 1
        m2 = re.search(r"rejection_stream_(?!ptr)(\w+)", s)
        if m2:
            labels.append(f"rejection_stream_{m2.group(1)}")
    return total, labels


def load_app_calls(logs_dir: Path, version: str):
    """→ (app 挤压总次数, app 的 poly_gen_matrix 调用次数) 或 None"""
    hits = sorted((logs_dir / f"{version}_profiling").glob("*.json"))
    if not hits:
        return None
    data = json.loads(hits[0].read_text(encoding="utf-8"))
    for row in data.get("rows", []):
        if row.get("phase") == "keygen_poly_gen_matrix":
            calls = row.get("calls", {})
            n_sq = calls.get(CALLERS[version])
            n_gm = calls.get("poly_gen_matrix")
            if n_sq is None or not n_gm:
                return None
            return n_sq, n_gm
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--logs-dir", default=str(REPO / "logs_hkem"))
    args = ap.parse_args()
    logs_dir = Path(args.logs_dir)

    failed = 0
    for version, pkg in VERSIONS.items():
        d = REPO / pkg
        stream, stubs = d / STREAM, d / STUBS
        if not (stream.exists() and stubs.exists()):
            print(f"### {version}: 缺文件（{STREAM} / {STUBS}），跳过")
            continue

        payload, labels = parse_stream(stream)
        n_sess = len(labels)
        # ⚠ 单位：payload 是**字节**；不变量 A 比的是**块**（32 B/块）⇒ 必须 /32，
        #   否则 21 块 ≤ 640「块」会假通过（2026-09-20 踩过）
        stride = payload // n_sess // 32 if n_sess else 0
        sym = parse_copy_stub_sym(stubs)
        so_row = d / "keygen_poly_gen_matrix_stub_overhead_profiling.s"
        rj_row = d / "keygen_poly_gen_matrix_rejection_profiling.s"
        so_replay, _ = count_replays(so_row, sym) if sym else (0, [])
        _, rj_labels = count_replays(rj_row, sym)

        print(f"### {version}")
        print(f"  流文件: 载荷 {payload} B = {payload // 32} 块；{n_sess} 会话；"
              f"每会话配额 {stride} 块（标签步长）")
        print(f"  拷贝桩符号: {sym}（每调用 32 B）；"
              f"stub_overhead replay = {so_replay} 次 = {so_replay * 32} B；"
              f"rejection 引用 {len(rj_labels)} 个会话标签")

        calls = load_app_calls(logs_dir, version)
        if calls is None:
            print(f"  （无 {version}_profiling JSON ⇒ 跳过 A/B 的实测对照）")
        else:
            n_sq, n_gm = calls
            per_sess = n_sq / n_gm
            print(f"  app 实测: {CALLERS[version]} ×{n_sq}、poly_gen_matrix ×{n_gm}"
                  f" ⇒ 每会话 {per_sess:.2f} 块")

            ok = per_sess <= stride
            print(f"  [A] 每会话消费 {per_sess:.2f} ≤ 配额 {stride} : {'✓' if ok else '✗ 越界/静默读邻居'}")
            failed += 0 if ok else 1

            ok = so_replay == n_sq
            print(f"  [B] stub_overhead replay {so_replay} == app 实测 {n_sq} : "
                  f"{'✓' if ok else '✗ 校准行次数陈旧（会在减法里残留偏差）'}")
            failed += 0 if ok else 1

        ok = so_replay * 32 <= payload
        print(f"  [D] 线性游走 {so_replay * 32} B ≤ 载荷 {payload} B : "
              f"{'✓' if ok else '✗ 越界 ⇒ 会读到 NOLOAD 区（DMEM_INTG_VIOLATION）'}")
        failed += 0 if ok else 1

        miss = [l for l in rj_labels if l not in labels]
        ok = not miss
        print(f"  [C] rejection 引用的会话标签都在流文件里 : {'✓' if ok else f'✗ 缺 {miss}'}")
        failed += 0 if ok else 1
        if calls is not None and labels:
            per_sess = calls[0] / calls[1]
            over = [l for l in rj_labels if labels.get(l, 0) + per_sess * 32 > payload]
            ok = not over
            print(f"  [C'] 每个会话消费不越过自己的配额 : "
                  f"{'✓' if ok else f'✗ 越界会话 {over}'}")
            failed += 0 if ok else 1
        print()

    print(f"结论：{'全部一致 ✓' if not failed else f'{failed} 项不一致 ✗（先修数据/行再重测）'}")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
