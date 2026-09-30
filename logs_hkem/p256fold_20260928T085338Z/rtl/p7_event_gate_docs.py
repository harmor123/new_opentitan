#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 收尾：把 P256EV 事件记录"默认关"这件事同步到**所有引用它的地方**（一次性；带断言）。

改 5 处：
  ① logs_hkem/.../rtl/p5_collect_device_evidence.sh （仓库内）—— 用法注释里补 plusarg
  ② test_perf/doc_fragments/ver1_2_extra.md        （仓库内）—— P256EV 证据行补"复现方式"
  ③ 06_P5_wrapper替换与KAT.md                       （文档）—— 同上
  ④ 08_P7_PPA与CSA决策.md §8.6 的 chip 行            （文档）
  ⑤ 13_合并影响与回归清单.md：第 4 行登记 + 更新记录一行

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_event_gate_docs.py [--check]
"""
import argparse
import pathlib

REPO = pathlib.Path(__file__).resolve().parents[3]          # .../opentitan
DOCS = REPO.parent / "md文档" / "p256方案20260927" / "new_contribution_2"
GATE = "`+p256_event_trace=1`"
NOTE = ("**注（2026-09-30 起）**：该证据需在运行期打开事件记录才打印 —— 芯片仿真加 "
        "`--test_arg=--verilator-args=+p256_event_trace=1`（见 `13_合并影响` 的登记）；"
        "默认静默（不打印/不写 CSV/不计数），且整块在 `ifndef SYNTHESIS` 内 ⇒ 网表与面积不受影响。")


def read(p):
    return p.read_text(encoding="utf-8")


def write(p, s):
    p.write_text(s, encoding="utf-8")


def sub_once(t, old, new, what):
    n = t.count(old)
    assert n == 1, "%s：期望 1 次，实际 %d 次" % (what, n)
    return t.replace(old, new, 1)


def patch_collector():
    p = REPO / "logs_hkem/p256fold_20260928T085338Z/rtl/p5_collect_device_evidence.sh"
    b = p.read_bytes()
    nl = "\r\n" if b"\r\n" in b else "\n"
    t = b.decode("utf-8").replace("\r\n", "\n")
    old = "#   bazel test //test_hybrid_kem_otbn_prompt_ver1_1:test_p256_only_sim_verilator $CHIP"
    assert t.count(old) == 1
    t = t.replace(old, old + "\n"
                  "#     ⚠ 2026-09-30 起事件记录**默认关**：要采 P256EV 必须再加\n"
                  "#       --test_arg=--verilator-args=+p256_event_trace=1", 1)
    if not args.check:
        p.write_bytes(t.replace("\n", nl).encode("utf-8"))
    return p, 0, 0


def patch_fragment():
    p = REPO / "test_perf/doc_fragments/ver1_2_extra.md"
    t = read(p)
    old = ("- **逐指令事件**（本版实现共 38,371 行 `P256EV`）：每条指令 `rows=27`、`err=0`、`wb=1`、"
           "`micro_mul=16`，serial 档 `overlap=0` —— 五个分布**全单键** ⇒ 定长性与写回不变式在设备路径上成立。")
    assert t.count(old) == 1
    t = t.replace(old, old + "（" + NOTE + "）", 1)
    if not args.check:
        write(p, t)
    return p, 0, 0


def patch_06():
    p = DOCS / "06_P5_wrapper替换与KAT.md"
    t = read(p)
    old = "（此前只在单元 TB 与 co-sim 上有此证据）。"
    assert t.count(old) == 1
    t = t.replace(old, "（此前只在单元 TB 与 co-sim 上有此证据）。" + NOTE, 1)
    if not args.check:
        write(p, t)
    return p, 0, 0


def patch_08():
    p = DOCS / "08_P7_PPA与CSA决策.md"
    t = read(p)
    old = "| chip 锚点（`test_p256_only_sim_verilator`） | `PASS!` + 四个指令数逐位不变 + `P256EV` 五列形态分布不变 | 见 §8.7 |"
    assert t.count(old) == 1
    t = t.replace(old, "| chip 锚点（`test_p256_only_sim_verilator`） | `PASS!` + 四个指令数逐位不变 + "
                       "`P256EV` 五列形态分布不变（**需 " + GATE + "**） | ✓（`PASSED`；形态分布未变） |", 1)
    if not args.check:
        write(p, t)
    return p, 0, 0


def patch_13():
    p = DOCS / "13_合并影响与回归清单.md"
    t = read(p)
    lines = t.split("\n")
    i = next(k for k, l in enumerate(lines) if l.startswith("| 4 | `rtl/otbn_mac_bignum.sv`"))
    assert lines[i].endswith(" |")
    lines[i] = lines[i][:-2] + (
        "；**P7 收尾**：P4 事件记录（`ifndef SYNTHESIS` 内）改为**默认关**，"
        "由 `$value$plusargs(\"p256_event_trace=%d\")` 控制（芯片仿真 "
        "`--test_arg=--verilator-args=+p256_event_trace=1`；独立仿真 `+p256_event_trace=1`）"
        "⇒ 日常回归不再打 3.8 万行、不再往 CWD 写 `otbn_p256_events.csv`；"
        "**综合时整块被裁掉 ⇒ 网表与面积不变** |")
    t = "\n".join(lines)

    lines = t.split("\n")
    i = next(k for k, l in enumerate(lines) if l.startswith("| 2026-09-30 | `543d39dc19` |"))
    lines.insert(i + 1,
                 "| 2026-09-30 | `d0a7922700` | **P7 收尾：`P256EV` 事件记录改为默认关（plusarg 打开）**。"
                 "`otbn_mac_bignum.sv` 的 P4 事件块此前每次运行都打印（设备测试一次 3.8 万行）并往 CWD 写 "
                 "`otbn_p256_events.csv`；现加 `p256_ev_en`（`$value$plusargs(\"p256_event_trace=%d\")`，"
                 "**默认 0**）门控 CSV 打开与 `always_ff` 的计数/写文件/打印整块。"
                 "**取证据**：芯片仿真 `--test_arg=--verilator-args=+p256_event_trace=1`、独立仿真 "
                 "`+p256_event_trace=1`（与 `p256_serial` 同套路，**不需要重建模型**）。"
                 "**为什么不用 `ifdef`**：那要改 Verilator 构建开关（fuseSoC/bazel），而 PDF §10.5 明说"
                 "自定义 build flag 的名字尚未规定。**不改网表**：整块在 `ifndef SYNTHESIS` 内 ⇒ "
                 "A0/A1/L1/B0 的面积数不受影响。引用处同步：`p5_collect_device_evidence.sh` 的用法注释、"
                 "`06_P5_*.md`、`08_P7_*.md` §8.6、`test_perf/doc_fragments/ver1_2_extra.md`。 |")
    t = "\n".join(lines)
    if not args.check:
        write(p, t)
    return p, 0, 0


def main():
    for name, fn in (("collector", patch_collector), ("fragment", patch_fragment),
                     ("doc06", patch_06), ("doc08", patch_08), ("doc13", patch_13)):
        p, _, _ = fn()
        print("%-10s %s" % (name, p.name))
    print("OK" + (" (check only, nothing written)" if args.check else ""))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    main()
