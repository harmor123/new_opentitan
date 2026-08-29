load("//rules:otbn.bzl", "otbn_binary", "otbn_library")

package(default_visibility = ["//visibility:public"])


# ---------------------------------------------------------------------------
# Shared plain-software P-256 arithmetic kernel
# ---------------------------------------------------------------------------

otbn_library(
    name = "p256_base_sw",
    srcs = [
        "p256_base_sw.s",
    ],
)


# ---------------------------------------------------------------------------
# Plain-software P-256 KeyGen
#
# Computes:
#
#     Q = d * G
#
# Input:
#     scalar
#
# Outputs:
#     pk_x
#     pk_y
# ---------------------------------------------------------------------------

otbn_binary(
    name = "p256_keygen_sw",
    srcs = [
        "p256_keygen_sw_entry.s",
        "p256_base_sw.s",
        "p256_keygen_sw.s",
    ],
)


# ---------------------------------------------------------------------------
# Plain-software P-256 ECDH shared-key computation
#
# Computes:
#
#     S = d * Q_peer
#
# Inputs:
#     scalar
#     peer_x
#     peer_y
#
# Output:
#     shared_x
# ---------------------------------------------------------------------------

otbn_binary(
    name = "p256_shared_key_sw",
    srcs = [
        "p256_shared_key_sw_entry.s",
        "p256_base_sw.s",
        "p256_shared_key_sw.s",
    ],
)

otbn_binary(
    name = "p256_scalar_mult_profile",
    srcs = [
        "p256_scalar_mult_profile.s",
        "p256_base_sw.s",
    ],
)

otbn_binary(
    name = "p256_proj_double_profile",
    srcs = [
        "p256_proj_double_profile.s",
        "p256_base_sw.s",
    ],
)

otbn_binary(
    name = "p256_proj_double_control",
    srcs = [
        "p256_proj_double_control.s",
        "p256_base_sw.s",
    ],
)

otbn_binary(
    name = "p256_proj_add_profile",
    srcs = [
        "p256_proj_add_profile.s",
        "p256_base_sw.s",
    ],
)

otbn_binary(
    name = "p256_proj_add_control",
    srcs = [
        "p256_proj_add_control.s",
        "p256_base_sw.s",
    ],
)

otbn_binary(
    name = "p256_proj_to_affine_profile",
    srcs = [
        "p256_proj_to_affine_profile.s",
        "p256_base_sw.s",
    ],
)

otbn_binary(
    name = "p256_proj_to_affine_control",
    srcs = [
        "p256_proj_to_affine_control.s",
        "p256_base_sw.s",
    ],
)

otbn_binary(
    name = "p256_mul_modp_profile",
    srcs = [
        "p256_mul_modp_profile.s",
        "p256_base_sw.s",
    ],
)

otbn_binary(
    name = "p256_mul_modp_control",
    srcs = [
        "p256_mul_modp_control.s",
        "p256_base_sw.s",
    ],
)