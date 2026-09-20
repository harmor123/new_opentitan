| 版本 | 阶段 | 周期 | 指令 | 停滞 | text(B) | data(B) | 镜像(B) | FIPS | 口径 |
|---|---|---:|---:|---:|---:|---:|---:|---|---|
| ver0_1 | keygen_poly_gen_matrix | 307,390 | 274,883 | 32,507 | 3,300 | 5,696 | 8,996 | Alg.13 L3–7 / Alg.7 | Exact-real-input |
| ver0_1 | keygen_hash_h | 68,354 | 63,213 | 5,141 | 1,712 | 6,336 | 8,048 | Alg.16 L3 | Direct |
| ver0_1 | keygen_poly_getnoise_eta_1 | 65,118 | 60,522 | 4,596 | 3,512 | 5,376 | 8,888 | Alg.13 L8–15 | Direct |
| ver0_1 | keygen_ntt | 48,810 | 46,710 | 2,100 | 3,612 | 5,280 | 8,892 | Alg.13 L16–17 | Direct |
| ver0_1 | keygen_basemul_basemul_acc | 41,754 | 41,037 | 717 | 3,036 | 6,848 | 9,884 | Alg.13 L18 | Direct |
| ver0_1 | keygen_poly_reduce | 5,679 | 5,571 | 108 | 264 | 1,600 | 1,864 | Alg.13 L18 support | Direct |
| ver0_1 | keygen_poly_add | 4,203 | 4,053 | 150 | 224 | 3,072 | 3,296 | Alg.13 L18 | Direct |
| ver0_1 | keygen_pack_pk | 1,853 | 1,759 | 94 | 648 | 2,752 | 3,400 | Alg.13 L19 | Direct |
| ver0_1 | keygen_pack_sk | 1,849 | 1,757 | 92 | 640 | 2,688 | 3,328 | Alg.13 L20 | Direct |
| ver0_1 | keygen_sha3_init_update_final | 5,382 | 5,169 | 213 | 1,736 | 5,152 | 6,888 | Alg.13 L1 / G(d‖k) | Direct |
| ver0_1 | keygen_poly_gen_matrix_shake | 265,315 | 244,591 | 20,724 | 5,112 | 5,152 | 10,264 | Alg.7 子分解 / XOF 路径 | Direct |
| ver0_1 | keygen_poly_gen_matrix_rejection | 55,731 | 42,674 | 13,057 | 2,028 | 15,552 | 17,580 | Alg.7 子分解 / 拒绝采样 | Direct |
| ver0_1 | keygen_poly_gen_matrix_stub_overhead | 2,199 | 1,442 | 757 | 900 | 5,824 | 6,724 | 校准（非 FIPS 步骤） | Calibration |
| ver0_1 | encap_poly_gen_matrix | 307,390 | 274,883 | 32,507 | 3,300 | 5,696 | 8,996 | Alg.14 L4–8 / Alg.7 | Exact-real-input |
| ver0_1 | encap_intt | 8,773 | 8,423 | 350 | 3,844 | 5,792 | 9,636 | Alg.14 L19,L21 | Direct (单次) |
| ver0_1 | encap_pack_ciphertext | 8,819 | 8,617 | 202 | 1,068 | 3,200 | 4,268 | Alg.14 L22–24 | Direct |
| ver0_1 | encap_unpack_pk | 1,879 | 1,785 | 94 | 384 | 6,848 | 7,232 | Alg.14 L2–3 | Direct |
| ver0_1 | encap_poly_frommsg | 1,355 | 1,335 | 20 | 216 | 576 | 792 | Alg.14 L20 | Direct |
| ver0_1 | encap_hash_g | 6,114 | 5,781 | 333 | 1,692 | 1,152 | 2,844 | Alg.17 L2 / G(m‖H(ek)) | Direct |
| ver0_1 | decap_poly_gen_matrix | 307,390 | 274,883 | 32,507 | 3,300 | 5,696 | 8,996 | Alg.18 L8→Alg.14 L4–8 | Exact-real-input |
| ver0_1 | decap_unpack_ciphertext | 8,264 | 8,061 | 203 | 1,068 | 3,232 | 4,300 | Alg.15 L1–4 | Direct |
| ver0_1 | decap_poly_sub | 139 | 88 | 51 | 208 | 1,568 | 1,776 | Alg.15 L6 | Direct |
| ver0_1 | decap_poly_tomsg | 1,393 | 1,372 | 21 | 252 | 608 | 860 | Alg.15 L7 | Direct |
| ver0_1 | decap_shake_z_ct | 67,727 | 62,715 | 5,012 | 1,732 | 2,176 | 3,908 | Alg.18 L9 / J(z‖c) | Direct |
| ver0_1 | decap_verify_cmov | 397 | 289 | 108 | 292 | 6,816 | 7,108 | Alg.18 L9–10 | Direct |
| ver0_1 | encap_poly_reduce_x4 | 7,572 | 7,428 | 144 | 332 | 5,760 | 6,092 | Alg.14 L19,L21 support | Direct |
| ver0_1 | decap_poly_reduce_x5 | 9,465 | 9,285 | 180 | 352 | 5,760 | 6,112 | arithmetic support | Direct |
| ver0_1 | encap_intt_x4 | 35,092 | 33,692 | 1,400 | 3,912 | 5,792 | 9,704 | Alg.14 L19,L21 | Direct |
| ver0_1 | encap_noise_x7 | 75,971 | 70,609 | 5,362 | 3,672 | 6,920 | 10,592 | Alg.14 L9–17 | Direct |
| ver0_1 | encap_h_ek | 68,354 | 63,213 | 5,141 | 1,708 | 6,336 | 8,044 | Alg.17 L1 subexpr. | Direct |
| ver0_1 | encap_basemul_acc_x12 | 55,672 | 54,716 | 956 | 3,140 | 7,360 | 10,500 | Alg.14 L19,L21 | Direct |
| ver0_1 | encap_ntt_x3 | 24,405 | 23,355 | 1,050 | 3,576 | 5,792 | 9,368 | Alg.14 L18 | Direct |
| ver0_1 | encap_poly_add_x5 | 7,005 | 6,755 | 250 | 328 | 5,120 | 5,448 | Alg.14 L19,L21 | Direct |
| ver0_1 | decap_noise_x7 | 75,971 | 70,609 | 5,362 | 3,672 | 6,920 | 10,592 | Alg.18 L8→Alg.14 L9–17 | Direct |
| ver0_1 | decap_basemul_acc_x15 | 69,590 | 68,395 | 1,195 | 3,248 | 7,360 | 10,608 | Alg.15 L6 + Alg.14 L19,L21 | Direct |
| ver0_1 | decap_ntt_x6 | 48,810 | 46,710 | 2,100 | 3,648 | 5,792 | 9,440 | Alg.15 L6 + Alg.14 L18 | Direct |
| ver0_1 | decap_intt_x5 | 43,865 | 42,115 | 1,750 | 3,936 | 5,792 | 9,728 | Alg.15 L6 + Alg.14 L19,L21 | Direct |
| ver0_1 | decap_pack_ciphertext | 8,819 | 8,617 | 202 | 1,092 | 7,328 | 8,420 | Alg.18 L8→Alg.14 L22–24 | Direct |
| ver0_1 | decap_poly_add_x5 | 7,005 | 6,755 | 250 | 328 | 5,120 | 5,448 | Alg.14 L19,L21 | Direct |
| ver0_1 | decap_hash_g_reuse | 6,114 | 5,781 | 333 | 1,708 | 5,248 | 6,956 | Alg.18 L8 → G(m'‖h) | Direct |
| ver0_1 | decap_unpack_sk_pk | 3,758 | 3,570 | 188 | 692 | 9,600 | 10,292 | Alg.15 L5 + Alg.14 L2–3 | Direct |
| ver0_1 | decap_poly_frommsg_reuse | 1,355 | 1,335 | 20 | 232 | 4,704 | 4,936 | Alg.18 L8→Alg.14 L20 | Direct |
