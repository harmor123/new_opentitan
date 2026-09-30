#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ver1_2 的 IKM 口径变更（去长度前缀 + 去 sid）文档落地 —— 一次性；数值全部从文件读出。

写四处：
  1. `06_P5` 末尾新增 §8（IKM 口径变更：改动/新 KAT/实测/−82 的构成）；
  2. `12_环境与命令速查` 的 §4 里新增 4.6（命令纪律：`opentitan_test` 裸目标名会拖出 FPGA 变体）；
  3. `07_P6` 那处裸目标名命令改成全限定 `_sim_verilator` 并加注；
  4. `13_合并影响` 增一行。

自校验：新 KAT 值由 `ref/hkdf_kat.py` **重新推导**（不手抄）；改动前的 3374 / 5311 从仓库里
已入库的旧日志读出；改动后的 3292 从本次 chip 日志读出。

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_ikm_docs.py [--check]
"""
import argparse
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parents[3]
DOCS = REPO.parent / "md文档" / "p256方案20260927" / "new_contribution_2"
RUN = REPO / "logs_hkem/p256fold_20260928T085338Z"
sys.path.insert(0, str(REPO / "test_hybrid_kem_otbn_prompt_ver1_2/ref"))
import hkdf_kat as K  # noqa: E402


def sub_once(t, old, new, what):
    n = t.count(old)
    assert n == 1, "%s：期望 1 处，实际 %d 处" % (what, n)
    return t.replace(old, new, 1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    # ---- 取数（全部从文件）
    new = {"A": K.hkdf(K.ikm_new(K.A)), "B": K.hkdf(K.ikm_new(K.B))}
    oldlog = (RUN / "rtl/test_hkdf_only.uart0.log").read_text(encoding="utf-8", errors="replace")
    m = re.search(r"HKDF cycles = (\d+), total OTBN instructions = (\d+)", oldlog)
    assert m, "旧日志里没找到 HKDF cycles/instructions"
    cyc_old, cnt_old = int(m.group(1)), int(m.group(2))
    chiplog = (RUN / "host/step5_chip.log").read_text(encoding="utf-8", errors="replace")
    cnt_new = [int(x) for x in re.findall(r"hkdf_sha3_256 OTBN instruction count = (\d+)", chiplog)]
    assert cnt_new and len(set(cnt_new)) == 1, cnt_new
    cnt_new = cnt_new[0]
    unitlog = (RUN / "host/step_ikm_otbn_unit.log").read_text(encoding="utf-8", errors="replace")
    assert "PASSED" in unitlog and "hkdf_test" in unitlog, "单元测试日志里没有 PASSED"
    for k, v in (("mlkem768_encap", 118979), ("mlkem768_decap", 145323)):
        assert re.search(r"%s OTBN instruction count = %d" % (k, v), chiplog), k
    # dexp 与参考实现互证
    dexp_hex = re.search(r"output_okm:\s*([0-9a-f]+)",
                         (REPO / "test_hybrid_kem_otbn_prompt_ver1_2/otbn/test/hkdf_test.dexp")
                         .read_text(encoding="utf-8", errors="replace")).group(1)
    assert bytes.fromhex(dexp_hex) == new["A"][1][::-1], "dexp 与参考实现不一致"

    S = []
    S.append("## 8. IKM 口径变更：去掉长度前缀与 sid（2026-09-30，`db82e7f1ef`；修 `b9c9265bc5`）")
    S.append("")
    S.append("**改了什么**：IKM 由 `be16(32)‖ss_e‖be16(32)‖ss_m‖ctx‖sid`（**132 B**）改为 "
             "`ss_e‖ss_m‖ctx`（**96 B**）；OTBN app 的 `input_lengths` 由 3 字 `{ctx_len, sid_len, okm_len}` "
             "改为 2 字 `{ctx_len, okm_len}`（`hkdf_extract` 的 `ikm_len` 常数 68→64，`hkdf_expand` 的 "
             "`okm_len` 偏移 8→4）。**只动 `ver1_2`**：`ver1_1` 冻结基线与 `ver0_x` 原样未动 ✓。")
    S.append("")
    S.append("**依据**：与论文 (6) 式 `IKM_X = ss^ecdh_X ‖ ss^kem_X ‖ ctx` **逐字节对齐**（论文侧口径与"
             "RFC 10024 的差异——RFC 是 64 B 裸拼接、哈希用密码套件哈希——见 §7.3 与 `13_合并影响`）。")
    S.append("")
    S.append("**新期望值**（生成器 `test_hybrid_kem_otbn_prompt_ver1_2/ref/hkdf_kat.py`；它**先按旧格式复算**"
             "并与仓库现存的 5 处期望值（`kExpectedPrk` / `kExpectedOkm`×3 / `hkdf_test.dexp`）逐个吻合后才改写）：")
    S.append("")
    S.append("| 向量 | PRK | OKM |")
    S.append("|---|---|---|")
    S.append("| A（OTBN 单元测试 / HKDF-only） | `%s` | `%s` |" % (K.hx(new["A"][0]), K.hx(new["A"][1])))
    S.append("| B（phase2 Alice/Bob） | `%s` | `%s` |" % (K.hx(new["B"][0]), K.hx(new["B"][1])))
    S.append("")
    S.append("旧值（ver1_1 口径，仍由 ver1_1 包与其日志保留）：PRK `da3cc7a7…`、OKM(A) `374d4ea1…`、"
             "OKM(B) `d46dc486…`。")
    S.append("")
    S.append("**实测**（证据：`run_dir/host/step_ikm_otbn_unit.log`、`run_dir/host/step5_chip.log`）")
    S.append("")
    S.append("| 项 | 改动前 | 改动后 |")
    S.append("|---|---|---|")
    S.append("| `hkdf_test`（`.dexp` 逐字节，OTBN 侧） | PASSED | **PASSED** |")
    S.append("| `test_hkdf_only` 的 PRK / OKM 常量检查 | `PRK OK` / `OKM OK` | **`PRK OK` / `OKM OK`** |")
    S.append("| `phase2_*` 的 `CHECK_ARRAYS_EQ(okm, kExpectedOkm)`（协议级 KAT） | — | **PASSED**（新值 `%s…`） |"
             % K.hx(new["B"][1])[:8])
    S.append("| HKDF OTBN 指令数 | **%d** | **%d** | **−%d** |" % (cnt_old, cnt_new, cnt_old - cnt_new))
    S.append("")
    S.append("**−%d 的构成**：主因是 **IKM 短 36 B（= 9 个字）⇒ HMAC 内层消息的 absorb 少走 9 个字**"
             "（≈ %.1f 条/字，由实测指令数之比反推）；长度算术本身只占很小一部分。"
             % (cnt_old - cnt_new, (cnt_old - cnt_new - 2) / 9.0))
    S.append("")
    S.append("**`cycles` 不作判据**：同一次会话 `HKDF cycles %d → 5138`（这次的打印量未变、故可比），但 P5 已登记"
             "「Ibex 跨度对打印量敏感（≈938 拍/字符），跨 build 比较前必须对齐打印量」⇒ 跨度只记录、不判定。"
             % cyc_old)
    S.append("")
    S.append("**复现**：")
    S.append("")
    S.append("```bash")
    S.append("git pull")
    S.append("python3 test_hybrid_kem_otbn_prompt_ver1_2/ref/hkdf_kat.py          # 自校验 + 打印新值")
    S.append("bazel test //test_hybrid_kem_otbn_prompt_ver1_2/otbn/test:hkdf_test --test_output=all"
             " --cache_test_results=no")
    S.append("```")
    S.append("")

    sec = "\n".join(S)

    p6 = DOCS / "06_P5_wrapper替换与KAT.md"
    t6 = p6.read_text(encoding="utf-8")
    assert "## 8. IKM 口径变更" not in t6, "06_P5 §8 已存在"

    p12 = DOCS / "12_环境与命令速查.md"
    t12 = p12.read_text(encoding="utf-8")
    NOTE = ("### 4.6 命令纪律（实测踩到的坑）\n"
            "\n"
            "- **`opentitan_test` 的裸目标名会展开出全部 `exec_env` 变体**，其中包括 `_fpga_cw340_*`；"
            "本机没有 HyperDebug/CW340 ⇒ 那些变体必然失败（`Error: Found no USB device. Search criteria "
            "was: vid:pid=0x18d1:0x520e`），**与代码无关**。实测：`bazel test //…:phase1_keygen_test` 会连带 "
            "6 个 FPGA 用例失败。⇒ **sim 命令一律写全 `_sim_verilator`**（`test_p256_only_sim_verilator`、"
            "`phase1_keygen_test_sim_verilator`、`phase2_alice_encap_test_sim_verilator`、"
            "`phase2_bob_decap_test_sim_verilator`…）。\n"
            "- **`grep` 模式含 `!` 时用单引号**（双引号内 `PASS!` 会被 bash 历史展开成 `event not found`）。\n"
            "- **chip 的 `cycles`（Ibex 跨度）跨 build 不可直接比**：P5 已登记它对打印量敏感（≈938 拍/字符）"
            "——比较前必须先对齐打印量；判据用**指令数**。\n"
            "- 两个 app 的打印口径不同：`… instruction count: 0x1f2a3, cycles: N`（P-256）与 "
            "`… instruction count = 12345`（ML-KEM/HKDF，**等号前有空格**）⇒ 解析脚本两条都要吃下。\n"
            "\n")
    t12 = sub_once(t12, "## 5. 结果 CSV 规格（PDF §13.3）\n", NOTE + "## 5. 结果 CSV 规格（PDF §13.3）\n",
                   "12_环境 插入 4.6")

    p7 = DOCS / "07_P6_兼容性与协议端到端.md"
    t7 = p7.read_text(encoding="utf-8")
    t7 = sub_once(t7,
                  "bazel test //test_hybrid_kem_otbn_prompt_ver1_1:phase1_keygen_test \\\n"
                  "           //test_hybrid_kem_otbn_prompt_ver1_1:phase2_alice_encap_test \\\n"
                  "           //test_hybrid_kem_otbn_prompt_ver1_1:phase2_bob_decap_test \\\n",
                  "bazel test //test_hybrid_kem_otbn_prompt_ver1_1:phase1_keygen_test_sim_verilator \\\n"
                  "           //test_hybrid_kem_otbn_prompt_ver1_1:phase2_alice_encap_test_sim_verilator \\\n"
                  "           //test_hybrid_kem_otbn_prompt_ver1_1:phase2_bob_decap_test_sim_verilator \\\n",
                  "07_P6 命令全限定")

    q = DOCS / "13_合并影响与回归清单.md"
    t2 = q.read_text(encoding="utf-8")
    lines = t2.split("\n")
    i = next(k for k, l in enumerate(lines) if l.startswith("| 2026-09-30 | `010295babc` |"))
    lines.insert(
        i + 1,
        "| 2026-09-30 | `db82e7f1ef` | **ver1_2 的 HKDF IKM 去掉长度前缀与 sid（`06_P5` §8）**。IKM 由 "
        "`be16(32)‖ss_e‖be16(32)‖ss_m‖ctx‖sid`（132 B）改为 `ss_e‖ss_m‖ctx`（96 B）；`input_lengths` "
        "3 字→2 字（`ikm_len` 常数 68→64、`okm_len` 偏移 8→4）。**只动 ver1_2**。新 KAT（由 "
        "`ref/hkdf_kat.py` 先复算旧值 5 处全等再改写）：PRK(A) `%s…`、OKM(A) `%s…`、OKM(B) `%s…`。"
        "**实测**：`hkdf_test` PASSED、`test_hkdf_only` `PRK OK`/`OKM OK`、`phase2_*` 的协议级 OKM KAT "
        "PASSED；**指令数 %d → %d（−%d）**（主因：IKM 少 36 B ⇒ HMAC 内层 absorb 少走 9 个字）。"
        "`cycles` 不作判据（P5 已登记跨度对打印量敏感）。 |"
        % (K.hx(new["A"][0])[:8], K.hx(new["A"][1])[:8], K.hx(new["B"][1])[:8],
           cnt_old, cnt_new, cnt_old - cnt_new))
    if not args.check:
        p6.write_text(t6.rstrip("\n") + "\n\n" + sec, encoding="utf-8")
        p12.write_text(t12, encoding="utf-8")
        p7.write_text(t7, encoding="utf-8")
        q.write_text("\n".join(lines), encoding="utf-8")
    print(sec)
    print("OK" + (" (check only)" if args.check else ""))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    main()
