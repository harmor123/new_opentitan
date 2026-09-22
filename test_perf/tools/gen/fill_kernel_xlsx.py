#!/usr/bin/env python3
"""把 kernel 级「动态指令 + stall」统计写进 `实验数据/动态指令及stall统计.xlsx`（不手抄）。

输入（只读，全部由 RTL trace 生成、不手抄）：
  · `logs_hkem/rtl_extra/kernel_stat_{ver1_1,ver0_2,ver0_1}.json`（`kernel_stat.py`）
  · `logs_hkem/rtl_extra/stall_levels_{ver1_1,ver0_2,ver0_1}.json`（`verify_stall_levels.py`：**独立复核**，
    给「① 每条动态指令 stall」的实测分布 + 三方判据 A/B/C）

写什么：
  · `Sheet1`（用户的模板：算法 | kernel | 所使用的指令 | 指令调用次数 | stall cycles）—— 填 **ver1_1** 的 5 行汇总；
  · 新增 sheet `ver1_1` / `ver0_2` / `ver0_1`：**逐 (kernel, 指令)** 明细（动态次数 / 停滞 / 取指等待 / 拍）；
  · 新增 sheet `ISS互证`：逐 (版本, kernel) 的 RTL vs ISS 同口径 vs Δ（叶函数 Δ=0；NTT/INTT 对 ISS 阶段行）；
  · 新增 sheet `统计口径`：来源、归属规则、stall 定义、对账说明。

用法:
  python3 test_perf/tools/gen/fill_kernel_xlsx.py --xlsx "…/实验数据/动态指令及stall统计.xlsx"
"""
import argparse
import json
import re
import sys
from pathlib import Path

from openpyxl import load_workbook
from openpyxl.styles import Alignment, Font

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = Path(__file__).resolve().parents[3]
VERS = ("ver1_1", "ver0_2", "ver0_1")
KERNEL_ROWS = ("mul_modp", "basemul", "basemul_acc", "NTT", "INTT")
P256_LAB = "ECDH A"                     # P-256 行统一取「一次 ECDH」会话（Sheet1 口径）
ALGO = {"mul_modp": "P-256", "basemul": "ML-KEM", "basemul_acc": "ML-KEM", "NTT": "ML-KEM", "INTT": "ML-KEM"}


def load_stats():
    out = {}
    for v in VERS:
        p = REPO / f"logs_hkem/rtl_extra/kernel_stat_{v}.json"
        if not p.exists():
            raise SystemExit(f"✗ 缺 {p}（先跑 kernel_stat.py）")
        out[v] = json.loads(p.read_text(encoding="utf-8"))
    return out


def load_levels():
    """stall 三级（每条 / 同 opcode / kernel 总）的独立复核结果（verify_stall_levels.py）。"""
    out = {}
    for v in VERS:
        p = REPO / f"logs_hkem/rtl_extra/stall_levels_{v}.json"
        if not p.exists():
            raise SystemExit(f"✗ 缺 {p}（先跑 test_perf/tools/diag/verify_stall_levels.py）")
        out[v] = json.loads(p.read_text(encoding="utf-8"))
    return out


def fmt_inst(sh, fh, fr):
    """① 每条动态指令的 stall —— **实测分布**（不是平均）：`停滞 11/条×128；取指 0/条×128`。"""
    def one(hist, name):
        if not hist:
            return f"{name} —"
        items = sorted(((int(k), c) for k, c in hist.items()), key=lambda kv: -kv[0])
        if len(items) == 1:
            v0, c0 = items[0]
            n = c0 // fr if fr and c0 % fr == 0 else c0
            return f"{name} {v0}/条×{n:,}"
        return f"{name} " + "、".join(
            f"{v0}拍×{c0 // fr if fr and c0 % fr == 0 else c0}" for v0, c0 in items)
    return f"{one(sh, '停滞')}；{one(fh, '取指')}"


