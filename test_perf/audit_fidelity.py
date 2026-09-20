#!/usr/bin/env python3
"""判定性审计：harness 的每一行**能不能代表 app 的真实情况**（逐行给是/否）。

回答四问中的三问（第四问是数据无关性，用 `fidelity_check.py` 跑 ISS 判定）：

  ① **内核源码同一份？** 行链接的 .s 文件里是不是**定义该内核的那个文件**，
     且该文件也是 app 链接的？（不是"同名副本"—— 是同一份源文件）
  ② **调用次数对齐？** app 的动态调用次数（ISS `func_calls`，真实执行轨迹）
     vs 进 Σ 的各行声明次数之和。**app 调了而行里没有 = 成本未被归因；
     行调了而 app 没有 = 幽灵行（凭空多算）**。
  ③ **Δ 语义 = 内核净成本？** control 是否逐条等于 profiling 去掉 `jal`
     （调 `fix_controls.py` 的同一套判定）。

用法:
    python3 test_perf/audit_fidelity.py --version ver1_1
    python3 test_perf/audit_fidelity.py --version ver0_1 --rows-only-noisy   # 只打印有问题/未覆盖的
"""
import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parent))
import fix_controls as F      # noqa: E402  复用"control ≡ profiling−jal"的判定


# 框架/容器函数：它们的成本**预期**落在残差里（阶段行只覆盖它们调用的内核）
FRAMEWORK = ("crypto_kem_", "indcpa_", "_encrypt_core", "_decrypt_core")


def is_framework(sym: str) -> bool:
    return any(sym.startswith(p) for p in FRAMEWORK)


