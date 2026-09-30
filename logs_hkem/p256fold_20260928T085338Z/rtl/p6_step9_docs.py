#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P6 Step 9 的文档更新（一次性工具；带断言，定位失败即报错）。

改三个文件（都在 <repo>/../md文档/p256方案20260927/new_contribution_2/）：
  07_P6_兼容性与协议端到端.md —— Step 9 的命令/口径落地 + 新增 §8.6 实测 + 旧 §8.6/§8.7 顺延为 §8.7/§8.8
  13_合并影响与回归清单.md      —— P6 进度行补 Step 9 + 数据面计数刷新 + 更新记录加一行 + §8.6→§8.7 引用
  10_正确性验证_§14.md          —— §14.3.1 组 2 标注已实测指针

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p6_step9_docs.py [--check]
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


CMD_BLOCK = '''```bash
cd "$repo_root"
# 逐实例 (stall, fetch) 固定性 —— 四条独立路径，全部带断言（不一致即退出码 1）
python3 %(dev)s/host/p6_stall_p256.py \\
    --trace-serial  %(dev)s/rtl/p5_ecdh_trace_es.txt \\
    --trace-overlap %(dev)s/rtl/p5_ecdh_trace_es_overlap.txt \\
    --device        %(dev)s/rtl/p5_device_evidence.ver1_2.txt \\
    --frames-csv    %(dev)s/reports/frames_p256.csv \\
    --out           %(dev)s/host/stall_p256.new.log
```
> **口径**：目标帧 = **帧内含本版 `bn.p256mul`** 的帧；帧的定义与 P0/P5 的帧模型逐字一致
> （`run_dir/rtl/frames_p256.py`）：`retired` = 帧内 `E` 记录数、`exec_stall` = 帧内 `S` 记录数、
> `fetch_gap` = 帧内 cycle 空档合计、`span = 离开拍 − 进入拍`。新指令由 `E` 行的**指令字解码**
> 判定（`sim.decode`，与 ISS 同一份指令表）⇒ 本工具**不依赖 ELF/符号表**。
> 实测结果见 §8.6。''' % {"dev": DEV}

S86_NEW = '''### 8.6 Step 9：新指令的逐实例 (stall, fetch) 固定性（本次完成）

```bash
python3 %(dev)s/host/p6_stall_p256.py \\
    --trace-serial  %(dev)s/rtl/p5_ecdh_trace_es.txt \\
    --trace-overlap %(dev)s/rtl/p5_ecdh_trace_es_overlap.txt \\
    --device        %(dev)s/rtl/p5_device_evidence.ver1_2.txt \\
    --frames-csv    %(dev)s/reports/frames_p256.csv \\
    --out           %(dev)s/host/stall_p256.new.log     # 入库的留档报告
```

| 路径 | 结果 |
|---|---|
| ① RTL 真机 serial | `(2, 27, 1, 30) × 9,599` —— **单一键**（2 退休 + 27 停滞 + 1 取指空档 = 30 拍/次） |
| ① RTL 真机 overlap | `(2, 21, 1, 24) × 9,599` —— **单一键** |
| ① 记录数自证 | ΣE+ΣS = 351,638 / 294,044 = 文件记录数（两档 ΣE 均 91,795） |
| ② 程序级闭合 | 事件数差 **57,594 = 9,599 × 6**；每帧 `exec_stall` 差 `[27] → [21]` |
| ③ 设备侧形态分布（chip sim + 真 Ibex） | `rows=27`、`err=0`、`wb=1`、`micro_mul=16`、`overlap=0`，各 **38,371 行、列列单键** |
| ④ 旧实现对照（P0 冻结） | `(53, 0, 1, 54) × 38,390` —— 单键 |
| 新指令落点 | **单一 PC `0x1a4`**（新 `mul_modp` 体只有一条 fold 指令） |

⇒ **判据 1 成立**：新指令在**相同 fetch 条件**下的 `(stall, fetch)` **单一键**（serial 27 / overlap 21），
与输入值、商 `k`、条件 ±p 修正分支无关。

**声明边界（§14.3 原文三层，分开报、不得混谈）**：本步只做「新指令/函数在相同 `fetch` 条件下是否
固定」；协议/外设的时间分布属另一层（见 `host/protocol_ver1_2.log` 的 `HKEM_PROF` 分段）。本文
**不声称侧信道抵抗** —— 固定周期只保证状态数/地址不依赖秘密，**不**等于抗功耗/抗故障；也未做泄漏
分析或攻击评估，清零路径的切换泄漏同理未评估。

**两条取证（防重走）**：① `run_p256.elf` 是**裸 app**（靠宿主 cryptolib 投喂输入），独立在 ISS 里
跑 218 拍即 `LOCKED`（实测）⇒ ISS 口径只能用自带输入的 `otbn_sim_test`（两个 RTL 记录正是它跑出来的）；
② `rtl_extra/run_p256.elf` 与 `baseline/run_p256.elf` 的符号布局**完全相同**（`mul_modp` 皆 53 words）
⇒ 二者都是**基线 app**，拿来映射新 app 的 trace 会错位（工具据此改为按指令字解码）。

''' % {"dev": DEV}


