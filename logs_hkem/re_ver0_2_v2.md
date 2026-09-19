| 版本 | 阶段 | 周期 | 指令 | 停滞 | text(B) | data(B) | 镜像(B) | FIPS | 口径 |
|---|---|---:|---:|---:|---:|---:|---:|---|---|
| ver0_2 | keygen_ntt | 48,830 | 46,730 | 2,100 | 3,612 | 5,280 | 8,892 | Alg.13 L16–17 | Direct |
| ver0_2 | keygen_basemul_basemul_acc | 41,754 | 41,037 | 717 | 3,036 | 6,848 | 9,884 | Alg.13 L18 | Direct |
| ver0_2 | keygen_poly_reduce | 5,679 | 5,571 | 108 | 264 | 1,600 | 1,864 | Alg.13 L18 support | Direct |
| ver0_2 | keygen_poly_add | 4,203 | 4,053 | 150 | 224 | 3,072 | 3,296 | Alg.13 L18 | Direct |
| ver0_2 | keygen_pack_pk | 1,853 | 1,759 | 94 | 616 | 2,752 | 3,368 | Alg.13 L19 | Direct |
| ver0_2 | keygen_pack_sk | 1,849 | 1,757 | 92 | 608 | 2,688 | 3,296 | Alg.13 L20 | Direct |
| ver0_2 | keygen_hash_h | 2,210 | 1,618 | 592 | 648 | 5,312 | 5,960 | Alg.16 L3 | Direct |
| ver0_2 | keygen_sha3_init_update_final | 362 | 267 | 95 | 692 | 4,224 | 4,916 | Alg.13 L1 / G(d‖k) | Direct |
| ver0_2 | keygen_poly_getnoise_eta_1 | 12,783 | 11,955 | 828 | 1,984 | 5,320 | 7,304 | Alg.13 L8–15 | Direct |
| ver0_2 | keygen_poly_gen_matrix | 47,736 | 36,513 | 11,223 | 1,460 | 5,664 | 7,124 | Alg.13 L3–7 / Alg.7 | Exact-real-input |
| ver0_2 | encap_hash_g | 352 | 260 | 92 | 672 | 4,224 | 4,896 | Alg.17 L2 / G(m‖H(ek)) | Direct |
| ver0_2 | encap_poly_gen_matrix | 47,736 | 36,513 | 11,223 | 1,460 | 5,664 | 7,124 | Alg.14 L4–8 / Alg.7 | Exact-real-input |
| ver0_2 | decap_poly_gen_matrix | 47,736 | 36,513 | 11,223 | 1,460 | 5,664 | 7,124 | Alg.18 L8→Alg.14 L4–8 | Exact-real-input |
| ver0_2 | decap_shake_z_ct | 2,141 | 1,567 | 574 | 668 | 5,248 | 5,916 | Alg.18 L9 / J(z‖c) | Direct |
| ver0_2 | encap_intt | 8,773 | 8,423 | 350 | 3,844 | 5,792 | 9,636 | Alg.14 L19,L21 | Direct (单次) |
| ver0_2 | encap_pack_ciphertext | 8,819 | 8,617 | 202 | 1,068 | 3,200 | 4,268 | Alg.14 L22–24 | Direct |
| ver0_2 | encap_unpack_pk | 1,874 | 1,781 | 93 | 368 | 6,848 | 7,216 | Alg.14 L2–3 | Direct |
| ver0_2 | encap_poly_frommsg | 1,355 | 1,335 | 20 | 216 | 576 | 792 | Alg.14 L20 | Direct |
| ver0_2 | decap_unpack_ciphertext | 8,264 | 8,061 | 203 | 1,068 | 3,232 | 4,300 | Alg.15 L1–4 | Direct |
| ver0_2 | decap_poly_sub | 139 | 88 | 51 | 208 | 1,568 | 1,776 | Alg.15 L6 | Direct |
| ver0_2 | decap_poly_tomsg | 1,393 | 1,372 | 21 | 252 | 608 | 860 | Alg.15 L7 | Direct |
| ver0_2 | decap_verify_cmov | 397 | 289 | 108 | 292 | 6,816 | 7,108 | Alg.18 L9–10 | Direct |
| ver0_2 | keygen_poly_gen_matrix_shake | 10,024 | 7,736 | 2,288 | 4,524 | 4,192 | 8,716 | Alg.7 子分解 / XOF 路径 | Direct |
| ver0_2 | keygen_poly_gen_matrix_rejection | 41,541 | 31,635 | 9,906 | 1,256 | 15,552 | 16,808 | Alg.7 子分解 / 拒绝采样 | Direct |
| ver0_2 | keygen_poly_gen_matrix_stub_overhead | 2,101 | 1,463 | 638 | 952 | 9,888 | 10,840 | 校准（非 FIPS 步骤） | Calibration |
| ver0_2 | encap_intt_x4 | 35,092 | 33,692 | 1,400 | 0 | 0 | 0 | Alg.14 L19,L21 | Direct ×4 |
| ver0_2 | encap_noise_x7 | 14,914 | 13,948 | 966 | 0 | 0 | 0 | Alg.14 L9–17 | Estimated reuse |
| ver0_2 | encap_h_ek | 2,210 | 1,618 | 592 | 0 | 0 | 0 | Alg.17 L1 subexpr. | Reuse-identical |
| ver0_2 | encap_basemul_acc_x12 | 55,672 | 54,716 | 956 | 0 | 0 | 0 | Alg.14 L19,L21 | Reuse-fixed |
| ver0_2 | encap_ntt_x3 | 24,415 | 23,365 | 1,050 | 0 | 0 | 0 | Alg.14 L18 | Reuse-fixed |
| ver0_2 | encap_poly_reduce_x4 | 7,572 | 7,428 | 144 | 0 | 0 | 0 | Alg.14 L19,L21 support | Reuse-fixed |
| ver0_2 | encap_poly_add_x5 | 7,005 | 6,755 | 250 | 0 | 0 | 0 | Alg.14 L19,L21 | Reuse-fixed |
| ver0_2 | decap_noise_x7 | 14,914 | 13,948 | 966 | 0 | 0 | 0 | Alg.18 L8→Alg.14 L9–17 | Estimated reuse |
| ver0_2 | decap_basemul_acc_x15 | 69,590 | 68,395 | 1,195 | 0 | 0 | 0 | Alg.15 L6 + Alg.14 L19,L21 | Reuse-fixed |
| ver0_2 | decap_ntt_x6 | 48,830 | 46,730 | 2,100 | 0 | 0 | 0 | Alg.15 L6 + Alg.14 L18 | Reuse-fixed |
| ver0_2 | decap_intt_x5 | 43,865 | 42,115 | 1,750 | 0 | 0 | 0 | Alg.15 L6 + Alg.14 L19,L21 | Direct/reuse |
| ver0_2 | decap_poly_reduce_x5 | 9,465 | 9,285 | 180 | 0 | 0 | 0 | arithmetic support | Reuse-fixed |
| ver0_2 | decap_pack_ciphertext | 8,819 | 8,617 | 202 | 0 | 0 | 0 | Alg.18 L8→Alg.14 L22–24 | Reuse |
| ver0_2 | decap_poly_add_x5 | 7,005 | 6,755 | 250 | 0 | 0 | 0 | Alg.14 L19,L21 | Reuse-fixed |
| ver0_2 | decap_hash_g_reuse | 352 | 260 | 92 | 0 | 0 | 0 | Alg.18 L8 → G(m'‖h) | Reuse-identical |
| ver0_2 | decap_unpack_sk_pk | 3,748 | 3,562 | 186 | 0 | 0 | 0 | Alg.15 L5 + Alg.14 L2–3 | Reuse |
| ver0_2 | decap_poly_frommsg_reuse | 1,355 | 1,335 | 20 | 0 | 0 | 0 | Alg.18 L8→Alg.14 L20 | Reuse-fixed |
