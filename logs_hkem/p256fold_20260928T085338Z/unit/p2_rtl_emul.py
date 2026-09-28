#!/usr/bin/env python3
"""P2 SV 语义预检：逐句模拟 hw/ip/otbn/rtl/otbn_p256_fold.sv，与模型逐拍比对。

用途与边界（必须一起读）：
  * 本脚本把 SV 的**调度与算术语句**逐句转写成 Python，再与 `p256_fold_model.py` 的
    `light()`/`mac()` 逐拍比对 ⇒ 它检查的是「SV 源码语义 vs 模型」，**不是** RTL 仿真结果；
  * 真正判 P2 的是 Verilator 单模块 testbench（`p2_inject.log` + `compare_to_model.py`）。
  本脚本的价值：在去 Linux 之前把调度/位宽/拼接错误暴露在纯 py 层（Windows 侧可跑）。
  * KD LUT 不是重算，而是**从 .sv 文件里解析** localparam 常量，再断言 == (k·d) & MASKW，
    这样 SV 里嵌的常数也被检查到。

用法：PYTHONUTF8=1 python3 p2_rtl_emul.py [--vectors p2_vectors.json] [--rtl ../../../../hw/ip/otbn/rtl/otbn_p256_fold.sv]
"""
import argparse
import hashlib
import importlib.util
import json
import random
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]                      # logs_hkem/<run>/unit → 仓库根
W = 260
MASKW = (1 << W) - 1
MASK128 = (1 << 128) - 1


def sgn(x):
    """260-bit 二补码解释（与 SV 的 signed [W-1:0] 一致）。"""
    x &= MASKW
    return x - (1 << W) if x >> (W - 1) else x


