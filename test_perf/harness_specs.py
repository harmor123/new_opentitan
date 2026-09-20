"""各版本剖面实测行的调用序列规格（供 test_perf/gen_harness.py 生成 .s）。

每个 row 一个 dict：
    op / row / app : 目标名 = mlkem768_<op>_<row>_{profiling,control}，app 用于写头注释
    note           : 该行的语义与调用次数来源（写进生成文件头 + config 注释）
    srcs           : 除调用段与 common_data.s 外还需要链接的文件
    prelude        : 调用序列前的一次性寄存器准备
    calls          : [(重复次数, [汇编行...]), ...]；control 会自动去掉含 jal 的行
    data           : .data 段内容（每行一个字符串）

计数来源：app 源码里 `jal x1, <内核>` 所在 loopi 的迭代数连乘
（ver1_1：keygen 9 gen_matrix / 6 ntt / 6 tobytes / 3 标度 basemul / 9 basemul_acc /
 7 getnoise…；encap 9 gen_matrix / 3 ntt / 3 标度 basemul / 12 basemul_acc / 4 intt /
 7 getnoise / 5 poly_add / 6 frombytes；decap 9 / 6 ntt / 6 标度 basemul / 15 basemul_acc /
 5 intt / 7 getnoise / 5 poly_add / 6 frombytes + 3 decompress_10 + 1 decompress_4 …）。
"""

SCALE_CONST_1024 = [
    "keygen_scale_const_2988:",
    "  .rept 32",
    "  .word 0x00000bac, 0x00000000, 0x00000bac, 0x00000000",
    "  .word 0x00000bac, 0x00000000, 0x00000bac, 0x00000000",
    "  .endr",
]

XOF = "//test_hybrid_kem_otbn_prompt_ver1_1/otbn/kmac_official:xof.s"

# 每版本的前奏（与各版现有 harness 文件一致）与必带数据段、默认附加 srcs
PROLOGUE = {
    "ver1_1": ["  /* 栈指针 x31 ← stack（app 的 crypto_kem_* 入口同样写法；内核压栈用 0(x31)） */",
               "  la   x31, stack",
               "  bn.xor w31, w31, w31",
               "",
               "  /* MOD CSR ← {q = 3329, mu = -q^-1 mod 2^32}，与 app 一致 */",
               "  la   x2, mlkem768_const_params",
               "  bn.lid x0, 0(x2)",
               "  bn.wsrw MOD, w0"],
    "ver0_2": ["  /* 独立栈：ver0_2 内核用 fp 相对寻址（与 app 的 wrapper 同布局） */",
               "  la   x2, stack",
               "  li   x3, 4096",
               "  add  x2, x2, x3",
               "  addi fp, x2, 0"],
    "ver0_1": ["  /* 独立栈：ver0_1 内核用 fp 相对寻址（与 app 的 wrapper 同布局） */",
               "  la   x2, stack",
               "  li   x3, 4096",
               "  add  x2, x2, x3",
               "  addi fp, x2, 0"],
}
MANDATORY_DATA = {"ver1_1": [], "ver0_2": ["stack:", "  .zero 4096"],
                  "ver0_1": ["stack:", "  .zero 4096"]}
DEFAULT_EXTRA = {"ver1_1": ["common_data.s"], "ver0_2": [], "ver0_1": []}


from harness_specs_ver0_2 import SPECS02
from harness_specs_ver0_1 import SPECS01