def patch_07():
    p = DOCS / "07_P6_兼容性与协议端到端.md"
    t = read(p)
    orig = t

    # ① Step 9 的命令块（唯一锚：那一行旧的 stall_profile 调用）
    old_cmd = ('```bash\ncd "$repo_root"\n'
               '# 确定性部分：逐实例 stall/fetch 直方图（新指令必须落在单一键上）\n'
               'python3 test_perf/tools/diag/stall_profile.py --target "$ELF" --version ver1_1 --op p256 \\\n'
               '    --out "$run_dir/host/stall_p256.new.log"\n```')
    t = sub_once(t, old_cmd, CMD_BLOCK, "07/Step9 命令块")

    # ② 新增 §8.6，旧 §8.6 / §8.7 顺延
    t = sub_once(t, "### 8.6 本节未覆盖的 P6 步骤（诚实清单）",
                 S86_NEW + "### 8.7 本节未覆盖的 P6 步骤（诚实清单）", "07/§8.6 插入")
    t = sub_once(t, "### 8.7 对 §7.3 待确认项的更新",
                 "### 8.8 对 §7.3 待确认项的更新", "07/§8.7 顺延")
    t = sub_once(t, "**仍未解决**，见 8.6 的清单", "**仍未解决**，见 8.7 的清单", "07/§8.8 引用")

    # ③ §8.7 未覆盖清单：Step 9 已完成
    lines = t.split("\n")
    i = line_index(lines, "- §3 的 **Step 8–10**", "07/§8.7 Step8-10 条")
    assert lines[i + 1].startswith("  （依赖时钟扫描流程"), "07：Step 8–10 条的第二行对不上"
    lines[i:i + 2] = [
        "- §3 的 **Step 9**（逐实例 stall/fetch 直方图单键）：**已于本次完成，见 §8.6** ✓。",
        "- §3 的 **Step 8 / Step 10**（同频 cycle + 各自 Fmax、结果 CSV/JSON）：**未做** —— Step 8 依赖",
        "  时钟扫描流程（见 §7.3 第 5 条），Step 10 的表要等 Step 8 的数。",
    ]
    t = "\n".join(lines)

    # ④ §6 产物清单：补生成器与判据
    t = sub_once(t, "| 逐实例 stall/fetch 直方图 | `$run_dir/host/stall_p256.new.log` | 单键 |",
                 "| 逐实例 stall/fetch 直方图 | `$run_dir/host/stall_p256.new.log`（生成器 "
                 "`$run_dir/host/p6_stall_p256.py`，自带断言） | 四条路径**各自单一键**；断言不过则退出码 1 |",
                 "07/§6 产物行")

    assert t != orig
    if not args.check:
        write(p, t)
    return p, len(orig.split("\n")), len(t.split("\n"))