def file_sha256_lf(path):
    """跨平台哈希口径：Windows 工作树是 CRLF、git blob 是 LF ⇒ 先归一化再哈希。"""
    return hashlib.sha256(Path(path).read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def k4(x):
    """4-bit 二补码解释（与 SV 的 signed [3:0] 一致）：0xc…0xf → −4…−1。"""
    x &= 0xF
    return x - 16 if x >= 8 else x


CASE_LABEL = re.compile(r"\b\d*'([bdh])([0-9a-fA-F]+)\b")


def check_unique_case(rtl_path):
    """静态检查：每个 `unique case` 块内标签不得重复。

    动机（本 run 实测踩到）：SV 的 case 是**首个匹配项胜出**，若同一个值出现在两个 item 里，
    后面的 item 被静默遮蔽（Verilator 只报 `CASEOVERLAP` 警告，而它默认把警告当错误才不至于漏）。
    逐句转写的模拟器用独立 `if` 复现语义，**看不到**这个问题 ⇒ 必须单独做源码级检查。
    """
    txt = rtl_path.read_text(encoding="utf-8")
    bad = []
    for m in re.finditer(r"unique case\s*\(([^)]*)\)", txt):
        try:
            end = txt.index("endcase", m.end())
        except ValueError:
            bad.append((m.start(), "缺 endcase"))
            continue
        body = txt[m.end():end]
        seen = {}
        for raw in body.splitlines():
            line = raw.split("//")[0]                       # 去注释
            # 只认**item 头部**的标签（`5'd3: …`）或**续行标签列表**（`5'd10, 5'd11,`）；
            # 语句中间的常量（如 `cpa_b = 1'b1;`、`{{(W-256){1'b0}}}`）不算标签
            m_head = re.match(r"^\s*((?:\d*'[bdh][0-9a-fA-F]+\s*,\s*)*\d*'[bdh][0-9a-fA-F]+)\s*:\s*\S", line)
            m_cont = re.match(r"^\s*((?:\d*'[bdh][0-9a-fA-F]+\s*,\s*)*\d*'[bdh][0-9a-fA-F]+)\s*,\s*$", line)
            grp = m_head.group(1) if m_head else (m_cont.group(1) if m_cont else None)
            if grp is None:
                continue
            for (b, v) in CASE_LABEL.findall(grp):
                key = "%s'%s" % (b, v.lower())
                seen[key] = seen.get(key, 0) + 1
        dup = sorted(k for k, n in seen.items() if n > 1)
        if dup:
            line = txt[:m.start()].count("\n") + 1
            bad.append((line, "%s（重复标签 %s）" % (m.group(1).strip(), dup)))
        # 同一 case 里也检查 default 只出现一次
        if body.count("default:") > 1:
            line = txt[:m.start()].count("\n") + 1
            bad.append((line, "多个 default"))
    return bad


def parse_kd(rtl_path):
    """从 .sv 解析 KD_xx localparam（返回 {k: 260-bit 常量}）。"""
    txt = rtl_path.read_text(encoding="utf-8")
    lut = {}
    for m_ in re.finditer(r"KD_(\d\d)\s*=\s*W'\(260'h([0-9a-f]+)\);\s*//\s*k=\s*(-?\d+)", txt):
        idx, hexval, k = int(m_.group(1)), int(m_.group(2), 16), int(m_.group(3))
        assert idx == k + 4, (idx, k)         # 索引 = k+4
        lut[k] = hexval
    assert len(lut) == 12, len(lut)
    return lut


def parse_p260(rtl_path):
    txt = rtl_path.read_text(encoding="utf-8")
    m_ = re.search(r"P260\s*=\s*W'\(260'h([0-9a-f]+)\)", txt)
    return int(m_.group(1), 16)


class Fold:
    """otbn_p256_fold.sv 的逐句转写（寄存器状态；每拍记录可观测视图）。"""

    def __init__(self, kd, p260):
        self.kd = kd
        self.p260 = p260
        self.reset()

    def reset(self):
        self.cycle = 31
        self.busy = False
        self.f = 0
        self.h = 0
        self.ll = 0
        self.acc130 = 0
        self.k = 0
        self.wd_valid = False
        self.wd = 0

    # --- 前端 row mux：与 .sv 的八条 assign 逐句对应（h 字 j = h[32*j +: 32]） ---
    def words(self):
        return [(self.h >> (32 * j)) & 0xFFFFFFFF for j in range(8)]

    def rows(self):
        w = self.words()
        z = 0
        v_a = (w[7] << 224) | (w[6] << 192) | (w[5] << 160) | (w[4] << 128) | (w[3] << 96) | (z << 64) | (z << 32) | z
        v_b = (z << 224) | (w[7] << 192) | (w[6] << 160) | (w[5] << 128) | (w[4] << 96) | (z << 64) | (z << 32) | z
        v_p0 = (w[0] << 224) | (w[5] << 192) | (w[7] << 160) | (w[6] << 128) | (w[5] << 96) | (w[2] << 64) | (w[1] << 32) | w[0]
        v_p1 = (w[7] << 224) | (w[6] << 192) | (z << 160) | (z << 128) | (z << 96) | (w[3] << 64) | (w[2] << 32) | w[1]
        v_m0 = (w[2] << 224) | (w[0] << 192) | (w[2] << 160) | (w[1] << 128) | (w[0] << 96) | (w[5] << 64) | (w[4] << 32) | w[3]
        v_m1 = (w[3] << 224) | (w[1] << 192) | (w[3] << 160) | (w[2] << 128) | (w[1] << 96) | (w[6] << 64) | (w[5] << 32) | w[4]
        v_m2 = (w[4] << 224) | (z << 192) | (z << 160) | (z << 128) | (w[7] << 96) | (w[7] << 64) | (w[6] << 32) | w[5]
        v_m3 = (w[5] << 224) | (z << 192) | (z << 160) | (z << 128) | (z << 96) | (z << 64) | (w[7] << 32) | w[6]
        return {
            10: (v_a << 1) & MASKW,                                     # 2A
            11: (v_b << 1) & MASKW,                                     # 2Bv
            12: v_p0,                                                   # P0
            13: v_p1,                                                   # P1
            14: (~v_m0) & MASKW,                                        # −M0（反相 + 进位）
            15: (~v_m1) & MASKW,
            16: (~v_m2) & MASKW,
            17: (~v_m3) & MASKW,
        }

    def cpa(self):
        """与 .sv 的 always_comb（operand mux）逐句对应；返回 (a, b, sub)。"""
        a, b, sub = self.f & MASKW, 0, 0
        if self.busy:
            c = self.cycle
            if c in (10, 11, 12, 13, 14, 15, 16, 17):
                b, sub = self.rows()[c], 1 if c in (14, 15, 16, 17) else 0
            elif c == 18:
                b = ((self.acc130 << 128) | self.ll) & MASKW        # L0：258 位零扩，绝不截断
            elif c == 19:
                a = self.f & ((1 << 256) - 1)                        # x = F[255:0]（§5：CPA 第一输入切为 zero-extended x）
                b = self.kd[k4(self.f >> (W - 4))]                   # k·d（12 项常量 LUT）
            elif c == 20:
                # 第二输入切为 ±p：T<0 ⇒ +p（原样，进位 0）；T≥0 ⇒ −p（反相 + 进位）
                if (self.f >> (W - 1)) & 1:
                    b, sub = self.p260, 0
                else:
                    b, sub = (~self.p260) & MASKW, 1
        return a, b, sub

    def step(self, start=0, abort=0, wipe=0, pre_so=0, acc_after=0):
        """推进一拍（组合次态 + 时序）。

        返回**本拍周期末锁存后**的可观测视图，键 `cycle` = 刚完成的周期号
        （§8 约定：结果在该周期末锁存、下一周期可用）。"""
        done = self.cycle if self.busy else 31

        # ---- 组合次态（与 always_comb 逐句对应）----
        cycle_d, busy_d = self.cycle, self.busy
        f_d, h_d, ll_d, acc_d, k_d = self.f, self.h, self.ll, self.acc130, self.k
        wd_valid_d, wd_d = False, self.wd
        a, b, sub = self.cpa()
        ext = sgn(a) + sgn(b) + sub                       # 261 位精确和（Python 无限精度）

        if start:
            cycle_d, busy_d = 0, True
            f_d = h_d = ll_d = acc_d = k_d = 0
            wd_valid_d = False
        elif self.busy:
            cycle_d = (self.cycle + 1) & 0x1F
            busy_d = False if self.cycle == 21 else True
            if self.cycle == 19:
                k_d = (self.f >> (W - 4)) & 0xF
            c = self.cycle
            if c == 3:
                f_d = (pre_so & MASK128) << 128
            elif c == 9:
                h_d = pre_so & ((1 << 256) - 1)
            elif c == 12:
                ll_d = pre_so & MASK128
            elif c == 15:
                acc_d = acc_after & ((1 << 130) - 1)
            if c in (10, 11, 12, 13, 14, 15, 16, 17, 18, 19):
                f_d = ext & MASKW
            elif c == 20:
                f_d = (ext & MASKW) if (((self.f >> (W - 1)) & 1) or not ((ext >> (W - 1)) & 1)) else self.f
            elif c == 21:
                wd_d, wd_valid_d = self.f & ((1 << 256) - 1), (not abort)
        else:
            cycle_d = 31

        if abort or wipe:
            f_d = h_d = ll_d = acc_d = k_d = 0
            wd_valid_d = False
            if abort:
                busy_d, cycle_d = False, 31

        # ---- 时序 ----
        self.cycle, self.busy, self.f, self.h = cycle_d, busy_d, f_d & MASKW, h_d
        self.ll, self.acc130, self.k = ll_d, acc_d, k_d
        self.wd_valid, self.wd = wd_valid_d, wd_d
        return {"cycle": done, "busy": self.busy, "F": self.f & MASKW, "h": self.h,
                "ll": self.ll, "acc130": self.acc130, "k": self.k,
                "wd_valid": self.wd_valid, "wd": self.wd}


def run_vector(vec, kd, p260):
    """跑一条向量，返回 (逐拍 F 对照表, 错误列表)。"""
    dut = Fold(kd, p260)
    H = int(vec["H"], 16)
    high = int(vec["high"], 16)
    ll = int(vec["LL"], 16)
    acc130 = int(vec["ACC130"], 16)
    obs = {}
    if vec["source"] == "mac":
        pre = [int(x, 16) for x in vec["mac_taps"]["pre_so"]]
        aft = [int(x, 16) for x in vec["mac_taps"]["acc_after"]]
    else:
        pre = [0] * 16
        aft = [0] * 16
    errs = []
    dut.step(start=1)
    for c in range(0, 22):
        if vec["source"] == "mac":
            p_so, a_so = pre[c] if c < 16 else 0, aft[c] if c < 16 else 0
        else:  # inject：四个采样周期给出对应值，其余周期为 0
            p_so = {3: H >> 128, 9: high, 12: ll}.get(c, 0)
            a_so = acc130 if c == 15 else 0
        o = dut.step(pre_so=p_so, acc_after=a_so)
        assert o["cycle"] == c, (o["cycle"], c)
        obs[c] = o                           # 周期 c 末锁存后的视图
    # 采样点核对（三个 off-by-one 断言的正面对照点）
    if obs[3]["F"] != H:
        errs.append("H capture: F@c3 == 0x%x != H" % obs[3]["F"])
    if obs[9]["h"] != high:
        errs.append("high capture: h@c9 != high")
    if obs[12]["ll"] != ll:
        errs.append("LL capture: LL@c12 != LL")
    if obs[15]["acc130"] != acc130:
        errs.append("ACC130 capture: @c15 != ACC130")
    # 逐拍 F 对照（模型 fold trace 的 cycle c == RTL 在 c 拍末锁存的值）
    rows = []
    for cyc, f_model in sorted(vec["fold_F"].items(), key=lambda kv: int(kv[0])):
        c = int(cyc)
        got = obs[c]["F"]
        want = int(f_model, 16) & MASKW
        rows.append((c, got, want, got == want))
        if got != want:
            errs.append("F mismatch @c%d: rtl 0x%x model 0x%x" % (c, got, want))
    # k 与写回
    if obs[19]["k"] != (vec["q"] & 0xF):
        errs.append("k@c19 != q")
    if not obs[21]["wd_valid"] or obs[21]["wd"] != int(vec["result"], 16):
        errs.append("wd@c21 != result")
    # 完成周期固定（c21 后 busy 落 0，再一拍进 idle）
    if dut.busy or dut.cycle != 22:
        errs.append("completion: cycle=%d busy=%d（应 c22 且 busy=0）" % (dut.cycle, dut.busy))
    dut.step()
    if dut.cycle != 31 or dut.busy:
        errs.append("idle: cycle=%d（应为 31）" % dut.cycle)
    return rows, errs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--vectors", type=Path, default=HERE / "p2_vectors.json")
    ap.add_argument("--rtl", type=Path,
                    default=REPO / "hw/ip/otbn/rtl/otbn_p256_fold.sv")
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--fuzz", type=int, default=0,
                    help="额外随机 (a,b) 组数（同一条向量检查，不进 JSON）")
    args = ap.parse_args()

    kd = parse_kd(args.rtl)
    case_bad = check_unique_case(args.rtl)
    if case_bad:
        for (line, why) in case_bad:
            print("unique case 检查 FAIL: 行 %s: %s" % (line, why))
        raise SystemExit(1)
    print("unique case 检查: OK（各块标签唯一、default 唯一）")
    p260 = parse_p260(args.rtl)
    # KD LUT 自检（SV 内嵌常量 vs 模型现算）
    spec = importlib.util.spec_from_file_location("m", HERE.parent / "model" / "p256_fold_model.py")
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    assert p260 == m.P, "SV 的 P260 与模型 P 不一致"
    assert kd == {k: (k * m.D) & MASKW for k in range(-4, 8)}, "KD LUT 与模型 k·d 不一致"
    print("KD LUT 自检: OK（12 项 == 模型 k·d，P260 == 模型 P）")

    doc = json.loads(args.vectors.read_text())
    total_err = 0
    fixed_cycles = set()
    for vec in doc["vectors"]:
        rows, errs = run_vector(vec, kd, p260)
        total_err += len(errs)
        if args.verbose:
            for (c, got, want, eq) in rows:
                print("  c%-2d rtl=0x%064x model=0x%064x %s" % (c, got, want, "OK" if eq else "**"))
        print("%-24s %-6s 拍数=%d  %s" % (vec["name"], vec["source"], len(rows),
                                          "OK" if not errs else "FAIL: " + "; ".join(errs)))
    print("vectors: %d, mismatches: %d" % (len(doc["vectors"]), total_err))
    if args.fuzz:
        mv_spec = importlib.util.spec_from_file_location("mv", HERE / "make_vectors.py")
        mv = importlib.util.module_from_spec(mv_spec)
        mv_spec.loader.exec_module(mv)
        rng = random.Random(0x5EED)
        fuzz_err = 0
        for i in range(args.fuzz):
            a, b = rng.randrange(mv.P), rng.randrange(mv.P)
            vec = mv.build_mac(a, b, "fuzz_%04d" % i, "fuzz")
            _, errs = run_vector(vec, kd, p260)
            if errs:
                fuzz_err += len(errs)
                print("fuzz %d FAIL: %s" % (i, "; ".join(errs)))
        print("fuzz: %d 条随机 (a,b), mismatches: %d" % (args.fuzz, fuzz_err))
        total_err += fuzz_err
    print("rtl sha256(LF 归一化，等于 git blob): %s" % file_sha256_lf(args.rtl))
    raise SystemExit(1 if total_err else 0)


if __name__ == "__main__":
    main()
