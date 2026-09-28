#!/usr/bin/env python3
"""P2 Step 6：由位精确模型生成单元验证向量（被测单元 = hw/ip/otbn/rtl/otbn_p256_fold.sv）。

产出 `p2_vectors.json`。两类向量（对应 PDF §11 P2 的**两步顺序**）：

* `source = "mac"`   —— 16 步真实 MAC 序列的派生量：含 (a,b)、16 拍 tap
                        （pre_so = shift-out 前；acc_after = shift-out 后）⇒ Step 5 用；
* `source = "inject"` —— 直接注入 (H, high, LL, ACC130) 的独立字盒用例 ⇒ Step 2 用。
                        极值 k/T 只在这种用例上可达（真实 (a,b)<p 的乘积覆盖不到），
                        与模型 verify_algebra() 的独立 word box 口径一致。

两类都含：H / high / LL / ACC130 / L0 / h[8] / R / T / q / result / 逐拍 F（fold trace）
与四个采样周期号（H=3, high=9, LL=12, ACC130=15）、完成周期 22。

覆盖 §11 P2 必测清单：全零 / 1 / p−1 / 2^32,64,128,192 边界 / 低位全 1 /
输入全 256-bit 全 1 / 长进位 / 负 C / L≥N / 2A 的 bit256=1 / k 边界 / T 边界。
「连续两次操作使用不同输入」是 testbench 场景（同一仿真跑两次会话），不在单条向量内。

用法：PYTHONUTF8=1 python3 make_vectors.py
（不手抄任何常数：全部由模型现算；并对模型自身的断言做交叉核对。）
"""
import hashlib
import importlib.util
import itertools
import json
import random
from pathlib import Path

# 跨平台文件哈希口径：Windows 工作树是 CRLF、git blob 是 LF ⇒ 一律先 CRLF→LF 归一化再哈希。
def file_sha256_lf(path):
    return hashlib.sha256(Path(path).read_bytes().replace(b"\r\n", b"\n")).hexdigest()

HERE = Path(__file__).resolve().parent
MODEL = HERE.parent / "model" / "p256_fold_model.py"
OUT = HERE / "p2_vectors.json"

N = 1 << 256
B = 1 << 64
Q = 1 << 32
MASK128 = (1 << 128) - 1
MASK130 = (1 << 130) - 1

spec = importlib.util.spec_from_file_location("m", MODEL)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
P = m.P

_lean = {}


def lean(a, b):
    """轻量字段（mac + terms + 小商折叠），供搜索用；与 build_mac() 共用同一算术路径。"""
    if (a, b) not in _lean:
        high, seed, low, _ = m.mac(a, b)
        h = [(high >> (32 * i)) & (m.Q - 1) for i in range(8)]
        R = seed + sum(m.terms(h)) + low
        T, q = m.quotient_fold(R)
        _lean[(a, b)] = (high, seed, low, h, q, T, R)
    return _lean[(a, b)]


def mac_taps(a, b):
    """与模型 mac() 同构的 16 拍 tap：pre_so = 加法后 shift-out 前；acc_after = shift-out 后。"""
    aa = [(a >> (64 * i)) & (B - 1) for i in range(4)]
    bb = [(b >> (64 * i)) & (B - 1) for i in range(4)]
    acc = 0
    pre_so, acc_after = [], []
    for (i, j, sh, zero, so) in m.MAC_STEPS:
        if zero:
            acc = 0
        acc = acc + (aa[i] * bb[j] << sh)
        assert 0 <= acc < N
        pre_so.append(acc)
        if so:
            acc >>= 128
        acc_after.append(acc)
    return pre_so, acc_after


def truncated_result(h, seed, low_trunc):
    """把 L0 截成 {ACC[127:0], LL[127:0]} 后的结果；越界（模型断言失败）返回 None。"""
    try:
        f = seed
        for x in m.terms(h):
            f = m.checked_add(f, x)
        f = m.checked_add(f, low_trunc)
        t, q = m.quotient_fold(f)
        return m.correction(t)
    except AssertionError:
        return None


