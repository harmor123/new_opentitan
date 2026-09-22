#!/usr/bin/env python3
"""**独立复核**：kernel 的 stall 三级统计是否成立、是否一致（全部基于 RTL trace 重算，不引用结论）。

要复核的三级（用户口径）：
  ① **某一次动态指令 stall 多少** —— 每条 E 记录（一次动态指令）它自己的停滞拍数 = 紧随其前的 `S`
     记录条数（`S`/`E` 同 PC 已实测）；它自己的取指等待 = 它之后到下一记录之间的空档。
  ② **同一种 opcode stall 加起来** —— ①按 opcode 求和（停滞 + 取指等待）。
  ③ **一个 kernel 中总 stall** —— ②再对 kernel 内全部 opcode 求和。
  另有恒等式：**叶函数** ③ == RTL 符号行 `stall + fetch_wait`；**子树** ③ == Σ帧跨度 − 子树指令数。

作用域规则（与 `kernel_stat.py` **同一口径**，但本文件是**独立实现**）：
  · **叶函数**（mul_modp / basemul / basemul_acc）：PC 落在其符号区间内；
  · **调用子树**（NTT / INTT）：调用栈上**任一帧的进入 PC** 落在其区间内
    ⇒ 覆盖「进入 NTT → 退出 NTT」的**全部**拍（含被调函数与内部 loop，loop 只是同 PC 重复执行）。
  · 帧识别：`jal`/`jalr(rd=x1)`=call、`jalr x0,x1,0`=ret、`ecall`=halt（切会话）；帧跨度 `[C1,C2)`。

三个交叉核对（任一不通过就报 ✗）：
  A. 逐 (op, kernel, opcode) 的 `[动态次数, 停滞, 取指等待]` == `kernel_stat_<v>.json`（另一份实现）；
  B. 叶函数：`[退役, 停滞, 取指]` == `rtl_trace_<op>.json` 符号行 `[retire, stall, fetch_wait]`；
  C. **每个 kernel**：自身总拍（退役+停滞+取指）== Σ**该 kernel 的帧跨度**（kernel_stat 的 `span_sum`）
     —— 叶函数：等号成立 ⇔ 真的没有被调（否则帧跨度会多出来）；子树：等号成立 ⇔ 整棵子树**没有漏拍**。

用法:
  python3 test_perf/tools/diag/verify_stall_levels.py --version ver1_1 \
      --json logs_hkem/ver1_1_profiling/re_ver1_1.json --trace-dir logs_hkem/ver1_1/rtl \
      --rtl-dir logs_hkem/ver1_1/rtl --ref logs_hkem/rtl_extra/kernel_stat_ver1_1.json \
      --p256-elf logs_hkem/rtl_extra/run_p256.elf --p256-trace logs_hkem/rtl_extra/p256_ver1_1.rtl_trace.log \
      --out logs_hkem/rtl_extra/stall_levels_ver1_1.md --json-out logs_hkem/rtl_extra/stall_levels_ver1_1.json
"""
import argparse
import bisect
import collections
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rtl_trace_attr as R                                  # noqa: E402  复用解码/边界口径（不贡献数字）

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

OPS = (("keygen", "keypair"), ("encap", "encap"), ("decap", "decap"))
KERNELS = (("mul_modp", "mul_modp", False), ("basemul", "basemul", False),
           ("basemul_acc", "basemul_acc", False), ("NTT", "ntt", True), ("INTT", "intt", True))
PK_LABELS = ("Keygen A", "Keygen B", "ECDH A", "ECDH B")

_MN = {}


def mnemonic(word: int) -> str:
    """指令字 → 助记符（ISS 自带 ISA 表；与 `kernel_stat.py` 同一个来源）。"""
    k = _MN.get(word)
    if k is None:
        try:
            from sim.decode import decode_words
            ins = decode_words(0, [(True, word)])
            inner = getattr(ins[0], "insn", None) if ins else None
            k = getattr(inner, "mnemonic", None) or "?"
        except Exception:
            k = "?"
        _MN[word] = k
    return k


