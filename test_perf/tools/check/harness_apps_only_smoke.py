#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""`harness.py` 的**打桩冒烟测试**：apps-only 条目（`phases: []`）与写出路径。

为什么需要它：`harness_config.yaml` 从 2026-10-01 起有 apps-only 条目（P-256 专表：
`p256_old` / `p256_ver1_2`）。这类条目没有 prof/control 桩 ⇒ 必须在 harness 里
走"没有阶段行"的分支（空 bazel_build 被放行、CSV 跳过、Markdown 出 app 表、
JSON 照常带 `apps[*].exec_insn`）。真跑一次要 bazel+ISS（Linux，分钟级）；
本脚本把 bazel/ISS 四项打桩（数字由目标名确定 ⇒ 可复现），几秒内把这三条路径都过一遍。

**覆盖**（缺一即非零退出）：
  ① apps_only：`rows == []`、apps 有数、逐符号 `exec_insn` 进 JSON、不写 CSV、MD 出 app 表；
  ② with_rows：有阶段行的条目行为不变（rows 非空、CSV/MD 都是阶段口径）；
  ③ mixed：两类条目同跑各归各；
  ④ 模型自检：`BNP256MUL.micro_cycles()` **运行期**读 env（默认 27 / env=0 时 21）——
     写死成 import 期常量会让 env 条目静默失效（曾发生：env 设了、拍数仍按 serial），这里钉住。

**不覆盖**（别当替代品）：真实的 bazel 构建/`cquery` 取 `.elf`、ISS 数值本身、
`.elf` 是否存在 —— 那些只能真跑（见 README 的命令）。

用法：python3 test_perf/tools/check/harness_apps_only_smoke.py
"""
import json
import os
import pathlib
import sys
import tempfile

REPO = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "test_perf"))


def main() -> int:
    import harness

    # ── 模型自检：折叠调度拍数必须运行期读 env ──────────────────────────
    # `import harness` 已把 otbnsim 放进 sys.path；这里直接问模型本身。
    from sim.insn import BNP256MUL
    env_before = os.environ.pop("OTBN_P256_SERIAL", None)
    try:
        assert BNP256MUL.micro_cycles() == 27, "默认应为 serial（27 拍停滞）"
        os.environ["OTBN_P256_SERIAL"] = "0"
        assert BNP256MUL.micro_cycles() == 21, "env=0 应为 overlap（21 拍停滞）"
    finally:
        os.environ.pop("OTBN_P256_SERIAL", None)
        if env_before is not None:
            os.environ["OTBN_P256_SERIAL"] = env_before
    print("[smoke] 模型自检 OK（BNP256MUL 运行期读 env：默认 27 / env=0 → 21）")

    # ── 打桩（不碰 bazel/ISS）────────────────────────────────────────────
    harness.bazel_build = lambda targets: None            # 不做真构建（apps-only 时 targets 为空）
    harness.bazel_elf = lambda t: "fake::" + t            # 假 ELF 路径（编码目标名）

    def fake_run_elf(elf: str):
        n = sum(ord(c) for c in elf) % 1000               # 由目标名决定的确定数
        histo = {"bn.mulqacc.wo": n % 17, "ecall": 1}
        calls = [{"callee_func": 0x8002}]
        bnds = [(0x8000, 0x8010, "fake_main"), (0x8010, 0x8100, "fake_kernel")]
        cov = {0x8002: n % 23, 0x8011: n % 29}
        halt = {"err_bits": 0, "pending_halt": False, "fsm": "IDLE", "ecall": 1}
        return (1000 + n, 900 + n, 100, histo, calls, bnds, cov, halt)

    seen_env = []                                  # 每次 run_elf 时看到的 OTBN_P256_SERIAL（条目级 env 自检）

    def fake_run_elf_env(elf: str):
        seen_env.append(os.environ.get("OTBN_P256_SERIAL"))
        return fake_run_elf(elf)

    harness.run_elf = fake_run_elf_env
    harness.elf_size = lambda elf: (4096, 128, 64)

    out = pathlib.Path(tempfile.mkdtemp(prefix="harness_smoke_"))
    argv = list(sys.argv)
    try:
        serial_before = os.environ.pop("OTBN_P256_SERIAL", None)   # 起点干净
        for case, vers in (("apps_only", ["p256_old", "p256_ver1_2"]),
                           ("overlap_env", ["p256_ver1_2_overlap"]),
                           ("with_rows", ["ver0_1"]),
                           ("mixed", ["ver0_1", "p256_ver1_2"])):
            sys.argv = ["harness.py", "--config", str(REPO / "test_perf/harness_config.yaml")]
            for v in vers:
                sys.argv += ["--version", v]
            sys.argv += ["--csv", str(out / f"{case}.csv"), "--json", str(out / f"{case}.json"),
                         "--markdown", str(out / f"{case}.md"), "--no-force-rebuild"]
            seen_env.clear()
            rc = harness.main()
            assert rc == 0, (case, rc)
            d = json.loads((out / f"{case}.json").read_text(encoding="utf-8"))
            rows, apps = d["rows"], d["apps"]
            if case == "apps_only":
                assert "0" not in seen_env, ("无 env 条目不该看到 OTBN_P256_SERIAL", seen_env)
                assert rows == [], "apps-only 不该有阶段行"
                assert set(apps) == {"p256_old", "p256_ver1_2"}, list(apps)
                a = apps["p256_ver1_2"]["ecdh"]
                assert a["exec_insn"].get("fake_main"), "逐符号 exec_insn 没进 JSON"
                assert a["exec_insn"].get("fake_kernel"), "逐符号 exec_insn 不完整"
                assert not (out / f"{case}.csv").exists(), "无阶段行时 CSV 应被跳过"
                md = (out / f"{case}.md").read_text(encoding="utf-8")
                assert "| 版本 | op |" in md and "p256_ver1_2" in md, "Markdown 应是 app 表"
            elif case == "with_rows":
                assert rows, "有阶段行的条目应有 rows"
                assert (out / f"{case}.csv").exists(), "有阶段行时 CSV 应写好"
                md = (out / f"{case}.md").read_text(encoding="utf-8")
                assert "| 版本 | 阶段 |" in md, "Markdown 应是阶段表"
            elif case == "overlap_env":
                # 条目级 env：本 case 的每次 run_elf 期间都必须是 0；main() 返回后必须已恢复
                assert seen_env and all(v == "0" for v in seen_env), ("运行期没看到 OTBN_P256_SERIAL=0", seen_env)
                assert os.environ.get("OTBN_P256_SERIAL") is None, "env 未恢复"
            else:
                assert rows and set(apps) == {"ver0_1", "p256_ver1_2"}
            print("[smoke] %-9s OK（rows=%d，版本=%s）" % (case, len(rows), sorted(apps)))
    finally:
        sys.argv = argv
        if serial_before is not None:
            os.environ["OTBN_P256_SERIAL"] = serial_before
    print("[smoke] 全部通过 ✓（打桩数据；产物在 %s，可删）" % out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