SPECS = {
    "ver1_1": [
        # ── Encaps ──────────────────────────────────────────────────────
        dict(op="encap", row="intt_x4", app="mlkem_encap",
             note="encap 的 4 次 INTT：u 行循环内 3 次（_encrypt_core）+ v 1 次（_encrypt_u_next）。",
             srcs=["intt.s", "ntt.s"], prelude=[],
             calls=[(4, ["la   x2, poly_a", "addi x3, x2, 0", "jal  x1, intt"])],
             data=["poly_a:", "  .zero 1024"]),
        dict(op="encap", row="noise_x7", app="mlkem_encap",
             note="encap 的 7 次噪声采样：y 行 N=0,1,2 + e1 N=3,4,5 + e2 N=6。",
             srcs=["poly.s", "cbd.s", XOF],
             prelude=["la   x2, sigma", "la   x4, out_poly"],
             calls=[(1, [f"li   x3, {n}", "jal  x1, poly_getnoise_eta_1"]) for n in range(7)],
             data=["sigma:", "  .zero 64", "", ".balign 32", "out_poly:", "  .zero 1024"]),
        dict(op="encap", row="basemul_acc_x12", app="mlkem_encap",
             note="encap 的 basemul 族：3 次标度 basemul（y_hat×2988）+ 12 次 basemul_acc（u 9 + v 3）。",
             srcs=["basemul.s", "ntt.s"],
             prelude=["la   x4, _basemul_twiddles"],
             calls=[(3, ["la   x2, poly_s", "la   x3, keygen_scale_const_2988",
                         "la   x4, _basemul_twiddles", "la   x5, poly_s", "jal  x1, basemul"])] +
                   [(4, ["la   x2, acc_poly", "bn.xor w0, w0, w0", "loopi 32, 1",
                         "  bn.sid x0, 0(x2++)", "  /* End of loop */"] +
                        ["la   x2, poly_a", "la   x3, poly_s", "la   x4, _basemul_twiddles",
                         "la   x5, acc_poly", "la   x6, acc_poly", "jal  x1, basemul_acc"] * 3)],
             data=["poly_a:", "  .zero 1024", "", ".balign 32", "poly_s:", "  .zero 1024",
                   "", ".balign 32", "acc_poly:", "  .zero 1024", "", ".balign 32"] + SCALE_CONST_1024),
        dict(op="encap", row="ntt_x3", app="mlkem_encap",
             note="encap 的 3 次 NTT（y[j] 采样后，_encrypt_core）。",
             srcs=["ntt.s"], prelude=[],
             calls=[(3, ["la   x2, poly_a", "addi x3, x2, 0", "jal  x1, ntt"])],
             data=["poly_a:", "  .zero 1024"]),
        dict(op="encap", row="poly_add_x5", app="mlkem_encap",
             note="encap 的 5 次 poly_add（e1 ×3 + e2 ×1 + μ ×1）。",
             srcs=["poly.s", "cbd.s", XOF], prelude=["la   x3, poly_b"],
             calls=[(5, ["la   x2, poly_a", "la   x4, poly_a", "jal  x1, poly_add"])],
             data=["poly_a:", "  .zero 1024", "", ".balign 32", "poly_b:", "  .zero 1024"]),
        dict(op="encap", row="h_ek", app="mlkem_encap",
             note="encap 的 H(ek) = SHA3-256(pk_t ‖ rho)，2 次 absorb。",
             srcs=[XOF], prelude=[],
             calls=[(1, ["jal  x1, xof_sha3_256_init",
                         "la   x21, input_pk", "li   x20, 1152", "li   x22, 0", "jal  x1, xof_absorb",
                         "la   x21, pk_rho", "li   x20, 32", "li   x22, 0", "jal  x1, xof_absorb",
                         "jal  x1, xof_process",
                         "jal  x1, xof_squeeze32", "bn.xor w0, w29, w30",
                         "li   x5, 0", "la   x12, output_hash", "bn.sid x5, 0(x12)",
                         "jal  x1, xof_finish"])],
             data=["input_pk:", "  .zero 1152", "", ".balign 32", "pk_rho:", "  .zero 32",
                   "", ".balign 32", "output_hash:", "  .zero 32"]),
        # ── Decaps ──────────────────────────────────────────────────────
        dict(op="decap", row="noise_x7", app="mlkem_decap",
             note="decap 的 7 次噪声采样（再加密路径）：y N=0,1,2 + e1 N=3,4,5 + e2 N=6。",
             srcs=["poly.s", "cbd.s", XOF],
             prelude=["la   x2, sigma", "la   x4, out_poly"],
             calls=[(1, [f"li   x3, {n}", "jal  x1, poly_getnoise_eta_1"]) for n in range(7)],
             data=["sigma:", "  .zero 64", "", ".balign 32", "out_poly:", "  .zero 1024"]),
        dict(op="decap", row="basemul_acc_x15", app="mlkem_decap",
             note="decap 的 basemul 族：6 次标度 basemul（解密核 3 + 再加密 3）+ 15 次 basemul_acc（解密 3 + 再加密 12）。",
             srcs=["basemul.s", "ntt.s"],
             prelude=["la   x4, _basemul_twiddles"],
             calls=[(6, ["la   x2, poly_s", "la   x3, keygen_scale_const_2988",
                         "la   x4, _basemul_twiddles", "la   x5, poly_s", "jal  x1, basemul"])] +
                   [(5, ["la   x2, acc_poly", "bn.xor w0, w0, w0", "loopi 32, 1",
                         "  bn.sid x0, 0(x2++)", "  /* End of loop */"] +
                        ["la   x2, poly_a", "la   x3, poly_s", "la   x4, _basemul_twiddles",
                         "la   x5, acc_poly", "la   x6, acc_poly", "jal  x1, basemul_acc"] * 3)],
             data=["poly_a:", "  .zero 1024", "", ".balign 32", "poly_s:", "  .zero 1024",
                   "", ".balign 32", "acc_poly:", "  .zero 1024", "", ".balign 32"] + SCALE_CONST_1024),
        dict(op="decap", row="ntt_x6", app="mlkem_decap",
             note="decap 的 6 次 NTT（解密核 u 3 + 再加密 y 3）。",
             srcs=["ntt.s"], prelude=[],
             calls=[(6, ["la   x2, poly_a", "addi x3, x2, 0", "jal  x1, ntt"])],
             data=["poly_a:", "  .zero 1024"]),
        dict(op="decap", row="intt_x5", app="mlkem_decap",
             note="decap 的 5 次 INTT（解密核 1 + 再加密 u 3 + v 1）。",
             srcs=["intt.s", "ntt.s"], prelude=[],
             calls=[(5, ["la   x2, poly_a", "addi x3, x2, 0", "jal  x1, intt"])],
             data=["poly_a:", "  .zero 1024"]),
        dict(op="decap", row="pack_ciphertext", app="mlkem_decap",
             note="decap 比较前的再压缩：compress_10 ×3（u'）+ compress_4 ×1（v'）。",
             srcs=["pack_ciphertext.s"], prelude=["la   x14, ct_u"],
             calls=[(3, ["la   x2, poly_u", "addi x3, x14, 0", "jal  x1, compress_10",
                         "addi x14, x14, 320"])] +
                   [(1, ["la   x2, poly_v", "la   x3, ct_v", "jal  x1, compress_4"])],
             data=["poly_u:", "  .zero 1024", "", ".balign 32", "poly_v:", "  .zero 1024",
                   "", ".balign 32", "ct_u:", "  .zero 960", "", ".balign 32", "ct_v:", "  .zero 128"]),
        dict(op="decap", row="poly_add_x5", app="mlkem_decap",
             note="decap 的 5 次 poly_add（再加密路径的 e1 ×3 + e2 ×1 + μ ×1）。",
             srcs=["poly.s", "cbd.s", XOF], prelude=["la   x3, poly_b"],
             calls=[(5, ["la   x2, poly_a", "la   x4, poly_a", "jal  x1, poly_add"])],
             data=["poly_a:", "  .zero 1024", "", ".balign 32", "poly_b:", "  .zero 1024"]),
        dict(op="decap", row="hash_g_reuse", app="mlkem_decap",
             note="decap 的 G(m' ‖ h) = SHA3-512，2 次 absorb（m' 与 h 分开吸收）。",
             srcs=[XOF], prelude=[],
             calls=[(1, ["jal  x1, xof_sha3_512_init",
                         "la   x21, input_m", "li   x20, 32", "li   x22, 0", "jal  x1, xof_absorb",
                         "la   x21, input_h", "li   x20, 32", "li   x22, 0", "jal  x1, xof_absorb",
                         "jal  x1, xof_process",
                         "jal  x1, xof_squeeze32", "bn.xor w0, w29, w30",
                         "li   x5, 0", "la   x12, output_K", "bn.sid x5, 0(x12)",
                         "jal  x1, xof_squeeze32", "bn.xor w0, w29, w30",
                         "li   x5, 0", "la   x12, output_r", "bn.sid x5, 0(x12)",
                         "jal  x1, xof_finish"])],
             data=["input_m:", "  .zero 32", "", ".balign 32", "input_h:", "  .zero 32",
                   "", ".balign 32", "output_K:", "  .zero 32", "", ".balign 32",
                   "output_r:", "  .zero 32"]),
        dict(op="decap", row="unpack_sk_pk", app="mlkem_decap",
             note="decap 的 6 次 poly_frombytes（sk_s 解码 3 + 再加密 t_hat 解码 3）。",
             srcs=["pack_keys.s"], prelude=["la   x14, input_bytes", "la   x15, poly_out"],
             calls=[(6, ["addi x2, x14, 0", "addi x3, x15, 0", "jal  x1, poly_frombytes",
                         "addi x14, x14, 384", "addi x15, x15, 1024"])],
             data=["input_bytes:", "  .zero 2304", "", ".balign 32", "poly_out:", "  .zero 1024"]),
        dict(op="decap", row="poly_frommsg_reuse", app="mlkem_decap",
             note="decap 的 1 次 poly_frommsg（再加密路径 μ = Decompress_1(m')）。",
             srcs=["poly.s", "cbd.s", XOF], prelude=[],
             calls=[(1, ["la   x2, input_message", "la   x3, output_poly",
                         "jal  x1, poly_frommsg"])],
             data=["input_message:", "  .zero 32", "", ".balign 32", "output_poly:", "  .zero 1024"]),
    ],

    "ver0_2": SPECS02,
    "ver0_1": SPECS01,
}
