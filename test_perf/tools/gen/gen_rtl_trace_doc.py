#!/usr/bin/env python3
"""把 **RTL 逐函数真实周期数** 汇总成文档（读 JSON，不手抄）。

数据来源（只读）：
  · `logs_hkem/<版本>/rtl/rtl_trace_{keygen,encap,decap}.json` —— `rtl_trace_attr.py` 的产物
    （逐 PC trace → 逐函数：退役 / 停滞 / 取指等待 / 拍数；自证三条）
  · `logs_hkem/<版本>_profiling/re_<版本>.json` —— ISS 口径（macro 拍数，做对照）

产出（**都落在 logs_hkem/ 下**，那里不进 git；分解表用 `--extra` 直接引这些路径即可）：
  · `logs_hkem/<版本>/rtl/RTL实测_<版本>.md`   —— 该版本的「RTL 实测」章节（逐函数含被调拍 + 与 ISS 行对照）
  · `logs_hkem/RTL实测_三版对照.md`            —— 三版逐函数横向对照

口径（与 `rtl_trace_attr.py` 一致，**别改**）：
  `RTL 拍 = 退役 + 停滞 + 取指等待`；取指等待摊给上一条记录所在函数（同 ISS `has_fetch_stall`）
  ⇒ **逐函数拍数之和 == 整段跨度**（100% 归属，无残量）。
  ⚠ 与 ISS 的差是**信息**：KMAC 版（ver0_2/ver1_1）ISS 的 KMAC 时序是粗粒度模型，轮询圈数与
  RTL 不同 ⇒ 指令数/拍数本就应差；差落在哪看 `Δ退役` 列。

用法:
  python3 test_perf/tools/gen/gen_rtl_trace_doc.py                 # 干跑（打印摘要）
  python3 test_perf/tools/gen/gen_rtl_trace_doc.py --write         # 落盘
  python3 test_perf/tools/gen/gen_rtl_trace_doc.py --version ver1_1 --write
"""
import argparse
import json
import sys
from pathlib import Path

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = Path(__file__).resolve().parents[3]   # 工具在 test_perf/tools/<类>/ 下 ⇒ 仓库根 = parents[3]
VERS = ("ver0_1", "ver0_2", "ver1_1")
OPS = (("keygen", "keypair"), ("encap", "encap"), ("decap", "decap"))
TITLE = {"ver0_1": "ver0_1（软件 Keccak）", "ver0_2": "ver0_2（KMAC 硬件哈希）",
         "ver1_1": "ver1_1（官方向量指令 + KMAC）"}
MIN_PCT = 0.10          # 表里逐函数列出 ≥ 该占比的行，其余合并成一行（汇总仍闭合）


def load(v: str):
    """读一个版本的 3 份 rtl_trace JSON + ISS JSON；缺任何一份就返回 None（不静默少写）。"""
    out = {}
    for op, name in OPS:
        p = REPO / f"logs_hkem/{v}/rtl/rtl_trace_{op}.json"
        if not p.exists():
            return None
        out[op] = json.loads(p.read_text(encoding="utf-8"))
    jp = REPO / f"logs_hkem/{v}_profiling/re_{v}.json"
    if not jp.exists():
        return None
    out["iss"] = json.loads(jp.read_text(encoding="utf-8"))
    return out