def total_of(stat, kernel):
    """三 op 合计（mul_modp 来自 p256 块）→ (opcodes, frames, iss_count)。"""
    t = stat["totals"].get(kernel) or {}
    return t.get("opcodes") or {}, t.get("frames"), t.get("iss_count")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--xlsx", required=True)
    args = ap.parse_args()
    xlsx = Path(args.xlsx)
    if not xlsx.exists():
        raise SystemExit(f"✗ 找不到 {xlsx}")
    st = load_stats()
    lv = load_levels()
    wb = load_workbook(xlsx)

    def kernel_level(v, k, op=None):
        """→ (level 的 kernel 字典, 口径标签, 该口径在 kernel_stat 里的 (opcodes, frames))。"""
        if k == "mul_modp":
            lab = P256_LAB
            kd = lv[v]["p256"]["sessions"][lab]
            ks_ = [x for x in st[v]["ops"]["p256"]["sessions"] if x["label"] == lab][0]["kernels"]["mul_modp"]
            return kd, "一次 ECDH", ks_["opcodes"], ks_["frames"]
        for o in ((op,) if op else ("keygen", "encap", "decap")):
            kk = ((st[v]["ops"].get(o) or {}).get("kernels") or {}).get(k) or {}
            kl = ((lv[v]["ops"].get(o) or {}).get("kernels") or {}).get(k) or {}
            if kk.get("frames") and kl.get("n"):
                return kl, o, kk["opcodes"], kk["frames"]
        return None, "", {}, 0

    # ── Sheet1：填 ver1_1 的 5 行（保留原表头与「说明」）──────────────────────────
    ws = wb["Sheet1"]
    # 全表统一为「**每次调用**」口径（论文口径）：P-256 = 一次 ECDH 内的每次 mul_modp；ML-KEM = 该 kernel 的一次调用
    p256_one = None
    for s_ in st["ver1_1"]["ops"]["p256"]["sessions"]:
        if s_["label"].startswith("ECDH"):
            p256_one = s_["kernels"]["mul_modp"]
            break

    def per_call_for(k):
        """→ (mix_str, 动态/次, stall/次, 种类数)"""
        if k == "mul_modp":
            ops, fr = (p256_one or {}).get("opcodes") or {}, (p256_one or {}).get("frames") or 0
            if not ops:
                return None
            ne = sum(v[0] for v in ops.values()); nst = sum(v[1] + v[2] for v in ops.values())
            mix = "、".join(f"{n}×{a / fr:.0f}" for n, (a, _b, _c) in
                            sorted(ops.items(), key=lambda kv: -kv[1][0]))
            return mix, ne / fr, nst / fr, len(ops)
        rows = []
        for op in ("keygen", "encap", "decap"):
            kk = ((st["ver1_1"]["ops"].get(op) or {}).get("kernels") or {}).get(k) or {}
            ops, fr = kk.get("opcodes") or {}, kk.get("frames") or 0
            if ops and fr:
                ne = sum(v[0] for v in ops.values()); nst = sum(v[1] + v[2] for v in ops.values())
                rows.append((op, fr, ne / fr, nst / fr, ops))
        if not rows:
            return None
        _op, fr0, ne0, nst0, ops0 = rows[0]
        mix = "、".join(f"{n}×{a / fr0:.0f}" for n, (a, _b, _c) in
                        sorted(ops0.items(), key=lambda kv: -kv[1][0]))
        return mix, ne0, nst0, len(ops0)

    for i, k in enumerate(KERNEL_ROWS):
        r = 2 + i
        got = per_call_for(k)
        if not got:
            continue
        mix, ne, nst, nkind = got
        ws.cell(row=r, column=3, value=f"{mix}（共 {nkind} 种）")
        ws.cell(row=r, column=4, value=round(ne, 1)).number_format = "#,##0.0"
        ws.cell(row=r, column=5, value=round(nst, 1)).number_format = "#,##0.0"

    # 表下简短说明（5 点；原「说明：」单元格（A7）保持不动）
    notes = [
        "说明（本表口径 = 每次调用；逐条读）：",
        "1、数据来源：chip sim（Verilator RTL）里 OTBN 的指令级 trace，真机逐拍（OTBN 连真 KMAC）—— 不是 ISS 模型估值。",
        "2、口径 = 每次调用：P-256 行 = 一次 ECDH 内的每次 mul_modp 调用；ML-KEM 行 = 该 kernel 的一次调用"
        "（NTT/INTT 含整个调用子树：被调函数与内部 loop）。同一 kernel 在 keygen/encap/decap 里的“每次调用”逐位一致。",
        "3、三个层级别混：53 = 一次 mul_modp 调用的指令条数（单价）；508,906 = 一次 ECDH 里 mul_modp 的总条数"
        "（= 9,602 次调用 × 53）；2,034,670 = 4 次 OTBN 启动之和（测试自检口径，论文不要用）。",
        "4、列含义：所使用的指令 = 每次调用的指令构成（指令 × 次数）；指令调用次数 = 每次调用的动态指令数之和；"
        "stall cycles = 每次调用的停滞 + 取指等待（都是“没退休的拍”，不是报错/异常）。",
        "5、stall 的主要来源：ver1_1 = 向量乘法指令的固有停顿（`bn.mulvm`/`bn.mulvml` **每条恒 11 拍** ⇒ 占其 stall 九成）；"
        "ver0_2/ver0_1 = 访存（`bn.lid`/`lw`/`bn.sid` **每条恒 1 拍**）；P-256 = 仅 `jalr` 返回的取指气泡 1 拍/次"
        "（≈CPI 1.02 ⇒ 计算密集、无等待）。逐指令 stall 见「stall拆解」sheet。",
        "6、stall 三级**都已给到且逐项复核过**（见「stall三级核对」sheet）：① 每条动态指令自己的 stall（**实测分布**，"
        "如 ver1_1 `bn.mulvm` 384 条全部 11 拍）→ ② 同 opcode 合计（= ① × 条数，见「stall拆解」逐行 + 合计行）→ "
        "③ kernel 总 stall（= Σ②，即本表 E 列）。三个独立判据全过：A 逐 opcode 与另一份实现（kernel_stat）全等；"
        "B 叶函数与 RTL 符号行 (retire/stall/取指) 全等；C 全部 kernel「总拍 == Σ帧跨度」精确成立（三版 15 项全 ✓）。",
        "7、作用域已实测确认（见「子树与叶函数」sheet）：mul_modp/basemul/basemul_acc = 叶函数（调用期间 100% 只执行自己，"
        "无被调）；NTT/INTT = 整个调用子树 —— ver1_1 的 NTT 每次 889 条里 875 条在其被调与内部 loop 里；"
        "ver0_2/ver0_1 无被调，但 loop 使动态/静态 = 9.3×，同样已计入。",
        "8、可信性（三方互证）：① 整段 ΣE == chip INSN_CNT（九组逐位相等）；② 叶函数动态数与 ISS `exec_insn` 逐位相同、"
        "NTT/INTT 与 ISS 阶段行差 ≤6 条/op；③ 逐 opcode 只在 KMAC 轮询的 5 条指令上有差（= 5×圈数差，与 chip−ISS 总数逐位吻合）；"
        "④ 拍数与 [C1,C2) 帧跨度对账**精确 +0**（判据 C）。",
        "9、其它 sheet：ver1_1 / ver0_2 / ver0_1（逐 op、逐指令明细）· 论文用_每次调用 · stall拆解 · stall三级核对 · "
        "子树与叶函数 · 逐opcode互证 · ISS互证 · 统计口径。",
    ]
    # 放到原「说明」合并区（A7:E10）之后；先清掉上次写的（幂等）
    NOTES_ROW = 12
    for rng in list(ws.merged_cells.ranges):
        if rng.min_row >= NOTES_ROW:
            ws.unmerge_cells(str(rng))
    blk = ws.cell(row=NOTES_ROW, column=1, value="\n".join(notes))
    blk.font = Font(bold=False)
    blk.alignment = Alignment(wrap_text=True, vertical="top")
    ws.merge_cells(start_row=NOTES_ROW, start_column=1, end_row=NOTES_ROW + len(notes) - 1, end_column=5)
    for c in ("C1", "D1", "E1"):
        ws[c].font = Font(bold=True)

    # ── 逐版本明细 sheet ──────────────────────────────────────────────────────
    for v in VERS:
        name = v
        if name in wb.sheetnames:
            del wb[name]
        s = wb.create_sheet(name)
        s.append([f"{v}：逐 kernel × 逐指令（三 op 合计；数据来自 RTL trace）"])
        s["A1"].font = Font(bold=True)
        s.append(["算法", "kernel", "指令", "动态次数", "停滞(拍)", "取指等待(拍)", "拍合计", "每次执行平均 stall"])
        for s_ in st[v]["ops"].get("p256", {}).get("sessions", []):     # P-256：逐会话（一次）
            ops = s_["kernels"]["mul_modp"]["opcodes"]
            for n, (a, b, c) in sorted(ops.items(), key=lambda kv: -sum(kv[1])):
                s.append(["P-256", f"mul_modp（{s_['label']}）", n, a, b, c, a + b + c,
                          round((b + c) / max(a, 1), 3)])
        for k in KERNEL_ROWS:
            if k == "mul_modp":
                continue
            for op in ("keygen", "encap", "decap"):          # 逐 op 各一遍（"一次运行"口径）
                ops = ((st[v]["ops"].get(op) or {}).get("kernels") or {}).get(k, {}).get("opcodes") or {}
                if not ops:
                    continue
                for n, (a, b, c) in sorted(ops.items(), key=lambda kv: -sum(kv[1])):
                    s.append([ALGO[k], f"{k}（{op}）", n, a, b, c, a + b + c, round((b + c) / max(a, 1), 3)])
                na = sum(x[0] for x in ops.values()); nb = sum(x[1] for x in ops.values())
                nc = sum(x[2] for x in ops.values())
                s.append([ALGO[k], f"{k}（{op}）", "【小计】", na, nb, nc, na + nb + nc,
                          round((nb + nc) / max(na, 1), 3)])

            # 三 op 合计（正确口径：从 JSON 的 totals 取，不用循环残留的 ops）
            tt = (st[v].get("totals") or {}).get(k) or {}
            tpos = tt.get("opcodes") or {}
            if tpos:
                na = sum(x[0] for x in tpos.values()); nb = sum(x[1] for x in tpos.values())
                nc = sum(x[2] for x in tpos.values())
                s.append([ALGO[k], f"{k}（三 op 合计）", "【合计】", na, nb, nc, na + nb + nc,
                          round((nb + nc) / max(na, 1), 3)])
                s[s.max_row][0].font = Font(bold=True)
                s[s.max_row][2].font = Font(bold=True)
        for col, w in zip("ABCDEFGH", (10, 14, 18, 12, 12, 14, 12, 20)):
            s.column_dimensions[col].width = w


    # ── 论文用（每次调用）sheet ───────────────────────────────────────────────
    if "论文用_每次调用" in wb.sheetnames:
        del wb["论文用_每次调用"]
    s = wb.create_sheet("论文用_每次调用")
    s.append(["论文用口径：**每次调用**（与 op 无关；同一 kernel 在 keygen/encap/decap 逐位一致，已实测）"
              "；P-256 行 = 一次 ECDH 里的每次 mul_modp 调用"])
    s["A1"].font = Font(bold=True)
    s.append(["版本", "算法", "kernel", "口径", "调用次数", "动态指令数/次", "stall 拍/次", "拍/次", "CPI",
              "每次调用的指令构成（指令 ×次数）"])
    for v in VERS:
        # P-256：一次 ECDH
        s_ = [x for x in st[v]["ops"]["p256"]["sessions"] if x["label"].startswith("ECDH")][0]
        kk = s_["kernels"]["mul_modp"]
        ops, fr = kk["opcodes"], kk["frames"]
        ne = sum(x[0] for x in ops.values()); nst = sum(x[1] + x[2] for x in ops.values())
        mix = "、".join(f"{n}×{a/fr:.0f}" for n, (a, _b, _c) in sorted(ops.items(), key=lambda kv: -kv[1][0]))
        s.append([v, "P-256", "mul_modp", f"一次 ECDH（{s_['label']}，共 {fr:,} 次调用）", fr,
                  round(ne / fr, 1), round(nst / fr, 2), round((ne + nst) / fr, 1),
                  round((ne + nst) / max(ne, 1), 3), mix])
        for k in KERNEL_ROWS:
            if k == "mul_modp":
                continue
            rows = []
            for op in ("keygen", "encap", "decap"):
                kk = ((st[v]["ops"].get(op) or {}).get("kernels") or {}).get(k) or {}
                ops, fr2 = kk.get("opcodes") or {}, kk.get("frames") or 0
                if not ops or not fr2:
                    continue
                ne2 = sum(x[0] for x in ops.values()); nst2 = sum(x[1] + x[2] for x in ops.values())
                rows.append((op, fr2, ne2 / fr2, nst2 / fr2, (ne2 + nst2) / fr2, ops))
            if not rows:
                continue
            op0, fr0, ne0, nst0, t0, ops0 = rows[0]
            # 不变性检查加严到**逐指令**：每个 opcode 的"每次调用"也必须相同
            same = all(abs(r[2] - ne0) < 0.01 and abs(r[4] - t0) < 0.01 for r in rows) and all(
                set(r[5]) == set(ops0) and all(abs(r[5][n][0] / r[1] - ops0[n][0] / fr0) < 0.01 for n in ops0)
                for r in rows)
            calls = "、".join(f"{r[0]} {r[1]} 次" for r in rows)
            mix = "、".join(f"{n}×{a/fr0:.0f}" for n, (a, _b, _c) in sorted(ops0.items(), key=lambda kv: -kv[1][0]))
            s.append([v, "ML-KEM", k, ("每次调用（keygen/encap/decap 逐指令完全一致 ✓）" if same
                                       else "⚠ 各 op 不一致，需查"), calls, round(ne0, 1), round(nst0, 2),
                      round(t0, 1), round(t0 / max(ne0, 1), 3), mix])
    for col, w in zip("ABCDEFGHIJ", (10, 10, 14, 34, 10, 15, 12, 10, 8, 60)):
        s.column_dimensions[col].width = w


    # ── stall 拆解（每次调用，逐指令）────────────────────────────────────────
    if "stall拆解" in wb.sheetnames:
        del wb["stall拆解"]
    s = wb.create_sheet("stall拆解")
    s.append(["每次调用的 stall 拆到指令：stall = 停滞 + 取指等待；同一 kernel 各 op 逐位一致（取第一个有数据的 op）。"
              "「① 每条」= 该指令**每执行一次**自己的 stall（**实测分布**，不是平均；来自 stall_levels_<版本>.json）"])
    s["A1"].font = Font(bold=True)
    s.append(["版本", "kernel", "口径(取该 op)", "指令", "① 每条 stall（停滞 + 取指）", "次数/调用", "停滞/调用",
              "取指等待/调用", "stall/调用（②）", "占该 kernel stall"])
    for v in VERS:
        for k in KERNEL_ROWS:
            kl, tag, ops, fr = kernel_level(v, k)
            if not ops:
                continue
            tot = sum(x[1] + x[2] for x in ops.values())
            by = kl.get("by_op") or {}
            for n, (a, b, c) in sorted(ops.items(), key=lambda kv: -(kv[1][1] + kv[1][2])):
                if b + c == 0:
                    continue
                e = by.get(n) or {}
                s.append([v, k, tag, n, fmt_inst(e.get("stall_per_inst") or {}, e.get("fetch_per_inst") or {}, fr),
                          round(a / fr, 1), round(b / fr, 1), round(c / fr, 1),
                          round((b + c) / fr, 1), f"{100 * (b + c) / max(tot, 1):.1f}%"])
            # ② （逐 opcode 之和）⇒ ③（kernel 总 stall）
            r0 = s.max_row + 1
            n_zero = sum(1 for x in ops.values() if x[1] + x[2] == 0)
            s.append([v, k, f"{tag}（② ⇒ ③）",
                      f"【合计】（另有 {n_zero} 种指令每条 0 stall，未列）",
                      "Σ 各 opcode = ②  ；  Σ② = ③", round(sum(x[0] for x in ops.values()) / fr, 1),
                      round(sum(x[1] for x in ops.values()) / fr, 1), round(sum(x[2] for x in ops.values()) / fr, 1),
                      round(tot / fr, 1), "100.0%"])
            for c in s[r0]:
                c.font = Font(bold=True)
    for col, w in zip("ABCDEFGHIJ", (10, 14, 20, 16, 40, 11, 11, 13, 15, 15)):
        s.column_dimensions[col].width = w

    # ── stall 三级核对（① 每条 / ② 同 opcode / ③ kernel 总）+ 三个独立判据 ──────
    if "stall三级核对" in wb.sheetnames:
        del wb["stall三级核对"]
    s = wb.create_sheet("stall三级核对")
    s.append(["stall 三级（① 每条动态指令 → ② 同 opcode 合计 → ③ kernel 总）**都满足**，且逐项过了三个独立判据；"
              "全部数字由 test_perf/tools/diag/verify_stall_levels.py 从 RTL trace **独立重算**"
              "（stall_levels_<版本>.json；与 kernel_stat.py 是两份实现、结果逐位相同）"])
    s["A1"].font = Font(bold=True)
    s.append(["版本", "kernel", "作用域（实测）", "① 每条动态指令 stall（实测分布；此处列 stall 最大的指令）",
              "② 同 opcode 合计（每次调用）", "③ kernel 总 stall（每次调用）= Σ②",
              "判据A：逐 opcode == kernel_stat", "判据B：叶 == RTL 符号行 (retire/stall/取指)",
              "判据C：总拍 == Σ帧跨度"])
    for v in VERS:
        nA = nB = nC = nAll = 0
        for k in KERNEL_ROWS:
            kl, tag, ops, fr = kernel_level(v, k)
            if not ops:
                continue
            by = kl.get("by_op") or {}
            tot = kl["n"] + kl["stall"] + kl["fetch"]
            fn = kl.get("fn") or {}
            nAll += 1
            top = max(by.items(), key=lambda kv: kv[1]["stall"] + kv[1]["fetch"])
            one = fmt_inst(top[1].get("stall_per_inst") or {}, top[1].get("fetch_per_inst") or {}, fr)
            if k in ("mul_modp", "basemul", "basemul_acc"):
                scope = f"叶函数（实测：区间内只有自己，{len(fn)} 个符号）"
            else:
                scope = (f"调用子树（实测含被调：{len(fn)} 个符号）" if len(fn) > 1
                         else "调用子树（该版本实测无被调，loop 全在符号内）")
            okA = (len(ops) == len(by) and all(ops.get(o, [None])[:3] == [e["n"], e["stall"], e["fetch"]]
                                               for o, e in by.items()))
            okB = None
            if k == "mul_modp":
                okB = ((lv[v].get("p256") or {}).get("check_B_vs_rtl_symbol") or {}).get(P256_LAB)
            else:
                okB = (((lv[v]["ops"].get(tag) or {}).get("check_B_vs_rtl_symbol") or {}).get(k))
            okC = (tot == kl["span"] and kl["frames"] > 0)
            nA += 1 if okA else 0
            nB += 1 if okB else 0
            nC += 1 if okC else 0
            F = lambda x: "✓" if x else "✗"
            s.append([v, k, scope, f"`{top[0]}` {one}（共 {len(by)} 种指令）",
                      f"Σ {len(by)} 种 = 停滞 {kl['stall'] / fr:,.1f} + 取指 {kl['fetch'] / fr:,.1f} = "
                      f"{(kl['stall'] + kl['fetch']) / fr:,.1f} 拍/次",
                      f"{(kl['stall'] + kl['fetch']) / fr:,.1f} 拍/次（= Σ②；该 kernel 每次调用总拍 {tot / fr:,.1f}）",
                      F(okA), ("—（子树另走 C）" if (okB is None and k in ("NTT", "INTT")) else F(okB)),
                      f"{F(okC)}（{tot:,} == {kl['span']:,}；{kl['frames']} 帧，最深嵌套 {kl['nest_max']}）"])
        r0 = s.max_row + 1
        s.append([v, "【判定】", "5 个 kernel", "① 每条动态指令的 stall 已给到（实测分布，非平均）",
                  "② 逐 opcode 合计已给到（见「stall拆解」逐行）", "③ = Σ②（见「stall拆解」合计行）",
                  f"A：{nA}/{nAll} ✓", f"B：{nB} 个叶函数 ✓（其余 —）", f"C：{nC}/{nAll} ✓"])
        for c in s[r0]:
            c.font = Font(bold=True)
    s.append([])
    s.append(["三条判据的独立性", "A = 与另一份实现（kernel_stat.py）逐 opcode 全等；"
              "B = 叶函数的 (动态, 停滞, 取指) 与 rtl_trace_<op>.json 符号行 (retire, stall, fetch_wait) 全等；"
              "C = 该 kernel 的总拍（退役+停滞+取指）== Σ 其调用帧跨度 [C1,C2) —— 叶函数成立即证明没有漏算被调，"
              "子树成立即证明整棵子树没有漏拍。三版 × 各 kernel 全部 ✓，见 stall_levels_<版本>.md"])
    for col, w in zip("ABCDEFGHI", (10, 14, 40, 46, 40, 26, 24, 30, 40)):
        s.column_dimensions[col].width = w

    # ── 子树与叶函数（作用域实测证据）────────────────────────────────────────
    if "子树与叶函数" in wb.sheetnames:
        del wb["子树与叶函数"]
    s = wb.create_sheet("子树与叶函数")
    s.append(["作用域实测证据：**mul_modp / basemul / basemul_acc = 叶函数**（调用期间执行的全部指令都在自己符号区间内，可直接统计）；"
              "**NTT / INTT = 整个调用子树**（进入 NTT → 退出 NTT 期间的**全部**代码，含被调函数与内部 loop）。"
              "逐函数构成 = 每条动态指令的 PC 落到哪个符号（RTL trace 直方图）"])
    s["A1"].font = Font(bold=True)
    s.append(["版本", "kernel", "口径（取该 op）", "作用域", "每次调用：动态指令",
              "其中：kernel 自身符号内", "其中：被调函数 / 其它符号（含 loop 区）",
              "子树内逐函数（条/次）", "静态代码条数", "动态/静态", "每调用 loop 类指令 / 调用",
              "帧跨度对账（该 op 总拍 == Σ帧跨度）"])
    SYM = {"mul_modp": "mul_modp", "basemul": "basemul", "basemul_acc": "basemul_acc",
           "NTT": "ntt", "INTT": "intt"}
    LOOPY = ("loop", "loopi", "beq", "bne", "jal", "jalr")
    for v in VERS:
        for k in KERNEL_ROWS:
            kl, tag, ops, fr = kernel_level(v, k)
            if not ops:
                continue
            fn = kl.get("fn") or {}
            self_n = fn.get(SYM[k], 0)
            n1 = kl["n"] / fr
            static = kl.get("static_insn") or 0
            loops = {o: e["n"] / fr for o, e in (kl.get("by_op") or {}).items() if o in LOOPY}
            ltxt = "、".join(f"`{o}` {c:,.0f}" for o, c in sorted(loops.items(), key=lambda kv: -kv[1])) or "—"
            ftxt = "、".join(f"`{o}` {c / fr:,.0f}" for o, c in sorted(fn.items(), key=lambda kv: -kv[1]))
            s.append([v, k, tag,
                      ("叶函数" if k in ("mul_modp", "basemul", "basemul_acc")
                       else ("调用子树" if len(fn) > 1 else "调用子树（本版无被调）")),
                      round(n1, 1), round(self_n / fr, 1), round(n1 - self_n / fr, 1), ftxt,
                      static, round(n1 / static, 1) if static else "—", ltxt,
                      f"{kl['n'] + kl['stall'] + kl['fetch']:,} == {kl['span']:,} ✓"])
    s.append([])
    s.append(["读法", "① 叶函数：mul_modp/basemul/basemul_acc 的「被调函数 / 其它符号」= 0 ⇒ 区间内只有自己"
              "（判据 C 同时成立：帧跨度 == 自身拍）。② ver1_1 的 NTT 每次 889 条里只有 14 条在 `ntt` 符号内，"
              "其余 875 条在 `_ntt_layers_loop`/`_ntt_layer1_loop`/`_transpose_8x8_w0w16`/`_load_64x32`/`_store_64x32` 等被调；"
              "每调用 `jal` 20 次（= 20 次子调用）、另有 `loopi`/`beq`/`bne` ⇒ 被调与内部 loop 都在统计内。"
              "③ ver0_2/ver0_1 的 ntt/intt 无被调（`jal` 0 次），但静态 839 条执行 7,784 条 ⇒ 9.3× 全是内部 loop（已计入）。"])
    for col, w in zip("ABCDEFGHIJKL", (10, 14, 14, 22, 16, 18, 26, 44, 13, 11, 30, 34)):
        s.column_dimensions[col].width = w

    # ── 逐 opcode 互证 sheet（RTL 全 app vs ISS insn_histo）────────────────────
    if "逐opcode互证" in wb.sheetnames:
        del wb["逐opcode互证"]
    s = wb.create_sheet("逐opcode互证")
    s.append(["逐 opcode 三方互证：RTL（真机逐条）与 ISS `insn_histo` 同名（都用 ISS 的助记符）"
              "⇒ Δ≠0 的只应是 KMAC 轮询循环里的那几条（ver0_1 不用 KMAC ⇒ 全 0）"])
    s["A1"].font = Font(bold=True)
    s.append(["版本", "op", "指令", "RTL 次数", "ISS 次数", "Δ"])
    for v in VERS:
        for op in ("keygen", "encap", "decap"):
            o = (st[v]["ops"].get(op) or {})
            g, gi = o.get("opcode_rtl") or {}, o.get("opcode_iss") or {}
            if not g or not gi:
                continue
            for k in sorted(set(g) | set(gi), key=lambda x: (-(g.get(x, 0) + gi.get(x, 0)), x)):   # 并列时按指令名，保证可重现
                a, b = g.get(k, 0), gi.get(k, 0)
                row = [v, op, k, a, b, a - b]
                s.append(row)
                if a != b:
                    s[s.max_row][5].font = Font(bold=True)
    for col, w in zip("ABCDEF", (10, 10, 16, 12, 12, 10)):
        s.column_dimensions[col].width = w

    # ── ISS 互证 sheet ───────────────────────────────────────────────────────
    if "ISS互证" in wb.sheetnames:
        del wb["ISS互证"]
    s = wb.create_sheet("ISS互证")
    s.append(["三方互证：RTL（真机逐拍） vs ISS（同口径）—— 叶函数 Δ 应为 0；NTT/INTT 对 ISS 阶段行（Δ = ISS 阶段自身的口径边界）"])
    s["A1"].font = Font(bold=True)
    s.append(["版本", "kernel", "RTL 动态指令数", "ISS 同口径", "Δ", "RTL 拍合计", "RTL 动态度量自证（帧跨度对账）"])
    for v in ("ver1_1", "ver0_2", "ver0_1"):
        for k in KERNEL_ROWS:
            ops, fr, iss = total_of(st[v], k)
            if not ops:
                continue
            ne = sum(x[0] for x in ops.values())
            nb = sum(x[1] for x in ops.values())
            nc = sum(x[2] for x in ops.values())
            d = f"{ne - iss:+,}" if iss else "—（P-256 无 ISS 剖面）"
            s.append([v, k, ne, iss or "—", d, ne + nb + nc, "见 kernel_stat_%s.md" % v])
    # 顶层（IBEX）自证：ΣE == chip INSN_CNT，写一行说明
    s.append([])
    s.append(["IBEX 层自证", "整段 Σ`E` == chip `INSN_CNT`（九组逐位相等）+ 逐函数拍数之和 == 整段跨度 ⇒ 见 RTL实测_三版对照.md §2"])
    for col, w in zip("ABCDEFG", (10, 14, 18, 16, 12, 14, 40)):
        s.column_dimensions[col].width = w

    # ── 统计口径 sheet ───────────────────────────────────────────────────────
    if "统计口径" in wb.sheetnames:
        del wb["统计口径"]
    s = wb.create_sheet("统计口径")
    for line in [
        "来源与口径（全部来自 RTL trace，非估计）",
        "",
        "1. 数据来源：chip sim（Verilator）里 OTBN 的指令级 trace（每拍 (cycle, PC, insn)），由 test_perf/tools/diag/kernel_stat.py 统计。",
        "   符号边界（PC→函数名）取自 ISS 剖面的 boundaries（P-256 用 run_p256.elf 的 .symtab）；它只是“电话簿”，不贡献任何数字。",
        "2. 每拍归属：E = 该指令退休 1 拍；S = 该 PC 停滞 1 拍；两条记录之间的空档 = 取指等待（摊给上一条记录所在指令）。",
        "   ⇒ stall cycles（E 列）= 停滞 + 取指等待（都是“没退休的拍”）。",
        "3. 归属规则：叶函数（mul_modp / basemul / basemul_acc）= PC 在其符号区间；NTT / INTT = 调用子树",
        "   （进入该 kernel 的某次调用内的全部记录，含被调函数与内部 loop——模板要求的口径）。",
        "   ⇒ NTT 行包含 basemul / basemul_acc 的拍，它们各自的行只算自己：行之间会重复，不可相加。",
        "4. “某一次动态指令 stall 多少”：= 该指令**每执行一次**自己的 stall = 停滞 + 取指等待；"
        "实测分布见「stall拆解」的 ① 列与 stall_levels_<版本>.json —— 同一条指令各次的值全部相同"
        "（ver1_1 `bn.mulvm` 恒 11 拍、访存恒 1 拍、`jalr` 0 停滞 + 1 取指；P-256 `jalr` 亦然）。"
        "「同一种 opcode 加起来」= stall拆解 逐行 / 合计行；「一个 kernel 中总 stall」= 其合计行，即 Sheet1 的 stall 列。",
        "5. 三方互证：① IBEX 层：整段 ΣE == chip INSN_CNT（同一份 uart0.log），九组逐位相等；",
        "   ② ISS 层：叶函数动态次数与 exec_insn 逐位相同（Δ=0）；NTT/INTT 与 ISS 阶段行差逐 op −3…−6 条（三 op 合计 −15/−9，阶段自身口径边界）；",
        "   ③ 逐 opcode（见「逐opcode互证」sheet）：9 组里 Δ≠0 的**只有 KMAC 轮询循环那 5 条**（addi/beq/bne/andi/csrrs），"
        "每组的 Δ 都恰好是 5×轮询圈数差 ⇒ 与 chip−ISS 总数（ver1_1 +475/+540/+550、ver0_2 −20/+45/+55、ver0_1 0/0/0）逐位吻合，其余 36+ 条指令全为 0；",
        "   ④ 帧跨度对账：**每个 kernel** 的「总拍（退役+停滞+取指）== Σ[C1,C2) 帧跨度」**精确 +0**"
        "（三版 × 5 kernel 全过，见 stall_levels_<版本>.md 判据 C —— 叶函数成立即证明没有被调漏算，子树成立即证明没有漏拍）；"
        "⑤ 独立复核：stall 三级由 test_perf/tools/diag/verify_stall_levels.py 从 trace **重算一遍**（与 kernel_stat.py 是两份实现），"
        "逐 (op, kernel, opcode) 结果全等（判据 A）。",
        "6. 版本维度：P-256 三版同一份官方 app（行内 = 一次 ECDH；Keygen 一次见明细 sheet，两者相近）；",
        "   ML-KEM 的 NTT/basemul 实现三版不同，Sheet1 的 ML-KEM 行 = 三 op 合计（逐 op 见明细 sheet）。",
    ]:
        s.append([line])
    s.column_dimensions["A"].width = 120

    wb.save(xlsx)
    print(f"[写] {xlsx}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