def finish(vec, h, seed, low, name, covers):
    """公共尾部：跑模型 light() 取 R/T/q/result 与逐拍 F，并做一致性核对。"""
    high = sum(h[i] << (32 * i) for i in range(8))
    got, st = m.light(h, seed, low, trace=True)
    acc130 = (low >> 128) & MASK130
    ll = low & MASK128
    # Step 4 的失败用例：截断 ACC[129:128] 后结果必须不同（否则该用例对 P2 无判别力）
    trunc = truncated_result(h, seed, ((acc130 & MASK128) << 128) | ll)
    vec.update({
        "name": name,
        "covers": covers,
        "H": hex(seed),
        "high": hex(high),
        "LL": hex(ll),
        "ACC130": hex(acc130),
        "L0": hex(low),
        "h": [hex(x) for x in h],
        "R": hex(st["R"]),
        "T": hex(st["T"]),
        "q": st["q"],
        "result": hex(got),
        "result_trunc": hex(trunc) if trunc is not None else None,
        "trunc_differs": (trunc is None) or (trunc != got),
        "acc130_hi_nonzero": (acc130 >> 128) != 0,
        "fold_F": {str(r["cycle"]): r["F"] for r in st["trace"]},
        "op_by_cycle": {str(r["cycle"]): r["op"] for r in st["trace"]},
        "completion_cycles": 22,
    })
    # L0 可由 ACC130 与 LL 重建（本单元的核心拼接契约）
    assert vec["L0"] == hex((int(vec["ACC130"], 16) << 128) | int(vec["LL"], 16)), name
    assert got == (seed + low + (high << 256)) % P, name      # §14.1 恒等式
    return vec


_mac_cache = {}


def build_mac(a, b, name, covers):
    if (a, b) not in _mac_cache:
        high, seed, low, h, q, T, R = lean(a, b)
        pre_so, acc_after = mac_taps(a, b)
        # 交叉核对：tap 派生量 == 模型 mac() 的返回值（逐位）
        assert (pre_so[3] & MASK128) << 128 == seed
        assert pre_so[9] == high
        assert (pre_so[12] & MASK128) == (low & MASK128)
        assert acc_after[15] == (low >> 128)
        assert ((acc_after[15] << 128) | (low & MASK128)) == low
        assert acc_after[15] < (1 << 130)                     # ACC130 tap 130 位足够
        assert (a * b) % P == m.light(h, seed, low)[0]        # 与模型最终结论独立核对
        vec = {"source": "mac", "a": hex(a), "b": hex(b),
               "mac_taps": {"pre_so": [hex(x) for x in pre_so],
                            "acc_after": [hex(x) for x in acc_after]}}
        finish(vec, h, seed, low, name, covers)
        assert vec["R"] == hex(R) and vec["T"] == hex(T) and vec["q"] == q
        _mac_cache[(a, b)] = vec
    out = dict(_mac_cache[(a, b)])
    out["name"] = name
    out["covers"] = covers
    return out


def build_inject(h, seed, low, name, covers):
    vec = {"source": "inject", "a": None, "b": None}
    finish(vec, h, seed, low, name, covers)
    return vec


def longest_ones(x):
    run = 0
    while x:
        x &= x << 1          # 每轮消掉每段连续 1 的最高位 ⇒ 轮数 = 最长段长
        run += 1
    return run


def carry_run(t):
    """进位链度量：F ^ 行项（260-bit 二补码）中最长连续 1 串。"""
    high, seed, low, h, q, T, R = t
    f = seed
    worst = 0
    for x in m.terms(h) + [low]:
        worst = max(worst, longest_ones((f ^ (x if x >= 0 else x + (1 << m.W))) & m.MASKW))
        f += x
    return worst


def corner_box():
    """独立字盒（与模型 verify_algebra 同口径）：h ∈ {0,Q−1}^8 × seed × low。

    seed 必须满足物理约束：seed = (MAC[127:0]) << 128 ⇒ **低 128 位恒为 0**
    （故不能用 N−1 这类非法值）。low = L0 可取 [0, 3N) 内任意值（258-bit 拼接）。"""
    for h in itertools.product([0, Q - 1], repeat=8):
        for seed in (0, N - (1 << 192), ((1 << 128) - 1) << 128):
            for low in (0, N, 2 * N, 3 * N - 1):
                yield list(h), seed, low


HEADER = HERE.parents[2] / "hw/ip/otbn/pre_dv" / "otbn_p256_fold_vectors.h"


def _w9(v):
    return ", ".join("0x%08xu" % ((v >> (32 * i)) & 0xFFFFFFFF) for i in range(9))


def _arr(v):
    return "{ " + _w9(v) + " }"