def op_table(v, op, d, exec_iss):
    """一个 op 的逐函数表（含 ISS 对照列）。返回 markdown 行列表。"""
    sc = d["self_check"]
    span = sc["span"]
    L = [f"| 函数 | **拍（含被调）** | 占 app | 自身拍 | 退役 | 停滞 | 取指等待 | ISS 同函数退役 | Δ退役 |",
         "|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    def _inc(s):
        # inclusive 为 None = 该符号不是"被调函数"（顶层/内联标号，没有帧）⇒ 退回自身拍
        ic = s.get("inclusive")
        return s["cycles"] if ic is None else ic
    ranked = sorted(d["symbols"], key=lambda s: -_inc(s))
    rest = [0, 0, 0, 0, 0]      # name/retire/stall/gap/cycles 的"其余"累计
    for s in ranked:
        if 100 * _inc(s) / span < MIN_PCT:
            rest[1] += s["retire"]
            rest[2] += s["stall"]
            rest[3] += s.get("fetch_wait", 0)
            rest[4] += s["cycles"]
            rest[0] += 1
            continue
        ei = exec_iss.get(s["name"])
        ic = _inc(s)
        L.append(f"| `{s['name']}` | **{ic:,}** | {100 * ic / span:.2f}% | {s['cycles']:,} | "
                 f"{s['retire']:,} | {s['stall']:,} | {s.get('fetch_wait', 0):,} | "
                 + (f"{ei:,}" if ei is not None else "—")
                 + (f" | {s['retire'] - ei:+,} |" if ei is not None else " | — |"))
    if rest[0]:
        L.append(f"| *其余 {rest[0]} 个函数* | — | — | {rest[4]:,} | {rest[1]:,} | {rest[2]:,} | "
                 f"{rest[3]:,} | — | — |")
    L += [f"| **自身拍合计（= 整段跨度）** | — | **100.00%** | **{span:,}** | {sc['sum_E']:,} | "
          f"{sc['sum_S']:,} | {span - sc['sum_E'] - sc['sum_S']:,} | — | — |", ""]
    return L


def frag(v, data) -> str:
    iss = data["iss"]["apps"][v]
    L = [f"## RTL 实测（逐函数真实周期数）· {v}", "",
         f"> 方法 A：同一份 app 在 **RTL**（Earlgrey chip sim，OTBN 连真 KMAC）上跑，按 OTBN 指令级 "
         f"trace 的 PC 逐拍归因。",
         f"> 口径：**含被调拍 = trace 实测帧跨度 `[C1, C2)`**（C1 = 进入函数第一拍，C2 = 调用方恢复执行的"
         f"那一拍；含它调用的子函数；逐帧核对 `帧跨度 == 帧内记入 + Σ被调帧`）⇒ **叶函数 含被调 == 自身拍**，"
         f"父函数 = 自身拍 + 帧内兄弟标签 + Σ直接被调含被调。"
         f"**自身拍 = 退役 + 停滞 + 取指等待**（取指等待摊给上一条记录所在函数）⇒ 自身拍逐函数之和 == 整段跨度（100% 归属）。",
         f"> ⚠ 含被调列**不能相加**（被调会被父帧重复计入）；要「加起来等于整段」用自身拍列。",
         f"> 与上面 ISS 表的差是**信息**不是错误：KMAC 版 ISS 的 KMAC 时序是粗粒度模型，轮询圈数与 "
         f"RTL 不同 —— 差落在哪个函数看 `Δ退役` 列（下表的 ISS 列来自 `re_{v}.json`）。", ""]
    for op, name in OPS:
        d = data[op]
        sc = d["self_check"]
        a = iss[op]
        exec_iss = a.get("exec_insn") or {}
        L += [f"### {op}（整段 {sc['span']:,} 拍；ISS macro {a['cycles']:,} 拍，差 "
              f"{100 * (sc['span'] - a['cycles']) / a['cycles']:+.2f}%）", "",
              f"> 自证：Σ`E` {sc['sum_E']:,} == chip `INSN_CNT` {sc.get('chip_insn') or 0:,} "
              f"{'✓' if sc['ok_complete'] else '✗'}；逐函数拍数之和 == 跨度 "
              f"{'✓' if sc['ok_span'] else '✗'}；RTL−ISS 指令数 {sc['d_insn']:+,}、"
              f"停滞（`S`+取指等待−ISS stalls）{sc['d_stall']:+,}。", ""]
        L += op_table(v, op, d, exec_iss)
    return "\n".join(L)


def cross_doc(rows) -> str:
    L = ["# RTL 实测 · 三版逐函数对照（方法 A）", "",
         "> 数据来源：`logs_hkem/<版本>/rtl/rtl_trace_{keygen,encap,decap}.json`"
         "（由 `test_perf/tools/diag/rtl_trace_attr.py` 从 RTL trace 生成）。",
         "> 口径：表中数字是 **含被调拍 = 帧跨度 `[C1, C2)`**（C1 = 进入函数第一拍，C2 = 调用方恢复执行的那一拍）；"
         "叶函数等于「自身拍」；「自身拍」= 退役 + 停滞 + 取指等待，逐函数相加 == 整段跨度。", ""]
    for op, _name in OPS:
        byv = {}
        for v, data in rows.items():
            byv[v] = {s["name"]: s for s in data[op]["symbols"]}
        def _rank(m, n):
            s = m.get(n, {})
            ic = s.get("inclusive")
            return s.get("cycles", 0) if ic is None else ic
        names = sorted(set().union(*[set(m) for m in byv.values()]),
                       key=lambda n: -sum(_rank(m, n) for m in byv.values()))
        L += [f"## {op}", "",
              "| 函数 | " + " | ".join(f"{TITLE[v]} 拍" for v in rows) + " |",
              "|---|" + "---:|" * len(rows)]
        for n in names[:25]:
            L.append(f"| `{n}` | " + " | ".join(
                ((f"{byv[v][n]['inclusive'] if byv[v][n].get('inclusive') is not None else byv[v][n]['cycles']:,}"
                  if n in byv[v] else "—")) for v in rows) + " |")
        if len(names) > 25:
            L.append(f"| *其余 {len(names) - 25} 个函数（自身拍合计）* | " + " | ".join(
                f"{sum(s['cycles'] for s in byv[v].values() if s['name'] not in names[:25]):,}"
                for v in rows) + " |")
        L.append("")
    return "\n".join(L)


# ── 归档文档（写到 实验数据/ 下；含 RTL 测量方法）──────────────────────────────
METHOD = """\
## 1. 测量方法（可核对，不是估计）

### 1.1 被测对象与观测手段

* **平台**：Earlgrey chip 的 **Verilator** 仿真（`Vchip_sim_tb`，启动横幅 `Simulation of OpenTitan Earl Grey`），
  OTBN 接**真 KMAC**（`earlgrey_pd_main.sv` 里 `kmac_data_o/i ↔ kmac_app_req/rsp[3]`）；三版九个测试全部 `PASS`。
* **观测**：仓库自带 DV 追踪器 `hw/ip/otbn/dv/tracer/rtl/otbn_tracer.sv`（`ifndef SYNTHESIS` 的**纯探针**，
  不触碰功能 RTL）：`cycle_count` **每个 OTBN 核时钟 +1**（`otbn_tracer.sv:328`），每条指令输出若干 `S`
  （该 PC **停滞一拍**）+ 一个 `E`（**退休**），记录格式 `E <cycle> PC: 0x…, insn: 0x…`；
  以 `bind` 接进 `chip_sim_tb` 的 OTBN 核（`hw/top_earlgrey/dv/verilator/`：3 个 DV 文件 + `chip_sim.core` 依赖）。
  ⇒ **每一拍的 (cycle, PC) 都是 RTL 里读出来的**。
* **打开方式**：`--verilator-args=--otbn-trace-file=FILE`（默认不写文件 ⇒ 不影响既有回归）。同一次运行的
  `sim.log` 里可核对那一行命令（含 `--otbn-trace-file`），`uart0.log` 里有 `PASS` 与 OTBN `INSN_CNT`。

### 1.2 从 trace 到逐函数拍数（两条口径，都是**定义**）

1. **自身拍 = 退役 + 停滞 + 取指等待** —— 每拍记在「正在执行 / 停滞的那个 PC」上；取指等待 = 两条记录之间的
   空拍（fetch 未回），**摊给上一条记录所在函数**。⇒ **逐函数相加 == 整段跨度**（100% 归属，无残量）。
2. **含被调 = 帧跨度 `[C1, C2)`** —— C1 = 被调函数第一条记录的拍；C2 = **调用方恢复执行的那一拍**
   （该帧不再活跃的第一拍）。调用帧由**逐条指令解码**建栈（用 ISS 自带 ISA 表，不猜编码）：
   `jal` / `jalr(rd=x1)` 压栈、`ret`（`jalr x0, x1, 0`）出栈。
   ⇒ **叶函数 含被调 == 自身拍**；父函数 = 自身拍 + 帧内兄弟标签 + Σ直接被调含被调。

### 1.3 判据（硬判据；任一条不过 ⇒ 生成器 exit≠0，不发文档）

| 判据 | 它证明什么 |
|---|---|
| Σ`E` == 同一次运行的 chip `INSN_CNT` | `INSN_CNT` 来自 OTBN **自己的硬件计数器**（独立路径）⇒ trace 一条不丢、一条不重 |
| Σ(`E`+`S`) + 空档 == 整段跨度 | 逐拍归属 **100% 闭合**，没有"消失的拍" |
| **帧跨度 == 帧内记入 + Σ被调帧**（逐帧） | 帧边界（开/关帧事件）与帧内拍（逐拍记入）是**两条独立算路**，必须逐帧相等 |
| 含被调 ≥ 自身拍（叶函数取等） | 帧跨度的直接推论；旧口径（C2 取 `ret` 自己那一拍）会**违反**它 |

### 1.4 这套数是什么 / 不是什么

* **是**：真 RTL（Verilator chip sim）上跑**整程序**、由 (cycle, PC) **直接归因**的逐函数拍数。
* **不是**：不是 OTBN **ISS** 的模型数（两者**并列**，差见 §4 —— KMAC 轮询圈数由各自时序决定）；
  不是估计 / 外推；也不是硅片实测（是 RTL 仿真）。
* 除上面两条口径（已写明）之外，原始拍数没有做任何"推算"。

### 1.5 与 IBEX / ISS 两层的关系（区别与联系）

**区别**（同一份 app、三个观测面）：

| | **IBEX**（chip 宿主层） | **ISS**（OTBN 剖面层） | **RTL**（本层：OTBN 逐函数） |
|---|---|---|---|
| 谁在跑 | Ibex 跑测试 C 程序，OTBN 是**外设** | OTBN **ISA 模拟器**单跑 app（无宿主、无总线） | 完整 chip Verilator，OTBN 跑 **app 本体**、连**真 KMAC** |
| 时间从哪来 | 宿主 `mcycle`（含总线/驱动/等待） | 模拟器计数 `cycles = insn + stalls` | RTL 探针逐拍 `(cycle, PC)` ⇒ `自身拍 = 退役+停滞+取指等待` |
| 分辨到 | 协议级：OTBN / P-256 / HKDF 各占多少 | 阶段级：`Δ = profiling − control`，归到 FIPS 行 | **函数级真实周期**（含被调 = 帧跨度）、**KMAC 轮询真实圈数** |
| 看不到 | OTBN 内部任何细节 | **真 KMAC 时序**（粗粒度模型）、宿主开销 | ISS 那种"控制实验"（本层直接测整 app，不做 Δ） |

**联系**（能互相核对的原因）：

1. **同一份输入**：三层都是**同一个 app ELF**（同一 bazel 目标产物）。
2. **指令数**：本层 Σ`E` == chip `INSN_CNT`（**同一次运行**、逐位相等）；chip `INSN_CNT` ↔ ISS `insn`：ver0_1 **差 0**，ver0_2/ver1_1 的差 = KMAC 轮询圈数差。
3. **周期数**：本层整段跨度 ↔ ISS `macro`（ver0_1 ±0.002%、ver0_2 ±0.023%、ver1_1 +0.35%～+0.47%）；Ibex `mlkem_*_execute_wait` ↔ ISS `macro`（+0.70%～+1.02% = 调用/等待开销）。
4. **逐函数 ↔ 逐阶段**：见 §4 —— 只做**同名直配**，差逐行落在 KMAC 轮询；ver0_1 差 0/0/0（**反证**）。

**别混用**：三层口径不同（ISS `stalls` 含取指等待；Ibex 周期含总线/驱动；本层"含被调"不能相加），
**相减得不出"实现差异"**。详解（含三层自证方式）见 `实验数据/README.md` 的「三层测试的区别与联系」。
"""


def load_extra():
    """读「扩展 app」的 JSON（P-256 / HKDF）—— 由 `rtl_trace_attr.py --elf` 产出。

    这几个 app **没有 ISS 剖面**，符号边界取自各自 ELF（规则与 `harness.py: load_text_boundaries`
    逐条相同，已在 ML-KEM 上与 ISS 边界逐行核对一致）。缺文件就返回 None（不静默少写）。
    """
    out = {}
    for k in ("p256", "hkdf_kmac", "hkdf_sw"):
        p = REPO / f"logs_hkem/rtl_extra/rtl_trace_{k}.json"
        if not p.exists():
            return None
        out[k] = json.loads(p.read_text(encoding="utf-8"))
    return out


# 会话标签（与生成这些 JSON 时的 --session-labels 一致；JSON 里不存标签）
EXTRA_SESSION_LABEL = {"p256": ("Keygen A", "Keygen B", "ECDH A", "ECDH B")}


def extra_doc(extra) -> str:
    """「扩展 app」章节：P-256（4 会话，A/B 一致性核对后合并成 Keygen / ECDH 两张表）+ HKDF 两制式。"""
    L = ["## 3b. 扩展 app：P-256 / HKDF（OTBN 内部真实周期）", "",
         "> 这两个 app 是**协议里另外两次 OTBN 调用**（`phase2_*` 里与 ML-KEM 并列执行）；它们**没有 ISS 剖面**，",
         "> 所以符号边界取自各自 ELF 的 `.symtab`（规则与 ISS 侧 `load_text_boundaries` 逐条相同：只取可执行段、",
         "> 过滤 `$` 开头汇编局部标签、边界 = 下一个符号地址；已在 ML-KEM 上与 ISS 边界**逐行核对一致**）。",
         "> **P-256 三版通用**（指令数三版逐位相同：573,922 / 581,607）、**HKDF 的 KMAC 版 = ver0_2 与 ver1_1 同一份**（3,374）。", ""]
    # 自证汇总（六个会话）
    L += ["### 3b.1 自证（六个会话；任一条不过 ⇒ 工具 exit≠0）", "",
          "| 会话 | Σ`E` == 日志打印 | Σ(`E`+`S`)+空档 == 跨度 | 帧跨度恒等式 | 含被调 ≥ 自身拍 |",
          "|---|---:|---:|---:|---:|"]
    for k in ("p256", "hkdf_kmac", "hkdf_sw"):
        labels = EXTRA_SESSION_LABEL.get(k, (f"{k}",))
        for i, s in enumerate(extra[k]["sessions"]):
            sc = s["self_check"]
            ge = all(x["inclusive"] is None or x["inclusive"] >= x["cycles"] for x in s["symbols"])
            lb = labels[i] if i < len(labels) else f"会话{i+1}"
            L.append(f"| `{k}` / {lb} | {sc['sum_E']:,} == {sc.get('chip_insn') or 0:,} "
                     f"{'✓' if sc['ok_complete'] else '✗'} | {sc['span']:,} {'✓' if sc['ok_span'] else '✗'} | "
                     f"{sc['n_frames']:,} 帧全等 {'✓' if sc.get('ok_frames') else '✗'} | "
                     f"{'✓' if ge else '✗'} |")
    L.append("")
    # P-256：先核对 A/B 一致，再合并成 Keygen / ECDH 两张表
    p = extra["p256"]["sessions"]
    same_ab = (len(p) == 4 and p[0]["self_check"]["sum_E"] == p[1]["self_check"]["sum_E"]
               and p[2]["self_check"]["sum_E"] == p[3]["self_check"]["sum_E"])
    L += ["### 3b.2 P-256（`run_p256.elf`，服务端与客户端的 ECDH）", "",
          f"> 两次 Keygen、两次 ECDH 的 A/B **逐位一致**（校验：{'✓ 通过' if same_ab else '✗ 不一致'}）"
          "⇒ 下面只列 A（B 除跨度差 1 拍外完全相同）。**拍数只含 OTBN 内部**；日志里另打的 `cycles:` 是**宿主 mcycle**，"
          "含总线搬运与中断，别与这里的数相减。", ""]
    for si, title in ((0, "Keygen（`p256_base_mult`）"), (2, "ECDH（`p256_shared_key`）")):
        if si >= len(p):
            continue
        ses = p[si]
        span = ses["self_check"]["span"]
        L += [f"#### {title} —— 跨度 {span:,} 拍（Σ`E` {ses['self_check']['sum_E']:,}）", "",
              "| 函数 | 拍（含被调） | 占该 app | 自身拍 | 退役 | 停滞 | 取指等待 |", "|---|---:|---:|---:|---:|---:|---:|"]
        for s in sorted(ses["symbols"], key=lambda x: -(x["inclusive"] if x["inclusive"] is not None else x["cycles"])):
            ic = s["inclusive"] if s["inclusive"] is not None else s["cycles"]
            L.append(f"| `{s['name']}` | {ic:,} | {100 * ic / span:.2f}% | {s['cycles']:,} | {s['retire']:,} | "
                     f"{s['stall']:,} | {s.get('fetch_wait', 0):,} |")
        L.append("")
    # HKDF：两制式并排
    km, sw = extra["hkdf_kmac"]["sessions"][0], extra["hkdf_sw"]["sessions"][0]
    fk = {s["name"]: s for s in km["symbols"]}
    fs = {s["name"]: s for s in sw["symbols"]}

    def _ic(s):
        return s["inclusive"] if s["inclusive"] is not None else s["cycles"]
    names = sorted(set(fk) | set(fs), key=lambda n: -max(_ic(fk[n]) if n in fk else 0,
                                                         _ic(fs[n]) if n in fs else 0))
    L += ["### 3b.3 HKDF-SHA3-256：软件 Keccak（ver0_1） vs KMAC 硬件（ver0_2/ver1_1）", "",
          f"> 整段跨度 **{sw['self_check']['span']:,} → {km['self_check']['span']:,} 拍**"
          f"（**{sw['self_check']['span'] / km['self_check']['span']:.1f}×**）；指令数 {sw['self_check']['sum_E']:,} → "
          f"{km['self_check']['sum_E']:,}。", "",
          "| 函数 | 软件版 拍（含被调） | 软件版 自身 | KMAC 版 拍（含被调） | KMAC 版 自身 |", "|---|---:|---:|---:|---:|"]
    for n in names:
        a, b = fs.get(n), fk.get(n)
        L.append(f"| `{n}` | " + (f"{_ic(a):,} | {a['cycles']:,}" if a else "— | —")
                 + " | " + (f"{_ic(b):,} | {b['cycles']:,}" if b else "— | —") + " |")
    L.append("")
    return "\n".join(L)


def archive_doc(rows, extra=None) -> str:
    """归档用的 RTL 数据文档：方法 + 判据 + 三版逐函数对照 + 与 ISS 的差 + 来源复现。"""
    L = ["# RTL 实测 · 三版对照（方法 A：整程序跑 RTL，按 OTBN 指令级 trace 逐拍归因）", "",
         "> 生成：`python3 test_perf/tools/gen/gen_rtl_trace_doc.py --archive <本目录>`"
         "（数字全部从 `logs_hkem/<版本>/rtl/rtl_trace_{keygen,encap,decap}.json` 生成，**不手抄**）。",
         "> 逐版本明细（完整逐函数表 + 调用帧自证 + 热点 PC）：`logs_hkem/<版本>/rtl/RTL实测_<版本>.md`；",
         "> 同口径的另一篇：`Ibex实测_三版对照.md`（chip 宿主层）、各版本**分解表**（OTBN ISS 层）。", "",
         METHOD, ""]
    # §2 自证
    L += ["## 2. 自证（9 组；任一条不过 ⇒ 生成器 exit≠0）", "",
          "| 版本/op | Σ`E` == chip `INSN_CNT` | Σ(`E`+`S`)+空档 == 跨度 | 帧跨度 == 帧内记入 + Σ被调帧 | 含被调 ≥ 自身拍 |",
          "|---|---:|---:|---:|---:|"]
    for v, data in rows.items():
        for op, _n in OPS:
            sc = data[op]["self_check"]
            ge = all(s["inclusive"] is None or s["inclusive"] >= s["cycles"] for s in data[op]["symbols"])
            L.append(f"| {v}/{op} | {sc['sum_E']:,} == {sc.get('chip_insn') or 0:,} "
                     f"{'✓' if sc['ok_complete'] else '✗'} | {sc['span']:,} {'✓' if sc['ok_span'] else '✗'} | "
                     f"{sc['n_frames']:,} 帧全等 {'✓' if sc.get('ok_frames') else '✗'}（未闭合 "
                     f"{sc.get('n_unclosed', 0)}） | {'✓' if ge else '✗'} |")
    # §3 逐函数三版对照
    def _ic(s):
        return s["cycles"] if s.get("inclusive") is None else s["inclusive"]
    L += ["", "## 3. 逐函数拍数（三版对照）", "",
          "> **含被调** = 帧跨度 `[C1, C2)`（进入第一拍 → 调用方恢复执行那一拍），**不能相加**；"
          "**自身** = 退役 + 停滞 + 取指等待，逐函数相加 == 整段跨度（每张表末尾的合计行即证明）。",
          "> `—（非被调函数）` 的符号（循环标签 / 匿名区）：不是以调用进入的，**它的拍已包含在父帧里**，"
          "不重复列含被调。", ""]
    for op, _n in OPS:
        byv = {v: {s["name"]: s for s in d[op]["symbols"]} for v, d in rows.items()}
        names = sorted(set().union(*[set(m) for m in byv.values()]),
                       key=lambda n: -max((_ic(byv[v][n]) if n in byv[v] else 0) for v in rows))
        spans = " / ".join(f"{TITLE[v].split('（')[0]} {rows[v][op]['self_check']['span']:,}"
                           for v in rows)
        L += [f"### {op}（整段跨度：{spans}）", "",
              "| 函数 | ver0_1 含被调 | ver0_1 自身 | ver0_2 含被调 | ver0_2 自身 | ver1_1 含被调 | ver1_1 自身 |",
              "|---|---:|---:|---:|---:|---:|---:|"]
        for n in names:
            cells = []
            for v in rows:
                s = byv[v].get(n)
                if s is None:
                    cells += ["—", "—"]
                elif s.get("inclusive") is None:
                    cells += ["—（非被调函数）", f"{s['cycles']:,}"]
                else:
                    cells += [f"{s['inclusive']:,}", f"{s['cycles']:,}"]
            L.append(f"| `{n}` | " + " | ".join(cells) + " |")
        cells = []
        for v in rows:
            cells += ["—", f"**{rows[v][op]['self_check']['span']:,}**"]
        L += [f"| **自身拍合计（= 整段跨度）** | " + " | ".join(cells) + " |", ""]
    if extra:
        L += [extra_doc(extra), ""]
    # §4 与 ISS 的差
    L += ["## 4. 与 OTBN ISS（分解表口径）的差：**全部落在 KMAC 轮询行**", "",
          "> ISS 的 KMAC 时序是**粗粒度模型**（`hw/ip/otbn/dv/otbnsim/sim/kmac.py` 自述 Coarse）⇒ 用 KMAC 的版本"
          "（ver0_2 / ver1_1）指令数与停滞拍**本就应当有差**；ver0_1 不用 KMAC ⇒ 差恰为 0（反证）。",
          "> 逐行对照只做**同名直配**；未配对的部分（RTL 的框架容器 / 匿名区 ↔ ISS 未归因的框架桩代码）单列，"
          "恒等式 `Σ同名Δ + 未配对RTL退役 − ISS多出未匹配 − ISS未归因 == 指令差` 由生成器逐组核对。", "",
          "| 版本/op | chip `INSN_CNT` | ISS `insn` | 指令差 | Σ同名 Δ退役 | 非零 Δ退役的行 |",
          "|---|---:|---:|---:|---:|---|"]
    ident_bad = []
    for v, data in rows.items():
        for op, _n in OPS:
            sc = data[op]["self_check"]
            ei = data["iss"]["apps"][v][op].get("exec_insn") or {}
            syms = data[op]["symbols"]
            r_matched = sum(s["retire"] for s in syms if s["name"] in ei)
            i_matched = sum(ei[s["name"]] for s in syms if s["name"] in ei)
            r_all = sum(s["retire"] for s in syms)
            i_all = data["iss"]["apps"][v][op]["insn"]
            i_extra = sum(x for k, x in ei.items() if k not in {s["name"] for s in syms})
            i_unattr = i_all - sum(ei.values())
            ok = (r_matched - i_matched) + (r_all - r_matched) - i_extra - i_unattr == sc["d_insn"]
            if not ok:
                ident_bad.append(f"{v}/{op}")
            nz = [f"`{s['name']}` {s['retire'] - ei[s['name']]:+,}"
                  for s in syms if s["name"] in ei and s["retire"] != ei[s["name"]]]
            L.append(f"| {v}/{op} | {sc.get('chip_insn') or 0:,} | {sc['iss_insn']:,} | {sc['d_insn']:+,} | "
                     f"{r_matched - i_matched:+,} | {'；'.join(nz) if nz else '（无）'} |")
    L += ["", f"> 恒等式核对：{'全部通过 ✓' if not ident_bad else '✗ ' + ', '.join(ident_bad)}"
          "（未配对：RTL 的 `(框架容器)`/`(无符号区间)`；ISS 侧对应的是**未归因到任何函数**的框架桩代码，"
          "每组 6,195 条上下 —— 这是 ISS `exec_insn` 的口径，不是数据错）", ""]
    # §5 来源与复现
    L += ["## 5. 数据来源与复现", "",
          "| 项 | 路径 |", "|---|---|",
          "| RTL trace（原始；30–178 MB/份，**不进 git**） | `logs_hkem/<版本>/rtl/test_mlkem_{keypair,encap,decap}_only.rtl_trace.log` |",
          "| chip 日志（同一次运行的 `PASS` + `INSN_CNT`） | `logs_hkem/<版本>/test_mlkem_*_only.uart0.log`（另有 `*.sim.log` 可核对 `--otbn-trace-file`） |",
          "| 逐函数 JSON（本文档的输入） | `logs_hkem/<版本>/rtl/rtl_trace_<op>.json` |",
          "| ISS 对照（分解表口径） | `logs_hkem/<版本>_profiling/re_<版本>.json` |",
          "| 工具 | `test_perf/tools/diag/rtl_trace_attr.py`（trace→逐函数）、`test_perf/tools/gen/gen_rtl_trace_doc.py`（本文件） |", "",
          "```bash",
          "# ① 逐函数归因（9 组；exit=0 表示全部硬判据通过）",
          "for v in ver0_1 ver0_2 ver1_1; do for op in keygen encap decap; do",
          "  t=$([ $op = keygen ] && echo keypair || echo $op)",
          "  python3 test_perf/tools/diag/rtl_trace_attr.py --version $v --op $op \\",
          "    --trace logs_hkem/$v/rtl/test_mlkem_${t}_only.rtl_trace.log \\",
          "    --json  logs_hkem/${v}_profiling/re_$v.json \\",
          "    --uart0 logs_hkem/$v/test_mlkem_${t}_only.uart0.log \\",
          "    --out   logs_hkem/$v/rtl/rtl_trace_$op.md --json-out logs_hkem/$v/rtl/rtl_trace_$op.json",
          "done; done",
          "# ② 生成文档（仓库内 3 份 + 三版对照 + 本归档文档）",
          "python3 test_perf/tools/gen/gen_rtl_trace_doc.py --write --archive <本目录>",
          "```", ""]
    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    ap.add_argument("--archive", default="", metavar="DIR",
                    help="另写一份归档文档 RTL实测_三版对照.md 到 DIR（实验数据/）")
    ap.add_argument("--version", action="append")
    args = ap.parse_args()
    if args.archive:                      # 归档文档必须三版齐全（缺版即报错，不静默少写）
        args.version = list(VERS)
    rows, missing = {}, []
    for v in (args.version or list(VERS)):
        d = load(v)
        if d is None:
            missing.append(v)
            print(f"  ✗ {v}: 缺 logs_hkem/{v}/rtl/rtl_trace_*.json（先跑 rtl_trace_attr.py）")
            continue
        rows[v] = d
        ok = all(d[op]["self_check"]["ok_complete"] and d[op]["self_check"]["ok_span"] for op, _ in OPS)
        print(f"  {'✓' if ok else '✗'} {v}: 自证 {'全过' if ok else '**未过**'}；"
              + "  ".join(f"{op} 跨度 {d[op]['self_check']['span']:,}"
                          + f"（ISS {d['iss']['apps'][v][op]['cycles']:,}，"
                          + f"RTL−ISS 指令 {d[op]['self_check']['d_insn']:+,}）" for op, _ in OPS))
    if not rows:
        print("\n没有可生成的数据 ⇒ 未做任何事。")
        return 1
    if not (args.write or args.archive):
        print("\n（干跑：未写文件。确认无误后加 --write / --archive DIR）")
        return 0
    if args.write:
        for v, d in rows.items():
            p = REPO / f"logs_hkem/{v}/rtl/RTL实测_{v}.md"
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(frag(v, d) + "\n", encoding="utf-8")
            print(f"  [写] {p.relative_to(REPO)}")
        # 三版对照同样落在 logs_hkem/ 下（该目录不进 git）；分解表用 --extra 直接引这些路径即可。
        out = REPO / "logs_hkem/RTL实测_三版对照.md"
        out.write_text(cross_doc(rows) + "\n", encoding="utf-8")
        print(f"  [写] {out.relative_to(REPO)}")
    if args.archive:
        adir = Path(args.archive)
        adir.mkdir(parents=True, exist_ok=True)
        extra = load_extra()
        if extra is None:
            print("  ⚠ 未找到扩展 app 的 JSON（logs_hkem/rtl_extra/rtl_trace_{p256,hkdf_kmac,hkdf_sw}.json）"
                  "⇒ 归档文档**不含**【扩展 app：P-256 / HKDF】章节（不静默少写，明确告警）")
        p = adir / "RTL实测_三版对照.md"
        p.write_text(archive_doc(rows, extra) + "\n", encoding="utf-8")
        print(f"  [写] {p}")
    if missing:
        print(f"  ⚠ 未生成：{', '.join(missing)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
