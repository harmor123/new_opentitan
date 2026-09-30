#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P6 Step 4 的文档更新（一次性工具；带断言，定位失败就报错、不静默写坏）。

改三个文件（都在 <repo>/../md文档/p256方案20260927/new_contribution_2/）：
  07_P6_兼容性与协议端到端.md —— Step 4 的命令/判据落地 + 新增 §8.5 实测 + 旧 §8.5 顺延为 §8.6
  13_合并影响与回归清单.md      —— 改动面计数刷新 + 第 12 行补混合测试资产 + P6 进度 + 更新记录
  10_正确性验证_§14.md          —— §14.2 组 3 的四向交界标注已实测指针

纪律：匹配一律用「行前缀」，不用含直引号的长串（文档里中英文引号混用，长串匹配易碎）；
新写的文本内不使用直引号（用「」），以免与 Python 字面量冲突。

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p6_step4_docs.py [--check]
"""
import argparse
import pathlib

DOCS = (pathlib.Path(__file__).resolve().parents[4] / "md文档"
        / "p256方案20260927" / "new_contribution_2")


def read(p):
    return p.read_text(encoding="utf-8")


def write(p, s):
    p.write_text(s, encoding="utf-8")


def line_index(lines, prefix, what):
    idx = [i for i, l in enumerate(lines) if l.startswith(prefix)]
    assert len(idx) == 1, "%s：期望 1 行，实际 %d 行（前缀 %r）" % (what, len(idx), prefix[:40])
    return idx[0]


def sub_once(text, old, new, what):
    n = text.count(old)
    assert n == 1, "%s：期望命中 1 次，实际 %d 次" % (what, n)
    return text.replace(old, new, 1)


# ────────────────────────────── 07_P6 ──────────────────────────────

STEP4_NEW = """**在哪做**：`hw/ip/otbn/dv/smoke/p256/` 下的**独立** smoke target（`p256_mixed_test.s` + `run_p256_mixed.sh`），不并进共享 target —— 判据①的 RTL↔ISS 逐条对拍由 `otbn_top_sim` 完成，判据②的参考/交替两遍比较由程序自身完成。

**命令**
```bash
cd "$repo_root"
bash hw/ip/otbn/dv/smoke/p256/run_p256_mixed.sh            # serial（P3 调度，28 拍）：1046 拍
bash hw/ip/otbn/dv/smoke/p256/run_p256_mixed.sh overlap    # overlap（P4 调度，22 拍）：962 拍
```
> 首次运行生成 `p256_mixed_test.expected.txt`（golden）并提示复核；之后每次运行做逐行 diff。
> 两种调度共用同一份 golden：最终寄存器 dump 与调度无关（实测两档 dump 逐字节相同，只有 `Executed cycles` 不同）。

**四组交替的构造**：参考值先在**干净上下文**（上下文里没有新指令）各算一遍，再在**交替上下文**重算一遍，逐位 XOR 后 OR 进错误累积器 `w29`。注意**累加链的交替点只能取在链边界**：`bn.mulqacc` 不带写回时 ACC 保持脏值（`bignum-insns.yml`：`wrd: bxxxxx`），`.wo` 只写回、**不清** ACC ⇒ 旧链须 `.z` 起头、`.wo` 收尾；链中途插入新指令会丢掉已累加的部分，那是**语义差异**、不是串值，不能算失败。

**判据**
1. 四组交替序列的结果与「把新指令换成等价的旧序列」逐位一致 —— 程序把参考值与交替值 XOR 后 OR 进 `w29`，**`w29 == 0` 即通过**（runner 里是硬断言，不是人工看）。
2. 新指令 busy 期间**源索引与目的索引稳定**（§14.2：「source index 和 destination index 在 busy 期间稳定」）—— 由 `otbn_top_sim` 的 RTL↔ISS **逐条指令对拍**覆盖：任何一拍不一致，仿真当场以 `Mismatch between RTL and ISS` 中止。
3. **任何两个候选写回不同时有效**（§14.2）；每拍最多一个 WDR 写回（§10.5 `otbn_core.sv` 回归列）。
4. 连续两次 `bn.p256mul` 使用**不同输入**，第二次结果正确（排除「第一次的暂存被复用」）。
5. 别名组合全覆盖：`wa=wb`、`wd=wa`、`wd=wb`、三者相同。

