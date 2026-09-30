#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P6 Step 5/6：把 ver1_2 的协议分段与冻结基线（ver1_1）逐段对照，并检查三条恒等式。

输入：`<run-dir>/<test>.base.txt` 与 `<run-dir>/<test>.<ver>.txt`
（由 `p6_collect_protocol.sh` 从 `logs_hkem/ver1_1/<test>.uart0.log` 与
 `bazel-testlogs/<ver1_2 包>/<test>_sim_verilator/test.log` 采出）。

判据（PDF §11 P6：「保留原有 HKEM_PROF 分段、保留旧 protocol_total 边界」）
  1. **段名集合必须相同**（我们没有动任何打印代码）—— 多一个/少一个都要报；
  2. **恒等式**（基线里已实测严格成立，本版必须同样成立）：
       protocol_total == Σ(非 TEST、非 SCOPE 的各段)
       scope_total    == accounted_total + unaccounted_total
       accounted_total == protocol_total + Σ(TEST 段) − test_total
  3. 数值：P-256 段应显著变小；其余段只应有跨 build 漂移量级（±400 拍）的变化 —— 超过就**标红**，
     不是"通过"（不许把漂移当噪音放过）。

用法：python3 p6_cmp_segments.py [--run-dir <dir>] [--ver ver1_2]
"""
import argparse
import pathlib
import re
import sys

# 与仓库其它工具一致：把 stdout 重配成 UTF-8，避免 Windows 控制台（GBK）在非 ASCII 上崩
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

REPO = pathlib.Path(__file__).resolve().parents[3]
TESTS = ["phase1_keygen_test", "phase2_alice_encap_test", "phase2_bob_decap_test"]
LINE = re.compile(r"HKEM_PROF(_TEST|_SCOPE)?,([a-z0-9_]+),([a-z0-9_]+),(\d+)")
P256 = ("p256_keygen_total", "p256_ecdh_official_api", "p256_unmask")
DRIFT = 400          # 同 build 内可复现、跨 build 会变（13 号文档 §5 实测 ±300）；超过就点名
# 派生量：由各段相加得来，**本就该随 P-256 段下降** ⇒ 不按漂移阈值判（恒等式已单独把关）
DERIVED = ("protocol_total", "accounted_total", "scope_total", "unaccounted_total")


def parse(path: pathlib.Path):
    segs, insn, veredict = {}, [], None
    if not path.exists():
        return None, None, None
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = LINE.search(line)
        if m:
            segs[(m.group(1) or "", m.group(3))] = int(m.group(4))
        mi = re.search(r"OTBN instruction count: (0x[0-9a-f]+)", line)
        if mi:
            insn.append(mi.group(1))
        if "PASS!" in line:
            veredict = "PASS!"
        elif "FAIL" in line:
            veredict = "FAIL"
    return segs, insn, veredict


def identities(segs):
    """返回 (protocol_total, Σ非TEST段, accounted, protocol+ΣTEST−test_total, scope, acct+unacct)。"""
    prot = segs.get(("", "protocol_total"))
    s_nontest = sum(v for (k, n), v in segs.items() if k == "" and n != "protocol_total")
    acct = segs.get(("_SCOPE", "accounted_total"))
    s_test = sum(v for (k, n), v in segs.items() if k == "_TEST" and n != "test_total")
    scope = segs.get(("_SCOPE", "scope_total"))
    unacct = segs.get(("_SCOPE", "unaccounted_total"))
    return prot, s_nontest, acct, (None if acct is None else prot + s_test), scope, \
        (None if acct is None or unacct is None else acct + unacct)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-dir", default="logs_hkem/p256fold_20260928T085338Z/host")
    ap.add_argument("--ver", default="ver1_2")
    ap.add_argument("--base-suffix", default="base",
                    help="基线文件名后缀：base（仓库里 ver1_1 早期日志）或 base_cur（当前模型上跑 ver1_1 同测试）")
    args = ap.parse_args()
    d = REPO / args.run_dir
    bad, flagged = [], []

    for t in TESTS:
        b, bi, bv = parse(d / ("%s.%s.txt" % (t, args.base_suffix)))
        n, ni, nv = parse(d / ("%s.%s.txt" % (t, args.ver)))
        print("\n=== %s" % t)
        if b is None or n is None:
            print("  缺文件（先跑 p6_collect_protocol.sh）")
            bad.append(t)
            continue
        print("  PASS：基线=%s 本版=%s；P-256 指令数：基线=%s 本版=%s"
              % (bv, nv, ",".join(bi) or "—", ",".join(ni) or "—"))
        if nv != "PASS!":
            bad.append("%s 本版没有 PASS!" % t)

        # ① 段名集合
        nb, nn = set(b), set(n)
        if nb != nn:
            print("  [DIFF] 段名集合不同：仅基线有 %s；仅本版有 %s"
                  % (sorted(nb - nn), sorted(nn - nb)))
            bad.append("%s 段名集合" % t)
        else:
            print("  段名集合：%d 个，完全相同" % len(nb))

        # ② 恒等式
        for tag, segs in (("基线", b), ("本版", n)):
            prot, snt, acct, acct_calc, scope, scope_calc = identities(segs)
            ok1 = prot == snt
            ok2 = scope == scope_calc
            ok3 = acct == acct_calc
            print("  %s 恒等式：protocol=%s vs Σ非TEST=%s [%s]；scope=%s vs acct+unacct=%s [%s]；"
                  "acct=%s vs protocol+ΣTEST−test_total=%s [%s]"
                  % (tag, prot, snt, "OK" if ok1 else "BAD",
                     scope, scope_calc, "OK" if ok2 else "BAD",
                     acct, acct_calc, "OK" if ok3 else "BAD"))
            if not (ok1 and ok2 and ok3):
                bad.append("%s 的 %s 恒等式不成立" % (t, tag))

        # ③ 逐段数值
        for key in sorted(nb & nn, key=lambda k: (k[0], k[1])):
            vb, vn = b[key], n[key]
            dv = vn - vb
            if key[1] in P256:
                print("  %-28s %12d → %12d   Δ=%+d（%.1f%%）"
                      % (key[1], vb, vn, dv, 100.0 * dv / vb if vb else 0))
            elif key[1] in DERIVED:
                print("  %-28s %12d → %12d   Δ=%+d（派生量）" % (key[1], vb, vn, dv))
            elif abs(dv) > DRIFT:
                print("  [FLAG] %-24s %12d → %12d   Δ=%+d  ← 非 P-256 段变动超过漂移量级"
                      % (key[1], vb, vn, dv))
                flagged.append("%s.%s" % (t, key[1]))
            else:
                print("  %-28s %12d → %12d   Δ=%+d（漂移内）" % (key[1], vb, vn, dv))

    print("\n--- 汇总")
    if bad:
        print("FAIL  不满足：%s" % bad)
        return 1
    if flagged:
        print("FLAG  段名/恒等式全过，但下列非 P-256 段变动超过 ±%d 拍，需逐条解释：%s"
              % (DRIFT, flagged))
        return 2
    print("PASS  段名集合相同、三条恒等式成立、非 P-256 段全在漂移内，只有 P-256 段显著下降")
    return 0


if __name__ == "__main__":
    sys.exit(main())
