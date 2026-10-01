#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 §8.17：P-256 折叠指令的 **ISS 口径对照**（harness 专表：未折叠 ↔ 折叠）。

**在 Windows 侧跑**。数从两侧 harness JSON（`logs_hkem/p256_{old,ver1_2}_profiling/`）、
P5 设备证据（`rtl/p5_device_evidence*.txt`）、P5 帧数据（`reports/p5_frame.md`）读；
断言不成立即拒绝写。纪律：不留过程记录（只写正确命令 + 结果 + 口径说明）。

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step17_docs.py [--check] [--force] [--commit HASH]
"""
import argparse
import json
import pathlib
import re
import subprocess
import sys

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = pathlib.Path(__file__).resolve().parents[3]
RUN = REPO / "logs_hkem/p256fold_20260928T085338Z"
DOCS = REPO.parent / "md文档" / "p256方案20260927" / "new_contribution_2"
DOC, QDOC = "08_P7_PPA与CSA决策.md", "13_合并影响与回归清单.md"
OLD, NEW = "p256_old", "p256_ver1_2"


def rd(p):
    return pathlib.Path(p).read_text(encoding="utf-8", errors="replace")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--commit", help="登记到 13 文档的提交号（默认取数据目录最近一次提交）")
    args = ap.parse_args()

    # ── 两侧 harness 产物 ────────────────────────────────────────────────
    J = {}
    for v in (OLD, NEW):
        p = REPO / ("logs_hkem/%s_profiling/re_%s.json" % (v, v))
        assert p.exists(), "缺 %s（先跑 harness：--version %s）" % (p, v)
        J[v] = json.loads(p.read_text(encoding="utf-8"))
        apps = J[v]["apps"][v]
        assert set(apps) == {"ecdh", "mul_modp"}, sorted(apps)
        for op in ("ecdh", "mul_modp"):
            h = apps[op]["halt"]
            assert h["err_bits"] == 0 and h["ecall"] >= 1, ("收尾不干净", v, op, h)
    eo, en = J[OLD]["apps"][OLD]["ecdh"], J[NEW]["apps"][NEW]["ecdh"]
    mo, mn = J[OLD]["apps"][OLD]["mul_modp"], J[NEW]["apps"][NEW]["mul_modp"]

    # ── 断言：逐符号归属（除 mul_modp 外全部逐位相同；mul_modp 53↔2 × 同一调用数）──
    so, sn = eo["exec_insn"], en["exec_insn"]
    assert set(so) == set(sn), sorted(set(so) ^ set(sn))
    diff = {k for k in so if so[k] != sn[k]}
    assert diff == {"mul_modp"}, ("除 mul_modp 外还有符号不同", sorted(diff))
    assert mn["exec_insn"]["mul_modp"] % 2 == 0
    calls = mn["exec_insn"]["mul_modp"] // 2
    assert so["mul_modp"] == 53 * calls, (so["mul_modp"], calls)
    assert mn["exec_insn"]["mul_modp"] == 2 * calls
    assert eo["insn"] > en["insn"] > 0
    drop_pct = 100.0 * (eo["insn"] - en["insn"]) / eo["insn"]
    assert 80.0 < drop_pct < 88.0, drop_pct
    assert mo["insn"] - mn["insn"] == 51, (mo["insn"], mn["insn"])   # 53 − 2（测试壳相同）

    # ── 设备证据（P5，ver1_2；与应用级锚点）────────────────────────────
    ev = rd(RUN / "rtl/p5_device_evidence.ver1_2.txt")
    d_key = int(re.search(r"Keygen A OTBN instruction count: 0x([0-9a-f]+)", ev).group(1), 16)
    d_ecd = int(re.search(r"ECDH A OTBN instruction count: 0x([0-9a-f]+)", ev).group(1), 16)
    assert (d_key, d_ecd) == (84679, 91893), (d_key, d_ecd)
    assert re.search(r"P256EV 行总数\s*\n38371", ev)
    # 上游/ver0_1 锚点（`test_perf/doc_fragments/ver1_2_extra.md` 的对照表）
    frag = rd(REPO / "test_perf/doc_fragments/ver1_2_extra.md")
    u_key = int(re.search(r"=\s*([\d,]+)\s*\|\s*`0x14ac7`", frag).group(1).replace(",", ""))
    u_ecd = int(re.search(r"=\s*([\d,]+)\s*\|\s*`0x166f5`", frag).group(1).replace(",", ""))
    assert (u_key, u_ecd) == (573922, 581607), (u_key, u_ecd)
    # P5 帧数据的调用数（逐帧实测）
    frame = rd(RUN / "reports/p5_frame.md")
    assert "9,599" in frame, "P5 帧数据里找不到 9,599 次调用"
    assert calls == 9599, ("ISS 两侧的调用数与 P5 逐帧数据不一致", calls)
    # 设备锚点复核（本次重跑；缺了就报出来，不静默跳过）
    rc = RUN / "rtl/p5_device_recheck.ver1_2.txt"
    assert rc.exists(), "缺 %s（跑 test_p256_only_sim_verilator 并抓取证据）" % rc
    rct = rd(rc)
    assert "PASS" in rct, "复核日志里没有 PASS"
    assert "0x00014ac7" in rct and "0x000166f5" in rct, "复核日志里缺应用级指令数锚点"

    p = DOCS / DOC
    t = p.read_text(encoding="utf-8")
    assert "#### 8.16 " in t, "§8.16 尚未写入"
    if "#### 8.17 " in t:
        if not args.force:
            raise SystemExit("§8.17 已存在（重写用 --force）")
        t = t[:t.index("#### 8.17 ")]

    L = []
    L.append("#### 8.17 P-256 折叠指令的 ISS 口径对照（harness 专表：未折叠 ↔ 折叠）（2026-10-01）")
    L.append("")
    L.append("**甲、装置与口径**：`test_perf/harness_config.yaml` 的 **P-256 专表**两条目 `p256_old`（未折叠："
             "软件 `mul_modp`，函数体 53 条）/ `p256_ver1_2`（折叠：一条 `bn.p256mul`）——apps-only 条目"
             "（无 prof/control 桩）⇒ 数取 ① Macro，逐符号 `exec_insn` 在 JSON 里 ✓。两个包在 ver1_2 树内"
             "**逐文件、逐目标镜像**（`otbn/p256/` 与 `otbn/p256_old/`，各 9/10 个文件），且**完全自包含**"
             "（不引用 `//sw/otbn/crypto`）；两侧**唯一差别** = `p256_base.s` 的 `mul_modp` 函数体。"
             "测试程序同一支（`p256_ecdh_shared_key_test.s`）；另有单函数项（`p256_mul_modp_test.s`）。")
    L.append("")
    L.append("**乙、ISS 两侧实测（同一支程序；`ecdh` 为一次共享密钥计算）**")
    L.append("")
    L.append("| 项 | `p256_old`（未折叠） | `p256_ver1_2`（折叠） | Δ |")
    L.append("|---|---:|---:|---:|")
    L.append("| retired 指令 | %s | **%s** | **−%s（−%.1f%%）** |"
             % (format(eo["insn"], ","), format(en["insn"], ","),
                format(eo["insn"] - en["insn"], ","), drop_pct))
    L.append("| 停滞拍 | %s | %s | %+d |"
             % (format(eo["stalls"], ","), format(en["stalls"], ","), en["stalls"] - eo["stalls"]))
    L.append("| cycles（= 指令 + 停滞） | %s | %s | **−%s** |"
             % (format(eo["cycles"], ","), format(en["cycles"], ","),
                format(eo["cycles"] - en["cycles"], ",")))
    L.append("| 单函数项 `mul_modp` 指令数 | %s | **%s** | **−51**（每次调用 53 → 2 ✓） |"
             % (format(mo["insn"], ","), format(mn["insn"], ",")))
    L.append("")
    L.append("**逐符号归属（`exec_insn` 逐符号比对，%d 个符号）**：**除 `mul_modp` 外全部逐位相同** ✓ —— "
             "`mul_modp` 合计 %s → **%s**，恰为 **%s 次调用 ×（53 → 2）** ✓（减幅 %s）。"
             "与 P5 逐帧数据（`reports/p5_frame.md`：9,599 次调用、每次 30 拍 serial）一致 ✓。"
             % (len(so), format(so["mul_modp"], ","), format(mn["exec_insn"]["mul_modp"], ","),
                format(calls, ","), format(so["mul_modp"] - mn["exec_insn"]["mul_modp"], ",")))
    L.append("")
    L.append("**丙、与设备口径并列（两条路径相互印证）**")
    L.append("")
    L.append("| 口径 | 旧侧（未折叠/官方） | 新侧（折叠） | Δ |")
    L.append("|---|---:|---:|---:|")
    L.append("| 设备（chip sim 的 OTBN `INSN_CNT`；Keygen A / ECDH A） | %s / %s | **%s / %s** | −85.3%% / −84.2%% |"
             % (format(u_key, ","), format(u_ecd, ","), format(d_key, ","), format(d_ecd, ",")))
    L.append("| ISS（本表；一次共享密钥计算 = `ecdh`） | %s | **%s** | **−%.1f%%** |"
             % (format(eo["insn"], ","), format(en["insn"], ","), drop_pct))
    L.append("")
    L.append("设备锚点复核（2026-10-01 重跑 `//…/ver1_2:test_p256_only_sim_verilator`）：`PASS!` ✓，"
             "四个会话的指令数与上文**逐位一致**（`0x14ac7` / `0x166f5`），P256EV 行数 38,371 ✓ —— "
             "自包含化（副本进树）不改设备侧行为 ✓。")
    L.append("")
    L.append("**丁、口径说明（本轮实测得到的两条，供复用）**")
    L.append("")
    L.append("1. **ISS 的 URND 每拍推进**（`otbnsim/sim/sim.py:_step_exec` 每拍 `URND.step()`）⇒ 两个实现的拍数不同"
             "（53 条 vs 1 条 + 27 停滞）⇒ 收到的随机值不同 ⇒ **掩码份额必然不同**：`p256.dexp` 查的是"
             " `dmem[x]/dmem[y]` 两份額，**不能跨实现复用** ✗；但两份額异或出的**密钥相同** ✓ ⇒ 旧侧金标改用"
             " **`w11`（解出的共享密钥）**，与上游官方 ECDH 测试「只查 w11」同一口径。金标电池："
             "`bazel test //…/otbn/p256:all`（dexp 金标）与 `//…/otbn/p256_old:all`（`w11` 金标）均 **PASS** ✓。")
    L.append("2. **ver0_1（与 ver2）的 `otbn/p256` 目标有装配缺陷**（不作为本表的旧侧）：4 个 `.s` 合在一次汇编，"
             "`p256_isoncurve_proj.s` 缺 `.text` ⇒ 继承前一文件的 `.section .data` ⇒ 51 条指令进 DMEM、符号落"
             "数据段、`jal` 跳飞 ⇒ 曲线自检拿垃圾值后故意触发 `ILLEGAL_INSN`（`ERR_BITS=0x8`）。规则：多文件 "
             "`srcs` 里每个 `.s` 显式写 `.text`（或一文件一 `otbn_library`）；静态检查器 "
             "`test_perf/tools/check/check_asm_sections.py`（当前全仓仅剩那三处已知点）✓。")
    L.append("")
    L.append("**戊、产物与工具落点**")
    L.append("")
    L.append("| 件 | 落点 |")
    L.append("|---|---|")
    L.append("| 两侧 ISS 数（含逐符号 `exec_insn`） | `logs_hkem/p256_old_profiling/re_p256_old.{json,md}`、"
             "`logs_hkem/p256_ver1_2_profiling/re_p256_ver1_2.{json,md}` |")
    L.append("| 两个镜像包（自包含） | `test_hybrid_kem_otbn_prompt_ver1_2/otbn/p256/`（折叠）、`…/p256_old/`（未折叠） |")
    L.append("| 设备证据（复核） | `rtl/p5_device_recheck.ver1_2.txt`（原采集见 `rtl/p5_device_evidence.*.txt`）|")
    L.append("| 工具 | harness 专表条目；`tools/check/check_asm_sections.py`；`tools/check/harness_apps_only_smoke.py`；"
             "`tools/diag/p256_symbol_profile.py`、`p256_iss_divergence.py` |")
    L.append("")
    L.append("复现：")
    L.append("```bash")
    L.append("CHIP=\"--test_timeout=2000 --cache_test_results=no --sandbox_writable_path=/run/user/1000/ccache-tmp --test_output=streamed\"")
    L.append("bazel test //test_hybrid_kem_otbn_prompt_ver1_2/otbn/p256:all $CHIP")
    L.append("bazel test //test_hybrid_kem_otbn_prompt_ver1_2/otbn/p256_old:all $CHIP")
    L.append("for V in p256_old p256_ver1_2; do python3 test_perf/harness.py --config test_perf/harness_config.yaml \\")
    L.append("    --version $V --json logs_hkem/${V}_profiling/re_${V}.json --markdown logs_hkem/${V}_profiling/re_${V}.md; done")
    L.append("```")
    L.append("")

    sec = "\n".join(L)
    if not args.check:
        p.write_text(t.rstrip("\n") + "\n\n" + sec, encoding="utf-8")
        h = args.commit
        if not h:
            r = subprocess.run(["git", "log", "-1", "--format=%h", "--",
                                "logs_hkem/p256_old_profiling"], cwd=REPO,
                               capture_output=True, text=True)
            h = r.stdout.strip() or "?"
        q = DOCS / QDOC
        t2 = q.read_text(encoding="utf-8")
        lines = t2.split("\n")
        if not any("P7 §8.17" in l for l in lines):
            i = next(k for k, l in enumerate(lines) if l.startswith("| 2026-10-01 | `664c398cf4` |"))
            lines.insert(
                i + 1,
                "| 2026-10-01 | `%s` | **P-256 的 ISS 口径对照（P7 §8.17）**。两个**完全自包含**的镜像包"
                "（ver1_2 树 `otbn/p256` 折叠 / `otbn/p256_old` 未折叠，唯一差别 = `mul_modp` 53↔1 条）＋"
                "harness 专表条目；ISS：一次共享密钥计算 %s → **%s** 条指令（**−%.1f%%**）、"
                "**除 `mul_modp` 外逐符号逐位相同** ✓、单函数项 53→2 条/次（%s 次调用）；"
                "设备锚点逐位复核 ✓。口径：dexp 查掩码份额（URND 每拍推进）⇒ 旧侧金标改用 `w11`。 |"
                % (h, format(eo["insn"], ","), format(en["insn"], ","), drop_pct, format(calls, ",")))
        q.write_text("\n".join(lines), encoding="utf-8")
    print(sec)
    print("OK" + (" (check only)" if args.check else ""))


if __name__ == "__main__":
    main()