**⚠ 一条硬约束（实测踩过，见 §8.5 的「撤回的误判」）**：**用到的 WDR 必须先显式清零**。OTBN 每次 start 都用 URND 随机数把 32 个 WDR 全写一遍（`otbn_core.sv:1018-1025` 的 `sec_wipe_wdr_q` 分支 → `urnd_data`；状态机 `otbn_start_stop_control.sv:289` `OtbnStartStopSecureWipeWdrUrnd`），而 Python ISS 把 WDR 建模为 0 ⇒ 读未初始化的 WDR **必然** RTL↔ISS 分歧；`otbn_top_sim` 的 URND 种子固定 ⇒ 每次报**同一个常数**，极易误判成某条指令的 bug。
"""

S85_NEW = """### 8.5 Step 4：新旧指令交替（本次完成）

```bash
bash hw/ip/otbn/dv/smoke/p256/run_p256_mixed.sh            # serial：Executed cycles 1046
bash hw/ip/otbn/dv/smoke/p256/run_p256_mixed.sh overlap    # overlap：Executed cycles 962
```

| 判据 | 结果 |
|---|---|
| ① RTL↔ISS 逐条对拍 | **无分歧**（两档都不出现 `Mismatch between RTL and ISS`） |
| ② 程序自身 ref-vs-mixed（`w29`） | **0**（runner 硬断言通过），scratch `w23` 也是 0 |
| golden diff | 两档均 `P256 MIXED TEST PASS for program p256_mixed_test`；两档 dump **逐字节相同**（只有 `Executed cycles` 不同） |
| 别名组合 | `wd=wb`：w18≡w19；`wd=wa`：w21≡w17；`wa=wb`+三者相同：w22≡w20；`(p-1)^2=1`：w16≡w15 |
| 交替四组 | 链 A：w4≡w10；链 B：w6≡w11；新指令紧跟脏 ACC：w5≡w14；向量：w7≡w12、w8≡w13 |
| 连续两条 `bn.p256mul`（同目的寄存器、不同输入） | w30≡w9（独立寄存器算的 y²） |
| 交叉验证 | `d0*x` 在**4 个不同上下文**（A0 / A1 / B0 参考 / B1 紧跟脏 ACC）给出同一个数 |

**过程中撤回的一条误判**（留档，防重走）：混合测试首跑在第一条 `bn.mulqacc` 处报 ACC 分歧
（RTL 常数 `0x…7ccc92ef_f7c2f9a4_c887770a_3dba84b0` vs ISS `0x0`），一度被解释成「新指令留下的
ACC 末值让旧指令对 ACC 的看法不一致」。最小探针 `hw/ip/otbn/dv/smoke/p256/probe_min_after.sh`
否掉了它：`mulqacc_only`（**不含**任何新指令、只是读到未初始化的 w2/w3）**同样分歧**，而先
`bn.xor` 清零 w2/w3 的同段代码 **PASS** ⇒ 根因是**测试程序没按约定清零 WDR**（见 §3 Step 4
的硬约束），**与 fold 的 RTL 无关**。该探针保留为这次否证的证据，不是待修问题。

