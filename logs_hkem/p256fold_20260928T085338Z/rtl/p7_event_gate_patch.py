#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 P4 的 P256EV 事件记录改成**默认关**、用运行期 plusarg 打开（P7 收尾的"调试日志"处理）。

为什么用 plusarg 而不是 `ifdef`：`ifdef` 需要改 Verilator **构建**开关（芯片仿真那条路要动
fuseSoC/bazel，而 PDF §10.5 明说"自定义 build flag 的名字尚未规定"）✗；plusarg 与 `p256_serial`
同一套路，**不需要重建**、命令行即可开关 ✓。

改三处（都在 `otbn_mac_bignum.sv` 的 `ifndef SYNTHESIS` 块内，**综合时整块被裁掉** ⇒ 不影响网表）：
  ① 加 `p256_ev_en` + `$value$plusargs("p256_event_trace=%d")`
  ② CSV 打开只在开时做（并给默认值避免 X）
  ③ `always_ff` 的非复位分支改成 `else if (p256_ev_en)` ⇒ 关时计数/CSV/打印全停

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_event_gate_patch.py [--check]
"""
import argparse
import pathlib

BS = chr(92)
F = pathlib.Path("hw/ip/otbn/rtl/otbn_mac_bignum.sv")


def main():
    raw = F.read_bytes().decode("utf-8")
    nl = "\r\n" if "\r\n" in raw else "\n"
    lines = raw.replace("\r\n", "\n").split("\n")
    n = 0

    # ① 声明 + plusarg：插在 ov0..ov5 声明之后
    i = next(k for k, l in enumerate(lines)
             if l.strip().startswith("logic [4:0] p256_ev_ov0"))
    decl = [
        "",
        "  // 事件记录**总开关**（默认关）：不打印、不写 CSV、不计数 ⇒ 日常回归安静。",
        "  // 取证据时用运行期 plusarg（与 p256_serial 同一套路，**不需要重建** Verilator 模型）：",
        "  //   芯片仿真：bazel test … --test_arg=--verilator-args=+p256_event_trace=1",
        "  //   独立仿真：Votbn_top_sim --load-elf=… +p256_event_trace=1",
        "  logic        p256_ev_en;",
        "  int          p256_ev_arg;",
        "  initial begin",
        "    p256_ev_en = 1'b0;",
        '    if ($value$plusargs("p256_event_trace=%d", p256_ev_arg)) begin',
        "      p256_ev_en = p256_ev_arg[0];",
        "    end",
        "  end",
    ]
    lines[i + 1:i + 1] = decl
    n += 1

    # ② CSV 打开块：行区间替换（从 `initial begin` 到与之配对的 `  end`）
    j = next(k for k, l in enumerate(lines) if "otbn_p256_events.csv" in l and "$fopen" in l)
    assert lines[j - 1].strip() == "initial begin", "② 起点不是 initial begin"
    e = next(k for k in range(j, len(lines)) if lines[k] == "  end")
    lines[j - 1:e + 1] = [
        "  initial begin",
        "    p256_ev_fd = 0;",
        "    p256_ev_open = 1'b0;",
        "    if (p256_ev_en) begin",
        '      p256_ev_fd = $fopen("otbn_p256_events.csv", "w");',
        "      p256_ev_open = (p256_ev_fd != 0);",
        "      if (p256_ev_open) begin",
        '        $fwrite(p256_ev_fd, "cycle,mac_micro_commit,fold_we,wdr_we,fold_f_changed,fold_phase'
        + BS + 'n");',
        "      end else begin",
        '        $error("P256EV: could not open otbn_p256_events.csv");',
        "      end",
        "    end",
        "  end",
    ]
    n += 1

    # ③ always_ff 的非复位分支
    k = next(i for i, l in enumerate(lines)
             if l.strip() == "end else begin" and lines[i - 1].strip().startswith("p256_ev_ov3 <= 5'd31"))
    assert lines[k + 1].strip() == "p256_ev_fprev <= p256_fold_f;", "③ 后继行不是 fprev"
    lines[k] = "    end else if (p256_ev_en) begin      // 默认关：整块（计数 + CSV + 打印）都不执行"
    n += 1

    out = "\n".join(lines).replace("\n", nl).encode("utf-8")
    if not args.check:
        F.write_bytes(out)
    print("edits=%d  CRLF=%d LF=%d  %s"
          % (n, out.count(b"\r\n"), out.count(b"\n"),
             "(check only)" if args.check else "(written)"))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    main()
