"""ver0_2 的剖面实测行规格（供 test_perf/tools/gen/gen_harness.py 生成 .s）。

行名与 config 里原有的 reuse 行一致，但这里**在它所属的 op 里真实调用**
（次数 = 该 app 源码的静态调用次数）。

调用次数（ver0_2 app 源码静态计数，.rept / LOOPI 迭代数连乘）：
  keygen : ntt 6, getnoise_eta_1 6, gen_matrix 9, basemul 3, basemul_acc 6,
           poly_reduce 3, poly_add 3, pack_sk 1, pack_pk 1
  encap  : ntt 3, basemul 4, basemul_acc 8, intt 4, poly_reduce 4,
           getnoise_eta_1 3, getnoise_eta_2 4, poly_add 5, gen_matrix 9,
           frommsg 1, unpack_pk 1, pack_ciphertext 1
  decap  : ntt 6, basemul 5, basemul_acc 10, intt 5, poly_reduce 5, poly_add 5,
           getnoise_eta_1 3, getnoise_eta_2 4, gen_matrix 9, 解包 2,
           frommsg 1, pack_ciphertext 1, 比较 1  →  + 再加密（= encap 的那套）
注意：行名里的 "xN" 就是内核调用次数（noise_x7 = 3+1+3、basemul_acc_x12 = 4+8、
x15 = 5+10、unpack_sk_pk = 2），与 ver0_2 的 app 完全对应。
"""

XOF02 = "//test_hybrid_kem_otbn_prompt_ver0_2/otbn/kmac_official:xof.s"

# ver0_2 内核调用范式（逐字取自 app 的调用点；Plantard 标量约定）
_NTT = ["la   x10, poly_a", "add  x12, x0, x10", "la   x11, twiddles_ntt", "jal  x1, ntt"]
_INTT = ["la   x10, poly_a", "add  x12, x0, x10", "la   x11, twiddles_intt", "jal  x1, intt"]
_BM = ["la   x29, poly_sk", "la   x11, poly_a", "la   x13, acc_poly",
       "la   x28, twiddles_ntt", "jal  x1, basemul"]
_BMA = ["la   x29, poly_sk", "la   x11, poly_a", "la   x13, acc_poly",
        "la   x28, twiddles_ntt", "jal  x1, basemul_acc"]
_ADD = ["la   x10, poly_a", "la   x11, poly_b", "add  x12, x0, x10", "jal  x1, poly_add"]
# 注意：ver0_2 的噪声内核里是 `add x9, fp, x13`（x13 是 **fp 相对偏移**，
# app 传 -64），因此 nonce 必须写到 -64(fp)，x13 也传 -64；x10/x6/x11 是绝对指针。
_NOISE1 = ["li   x13, -64", "la   x10, seed", "la   x6, shake_buf",
           "la   x11, out_poly", "jal  x1, poly_getnoise_eta_1"]
_NOISE2 = ["li   x13, -64", "la   x10, seed", "la   x11, out_poly",
           "la   x6, shake_buf", "jal  x1, poly_getnoise_eta_2"]


def _setn(n):
    return ["li   x12, " + str(n), "sw   x12, -64(fp)"]


_POLY_DATA = ["poly_a:", "  .zero 512", "", ".balign 32", "poly_b:", "  .zero 512",
              "", ".balign 32", "acc_poly:", "  .zero 512", "", ".balign 32",
              "poly_sk:", "  .zero 512"]
_NOISE_DATA = ["seed:", "  .zero 64", "", ".balign 32", "shake_buf:", "  .zero 512",
               "", ".balign 32", "out_poly:", "  .zero 1024"]
_NOISE_CALLS = [(1, _setn(0) + _NOISE1), (1, _setn(1) + _NOISE1), (1, _setn(2) + _NOISE1),
                (1, _setn(6) + _NOISE2), (1, _setn(3) + _NOISE2), (1, _setn(4) + _NOISE2),
                (1, _setn(5) + _NOISE2)]