def patch_13():
    p = DOCS / "13_合并影响与回归清单.md"
    t = read(p)
    orig = t

    # ① §8.6 → §8.7（两处引用：1b9b20af20 行 + P6 进度行）
    n = t.count("清单见 `07_P6_*.md` §8.6")
    assert n == 2, "13：§8.6 引用应为 2 处，实际 %d" % n
    t = t.replace("清单见 `07_P6_*.md` §8.6", "清单见 `07_P6_*.md` §8.7")

    # ② 数据面计数刷新（138/722,059 → 141/722,637）
    t = sub_once(t, "§1 的 ②（**138 文件 / +722,059 行**）", "§1 的 ②（**141 文件 / +722,637 行**）",
                 "13/数据面计数")

    # ③ P6 进度行：补 Step 9（只换尾巴，避免匹配带连字符的长串）
    lines = t.split("\n")
    i = line_index(lines, "| **P6**（共享平台与协议端到端）", "13/P6 进度行")
    k = lines[i].find("**未做**：")
    assert k > 0, "13/P6 进度行找不到「**未做**：」"
    lines[i] = lines[i][:k] + (
        "**已补做 Step 9**（逐实例 stall/fetch 固定性）：`python3 "
        "logs_hkem/p256fold_20260928T085338Z/host/p6_stall_p256.py --trace-serial … --trace-overlap … "
        "--device … --frames-csv … --out …` ⇒ 四条独立路径**全部单一键**：RTL 真机 serial "
        "`(2,27,1,30)×9,599`、overlap `(2,21,1,24)×9,599`（目标帧 = 帧内含 `bn.p256mul` 的帧，"
        "新指令按指令字解码判定、不依赖 ELF）；程序级闭合 57,594 = 9,599×6；设备侧 `rows=27 / err=0 / "
        "wb=1 / micro_mul=16 / overlap=0` 各 38,371 行列列单键；P0 旧实现对照 `(53,0,1,54)×38,390` "
        "单键。留档 `host/stall_p256.new.log`（工具 `host/p6_stall_p256.py`，断言不过即退出码 1）；"
        "声明边界（不声称侧信道抵抗、另报协议时间分布）见 `07_P6_*.md` §8.6。"
        "**未做**：Step 1–2 的 MAC/KMAC 用户回归、Step 8/10（时钟扫描 + 结果 CSV），"
        "清单见 `07_P6_*.md` §8.7 |")
    t = "\n".join(lines)

    # ④ 更新记录追加一行
    lines = t.split("\n")
    i = line_index(lines, "| 2026-09-30 | `7eda34aea3` |", "13/更新记录锚点")
    lines.insert(i + 1,
                 "| 2026-09-30 | `994fdbf5ef` | **P6 Step 9 完成（新指令逐实例 (stall, fetch) 固定性）**。"
                 "工具 `logs_hkem/p256fold_20260928T085338Z/host/p6_stall_p256.py`（纯 py、无 ELF 依赖、"
                 "自带断言），留档 `host/stall_p256.new.log`。**四条独立路径全部单一键**："
                 "① RTL 真机逐帧（目标帧 = 帧内含本版 `bn.p256mul` 的帧，新指令由 `E` 行**指令字解码**"
                 "判定 ⇒ 不依赖 ELF/符号表）：serial **`(2,27,1,30) × 9,599`**、overlap "
                 "**`(2,21,1,24) × 9,599`**，与 P5 冻结表逐项吻合；② 程序级闭合：Σ(E,S) = 351,638 / "
                 "294,044 == 文件记录数（ΣE 均 91,795），两模式差 **57,594 = 9,599 × 6**；"
                 "③ 设备侧形态分布（chip sim + 真 Ibex）：`rows=27` / `err=0` / `wb=1` / `micro_mul=16` / "
                 "`overlap=0` 各 **38,371 行、列列单键**；④ P0 旧实现对照：`(53,0,1,54) × 38,390` 单键。"
                 "⇒ 新指令在**相同 fetch 条件**下的 `(stall, fetch)` 单一键，与输入值/商 `k`/±p 修正分支无关；"
                 "**声明边界**照 §14.3 三层分开报（不声称侧信道抵抗、协议时间分布另报）。"
                 "**两条取证（防重走）**：裸 app `run_p256.elf` 独立在 ISS 里 218 拍即 `LOCKED`（靠宿主投喂输入，"
                 "不能用它取 ISS 口径）；`rtl_extra/run_p256.elf` 与 `baseline/run_p256.elf` 符号布局相同"
                 "（`mul_modp` 皆 53 words）⇒ 都是基线 app、不能映射新 app 的 trace。"
                 "§1 的 ② 刷新为 **141 文件 / +722,637 行**。 |")

    t = "\n".join(lines)
    assert t != orig
    if not args.check:
        write(p, t)
    return p, len(orig.split("\n")), len(t.split("\n"))


NOTE_10 = ("**执行状态（2026-09-30）**：本组「新指令在相同 `fetch` 条件下是否固定」已实测覆盖 —— "
           "`python3 logs_hkem/p256fold_20260928T085338Z/host/p6_stall_p256.py "
           "--trace-serial logs_hkem/p256fold_20260928T085338Z/rtl/p5_ecdh_trace_es.txt "
           "--trace-overlap logs_hkem/p256fold_20260928T085338Z/rtl/p5_ecdh_trace_es_overlap.txt "
           "--device logs_hkem/p256fold_20260928T085338Z/rtl/p5_device_evidence.ver1_2.txt "
           "--frames-csv logs_hkem/p256fold_20260928T085338Z/reports/frames_p256.csv "
           "--out logs_hkem/p256fold_20260928T085338Z/host/stall_p256.new.log`；"
           "逐实例 `(stall, fetch)` 落在**单一键**（serial `(2,27,1,30) × 9,599`、overlap `(2,21,1,24) × 9,599`，"
           "设备侧五列单键）。「必须另报外设/协议时间分布」与「不得据此声称侧信道抵抗」两条限定已在该节明文写出；"
           "证据见 `07_P6_兼容性与协议端到端.md` §8.6。")


def patch_10():
    p = DOCS / "10_正确性验证_§14.md"
    t = read(p)
    orig = t
    t = sub_once(t, "**声明边界的三条铁律**：", "> " + NOTE_10 + "\n\n**声明边界的三条铁律**：",
                 "10/§14.3.1 组 2 注")
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
