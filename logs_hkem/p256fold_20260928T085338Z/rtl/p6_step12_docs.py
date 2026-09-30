#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P6 Step 1/2 的文档更新（一次性工具；带断言）。

改三个文件（都在 <repo>/../md文档/p256方案20260927/new_contribution_2/）：
  07_P6_兼容性与协议端到端.md —— Step 1/2 命令换成实测版 + 新增 §8.7 实测 + 旧 §8.7/§8.8 顺延为 §8.8/§8.9
  13_合并影响与回归清单.md      —— P6 进度行补 Step 1/2 + 数据面计数刷新 + 更新记录加一行
  10_正确性验证_§14.md          —— §14.3.1 组 1 标注不退化证据的指针

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p6_step12_docs.py [--check]
"""
import argparse
import pathlib

DOCS = (pathlib.Path(__file__).resolve().parents[4] / "md文档"
        / "p256方案20260927" / "new_contribution_2")
DEV = "logs_hkem/p256fold_20260928T085338Z"


def read(p):
    return p.read_text(encoding="utf-8")


def write(p, s):
    p.write_text(s, encoding="utf-8")


def sub_once(t, old, new, what):
    n = t.count(old)
    assert n == 1, "%s：期望 1 次，实际 %d 次" % (what, n)
    return t.replace(old, new, 1)


def line_index(lines, prefix, what):
    idx = [i for i, l in enumerate(lines) if l.startswith(prefix)]
    assert len(idx) == 1, "%s：期望 1 行，实际 %d 行" % (what, len(idx))
    return idx[0]


STEP1_OLD = r'''```bash
cd "$repo_root"
bazel test //test_hybrid_kem_otbn_prompt_ver1_1:test_mlkem_keypair_only \
           //test_hybrid_kem_otbn_prompt_ver1_1:test_mlkem_encap_only \
           //test_hybrid_kem_otbn_prompt_ver1_1:test_mlkem_decap_only \
           //test_hybrid_kem_otbn_prompt_ver1_1:test_hkdf_only \
           --test_output=errors 2>&1 | tee "$run_dir/host/regression_mlkem_hkdf.log"
```'''

STEP1_NEW = r'''```bash
cd "$repo_root"
run_dir=logs_hkem/p256fold_20260928T085338Z
CHIP="--test_timeout=2000 --cache_test_results=no --sandbox_writable_path=/run/user/1000/ccache-tmp --test_output=streamed"

# chip 侧（ver1_1 = 固定基线树，跑在含 fold 的 RTL 上）—— 实测：4/4 PASSED
bazel test //test_hybrid_kem_otbn_prompt_ver1_1:test_mlkem_keypair_only_sim_verilator \
           //test_hybrid_kem_otbn_prompt_ver1_1:test_mlkem_encap_only_sim_verilator \
           //test_hybrid_kem_otbn_prompt_ver1_1:test_mlkem_decap_only_sim_verilator \
           //test_hybrid_kem_otbn_prompt_ver1_1:test_hkdf_only_sim_verilator $CHIP \
           2>&1 | tee "$run_dir/host/regression_mlkem_hkdf.log"
```
> **`_sim_verilator` 后缀要写全**（裸目标名会把 `sim_dv` 一起拖进来）；chip 路径**必须带 `$CHIP`**
> （`--sandbox_writable_path` 给 ccache，见 `13_合并影响与回归清单.md` §5 的 3c）。实测结果见 §8.7。'''

STEP2A_OLD = 'python3 -m pytest hw/ip/otbn/dv/otbnsim/test/ -q   # 逐 insn .s/.exp 对拍'
STEP2A_NEW = ('python3 -m pytest hw/ip/otbn/dv/otbnsim/test/ -q 2>&1 | tee "$run_dir/host/iss_simd_tests.log"'
              '   # 逐 insn .s/.exp 对拍；实测：86 passed')

STEP2B_OLD = 'bazel test //test_hybrid_kem_otbn_prompt_ver1_1:test_hkdf_only --test_output=all'
STEP2B_NEW = ('bazel test //test_hybrid_kem_otbn_prompt_ver1_1:test_hkdf_only_sim_verilator $CHIP'
              '   # 与 Step 1 同一份日志；实测 PASSED，指令数 3,374 逐位不变')

S87_NEW = '''### 8.7 Step 1/2：三 op ML-KEM + HKDF 与 MAC/KMAC 用户回归（本次完成）

```bash
cd "$repo_root"
run_dir=logs_hkem/p256fold_20260928T085338Z
CHIP="--test_timeout=2000 --cache_test_results=no --sandbox_writable_path=/run/user/1000/ccache-tmp --test_output=streamed"

# 2A · ISS 侧 BN SIMD 指令向量（上游自带套件；含 Montgomery / lane / pack-unpack）
python3 -m pytest hw/ip/otbn/dv/otbnsim/test/ -q 2>&1 | tee "$run_dir/host/iss_simd_tests.log"

# 1 + 2B · chip 侧三 op ML-KEM + HKDF（ver1_1 = 固定基线树，跑在含 fold 的 RTL 上）
bazel test //test_hybrid_kem_otbn_prompt_ver1_1:test_mlkem_keypair_only_sim_verilator \\
           //test_hybrid_kem_otbn_prompt_ver1_1:test_mlkem_encap_only_sim_verilator \\
           //test_hybrid_kem_otbn_prompt_ver1_1:test_mlkem_decap_only_sim_verilator \\
           //test_hybrid_kem_otbn_prompt_ver1_1:test_hkdf_only_sim_verilator $CHIP \\
           2>&1 | tee "$run_dir/host/regression_mlkem_hkdf.log"
```

| 判据 | 结果 |
|---|---|
| ISS 侧 BN SIMD 套件（2A） | **86 passed**，0 失败（38.18 s） |
| chip 侧四个 target（1 + 2B） | **4/4 PASSED**（keypair 336.4 s / encap 338.1 s / decap 360.9 s / hkdf 276.3 s） |
| **OTBN 指令数**（对 P0 冻结锚点逐位比对） | keypair **97,301** ✓、encap **118,979** ✓、decap **145,323** ✓、hkdf **3,374** ✓ |
| `cycles`（**只记录不判定**） | 139,563 / 171,654 / 217,171 / 5,311 —— 与 P0 恰好也相同 |

`cycles` 那列**不是**判据（§5 的 3c 已登记：同一 build 内可复现，跨 build 会变，且**打印量本身**就会改变跨度）；
**指令数才是**：四个数与 P0 逐位相同 ⇒ 新 RTL 没有波及旧 ML-KEM/HKDF 路径；`test_hkdf_only` 走**真 KMAC**
硬件哈希 ⇒ §11 P6 的「既有其它 MAC 用户回归」在 KMAC 一侧同时成立。
原始日志：`host/iss_simd_tests.log`、`host/regression_mlkem_hkdf.log`。

'''


def patch_07():
    p = DOCS / "07_P6_兼容性与协议端到端.md"
    t = read(p)
    orig = t

    t = sub_once(t, STEP1_OLD, STEP1_NEW, "07/Step1 命令块")
    t = sub_once(t, STEP2A_OLD, STEP2A_NEW, "07/Step2A 命令")
    t = sub_once(t, STEP2B_OLD, STEP2B_NEW, "07/Step2B 命令")

    # 新增 §8.7，旧 §8.7 / §8.8 顺延
    t = sub_once(t, "### 8.7 本节未覆盖的 P6 步骤（诚实清单）",
                 S87_NEW + "### 8.8 本节未覆盖的 P6 步骤（诚实清单）", "07/§8.7 插入")
    t = sub_once(t, "### 8.8 对 §7.3 待确认项的更新",
                 "### 8.9 对 §7.3 待确认项的更新", "07/§8.8 顺延")
    t = sub_once(t, "**仍未解决**，见 8.7 的清单", "**仍未解决**，见 8.8 的清单", "07/§8.9 引用")

    # §8.8 未覆盖清单：Step 1–2 已完成
    lines = t.split("\n")
    i = line_index(lines, "- §3 的 **Step 1–2**", "07/§8.8 Step1-2 条")
    assert lines[i + 1].startswith("  **MAC/KMAC 用户回归未做**"), "07：Step 1–2 条的第二行对不上"
    lines[i:i + 2] = [
        "- §3 的 **Step 1–2**（ML-KEM/HKDF 三 op 回归、MAC/KMAC 用户回归）：**已于本次完成，见 §8.7** ✓",
        "  —— ISS 侧 BN SIMD 套件 86 passed、chip 侧四个 target 全 PASSED 且指令数逐位等于 P0 锚点。",
    ]
    t = "\n".join(lines)

    # §6 产物清单：回归日志行的判据写细
    t = sub_once(t, "| 三 op ML-KEM + HKDF 回归日志 | `$run_dir/host/regression_mlkem_hkdf.log` | 全绿 + `ΣE == INSN_CNT` |",
                 "| 三 op ML-KEM + HKDF 回归日志 | `$run_dir/host/regression_mlkem_hkdf.log`（+ ISS 侧 "
                 "`host/iss_simd_tests.log`） | 4/4 PASSED **且四个 OTBN 指令数逐位等于 P0 锚点**"
                 "（97301 / 118979 / 145323 / 3374）；ISS 套件 86 passed |", "07/§6 产物行")

    assert t != orig
    if not args.check:
        write(p, t)
    return p, len(orig.split("\n")), len(t.split("\n"))


def patch_13():
    p = DOCS / "13_合并影响与回归清单.md"
    t = read(p)
    orig = t

    n = t.count("清单见 `07_P6_*.md` §8.7")
    assert n == 2, "13：§8.7 引用应为 2 处，实际 %d" % n
    t = t.replace("清单见 `07_P6_*.md` §8.7", "清单见 `07_P6_*.md` §8.8")
    t = sub_once(t, "§1 的 ②（**141 文件 / +722,637 行**）", "§1 的 ②（**144 文件 / +723,140 行**）",
                 "13/数据面计数")

    lines = t.split("\n")
    i = line_index(lines, "| **P6**（共享平台与协议端到端）", "13/P6 进度行")
    k = lines[i].find("**未做**：")
    assert k > 0, "13/P6 进度行找不到「**未做**：」"
    lines[i] = lines[i][:k] + (
        "**已补做 Step 1/2**（三 op ML-KEM + HKDF 与 MAC/KMAC 用户回归）：ISS 侧上游 BN SIMD 套件 "
        "**86 passed**（0 失败）；chip 侧四个 target **4/4 PASSED**，且**四个 OTBN 指令数与 P0 冻结锚点"
        "逐位相同**（keypair 97,301 / encap 118,979 / decap 145,323 / hkdf 3,374），`cycles` 只记录不判定；"
        "`test_hkdf_only` 走真 KMAC ⇒ KMAC 用户一侧同时成立。日志 `host/iss_simd_tests.log` + "
        "`host/regression_mlkem_hkdf.log`，见 `07_P6_*.md` §8.7。**未做**：Step 8/10（时钟扫描 + 结果 CSV），"
        "清单见 `07_P6_*.md` §8.8 |")
    t = "\n".join(lines)

    lines = t.split("\n")
    i = line_index(lines, "| 2026-09-30 | `994fdbf5ef` |", "13/更新记录锚点")
    lines.insert(i + 1,
                 "| 2026-09-30 | `16af5ad87f` | **P6 Step 1/2 完成（三 op ML-KEM + HKDF 与 MAC/KMAC 用户回归）**。"
                 "**判据 = 指令数逐位不变、不是再 PASS 一次**：chip 侧四个 target 全 `PASSED`"
                 "（keypair 336.4 s / encap 338.1 s / decap 360.9 s / hkdf 276.3 s），**四个 OTBN 指令数与 P0 "
                 "冻结锚点逐位相同**（97,301 / 118,979 / 145,323 / 3,374，取自 `rtl/test_*_only.sim.log`）、"
                 "`cycles`（139,563 / 171,654 / 217,171 / 5,311）恰好也相同但**只记录不判定**（跨 build 会漂，"
                 "§5 的 3c）；ISS 侧上游自带 BN SIMD 套件 `pytest hw/ip/otbn/dv/otbnsim/test -q` **86 passed** "
                 "（0 失败）⇒ 旧 opcode 的 ISS 语义未漂移。`test_hkdf_only` 走**真 KMAC** ⇒ §11 P6 的"
                 "「既有其它 MAC 用户回归」在 KMAC 一侧成立；MAC bignum 一侧由 BN SIMD 套件 + P3/P4 的 "
                 "smoke 覆盖。命令要点：chip 侧要写全 **`_sim_verilator` 后缀**并带 `$CHIP`。"
                 "日志 `host/iss_simd_tests.log` + `host/regression_mlkem_hkdf.log`；§1 的 ② 刷新为 "
                 "**144 文件 / +723,140 行**。 |")

    t = "\n".join(lines)
    assert t != orig
    if not args.check:
        write(p, t)
    return p, len(orig.split("\n")), len(t.split("\n"))


NOTE_10 = ("**执行状态（2026-09-30）**：本组「与既有参考匹配 + 保留上层流程」中，**ML-KEM / HKDF 路径的"
           "不退化**已由 P6 Step 1 实测覆盖 —— chip 侧四个 target（三 op ML-KEM + HKDF）全 `PASSED` 且"
           "**四个 OTBN 指令数与 P0 冻结锚点逐位相同**（97,301 / 118,979 / 145,323 / 3,374；指令数是判据，"
           "`cycles` 只记录），`test_hkdf_only` 走真 KMAC；KAT/参考匹配的逐项校验随各协议测试自身成立"
           "（P-256 一侧见 `07_P6_兼容性与协议端到端.md` §8.1/§8.3，ECDH 端到端 `.dexp` 见 P5）。")


def patch_10():
    p = DOCS / "10_正确性验证_§14.md"
    t = read(p)
    orig = t
    t = sub_once(t, "#### 组 2 · 时间恒定性与其声明边界",
                 "> " + NOTE_10 + "\n\n#### 组 2 · 时间恒定性与其声明边界", "10/§14.3.1 组 1 注")
    assert t != orig
    if not args.check:
        write(p, t)
    return p, len(orig.split("\n")), len(t.split("\n"))


def main():
    for name, fn in (("07_P6", patch_07), ("13_merge", patch_13), ("10_sec14", patch_10)):
        path, a, b = fn()
        print("%-10s %-44s %4d -> %4d lines" % (name, path.name, a, b))
    print("OK" + (" (check only, nothing written)" if args.check else ""))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    main()