def build_srcs(build: Path, target: str):
    """某目标 srcs 的**展开文本**：把 BUILD 顶层字符串变量（如 ver1_1 的 XOF）换成其值。

    否则 ver1_1 的行/app 用了裸变量名 `XOF,`，子串判断会误报"没链接定义文件"。
    """
    txt = build.read_text(encoding="utf-8")
    vars_ = dict(re.findall(r'^([A-Za-z_]\w*)\s*=\s*"([^"]*)"', txt, flags=re.M))
    m = re.search(r'name = "%s",\s*\n\s*srcs = \[(.*?)\]' % re.escape(target), txt, re.S)
    if not m:
        return ""
    body = m.group(1)
    for k, val in vars_.items():
        body = re.sub(r'(?<![\w"])%s(?![\w"])' % re.escape(k), val, body)
    return body


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--quiet-ok", action="store_true")
    args = ap.parse_args()

    v = args.version
    pkg = REPO / f"test_hybrid_kem_otbn_prompt_{v}" / "otbn" / "mlkem768"
    build = pkg / "BUILD"
    d = json.loads((REPO / "logs_hkem" / f"{v}_profiling" / f"re_{v}.json").read_text(encoding="utf-8"))
    rows, apps = d["rows"], d["apps"][v]

    # 每个符号定义在哪个 .s（含同仓库其它包，避免把"定义在别的包"误判成"没有定义"）
    defs = {}
    others = list(pkg.glob("*.s")) + list((pkg.parent.parent).glob("*/**/*.s"))
    for f in others:
        for s in re.findall(r"^\s*\.(?:globl|global)\s+([A-Za-z_]\w*)\s*$",
                            f.read_text(encoding="utf-8", errors="replace"), re.M):
            defs.setdefault(s, []).append(f.name)

    print(f"===== {v} 行的真实性判定")
    bad = []
    for op in ("keygen", "encap", "decap"):
        app_srcs_txt = build_srcs(build, f"mlkem768_{'keypair' if op=='keygen' else op}")
        # ② app 的动态调用次数
        a = apps[op]
        m = {x[0]: x[2] for x in a["boundaries"]}
        app_calls = Counter()
        for c in a["func_calls"]:
            n = m.get(c.get("callee_func"))
            if n and not n.startswith("$"):
                app_calls[n] += 1
        sum_rows = Counter()
        for r in rows:
            if r["phase"].startswith(op + "_") and r.get("closure", True) and not r.get("reused_from"):
                for k, x in (r.get("calls") or {}).items():
                    sum_rows[k] += x
        for k, cnt in app_calls.items():
            if not cnt or is_framework(k):
                continue        # 框架函数：成本预期计入残差，跳过
            # ① 内核源码同一份？
            dfiles = defs.get(k, [])
            in_app = any(x in app_srcs_txt for x in dfiles) if dfiles else None
            rs = [r["phase"] for r in rows if r["phase"].startswith(op + "_")
                  and not r.get("reused_from") and (r.get("calls") or {}).get(k)]
            in_row = any(any(x in build_srcs(build, f"mlkem768_{r}_profiling") for x in dfiles)
                         for r in rs) if (dfiles and rs) else None
            prob = []
            if sum_rows[k] < cnt:
                prob.append(f"② 覆盖不足 app={cnt} vs 行={sum_rows[k]}")
            if sum_rows[k] > cnt:
                prob.append(f"② 凭空多算 app={cnt} vs 行={sum_rows[k]}")
            local = [x for x in dfiles if not x.endswith("_stubs.s")]
            if in_app is False and not local:
                prob.append(f"① 定义在其它包（{dfiles}），本包无副本 —— 需人工确认不是桩")
            elif in_app is False:
                prob.append(f"① app 自己没链接定义文件 {local}")
            if in_row is False and local:
                prob.append(f"① 行没链接定义文件 {local}（可能是同名副本！）")
            if prob:
                bad.append((op, k, prob))
                print(f"  ⚠ {op}/{k}: " + "；".join(prob))
        # ②'' 桩法三行（`_shake`/`_rejection`/`_stub_overhead`）的调用次数必须与**父行相等**。
        #    ⚠ 基准必须是**父行**（阶段行本身，独立实测），不能用 app 级计数：keygen 里 η 采样
        #    也走 shake_out ⇒ app 级 159 > 阶段级 135，用 app 级做上界就永远抓不到问题。
        #    2026-09-20 漏过：ver0_x 的 `_shake` 行还写着旧 ρ 时代的 137（父行实测 135）
        #    ⇒ +2 次 squeeze / +2 次 keccakf ⇒ `shake+rejection−stub` 闭合差 +10,732 拍。
        #    这三行是"同一轨迹、替换一个面"的分解行：凡是两行都调用的符号，次数必须一致。
        #    （单次探针行如 `encap_intt` 不在三行之列，不受此约束。）
        FACETS = ("_shake", "_rejection", "_stub_overhead")
        ph2c = {r["phase"]: (r.get("calls") or {}) for r in rows if r["phase"].startswith(op + "_")}
        for ph, calls in ph2c.items():
            facet = next((s for s in FACETS if ph.endswith(s)), None)
            if not facet:
                continue
            pc = ph2c.get(ph[: -len(facet)])
            if not pc:
                continue
            for k, n in calls.items():
                if k in pc and n != pc[k]:
                    bad.append((op, f"{ph}/{k}", [f"②'' 桩法行 {n} ≠ 父行 {pc[k]}"]))
                    print(f"  ⚠ {op}/{ph}: ②'' {k} {n} 次 ≠ 父行 {ph[: -len(facet)]} 的 {pc[k]} 次")

        # ②' 幽灵行：行调用了 app **从不调用**的内核 ⇒ 凭空多算成本（必须从 Σ 剔除或标注）
        for k, cnt in sum_rows.items():
            if app_calls.get(k, 0) == 0 and not is_framework(k):
                who = [r["phase"] for r in rows if r["phase"].startswith(op + "_")
                       and not r.get("reused_from") and (r.get("calls") or {}).get(k)]
                bad.append((op, k, ["② 幽灵行"]))
                print(f"  ⚠ 幽灵行 {op}/{k}: app 调用 0 次，但行 {who} 声明 {cnt} 次"
                      f"（凭空多算成本）")
        # ②' 幽灵行：行调用了 app **从不调用**的内核（会凭空多算成本）
        phantom = {k: v for k, v in sum_rows.items() if app_calls[k] == 0 and not is_framework(k)}
        for k, v in phantom.items():
            who = [r["phase"] for r in rows if r["phase"].startswith(op + "_")
                   and not r.get("reused_from") and (r.get("calls") or {}).get(k)]
            if k in defs or any(k in build_srcs(build, f"mlkem768_{r}_profiling") for r in who):
                bad.append((op, k, ["② 幽灵行"]))
                print(f"  ⚠ 幽灵行 {op}/{k}: app 调用 0 次，但行 {who} 声明 {v} 次（凭空多算成本）")
    if not bad:
        print("  ①② 全部通过：每个内核都是同一份源文件、调用次数逐一对齐 ✓")

    # ③ Δ 语义
    print("\n ③ Δ 语义（control ≡ profiling − jal）：")
    f1, f2, f3 = Path(F.__file__), pkg, build  # noqa: F841
    state = F.main if False else None         # 不递归调用，用同一套函数直接判
    rows_need = []
    for r in rows:
        if r.get("reused_from"):
            continue
        p, c = pkg / f"{r['phase']}_profiling.s", pkg / f"{r['phase']}_control.s"
        if not (p.exists() and c.exists()):
            continue
        pt = p.read_text(encoding="utf-8")
        if not any("jal" in l.split("#")[0] for l in pt.splitlines()):
            rows_need.append((r["phase"], "内联块行（无 jal，按设计）"))
            continue
        if F.insns(F.make_control(pt)) != F.insns(c.read_text(encoding="utf-8")):
            rows_need.append((r["phase"], "control ≠ profiling−jal ✗"))
    if not rows_need:
        print("    全部行满足（内联块行除外，见下）✓")
    for n, why in rows_need:
        print(f"    · {n}: {why}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