"""


def patch_07():
    p = DOCS / "07_P6_兼容性与协议端到端.md"
    t = read(p)
    orig = t
    lines = t.split("\n")

    # ① Step 4 区块（按行前缀定位整段：从「**在哪做**：OTBN 汇编级混合测试」到判据第 5 条）
    i = line_index(lines, "**在哪做**：OTBN 汇编级混合测试", "07/Step4 起点")
    j = line_index(lines, "5. 别名组合全覆盖：", "07/Step4 终点")
    assert i < j, "07/Step4 起止顺序不对"
    lines = lines[:i] + STEP4_NEW.split("\n") + lines[j + 1:]
    t = "\n".join(lines)

    # ② 新增 §8.5，旧 §8.5 顺延为 §8.6
    t = sub_once(t, "### 8.5 本节未覆盖的 P6 步骤（诚实清单）",
                 S85_NEW + "### 8.6 本节未覆盖的 P6 步骤（诚实清单）", "07/§8.5 插入并顺延")

    # ③ §8.6 里的引用
    t = sub_once(t, "**仍未解决**，见 8.5 的清单", "**仍未解决**，见 8.6 的清单", "07/§8.6 引用")

    # ④ §8.6 的对 §7.3 更新表：第 9 条单独拆出为已定
    old_row = ("| 2 / 3 / 5 / 6 / 9（时钟、`rtl_sha`、时钟扫描、α、混合指令载体） | "
               "**仍未解决**，见 8.6 的清单 |")
    new_rows = ("| 9（混合指令测试的载体） | **本次已定**：自建独立 smoke target "
                "`dv/smoke/p256/p256_mixed_test.s` + `run_p256_mixed.sh`，不并进共享 target；本次**未新增任何 build flag**"
                "（RTL 侧用既有 `+p256_serial` 开关）。命令/判据见 §3 Step 4，实测见 §8.5 |\n"
                "| 2 / 3 / 5 / 6（时钟、`rtl_sha`、时钟扫描、α） | **仍未解决**，见 8.6 的清单 |")
    t = sub_once(t, old_row, new_rows, "07/§8.6 第 9 条")

    # ⑤ §8.6 未覆盖清单里 Step 3–4 那一条（按行定位，避开长串里的引号）
    lines = t.split("\n")
    i = line_index(lines, "- §3 的 **Step 3", "07/§8.6 Step3-4 条")
    assert lines[i + 1].startswith("  chip 锚点覆盖"), "07/§8.6 Step3-4 条的第二行对不上"
    lines[i:i + 2] = [
        "- §3 的 **Step 3–4**（旧 opcode 六项状态 diff、新旧指令交替四组）：旧指令侧由 P3/P4 的 smoke + ISS 自检 66 checks +",
        "  chip 锚点覆盖 ✓；**新旧指令交替已于本次完成（见 §8.5）** ✓。",
    ]
    t = "\n".join(lines)

    # ⑥ §7.3 第 9 条：待确认 → 已定（按行前缀定位）
    lines = t.split("\n")
    i = line_index(lines, "9. **待确认**：混合指令测试的", "07/§7.3 第 9 条")
    lines[i] = ("9. **已定（2026-09-30）**：混合指令测试的**载体** = 自建独立 smoke target "
                "`hw/ip/otbn/dv/smoke/p256/{p256_mixed_test.s,run_p256_mixed.sh}`（不并进共享 target）；"
                "本次**未新增任何 build flag**，RTL 侧用既有 `+p256_serial` 开关（见 §8.4）。"
                "命令与判据见 §3 Step 4，实测见 §8.5。")
    t = "\n".join(lines)

    # ⑦ §6 产物清单：交替测试的落点与校验
    t = sub_once(t,
                 "| 新旧指令交替测试 | `$run_dir/unit/mixed_regs.txt` + 四模式向量 | 与等价旧序列逐位一致 |",
                 "| 新旧指令交替测试 | `hw/ip/otbn/dv/smoke/p256/{p256_mixed_test.s, p256_mixed_test.expected.txt, run_p256_mixed.sh}` | "
                 "① RTL↔ISS 逐条对拍无分歧；② 程序自比较 `w29 == 0`（runner 硬断言）；③ serial/overlap 两档 dump 逐字节相同 |",
                 "07/§6 产物行")

    assert t != orig
    if not args.check:
        write(p, t)
    return p, len(orig.split("\n")), len(t.split("\n"))


# ────────────────────────────── 13_合并影响 ──────────────────────────────

ROW12_NEW = ("| 12 | `hw/ip/otbn/dv/smoke/p256/{p256_fold_test.s, run_p256_fold.sh, p256_mixed_test.s, "
             "run_p256_mixed.sh, p256_mixed_test.expected.txt, probe_min_after.sh, README.md, p256_fold_test.expected.txt}`"
             "（**新增**；原 `dv/p256/` 已并入 `dv/smoke/` 之下，仍独立成目录、不并进 `smoke_test.s`） | "
             "纯新增 DV 资产：`dv/smoke/BUILD` 是显式 `srcs = [\"smoke_test.s\"]`、`run_smoke.sh` 无 `*.s` glob ⇒ "
             "**不会被吸进 smoke 测试**；`//hw:rtl_files` 的 glob 排除 `**/dv/**` ⇒ 不影响 chip 模型哈希 | "
             "新指令的 ISS↔RTL co-sim：`run_p256_fold.sh`（单条指令 + 官方向量）、`run_p256_mixed.sh`"
             "（新旧交替四组 + 别名组合，serial/overlap 两档） | "
             "**已实测绿** ✓：`P256 FOLD TEST PASS`（w19/w20/w21 三个官方向量结果全对）；`P256 MIXED TEST PASS`"
             "（serial 1046 拍 / overlap 962 拍，`w29=0`，两档 dump 逐字节相同）。`probe_min_after.sh` 是一次假警报的"
             "**否证记录**（判据 = co-sim 是否分歧；证明读未初始化 WDR 即可复现 ACC 分歧、与 fold 无关），**不是待修问题** |")

P6_PROGRESS_TAIL = ("**已补做 Step 4**（新旧指令交替）：`bash hw/ip/otbn/dv/smoke/p256/run_p256_mixed.sh [overlap]` 两档 "
                    "`P256 MIXED TEST PASS`、程序自比较 `w29=0`、两档 dump 逐字节相同（serial 1046 / overlap 962 拍）；"
                    "另留一份否证探针 `probe_min_after.sh`（撤回一条 ACC 分歧 = fold bug 的误判：读未初始化 WDR 即可复现、"
                    "与 fold 无关），见 `07_P6_*.md` §8.5。**未做**：Step 1–2 的 MAC/KMAC 用户回归、"
                    "Step 8–10（时钟扫描 / stall 直方图 / 结果 CSV），清单见 `07_P6_*.md` §8.6 |")

RECORD_ROW = ("| 2026-09-30 | `7eda34aea3` | **P6 Step 4 完成（新旧指令交替）**。"
              "载体 = `hw/ip/otbn/dv/smoke/p256/p256_mixed_test.s` + `run_p256_mixed.sh`（独立 smoke target，不并进共享 target；"
              "未新增 build flag）。**判据两层**：① `otbn_top_sim` 的 RTL↔ISS **逐条指令对拍**无分歧（任何一拍不一致即 "
              "`Mismatch between RTL and ISS` 中止）；② 程序自身参考遍 vs 交替遍的逐位比较，`w29 == 0`（runner 硬断言）。"
              "**实测**：serial **1046** 拍 / overlap **962** 拍，两档 dump **逐字节相同**"
              "（金标 `p256_mixed_test.expected.txt`），别名组合 4 种 + 交替四组 + 连续两条同目的寄存器全部逐位一致，"
              "`d0*x` 在 4 个不同上下文给出同一个数。**⚠ 撤回一条误判（留档防重走）**：首跑在第一条 `bn.mulqacc` 处报 ACC 分歧"
              "（RTL 常数 `0x…7ccc92ef_f7c2f9a4_c887770a_3dba84b0` vs ISS `0x0`），曾被解释为「新指令留下 ACC 末值 ⇒ 旧指令读法不一致」；"
              "最小探针 `probe_min_after.sh` 否掉它 —— `mulqacc_only`（**不含**新指令、只读到未初始化 w2/w3）同样分歧，"
              "先 `bn.xor` 清零 w2/w3 的同段代码 PASS ⇒ 根因是**测试程序没按约定清零 WDR**：OTBN 每次 start 用 URND 随机数写满 "
              "32 个 WDR（`otbn_core.sv:1018-1025` / `otbn_start_stop_control.sv:289`），ISS 建模为 0，`otbn_top_sim` 的 URND "
              "种子固定 ⇒ 每次同一常数。**与 fold 的 RTL 无关**。§1 的 ① 刷新为 **168 个文件**"
              "（+4：`p256_mixed_test.s`、`p256_mixed_test.expected.txt`、`run_p256_mixed.sh`、`probe_min_after.sh`）。 |")


def patch_13():
    p = DOCS / "13_合并影响与回归清单.md"
    t = read(p)
    orig = t

    # ① §3 抬头与计数
    t = sub_once(t, "## 3. 当前清单（截至 `1b9b20af20`；对应基线 `2d87e79bee`）",
                 "## 3. 当前清单（截至 `7eda34aea3`；对应基线 `2d87e79bee`）", "13/§3 抬头")
    t = sub_once(t, "**代码/配置面（164 个文件，排除 `logs_hkem/`；与 §1 的 ① 逐行对应）**",
                 "**代码/配置面（168 个文件，排除 `logs_hkem/`；与 §1 的 ① 逐行对应）**", "13/§3 计数")

    # ② 第 12 行（单行替换，按行前缀定位；不动第 13 行）
    lines = t.split("\n")
    i = line_index(lines, "| 12 | `hw/ip/otbn/dv/smoke/p256/{", "13/第 12 行")
    assert lines[i + 1].startswith("| 13 | `dv/smoke/smoke_vectorized_expected.txt`"), "13/第 13 行不在预期位置"
    lines[i] = ROW12_NEW
    t = "\n".join(lines)

    # ③ P6 进度行：只换尾巴（从「**未做**：」起到行尾），避免匹配带连字符的长串
    lines = t.split("\n")
    i = line_index(lines, "| **P6**（共享平台与协议端到端）", "13/P6 进度行")
    k = lines[i].find("**未做**：")
    assert k > 0, "13/P6 进度行里找不到「**未做**：」"
    lines[i] = lines[i][:k] + P6_PROGRESS_TAIL
    t = "\n".join(lines)

    # ④ 更新记录追加一行
    lines = t.split("\n")
    i = line_index(lines, "| 2026-09-30 | `1b9b20af20` |", "13/更新记录锚点")
    lines.insert(i + 1, RECORD_ROW)
    t = "\n".join(lines)

    assert t != orig
    if not args.check:
        write(p, t)
    return p, len(orig.split("\n")), len(t.split("\n"))


# ────────────────────────────── 10_§14 ──────────────────────────────

NOTE_10 = ("\n> **执行状态（2026-09-30）**：本组的「各 alias 组合」与四个方向箭头（旧 MAC→新指令、新指令→旧 MAC、向量→新指令、"
           "新指令→向量）已由 `hw/ip/otbn/dv/smoke/p256/p256_mixed_test.s` 实测覆盖"
           "（命令 `bash hw/ip/otbn/dv/smoke/p256/run_p256_mixed.sh [overlap]`；判据：① RTL↔ISS 逐条对拍无分歧、"
           "② 程序自比较 `w29 == 0`）。结果与一条撤回的误判见 `07_P6_兼容性与协议端到端.md` §8.5。"
           "本组其余两行不在该测试内：「连续调用」由本文档组 3 之外的连续调用项覆盖，"
           "「不增加 WDR 端口」由静态结构检查覆盖。（原文注：本注为本次追加，不改动上表原有内容。）\n")


def patch_10():
    p = DOCS / "10_正确性验证_§14.md"
    t = read(p)
    orig = t
    lines = t.split("\n")
    i = line_index(lines, "| **新指令 → 向量** | 反向顺序 |", "10/组 3 表尾")
    lines.insert(i + 1, NOTE_10.rstrip("\n"))
    t = "\n".join(lines)
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