def emit_header(doc, path):
    """把向量编成 C++ 头文件（TB 无需解析 JSON、无需运行时文件依赖）。"""
    sc = doc["sample_cycles"]
    L = ["// 自动生成，**请勿手改**：由 logs_hkem/<run>/unit/make_vectors.py 从 p256_fold_model.py 现算。",
         "// 供 hw/ip/otbn/pre_dv/otbn_p256_fold_tb.cpp 使用。",
         "// 打包口径：Verilator 4.x 把宽信号按 32-bit 字打包，**低字在前**（word i 覆盖 bit[32i+31:32i]）。",
         "#ifndef OPENTITAN_HW_IP_OTBN_PRE_DV_OTBN_P256_FOLD_VECTORS_H_",
         "#define OPENTITAN_HW_IP_OTBN_PRE_DV_OTBN_P256_FOLD_VECTORS_H_",
         "",
         "#include <cstdint>",
         "",
         "static constexpr int kP2Words = 9;   // 9*32 = 288 bit >= 260",
         "static constexpr int kP2SampleH = %d;" % sc["H"],
         "static constexpr int kP2SampleHigh = %d;" % sc["high"],
         "static constexpr int kP2SampleLL = %d;" % sc["LL"],
         "static constexpr int kP2SampleACC = %d;" % sc["ACC130"],
         "static constexpr int kP2Completion = %d;" % doc["completion_cycles"],
         "",
         "struct P2FoldF { int cycle; uint32_t F[kP2Words]; };",
         "",
         "struct P2Vector {",
         "  const char *name;",
         "  int q;                     // 模型商 k（-4…7）",
         "  int source;                // 0 = inject（直接注入四采样）；1 = mac（16 拍真实序列）",
         "  uint32_t H[kP2Words], high[kP2Words], LL[kP2Words], ACC130[kP2Words], L0[kP2Words];",
         "  uint32_t result[kP2Words];              // 正确结果",
         "  uint32_t result_trunc[kP2Words];        // L0 截成 {ACC[127:0],LL[127:0]} 时的结果",
         "  int trunc_differs;                      // 1 = 截断改变结果（该向量对 Step 4 有效）",
         "  int acc130_hi_nonzero;                  // 1 = ACC130[129:128] != 0",
         "  const uint32_t (*pre_so)[kP2Words];     // mac: 16 拍 tap；inject: nullptr",
         "  const uint32_t (*acc_after)[kP2Words];  // 同上",
         "  int n_fold;",
         "  P2FoldF fold[13];",
         "};",
         ""]
    for i, v in enumerate(doc["vectors"]):
        if v["source"] != "mac":
            continue
        slug = "v%02d" % i
        for nm, key in (("pre", "pre_so"), ("acc", "acc_after")):
            L.append("static const uint32_t %s_%s[16][kP2Words] = {" % (slug, nm))
            for x in v["mac_taps"][key]:
                L.append("  %s," % _arr(int(x, 16)))
            L.append("};")
        L.append("")
    L.append("static const P2Vector kP2Vectors[] = {")
    for i, v in enumerate(doc["vectors"]):
        slug = "v%02d" % i
        folds = sorted((int(c), int(f, 16)) for c, f in v["fold_F"].items())
        fl = ", ".join("{ %d, %s }" % (c, _arr(f)) for c, f in folds)
        taps = ("%s_pre, %s_acc" % (slug, slug)) if v["source"] == "mac" else "nullptr, nullptr"
        L.append("  // %s / %s" % (v["name"], v["covers"]))
        L.append("  { %s, %d, %d, %s, %s, %s, %s, %s, %s, %s, %d, %d, %s, %d, { %s } },"
                 % (json.dumps(v["name"], ensure_ascii=True), v["q"],
                    1 if v["source"] == "mac" else 0,
                    _arr(int(v["H"], 16)), _arr(int(v["high"], 16)), _arr(int(v["LL"], 16)),
                    _arr(int(v["ACC130"], 16)), _arr(int(v["L0"], 16)), _arr(int(v["result"], 16)),
                    _arr(int(v["result_trunc"], 16) if v["result_trunc"] else 0),
                    int(v["trunc_differs"]), int(v["acc130_hi_nonzero"]), taps, len(folds), fl))
    L += ["};",
          "",
          "static constexpr int kP2NumVectors = (int)(sizeof(kP2Vectors) / sizeof(kP2Vectors[0]));",
          "",
          "#endif  // OPENTITAN_HW_IP_OTBN_PRE_DV_OTBN_P256_FOLD_VECTORS_H_"]
    path.write_text("\n".join(L) + "\n", encoding="utf-8")


