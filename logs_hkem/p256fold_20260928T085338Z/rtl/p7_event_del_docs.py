#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把"P256EV 调试块已删除"同步到所有引用处（一次性；带断言）。

删除提交 = 5f24200748（`otbn_mac_bignum.sv` 的 P4 事件块整体删除）。
改 5 处：采集脚本用法注释、ver1_2 片段、06_P5 文档、08_P7 §8.6、13_合并影响（第 4 行 + 更新记录）。

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_event_del_docs.py [--check]
"""
import argparse
import pathlib

REPO = pathlib.Path(__file__).resolve().parents[3]
DOCS = REPO.parent / "md文档" / "p256方案20260927" / "new_contribution_2"
DEL = "5f24200748"

NOTE_OLD_A = ("**注（2026-09-30 起）**：该证据需在运行期打开事件记录才打印 —— 芯片仿真加 "
              "`--test_arg=--verilator-args=+p256_event_trace=1`（见 `13_合并影响` 的登记）；"
              "默认静默（不打印/不写 CSV/不计数），且整块在 `ifndef SYNTHESIS` 内 ⇒ 网表与面积不受影响。")
NOTE_NEW = ("**注（2026-09-30）**：该证据来自 P4 期的**仿真调试事件块**（`otbn_mac_bignum.sv` 的 "
            "`ifndef SYNTHESIS` 区），该块已在 `" + DEL + "` **整体删除** —— 调试脚手架不进交付网表；"
            "已入库的日志就是该证据的存档，需要复现时 `git revert " + DEL + "` 即可取回。")


def sub_once(t, old, new, what):
    n = t.count(old)
    assert n == 1, "%s：期望 1 次，实际 %d 次" % (what, n)
    return t.replace(old, new, 1)


def patch_collector():
    p = REPO / "logs_hkem/p256fold_20260928T085338Z/rtl/p5_collect_device_evidence.sh"
    b = p.read_bytes()
    nl = "\r\n" if b"\r\n" in b else "\n"
    t = b.decode("utf-8").replace("\r\n", "\n")
    old = ("#     ⚠ 2026-09-30 起事件记录**默认关**：要采 P256EV 必须再加\n"
           "#       --test_arg=--verilator-args=+p256_event_trace=1")
    new = ("#     ⚠ 2026-09-30：产生 P256EV 的**调试事件块已整体删除**（" + DEL + "）⇒ 本脚本现在只用于\n"
           "#       复核**当时**采集的日志，不能再对新运行采数；要复现请 `git revert " + DEL + "` 取回该块。")
    t = sub_once(t, old, new, "collector")
    if not args.check:
        p.write_bytes(t.replace("\n", nl).encode("utf-8"))


def patch_fragment():
    p = REPO / "test_perf/doc_fragments/ver1_2_extra.md"
    t = sub_once(p.read_text(encoding="utf-8"), NOTE_OLD_A, NOTE_NEW, "fragment")
    if not args.check:
        p.write_text(t, encoding="utf-8")


def patch_md(name, what):
    p = DOCS / name
    t = p.read_text(encoding="utf-8")
    t = sub_once(t, NOTE_OLD_A, NOTE_NEW, what)
    if not args.check:
        p.write_text(t, encoding="utf-8")


def patch_08():
    p = DOCS / "08_P7_PPA与CSA决策.md"
    t = p.read_text(encoding="utf-8")
    old = ("| chip 锚点（`test_p256_only_sim_verilator`） | `PASS!` + 四个指令数逐位不变 + "
           "`P256EV` 五列形态分布不变（**需 `+p256_event_trace=1`**） | ✓（`PASSED`；形态分布未变） |")
    assert t.count(old) == 1
    t = t.replace(old, "| chip 锚点（`test_p256_only_sim_verilator`） | `PASS!` + 四个指令数逐位不变"
                       "（该证据来自设备测试自身的打印，**不依赖**调试块）；`P256EV` 五列形态分布不变属"
                       "**当时调试块的记录**（块已删，见 `13_合并影响`） | ✓（`PASSED`；形态分布未变） |", 1)
    if not args.check:
        p.write_text(t, encoding="utf-8")


def patch_13():
    p = DOCS / "13_合并影响与回归清单.md"
    t = p.read_text(encoding="utf-8")
    old = ("；**P7 收尾**：P4 事件记录（`ifndef SYNTHESIS` 内）改为**默认关**，"
           "由 `$value$plusargs(\"p256_event_trace=%d\")` 控制（芯片仿真 "
           "`--test_arg=--verilator-args=+p256_event_trace=1`；独立仿真 `+p256_event_trace=1`）"
           "⇒ 日常回归不再打 3.8 万行、不再往 CWD 写 `otbn_p256_events.csv`；"
           "**综合时整块被裁掉 ⇒ 网表与面积不变** |")
    assert t.count(old) == 1
    t = t.replace(old, "；**P7 收尾**：P4 的 `P256EV` 事件记录块**已整体删除**（`" + DEL + "`，116 行）"
                       "—— 它是实验脚手架、不属于交付网表；证据已入库（`logs_hkem/…`），复现用 "
                       "`git revert " + DEL + "`。**保留**同区内的 `P256FoldWbAtRetire` 断言。"
                       "（该块原本在 `ifndef SYNTHESIS` 内 ⇒ 删除对网表与面积零影响） |", 1)

    lines = t.split("\n")
    i = next(k for k, l in enumerate(lines) if l.startswith("| 2026-09-30 | `d0a7922700` |"))
    lines.insert(i + 1,
                 "| 2026-09-30 | `5f24200748` | **P7 收尾：删掉 `P256EV` 调试事件块**（`otbn_mac_bignum.sv` "
                 "的 P4 逐拍事件记录，116 行：计数 + CSV + `$display`；`p256_ev_en`/`p256_event_trace` "
                 "plusarg 一并移除）。**保留** `P256FoldWbAtRetire` 断言与上游 permutation 检查。"
                 "理由：调试脚手架不进交付网表。**证据不丢**：`rows=27 / err=0 / wb=1 / micro_mul=16 / "
                 "overlap=0`、38,371 行等形态分布已入库（`p5_device_evidence.*.txt`、"
                 "`host/stall_p256.new.log` 的「③ 设备侧形态分布」行）；复现用 `git revert "
                 "5f24200748`。**对面积/时序零影响**（本就在 `ifndef SYNTHESIS` 内）。"
                 "引用处（采集脚本、ver1_2 片段、`06_P5_*`、`08_P7_*` §8.6）已同步为「块已删」。 |")
    t = "\n".join(lines)
    if not args.check:
        p.write_text(t, encoding="utf-8")


def main():
    patch_collector()
    patch_fragment()
    patch_md("06_P5_wrapper替换与KAT.md", "doc06")
    patch_08()
    patch_13()
    print("OK" + (" (check only, nothing written)" if args.check else ""))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    main()
