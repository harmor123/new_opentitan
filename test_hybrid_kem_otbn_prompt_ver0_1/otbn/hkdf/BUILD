load("//rules:otbn.bzl", "otbn_binary")

package(default_visibility = ["//visibility:public"])

otbn_binary(
    name = "hkdf_sha3_256",
    srcs = [
        "hkdf_test.s",
        "hkdf_sha3_256.s",
        "hmac.s",
        "sha3_shake.s",
    ],
)
otbn_binary(
    name = "hkdf_extract_profile",
    srcs = [
        "hkdf_extract_profile.s",
        "hkdf_sha3_256.s",
        "hmac.s",
        "sha3_shake.s",
    ],
)
otbn_binary(
    name = "hkdf_expand_profile",
    srcs = [
        "hkdf_expand_profile.s",
        "hkdf_sha3_256.s",
        "hmac.s",
        "sha3_shake.s",
    ],
)

otbn_binary(
    name = "hmac64_profile",
    srcs = [
        "hmac64_profile.s",
        "hmac.s",
        "sha3_shake.s",
    ],
)

otbn_binary(
    name = "hmac65_profile",
    srcs = [
        "hmac65_profile.s",
        "hmac.s",
        "sha3_shake.s",
    ],
)
otbn_binary(
    name = "sha3_inner64_profile",
    srcs = [
        "sha3_inner64_profile.s",
        "sha3_shake.s",
    ],
)

otbn_binary(
    name = "sha3_inner65_profile",
    srcs = [
        "sha3_inner65_profile.s",
        "sha3_shake.s",
    ],
)

otbn_binary(
    name = "sha3_outer_profile",
    srcs = [
        "sha3_outer_profile.s",
        "sha3_shake.s",
    ],

)
otbn_binary(
    name = "keccakf_profile",
    srcs = [
        "keccakf_profile.s",
        "sha3_shake.s",
    ],
)
otbn_binary(
    name = "keccak_theta_profile",
    srcs = [
        "keccak_theta_profile.s",
        "sha3_shake.s",
    ],
)

otbn_binary(
    name = "keccak_setup_profile",
    srcs = [
        "keccak_setup_profile.s",
        "sha3_shake.s",
    ],
)

otbn_binary(
    name = "keccak_rhopi_profile",
    srcs = [
        "keccak_rhopi_profile.s",
        "sha3_shake.s",
    ],
)

otbn_binary(
    name = "keccak_chi_profile",
    srcs = [
        "keccak_chi_profile.s",
        "sha3_shake.s",
    ],
)

otbn_binary(
    name = "keccak_iota_profile",
    srcs = [
        "keccak_iota_profile.s",
        "sha3_shake.s",
    ],
)

otbn_binary(
    name = "keccak_state_update_profile",
    srcs = [
        "keccak_state_update_profile.s",
        "sha3_shake.s",
    ],
)