def main():
    rng = random.Random(0x2560960224)          # 固定种子：结果可复现
    pool = [(rng.randrange(P), rng.randrange(P)) for _ in range(20000)]
    vectors = []

    vectors.append(build_mac(0, 0, "01_zero", "全零"))
    vectors.append(build_mac(1, 1, "02_one", "1"))
    vectors.append(build_mac(P - 1, P - 1, "03_p_minus_1_squared", "p−1"))
    vectors.append(build_mac(1 << 32, 1 << 32, "04_q32_boundary", "2^32 边界"))
    vectors.append(build_mac(1 << 64, 1 << 64, "05_q64_boundary", "2^64 边界"))
    vectors.append(build_mac(1 << 128, 1 << 128, "06_q128_boundary", "2^128 边界"))
    vectors.append(build_mac(1 << 192, 1 << 192, "07_q192_boundary", "2^192 边界"))
    vectors.append(build_mac(MASK128, MASK128, "08_low_half_all_ones", "低位全 1"))
    vectors.append(build_mac(N - 1, N - 1, "09_full_256_all_ones", "输入全 256-bit 全 1"))

    # 长进位：在全域搜最长进位链（门槛 64 位）
    corners = [(P - 1 - i, N - 1 - j) for i in range(64) for j in range(64)]
    best = max((carry_run(lean(a, b)), a, b) for (a, b) in corners + pool)
    v10 = build_mac(best[1], best[2], "10_long_carry", "长进位")
    v10["carry_run_bits"] = best[0]
    assert v10["carry_run_bits"] >= 64, v10["carry_run_bits"]
    vectors.append(v10)

    # 负 C：取模型归档的真实归约操作数例子（两者 < p）
    res = json.loads((HERE.parent / "model" / "model_results.json").read_text())
    ex = res["actual_reduced_operand_example_requiring_290_signed_bits"]
    assert ex is not None
    vectors.append(build_mac(int(ex["a"], 16), int(ex["b"], 16), "11_negative_C", "负 C"))

    # L ≥ N：真实乘积里 L0 超过 2^256 的一组
    v, a, b = max((lean(a, b)[2], a, b) for (a, b) in pool)
    assert v >= N, v
    vectors.append(build_mac(a, b, "12_L_ge_N", "L≥N"))

    # 2A 的 bit256 = 1（v_a 顶字 h7 ≥ 2^31 ⇒ 2A ≥ 2^256）
    v, a, b = max((lean(a, b)[3][7], a, b) for (a, b) in pool)
    assert v >= (1 << 31), v
    vectors.append(build_mac(a, b, "13_two_A_bit256_set", "2A 的 bit256=1"))

    # k 边界与 T 边界：独立字盒（真实 (a,b)<p 覆盖不到 k=−4）
    box = list(corner_box())
    for k in (-4, 7):
        hits = [(h, s, l) for (h, s, l) in box if m.quotient_fold(m.light(h, s, l)[1]["R"])[1] == k]
        assert hits, k
        h, s, l = hits[0]
        vectors.append(build_inject(h, s, l, "14_k_boundary_k=%d" % k, "k 边界（k=%d）" % k))

    for want, tag in (("max", "15a_T_max"), ("min", "15b_T_min")):
        best = None
        for (h, s, l) in box:
            T = m.light(h, s, l)[1]["T"]
            if best is None or (want == "max" and T > best[0]) or (want == "min" and T < best[0]):
                best = (T, h, s, l)
        vectors.append(build_inject(best[1], best[2], best[3], tag, "T 边界（%s）" % want))

    # 随机补充（真实 MAC 序列）
    for idx in range(4):
        (a, b) = pool[idx]
        vectors.append(build_mac(a, b, "16_rand_%02d" % (idx + 1), "随机补充"))

    doc = {
        "note": "P2 单元向量；由 make_vectors.py 从 p256_fold_model.py 现算，无手抄常数",
        "sample_cycles": {"H": 3, "high": 9, "LL": 12, "ACC130": 15},
        "completion_cycles": 22,
        "model_sha256_lf": file_sha256_lf(MODEL),   # CRLF→LF 归一化 ⇒ 等于 git blob 的哈希
        "vector_count": len(vectors),
        "sources": {"mac": sum(1 for v in vectors if v["source"] == "mac"),
                    "inject": sum(1 for v in vectors if v["source"] == "inject")},
        "vectors": vectors,
    }
    OUT.write_text(json.dumps(doc, indent=2) + "\n")
    emit_header(doc, HEADER)
    print("wrote %s" % OUT)
    print("wrote %s（%d B，TB 的编译期向量表）"
          % (HEADER, HEADER.stat().st_size))
    for v in vectors:
        print("  %-24s %-6s q=%2d L0>=N:%d h7top=0x%s %s"
              % (v["name"], v["source"], v["q"], int(v["L0"], 16) >= N, v["h"][7][2:4],
                 ("carry=%d" % v["carry_run_bits"]) if "carry_run_bits" in v else ""))
    print("vectors: %d（mac %d / inject %d）" % (len(vectors), doc["sources"]["mac"],
                                                doc["sources"]["inject"]))
    print("k 覆盖: %s" % sorted({v["q"] for v in vectors}))
    print("L0>=N 条数: %d ；2A.bit256=1 条数: %d"
          % (sum(1 for v in vectors if int(v["L0"], 16) >= N),
             sum(1 for v in vectors if (int(v["h"][7], 16) >> 31) & 1)))
    print("p2_vectors.json sha256: %s" % hashlib.sha256(OUT.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