class Scope:
    """PC ↔ 符号（纯查表，不贡献任何数字）。"""

    def __init__(self, bnds):
        self.bnds = sorted((s, e, n) for s, e, n in bnds)
        self.starts = [b[0] for b in self.bnds]
        self._cache = {}

    def which(self, pc):
        i = bisect.bisect_right(self.starts, pc) - 1
        if i < 0:
            return None
        s, e, n = self.bnds[i]
        return n if s <= pc < e else None

    def sym_of(self, pc, sym):
        n = self.which(pc)
        return n is not None and (n == sym or n.endswith(":" + sym))

    def leaf_rows(self, pc):
        v = self._cache.get(pc)
        if v is None:
            v = frozenset(k for k, sym, sub in KERNELS if not sub and self.sym_of(pc, sym))
            self._cache[pc] = v
        return v

    def sub_rows(self, pc):
        return frozenset(k for k, sym, sub in KERNELS if sub and self.sym_of(pc, sym))


def new_acc():
    """一个会话的累加器：per kernel → 三级 + 帧 + 子树内逐函数构成。"""
    return {k: {"n": 0, "stall": 0, "fetch": 0, "by_op": {}, "fn": collections.Counter(),
                "frames": 0, "span": 0, "nest_max": 0} for k, _s, _sub in KERNELS}


def scan(trace: Path, sc: Scope):
    """流式扫 trace ⇒ `{会话号: acc}`。

    每拍归属（与 kernel_stat 同口径）：`E`=退休 1 拍；`S`=停滞 1 拍（记给**紧随的**那条 `E`）；
    记录间空档=取指等待（记给**上一条记录**）。每条记录首字符判断，快路径不用正则。
    """
    out, stack, active = {}, [], collections.Counter()
    sid, pending_call, pending_ret = 0, False, None
    srun, s_after, gap_after_S = 0, collections.Counter(), 0
    prev = None                                   # (pc, op, cyc, scope, 是否 E)
    last_cyc = None
    with trace.open("rb") as f:
        for raw in f:
            c = raw[0]
            if c != 69 and c != 83:               # b'E' / b'S'
                continue
            try:
                head, tail = raw.split(b", ", 1)
                a = head.split()
                cyc, pc, word = int(a[1]), int(a[3], 16), int(tail[6:], 16)
            except Exception:
                m = R.RE_TRACE.match(raw.decode("utf-8", "replace"))
                if not m:
                    continue
                cyc, pc, word = int(m.group(2)), int(m.group(3), 16), int(m.group(4), 16)
                c = ord(m.group(1))
            is_e = (c == 69)
            a_ = out.setdefault(sid, new_acc())

            # ① 空档（上一条记录之后）→ 取指等待，记给上一条记录；按实例：记给上一条**动态指令**
            if prev is not None and cyc > prev[2] + 1:
                g = cyc - prev[2] - 1
                for k in prev[3]:
                    a_[k]["fetch"] += g
                    if prev[4]:
                        e = a_[k]["by_op"].setdefault(prev[1], {"n": 0, "stall": 0, "fetch": 0,
                                                                "sh": collections.Counter(),
                                                                "fh": collections.Counter()})
                        e["fetch"] += g
                        e["fh"][g] += 1
                if not prev[4]:
                    gap_after_S += g

            # ② 帧的入/出（**先做**：本记录若是"调用方恢复执行"，就不该再算进被调子树；
            #    若是"被调第一条"，就该算进被调子树）—— 作用域在入/出栈**之后**再取
            if pending_ret is not None and stack:
                ent, c0, keys = stack.pop()
                for k in keys:
                    a_[k]["span"] += cyc - c0
                    active[k] -= 1
                    if active[k] == 0:
                        del active[k]                       # ⚠ Counter 的零值键不会自己消失
                for k in sc.leaf_rows(ent):                 # 叶函数也要帧跨度（判据 C 用）
                    a_[k]["span"] += cyc - c0
                pending_ret = None
            if pending_call:
                keys = sc.sub_rows(pc)
                stack.append((pc, cyc, keys))
                for k in sc.leaf_rows(pc) | keys:
                    a_[k]["frames"] += 1
                for k in keys:
                    active[k] += 1
                    a_[k]["nest_max"] = max(a_[k]["nest_max"], active[k])
                pending_call = False
            scope = sc.leaf_rows(pc) | frozenset(active)

            # ③ 本记录本身：S ⇒ 停滞 +1（留给紧随的 E）；E ⇒ 一次动态指令
            if not is_e:
                srun += 1
                s_after[pc] += 1
                prev = (pc, None, cyc, scope, False)
                last_cyc = cyc
                continue
            op = mnemonic(word)
            for k in scope:
                e = a_[k]["by_op"].setdefault(op, {"n": 0, "stall": 0, "fetch": 0,
                                                   "sh": collections.Counter(),
                                                   "fh": collections.Counter()})
                e["n"] += 1
                e["stall"] += srun
                e["sh"][srun] += 1
                a_[k]["n"] += 1
                a_[k]["stall"] += srun
                a_[k]["fn"][sc.which(pc) or "(无符号)"] += 1
            fk = R._flow_kind(word)
            if fk == "ret" and stack:
                pending_ret = True
            elif fk == "call":
                pending_call = True
            elif fk == "halt":
                while stack:                       # 会话结束：关掉未闭合帧（正常：顶层 main）
                    ent, c0, keys = stack.pop()
                    for k in keys:
                        a_[k]["span"] += cyc - c0
                        active[k] -= 1
                pending_ret, prev, srun = None, None, 0
                sid += 1
                last_cyc = cyc
                continue
            prev = (pc, op, cyc, scope, True)
            srun = 0
            last_cyc = cyc
    if stack:                                      # EOF：顶层未闭合帧（与 kernel_stat 同规则）
        c_end = last_cyc + 1 if last_cyc is not None else 0
        a_ = out.setdefault(sid, new_acc())
        while stack:
            ent, c0, keys = stack.pop()
            for k in keys | sc.leaf_rows(ent):
                a_[k]["span"] += c_end - c0
    return out


