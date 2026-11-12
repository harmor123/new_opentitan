| 版本 | 阶段 | 周期 | 指令 | 停滞 | text(B) | data(B) | 镜像(B) | FIPS | 口径 |
|---|---|---:|---:|---:|---:|---:|---:|---|---|
| ver1_1 | keygen_ntt | 13,878 | 5,340 | 8,538 | 1,668 | 2,720 | 4,388 | Alg.13 L16–17 | Direct |
| ver1_1 | keygen_basemul_basemul_acc | 26,979 | 8,145 | 18,834 | 2,484 | 5,792 | 8,276 | Alg.13 L18 | Direct |
| ver1_1 | keygen_pack_pk | 10,695 | 10,472 | 223 | 640 | 3,552 | 4,192 | Alg.13 L19 | Direct |
| ver1_1 | keygen_pack_sk | 10,853 | 10,553 | 300 | 672 | 6,016 | 6,688 | Alg.13 L20 | Direct |
| ver1_1 | keygen_hash_h | 2,206 | 1,612 | 594 | 668 | 5,312 | 5,980 | Alg.16 L3 | Direct |
| ver1_1 | keygen_sha3_init_update_final | 338 | 248 | 90 | 676 | 4,288 | 4,964 | Alg.13 L1 / G(d‖k) | Direct |
| ver1_1 | keygen_poly_getnoise_eta_1 | 18,480 | 17,532 | 948 | 1,692 | 1,248 | 2,940 | Alg.13 L8–15 | Direct |
| ver1_1 | keygen_poly_gen_matrix | 46,270 | 36,528 | 9,742 | 1,436 | 1,248 | 2,684 | Alg.13 L3–7 / Alg.7 | Exact-real-input |
| ver1_1 | encap_hash_g | 342 | 249 | 93 | 692 | 4,224 | 4,916 | Alg.17 L2 / G(m‖H(ek)) | Direct |
| ver1_1 | encap_poly_gen_matrix | 46,270 | 36,528 | 9,742 | 1,436 | 1,248 | 2,684 | Alg.14 L4–8 / Alg.7 | Exact-real-input |
| ver1_1 | decap_poly_gen_matrix | 46,270 | 36,528 | 9,742 | 1,436 | 1,248 | 2,684 | Alg.18 L8→Alg.14 L4–8 | Exact-real-input |
| ver1_1 | decap_shake_z_ct | 2,134 | 1,558 | 576 | 660 | 1,312 | 1,972 | Alg.18 L9 / J(z‖c) | Direct |
| ver1_1 | encap_intt | 2,736 | 960 | 1,776 | 2,828 | 3,264 | 6,092 | Alg.14 L19,L21 | Direct (单次) |
| ver1_1 | encap_pack_ciphertext | 13,038 | 11,156 | 1,882 | 1,236 | 3,296 | 4,532 | Alg.14 L22–24 | Direct |
| ver1_1 | encap_unpack_pk | 22,581 | 22,211 | 370 | 708 | 3,584 | 4,292 | Alg.14 L2–3 | Direct |
| ver1_1 | encap_poly_frommsg | 960 | 920 | 40 | 1,648 | 1,216 | 2,864 | Alg.14 L20 | Direct |
| ver1_1 | decap_unpack_ciphertext | 12,706 | 11,864 | 842 | 1,236 | 2,272 | 3,508 | Alg.15 L1–4 | Direct |
| ver1_1 | decap_poly_sub | 250 | 148 | 102 | 1,656 | 3,232 | 4,888 | Alg.15 L6 | Direct |
| ver1_1 | decap_poly_tomsg | 1,323 | 857 | 466 | 1,648 | 1,216 | 2,864 | Alg.15 L7 | Direct |
| ver1_1 | decap_verify_cmov | 244 | 168 | 76 | 380 | 6,432 | 6,812 | Alg.18 L9–10 | Direct |
| ver1_1 | encap_intt_x4 | 10,944 | 3,840 | 7,104 | 2,876 | 3,264 | 6,140 | Alg.14 L19,L21 | Direct |
| ver1_1 | encap_noise_x7 | 21,560 | 20,454 | 1,106 | 1,700 | 1,248 | 2,948 | Alg.14 L9–17 | Direct |
| ver1_1 | encap_h_ek | 2,206 | 1,612 | 594 | 668 | 1,376 | 2,044 | Alg.17 L1 subexpr. | Direct |
| ver1_1 | encap_basemul_acc_x12 | 33,852 | 10,284 | 23,568 | 2,708 | 5,792 | 8,500 | Alg.14 L19,L21 | Direct |
| ver1_1 | encap_ntt_x3 | 6,939 | 2,670 | 4,269 | 1,596 | 2,720 | 4,316 | Alg.14 L18 | Direct |
| ver1_1 | encap_poly_add_x5 | 1,250 | 740 | 510 | 1,736 | 2,208 | 3,944 | Alg.14 L19,L21 | Direct |
| ver1_1 | decap_noise_x7 | 21,560 | 20,454 | 1,106 | 1,700 | 1,248 | 2,948 | Alg.18 L8→Alg.14 L9–17 | Direct |
| ver1_1 | decap_basemul_acc_x15 | 47,085 | 14,151 | 32,934 | 2,968 | 5,792 | 8,760 | Alg.15 L6 + Alg.14 L19,L21 | Direct |
| ver1_1 | decap_ntt_x6 | 13,878 | 5,340 | 8,538 | 1,644 | 2,720 | 4,364 | Alg.15 L6 + Alg.14 L18 | Direct |
| ver1_1 | decap_intt_x5 | 13,680 | 4,800 | 8,880 | 2,892 | 3,264 | 6,156 | Alg.15 L6 + Alg.14 L19,L21 | Direct |
| ver1_1 | decap_pack_ciphertext | 13,038 | 11,156 | 1,882 | 1,236 | 3,296 | 4,532 | Alg.18 L8→Alg.14 L22–24 | Direct |
| ver1_1 | decap_poly_add_x5 | 1,250 | 740 | 510 | 1,736 | 2,208 | 3,944 | Alg.14 L19,L21 | Direct |
| ver1_1 | decap_hash_g_reuse | 342 | 249 | 93 | 692 | 288 | 980 | Alg.18 L8 → G(m'‖h) | Direct |
| ver1_1 | decap_unpack_sk_pk | 22,428 | 22,134 | 294 | 680 | 3,488 | 4,168 | Alg.15 L5 + Alg.14 L2–3 | Direct |
| ver1_1 | decap_poly_frommsg_reuse | 960 | 920 | 40 | 1,648 | 1,216 | 2,864 | Alg.18 L8→Alg.14 L20 | Direct |
| ver1_1 | keygen_poly_gen_matrix_shake | 12,105 | 9,279 | 2,826 | 3,276 | 928 | 4,204 | Alg.7 子分解 / XOF 路径 | Direct |
| ver1_1 | keygen_poly_gen_matrix_rejection | 39,790 | 31,479 | 8,311 | 1,392 | 15,520 | 16,912 | Alg.7 子分解 / 拒绝采样 | Direct |
| ver1_1 | keygen_poly_gen_matrix_stub_overhead | 5,625 | 4,230 | 1,395 | 2,888 | 6,976 | 9,864 | 校准（非 FIPS 步骤） | Calibration |