SPECS02 = [
    # ── Encaps ─────────────────────────────────────────────────────────────
    dict(op="encap", row="intt_x4", app="mlkem_encap",
         note="encap 的 4 次 INTT（解密核外的 u 行 3 + v 1；ver0_2 的 intt 就地、需 twiddles_intt）。",
         srcs=["intt.s", "encap_intt_data.s"], prelude=[],
         calls=[(4, _INTT)], data=["poly_a:", "  .zero 512"]),
    dict(op="encap", row="noise_x7", app="mlkem_encap",
         note="encap 的 7 次噪声采样：eta_1 N=0,1,2（y 行）+ eta_2 N=6（epp）+ eta_2 N=3,4,5（e1）。",
         srcs=["poly.s", "cbd.s", XOF02, "keygen_poly_getnoise_eta_1_data.s"],
         prelude=[], calls=_NOISE_CALLS, data=_NOISE_DATA),
    dict(op="encap", row="h_ek", app="mlkem_encap",
         note="encap 的 H(ek) = SHA3-256(ek 1184 B)，**1 次 absorb**（ver0_2 的 app 是连续缓冲；"
              "ver1_1 才拆成 pk_t+rho 两次）。",
         srcs=[XOF02], prelude=[],
         calls=[(1, ["jal  x1, xof_sha3_256_init",
                     "la   x21, input_ek", "li   x20, 1184", "li   x22, 0", "jal  x1, xof_absorb",
                     "jal  x1, xof_process",
                     "jal  x1, xof_squeeze32", "bn.xor w0, w29, w30",
                     "li   x5, 0", "la   x12, output_hash", "bn.sid x5, 0(x12)",
                     "jal  x1, xof_finish"])],
         data=["input_ek:", "  .zero 1184", "", ".balign 32", "output_hash:", "  .zero 32"]),
    dict(op="encap", row="basemul_acc_x12", app="mlkem_encap",
         note="encap 的 basemul 族 12 次：4 basemul（各行首积）+ 8 basemul_acc（u 6 + v 2）。",
         srcs=["basemul.s", "keygen_basemul_basemul_acc_data.s"], prelude=[],
         calls=[(1, _BM), (2, _BMA), (3, _BM), (6, _BMA)], data=_POLY_DATA),
    dict(op="encap", row="ntt_x3", app="mlkem_encap",
         note="encap 的 3 次 NTT（y[j] 采样后；needs twiddles_ntt）。",
         srcs=["ntt.s", "keygen_ntt_data.s"], prelude=[],
         calls=[(3, _NTT)], data=["poly_a:", "  .zero 512"]),
    dict(op="encap", row="poly_add_x5", app="mlkem_encap",
         note="encap 的 5 次 poly_add（e1 ×3 + e2 ×1 + μ ×1）。",
         srcs=["keygen_poly_add_impl.s"], prelude=[],
         calls=[(5, _ADD)], data=["poly_a:", "  .zero 512", "", ".balign 32",
                                  "poly_b:", "  .zero 512"]),
    # ── Decaps ─────────────────────────────────────────────────────────────
    dict(op="decap", row="noise_x7", app="mlkem_decap",
         note="decap 的 7 次噪声采样（再加密路径）：eta_1 N=0,1,2 + eta_2 N=6 + eta_2 N=3,4,5。",
         srcs=["poly.s", "cbd.s", XOF02, "keygen_poly_getnoise_eta_1_data.s"],
         prelude=[], calls=_NOISE_CALLS, data=_NOISE_DATA),
    dict(op="decap", row="basemul_acc_x15", app="mlkem_decap",
         note="decap 的 basemul 族 15 次：5 basemul + 10 basemul_acc（解密核 1+2，再加密 4+8）。",
         srcs=["basemul.s", "keygen_basemul_basemul_acc_data.s"], prelude=[],
         calls=[(1, _BM), (2, _BMA), (4, _BM), (8, _BMA)], data=_POLY_DATA),
    dict(op="decap", row="ntt_x6", app="mlkem_decap",
         note="decap 的 6 次 NTT（解密核 u 3 + 再加密 y 3）。",
         srcs=["ntt.s", "keygen_ntt_data.s"], prelude=[],
         calls=[(6, _NTT)], data=["poly_a:", "  .zero 512"]),
    dict(op="decap", row="intt_x5", app="mlkem_decap",
         note="decap 的 5 次 INTT（解密核 1 + 再加密 u 3 + v 1）。",
         srcs=["intt.s", "encap_intt_data.s"], prelude=[],
         calls=[(5, _INTT)], data=["poly_a:", "  .zero 512"]),
    dict(op="decap", row="pack_ciphertext", app="mlkem_decap",
         note="decap 比较前的再压缩：1 次 pack_ciphertext（与 encap 同一内核与调用点）。",
         srcs=["pack_ciphertext.s", "encap_pack_ciphertext_data.s", "decap_poly_sub_data.s"],
         prelude=["la   x10, b_polyvec", "la   x11, v_poly", "la   x12, ciphertext",
                  "la   x13, const_1290167", "la   x14, modulus_bn", "la   x15, modulus_over_2"],
         calls=[(1, ["jal  x1, pack_ciphertext"])],
         data=["b_polyvec:", "  .zero 1536", "", ".balign 32", "v_poly:", "  .zero 512",
               "", ".balign 32", "ciphertext:", "  .zero 1088"]),
    dict(op="decap", row="poly_add_x5", app="mlkem_decap",
         note="decap 的 5 次 poly_add（再加密路径的 e1 ×3 + e2 ×1 + μ ×1）。",
         srcs=["keygen_poly_add_impl.s"], prelude=[],
         calls=[(5, _ADD)], data=["poly_a:", "  .zero 512", "", ".balign 32",
                                  "poly_b:", "  .zero 512"]),
    dict(op="decap", row="hash_g_reuse", app="mlkem_decap",
         note="decap 的 G(m' ‖ h) = SHA3-512(64 B)，**1 次 absorb**（ver0_2 的 app 是连续缓冲）。",
         srcs=[XOF02], prelude=[],
         calls=[(1, ["jal  x1, xof_sha3_512_init",
                     "la   x21, input_mh", "li   x20, 64", "li   x22, 0", "jal  x1, xof_absorb",
                     "jal  x1, xof_process",
                     "jal  x1, xof_squeeze32", "bn.xor w0, w29, w30",
                     "li   x5, 0", "la   x12, output_K", "bn.sid x5, 0(x12)",
                     "jal  x1, xof_squeeze32", "bn.xor w0, w29, w30",
                     "li   x5, 0", "la   x12, output_r", "bn.sid x5, 0(x12)",
                     "jal  x1, xof_finish"])],
         data=["input_mh:", "  .zero 64", "", ".balign 32",
               "output_K:", "  .zero 32", "", ".balign 32", "output_r:", "  .zero 32"]),
    dict(op="decap", row="unpack_sk_pk", app="mlkem_decap",
         note="decap 的 2 次解包：unpack_sk（dk 里的 s polyvec）+ unpack_pk（再加密用的 pk）。",
         srcs=["pack_keys.s", "decap_unpack_ciphertext_data.s"], prelude=[],
         calls=[(1, ["la   x10, input_sk", "la   x12, out_sk_polyvec", "la   x15, const_0x0fff",
                     "jal  x1, unpack_sk"]),
                (1, ["la   x10, input_pk", "la   x12, out_pk_polyvec", "la   x13, const_0x0fff",
                     "jal  x1, unpack_pk"])],
         data=["input_sk:", "  .zero 1152", "", ".balign 32", "input_pk:", "  .zero 1184",
               "", ".balign 32", "out_sk_polyvec:", "  .zero 1536", "", ".balign 32",
               "out_pk_polyvec:", "  .zero 1536"]),
    dict(op="decap", row="poly_frommsg_reuse", app="mlkem_decap",
         note="decap 的 1 次 poly_frommsg（再加密路径 μ = Decompress_1(m')）。",
         srcs=["encap_poly_frommsg_impl.s", "encap_pack_ciphertext_data.s"], prelude=[],
         calls=[(1, ["la   x10, input_message", "la   x11, modulus_over_2",
                     "la   x12, output_poly", "jal  x1, poly_frommsg"])],
         data=["input_message:", "  .zero 32", "", ".balign 32", "output_poly:", "  .zero 512"]),
    # ── 归约（ver0_1/ver0_2 有独立 poly_reduce 内核；ver1_1 无，融进 basemul_acc）──
    dict(op="encap", row="poly_reduce_x4", app="mlkem_encap",
         note="encap 的 4 次 poly_reduce：v 用 const_1290167（1 次）+ u 三个多项式用 const_toplant（3 次）。",
         srcs=["keygen_poly_reduce_impl.s", "keygen_poly_reduce_data.s",
               "encap_pack_ciphertext_data.s"], prelude=[],
         calls=[(3, ["la   x10, poly_a", "la   x12, const_toplant", "jal  x1, poly_reduce"]),
                (1, ["la   x10, poly_a", "la   x12, const_1290167", "jal  x1, poly_reduce"])],
         data=["poly_a:", "  .zero 1536"]),
    dict(op="decap", row="poly_reduce_x5", app="mlkem_decap",
         note="decap 的 5 次 poly_reduce：解密核 1（const_1290167）+ 再加密 4（3× const_toplant + 1× const_1290167）。",
         srcs=["keygen_poly_reduce_impl.s", "keygen_poly_reduce_data.s",
               "encap_pack_ciphertext_data.s"], prelude=[],
         calls=[(1, ["la   x10, poly_a", "la   x12, const_1290167", "jal  x1, poly_reduce"]),
                (3, ["la   x10, poly_a", "la   x12, const_toplant", "jal  x1, poly_reduce"]),
                (1, ["la   x10, poly_a", "la   x12, const_1290167", "jal  x1, poly_reduce"])],
         data=["poly_a:", "  .zero 1536"]),
]