def merge(accs, sids=None):
    """按会话合并（sids=None ⇒ 全部会话）⇒ 一个 acc。"""
    tot = new_acc()
    for sid, a in accs.items():
        if sids is not None and sid not in sids:
            continue
        for k, v in a.items():
            t = tot[k]
            t["n"] += v["n"]
            t["stall"] += v["stall"]
            t["fetch"] += v["fetch"]
            t["frames"] += v["frames"]
            t["span"] += v["span"]
            t["nest_max"] = max(t["nest_max"], v["nest_max"])
            t["fn"] += v["fn"]
            for op, e in v["by_op"].items():
                d = t["by_op"].setdefault(op, {"n": 0, "stall": 0, "fetch": 0,
                                               "sh": collections.Counter(), "fh": collections.Counter()})
                d["n"] += e["n"]
                d["stall"] += e["stall"]
                d["fetch"] += e["fetch"]
                d["sh"] += e["sh"]
                d["fh"] += e["fh"]
    return tot


def keys_of(acc, k, sc=None):
    """→ (n, stall, fetch, span, frames) 与逐 opcode 摘要（供 md/json）。"""
    v = acc[k]
    by_op = {}
    for op, e in sorted(v["by_op"].items(), key=lambda kv: -kv[1]["n"]):
        by_op[op] = {"n": e["n"], "stall": e["stall"], "fetch": e["fetch"],
                     "stall_per_inst": dict(sorted((str(a), b) for a, b in e["sh"].items())),
                     "fetch_per_inst": dict(sorted((str(a), b) for a, b in e["fh"].items()))}
    out = {"n": v["n"], "stall": v["stall"], "fetch": v["fetch"], "by_op": by_op,
           "fn": dict(v["fn"].most_common()), "frames": v["frames"], "span": v["span"],
           "nest_max": v["nest_max"]}
    if sc is not None:                       # 子树/区间内各函数**静态代码条数**（动态/静态 ⇒ loop 证据）
        out["static_insn"] = sum((e - s) // 4 for s, e, n in sc.bnds if n in v["fn"])
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True)
    ap.add_argument("--json", required=True, help="ISS 剖面 JSON（只取 boundaries 当符号表）")
    ap.add_argument("--trace-dir", required=True)
    ap.add_argument("--rtl-dir", required=True, help="rtl_trace_<op>.json 所在目录（交叉核对 B）")
    ap.add_argument("--ref", required=True, help="kernel_stat_<v>.json（交叉核对 A/C）")
    ap.add_argument("--p256-elf", default="")
    ap.add_argument("--p256-trace", default="")
    ap.add_argument("--p256-ref", default="", help="含 p256 会话的 kernel_stat JSON（默认 = --ref）")
    ap.add_argument("--out", default="")
    ap.add_argument("--json-out", default="")
    args = ap.parse_args()

    d = json.loads(Path(args.json).read_text(encoding="utf-8"))
    ref = json.loads(Path(args.ref).read_text(encoding="utf-8"))
    RTLDIR = Path(args.rtl_dir)
    L = [f"# stall 三级独立复核 · {args.version}", "",
         "> 全部数字由 `test_perf/tools/diag/verify_stall_levels.py` **从 RTL trace 重算**；",
         "> ①=每条动态指令自己的 stall，②=同 opcode 求和，③=kernel 总 stall（停滞+取指等待）。", ""]
    out = {"version": args.version, "ops": {}, "checks": {}}
    all_ok = True

    for op, tname in OPS:
        tr = Path(args.trace_dir) / f"test_mlkem_{tname}_only.rtl_trace.log"
        if not tr.exists():
            print(f"  ⚠ 缺 {tr} ⇒ 跳过", file=sys.stderr)
            continue
        app = d["apps"][args.version][op]
        sc = Scope(app["boundaries"])
        print(f"[{args.version}] {op}: 扫 {tr.name} …", file=sys.stderr)
        accs = scan(tr, sc)
        acc = merge(accs)
        ks = {k: keys_of(acc, k, sc) for k, _s, _sub in KERNELS}

        # A. 与 kernel_stat（另一份实现）逐 (kernel, opcode) 比对
        chkA, chkC = {}, {}
        kref = ((ref.get("ops") or {}).get(op) or {}).get("kernels") or {}
        for k, _s, _sub in KERNELS:
            r = kref.get(k) or {}
            rops = r.get("opcodes") or {}
            okA = (len(rops) == len(ks[k]["by_op"])
                   and all(rops.get(o, [None])[:3] == [e["n"], e["stall"], e["fetch"]]
                           for o, e in ks[k]["by_op"].items()))
            chkA[k] = None if (ks[k]["n"] == 0 and not rops) else okA
            if ks[k]["frames"] == 0:                   # 该 op 里这个 kernel 没被调用 ⇒ 判据 C 不适用
                chkC[k] = {"ok": None, "total": 0, "span_sum": 0, "frames": 0, "nest_max": 0}
            else:
                chkC[k] = {"ok": ks[k]["n"] + ks[k]["stall"] + ks[k]["fetch"] == ks[k]["span"],
                           "total": ks[k]["n"] + ks[k]["stall"] + ks[k]["fetch"],
                           "span_sum": ks[k]["span"], "frames": ks[k]["frames"],
                           "nest_max": ks[k]["nest_max"]}

        # B. 与 rtl_trace_<op>.json 的符号行比对（叶函数：同口径）
        rtl = json.loads((RTLDIR / f"rtl_trace_{op}.json").read_text(encoding="utf-8"))
        syms = {s["name"]: s for s in rtl["symbols"]}
        chkB = {}
        for k, sym, is_sub in KERNELS:
            if is_sub or ks[k]["n"] == 0:              # 子树另走判据 C；本 op 没跑到的不适用
                chkB[k] = None
                continue
            s = syms.get(sym)
            chkB[k] = bool(s and s["retire"] == ks[k]["n"] and s["stall"] == ks[k]["stall"]
                           and s["fetch_wait"] == ks[k]["fetch"])
        out["ops"][op] = {"kernels": ks,
                          "check_A_vs_kernel_stat": chkA, "check_B_vs_rtl_symbol": chkB,
                          "check_C_total_eq_span": chkC,
                          "sessions": {str(i): {k: merge(accs, {i})[k]["frames"] for k, _s, _sub in KERNELS}
                                       for i in sorted(accs)}}
        L += [f"## {op}", "", "| kernel | 作用域 | ① 每条 stall（分布） | ② 逐 opcode 合计 | ③ kernel 总 stall | 帧数 | 总拍 == Σ帧跨度 |",
              "|---|---|---|---|---:|---:|---|"]
        for k, _s, is_sub in KERNELS:
            v = ks[k]
            # ① 分布摘要：只列"每条 stall"的取值形态（常数就写 `n×值`）
            one = []
            for o, e in v["by_op"].items():
                sh = e["stall_per_inst"]
                vals = "/".join(f"{cnt}×{s}" for s, cnt in sorted(sh.items(), key=lambda kv: -kv[1]))
                one.append(f"`{o}` {vals}")
            two = "、".join(f"`{o}` {e['stall'] + e['fetch']:,}" for o, e in v["by_op"].items())
            L.append(f"| `{k}` | {'子树' if is_sub else '叶'} | {len(v['by_op'])} 种指令，"
                     f"{'；'.join(one[:3])} … | {two[:120]} … | {v['stall'] + v['fetch']:,} | {v['frames']} | "
                     f"{'✓' if chkC[k]['ok'] else ('—' if chkC[k]['ok'] is None else '✗')} |")
        L += ["", f"**核对**：A(与 kernel_stat 全等) {chkA}；B(与 RTL 符号行全等) {chkB}；"
              f"C 总拍==Σ帧跨度 " + "；".join(
                  f"`{k}` {chkC[k]['total']:,} == {chkC[k]['span_sum']:,} ({chkC[k]['frames']} 帧, "
                  f"最深嵌套 {chkC[k]['nest_max']}) "
                  f"{'✓' if chkC[k]['ok'] else ('—' if chkC[k]['ok'] is None else '✗')}"
                  for k, _s, _sub in KERNELS), ""]
        all_ok = all_ok and all(v is not False for v in chkA.values()) \
            and all(chkC[k]["ok"] is not False for k in chkC) \
            and all(v is not False for v in chkB.values())

    # P-256：一次会话（含 ECDH A）
    if args.p256_elf and args.p256_trace:
        b2 = R.read_elf_boundaries(Path(args.p256_elf))
        off = 0x8000 if min(x[0] for x in b2) >= 0x8000 else 0
        sc = Scope([(a - off, e - off, n) for a, e, n in b2])
        print(f"[{args.version}] p256: 扫 {Path(args.p256_trace).name} …", file=sys.stderr)
        accs = scan(Path(args.p256_trace), sc)
        sess = {}
        for i in sorted(accs):
            a = merge(accs, {i})
            sess[PK_LABELS[i] if i < len(PK_LABELS) else f"会话{i+1}"] = keys_of(a, "mul_modp", sc)
        # 判据 B：与 rtl_trace_p256.json 的符号行（逐会话）比对（同口径：叶函数）
        pj = Path(args.p256_trace).with_name("rtl_trace_p256.json")
        chkB = {}
        if pj.exists():
            pj_all = json.loads(pj.read_text(encoding="utf-8")).get("sessions") or []
            for i, lab in enumerate(PK_LABELS):
                if lab not in sess or i >= len(pj_all):
                    continue
                row = next((x for x in pj_all[i]["symbols"] if x["name"] == "mul_modp"), None)
                if row is None:
                    chkB[lab] = False
                    continue
                v = sess[lab]
                chkB[lab] = bool(row["retire"] == v["n"] and row["stall"] == v["stall"]
                                 and row["fetch_wait"] == v["fetch"])
            L.append("**判据 B（P-256，逐会话）**：与 `rtl_trace_p256.json` 的 `mul_modp` 符号行 "
                     "(retire/stall/fetch_wait) 比对 —— "
                     + "、".join(f"{k} {'✓' if x else '✗'}" for k, x in chkB.items()) + "。")
            L.append("")
        out["p256"] = {"sessions": sess, "check_B_vs_rtl_symbol": chkB}
        L += ["## P-256（`mul_modp`）逐会话", "",
              "| 会话 | 动态指令 | stall | 逐 opcode（③） | 帧数 |", "|---|---:|---:|---|---:|"]
        for lab, v in sess.items():
            L.append(f"| {lab} | {v['n']} | {v['stall'] + v['fetch']} | "
                     + "、".join(f"`{o}` {e['n']}×({e['stall']}+{e['fetch']})" for o, e in v["by_op"].items())
                     + f" | {v['frames']} |")
        L.append("")
    if "p256" in out:
        all_ok = all_ok and all(v is not False for v in
                                (out["p256"].get("check_B_vs_rtl_symbol") or {}).values())
    out["checks"]["all_ok"] = all_ok
    L += [f"**总判定**：{'全部 ✓' if all_ok else '有不通过项 ✗（见上）'}", ""]
    txt = "\n".join(L) + "\n"
    print(txt)
    if args.out:
        Path(args.out).write_text(txt, encoding="utf-8")
        print(f"[写] {args.out}")
    if args.json_out:
        Path(args.json_out).write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
        print(f"[写] {args.json_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
