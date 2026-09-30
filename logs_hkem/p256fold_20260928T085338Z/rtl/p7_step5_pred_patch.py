#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 Step 5（PDF 优先级 1：有限结构调整）——给 `otbn_p256_fold.sv` 加**控制预译码寄存器**。

**依据（实测，见 §8.10）**：fold 自身的 1000/1000 条最差路径**起点 = 相位计数器 `cycle_q` / `busy_q`**、
终点 = fold 全部状态寄存器 ⇒ 关键链是
    `cycle_q → phase（比较/减法/22 路 case）→ CPA 操作数 mux → 260-bit CPA → f_d`
外加 `busy_q` 直接进 4 个 blanker 的使能（AND 门的一个输入）。
PDF §11 Step 5 的处置第 1 条正是「查 mux / fanout；**把可由 predecode 完成的控制移出组合路径**」。

**改法**：把「相位/拍号 → {CPA 操作数选择, blanking 使能}」整体**提前一拍寄存**（用 `cycle_q + 1`
预先译码）。**拍数不变、语义不变**；不做无收益的改动（其余相位译码位于 D 端 mux 的**选择**侧，
而那条链的晚到信号是数据 `cpa_ext`，故不动）。

**自校验（缺一不可）**：
1. 新增断言 `A_pd_matches: pd_q == pd_decode(cycle_q, mode_q, busy_q)` —— 逐拍证明预译码与组合译码
   逐位相同（`pd_q.valid ≡ busy_q` 由构造保证：唯一的 busy 退出点是相位 21，且 abort 当拍清零）；
2. 原有 20+ 条断言（`A_f_blanked_*`/`A_h_blanked_*`/`A_l0_blanked_*`/`A_wd_only_at_wb`/…）仍以
   **组合参考**（`busy_q && phase…`）判定，而数据通路已改走 `pd_q` ⇒ 它们同时成了本次改动的等价性检查；
3. 拍数与写回拍不变 ⇒ ISS 多周期模型、全部 latency/投影**无需改动**。

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_step5_pred_patch.py [--check|--revert]
"""
import argparse
import pathlib
import sys

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

REPO = pathlib.Path(__file__).resolve().parents[3]
F = REPO / "hw/ip/otbn/rtl/otbn_p256_fold.sv"
NL = {}


def read_text(p):
    b = p.read_bytes()
    crlf = b.count(b"\r\n")
    NL[p] = "\r\n" if crlf > (b.count(b"\n") - crlf) else "\n"
    return b.decode("utf-8").replace("\r\n", "\n")


def write_text(p, t):
    p.write_bytes(t.replace("\n", NL.get(p, "\n")).encode("utf-8"))


def sub_once(t, old, new, what):
    n = t.count(old)
    assert n == 1, "%s：期望 1 处，实际 %d 处" % (what, n)
    return t.replace(old, new, 1)


def sub_span(t, start, end, new, what):
    i = t.find(start)
    assert i >= 0 and t.count(start) == 1, "%s：起点锚不唯一/缺失" % what
    i = t.rfind("\n", 0, i) + 1
    j = t.find(end, i)
    assert j >= 0, "%s：终点锚缺失" % what
    j = t.find("\n", j) + 1
    return t[:i] + new + t[j:]


# ---------------------------------------------------------------- 插入的代码块
PD_BLOCK = '''
  // ---------------------------------------------------------------------------
  // 控制预译码（P7 Step 5「有限结构调整」；PDF 处置第 1 条：把可由 predecode 完成的控制
  // 移出组合路径）。动机是实测归属（§8.10）：fold 自身 1000/1000 条最差路径的**起点就是相位
  // 计数器** `cycle_q` / `busy_q`，终点是全部状态寄存器 ⇒ `cycle_q → phase → CPA 操作数 mux
  // → CPA → f_d` 这条控制锥在关键路径上。
  // 改法：把「拍号/相位 → {CPA 操作数选择, blanking 使能}」提前一拍译码并寄存（用 cycle_q+1），
  // 于是 CPA 输入 mux 与 blanker 的**选择端从寄存器直出**，不再是长锥的末端。
  // 拍数、语义、写回拍一律不变；`pd_q.valid ≡ busy_q`（唯一 busy 退出点是相位 21，abort 当拍清零），
  // 由断言 A_pd_matches 逐拍校验，且原有 blanking/wb 断言改由组合参考判定、同时兼作等价性检查。
  // ---------------------------------------------------------------------------
  typedef struct packed {
    logic       valid;    // 本拍在跑（≡ busy_q）
    logic [3:0] b_sel;    // CPA 第二输入：0=无 1=2A 2=2Bv 3=P0 4=P1 5=N0 6=N1 7=N2 8=N3 9=L0 10=k·d 11=±p
    logic       a_x;      // cpa_a = 零扩的 F[255:0]（k·d 拍）
    logic       sub;      // cpa_sub（控制决定的减：N0…N3；±p 拍的减由数据符号决定，不走这里）
    logic       bf;       // blanker 使能：F（相位 ≥ 10）
    logic       bh;       // blanker 使能：h（相位 10…17）
    logic       bl;       // blanker 使能：LL/ACC130（相位 18）
  } pd_t;

  // 组合参考译码（也是断言 A_pd_matches 的右手边）
  function automatic pd_t pd_decode(input logic [4:0] cyc, input logic mode, input logic valid);
    pd_t    r;
    logic [4:0] ph;
    r = '0;
    if (!valid) return r;                       // idle / 结束后：全部选择为 0（等价于旧版 busy_q=0）
    ph = (mode && (cyc >= 5'd10)) ? (cyc - TailShift) : cyc;
    r.valid = 1'b1;
    r.bf    = (ph >= 5'd10);
    r.bh    = (ph >= 5'd10) && (ph <= 5'd17);
    r.bl    = (ph == 5'd18);
    unique case (ph)
      5'd10: r.b_sel = 4'd1;                              // F ← F + 2A
      5'd11: r.b_sel = 4'd2;                              // F ← F + 2Bv
      5'd12: r.b_sel = 4'd3;                              // F ← F + P0
      5'd13: r.b_sel = 4'd4;                              // F ← F + P1
      5'd14: begin r.b_sel = 4'd5; r.sub = 1'b1; end       // F ← F − M0
      5'd15: begin r.b_sel = 4'd6; r.sub = 1'b1; end       // F ← F − M1
      5'd16: begin r.b_sel = 4'd7; r.sub = 1'b1; end       // F ← F − M2
      5'd17: begin r.b_sel = 4'd8; r.sub = 1'b1; end       // F ← F − M3
      5'd18: r.b_sel = 4'd9;                              // F ← F + L0
      5'd19: begin r.b_sel = 4'd10; r.a_x = 1'b1; end      // T ← x + k·d
      5'd20: r.b_sel = 4'd11;                             // candidate ← T ± p
      default: ;
    endcase
    return r;
  endfunction

  pd_t pd_q, pd_d;

  always_comb begin
    pd_d = '0;
    if (start_i) begin
      // 下一拍即 c0，模式取本拍锁存的新值
      pd_d = pd_decode(5'd0, mode_serial_i, 1'b1);
    end else if (busy_q) begin
      // 下一拍的译码；valid = 下一拍仍在跑（唯一退出点是相位 21；abort 当拍清 busy）
      pd_d = pd_decode(cycle_q + 5'd1, mode_q, !abort_i && (phase != 5'd21));
    end
  end
'''

MUX_NEW = '''  // ---------------------------------------------------------------------------
  // 唯一 260-bit CPA：operand mux（row mux + x+k·d 的 F→zero-extended x 切换 + ±p）
  // 选择端来自**预译码寄存器** `pd_q`（见上），数据端仍按原样组合；两者组合结果与
  // 原「按 phase 的 unique case」逐位相同（由 A_pd_matches + blanking 断言共同保证）。
  // 注意：±p 拍的 `cpa_sub`/±p 选择由**数据符号** `f_blanked[W-1]` 决定（不是控制），
  // 故不经 `pd_q.sub`，保持数据路径不变。
  // ---------------------------------------------------------------------------
  logic [W-1:0] cpa_a, cpa_b;
  logic         cpa_sub;   // 1 = 减：第二输入取反 + 进位 1（与加法共享同一加法器）

  always_comb begin
    cpa_a   = f_blanked;
    cpa_b   = '0;
    cpa_sub = 1'b0;
    if (pd_q.valid) begin
      unique case (pd_q.b_sel)
        4'd1:    cpa_b = t_2a;                             // F ← F + 2A
        4'd2:    cpa_b = t_2b;                             // F ← F + 2Bv
        4'd3:    cpa_b = t_p0;                             // F ← F + P0
        4'd4:    cpa_b = t_p1;                             // F ← F + P1
        4'd5:    begin cpa_b = ~t_n0; cpa_sub = 1'b1; end  // F ← F − M0
        4'd6:    begin cpa_b = ~t_n1; cpa_sub = 1'b1; end  // F ← F − M1
        4'd7:    begin cpa_b = ~t_n2; cpa_sub = 1'b1; end  // F ← F − M2
        4'd8:    begin cpa_b = ~t_n3; cpa_sub = 1'b1; end  // F ← F − M3
        4'd9:    cpa_b = t_l0;                             // F ← F + L0
        4'd10:   begin                                     // T ← x + k·d，x = zero-extended F[255:0]
          cpa_a = {{(W-256){1'b0}}, f_blanked[255:0]};
          cpa_b = kd_lut($signed(k_c19));
        end
        4'd11:   begin                                     // candidate ← T ± p（第二输入在 mux 里取 ±p）
          cpa_b   = f_blanked[W-1] ? P260 : ~P260;               // T<0 ⇒ +p；T≥0 ⇒ −p（反相 + 进位）
          cpa_sub = ~f_blanked[W-1];
        end
        default: ;
      endcase
    end
  end

  // 精确和（W+1 位有符号）：仅用于「落在 signed 260 范围内」的组合检查与 candidate 符号
  logic [W:0] cpa_ext;
  assign cpa_ext = {cpa_a[W-1], cpa_a} + {cpa_b[W-1], cpa_b} + {{W{1'b0}}, cpa_sub};
'''


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    t = read_text(F)
    if "pd_decode" in t:
        print("已是打补丁后的版本（检测到 pd_decode）；回退请用 git checkout")
        return 0

    if True:
        # ---- (1) blanker 使能改走预译码
        # ---- (1) blanker 使能改走预译码
        t = sub_once(t, ".en_i(busy_q && (phase >= 5'd10)),", ".en_i(pd_q.bf),", "f blanker 使能")
        t = sub_span(t, "u_blank_h", "(phase <= 5'd17)),",
                     "  prim_blanker #(.Width(256)) u_blank_h      (.in_i(h_q),      .en_i(pd_q.bh),\n",
                     "h blanker 使能")
        t = sub_span(t, "u_blank_ll", "u_blank_ll",
                     "  prim_blanker #(.Width(128)) u_blank_ll     (.in_i(ll_q),     .en_i(pd_q.bl),\n",
                     "ll blanker 使能")
        t = sub_span(t, "u_blank_acc130", "u_blank_acc130",
                     "  prim_blanker #(.Width(AW))  u_blank_acc130 (.in_i(acc130_q), .en_i(pd_q.bl),\n",
                     "acc130 blanker 使能")
        # ---- (2) 插入预译码块（放在 phase 定义之后）
        t = sub_once(t,
                     "  assign phase = (mode_q && (cycle_q >= 5'd10)) ? (cycle_q - TailShift) : cycle_q;\n",
                     "  assign phase = (mode_q && (cycle_q >= 5'd10)) ? (cycle_q - TailShift) : cycle_q;\n"
                     + PD_BLOCK,
                     "插入 pd 块")
        # ---- (3) CPA operand mux 改走预译码
        t = sub_span(t,
                     "  // ---------------------------------------------------------------------------\n"
                     "  // 唯一 260-bit CPA：operand mux",
                     "assign cpa_ext", MUX_NEW, "CPA mux")
        # ---- (4) 断言：逐拍校验预译码
        t = sub_once(t,
                     "    // §10.6：blanking 的两条不变量（未使能必须为 0；使能必须透传）\n",
                     "    // Step 5 预译码等价性：寄存的译码 == 组合参考译码（逐拍）\n"
                     "    A_pd_matches: assert (pd_q == pd_decode(cycle_q, mode_q, busy_q))\n"
                     "      else $error(\"A_pd_matches: 预译码与组合译码不一致\");\n"
                     "\n"
                     "    // §10.6：blanking 的两条不变量（未使能必须为 0；使能必须透传）\n",
                     "插入 A_pd_matches")
        # ---- (5) 时序
        t = sub_once(t, "      wd_valid_q <= 1'b0;\n      wd_q       <= '0;",
                     "      wd_valid_q <= 1'b0;\n      wd_q       <= '0;\n      pd_q       <= '0;",
                     "复位 pd_q")
        t = sub_once(t, "      wd_valid_q <= wd_valid_d;\n      wd_q       <= wd_d;",
                     "      wd_valid_q <= wd_valid_d;\n      wd_q       <= wd_d;\n      pd_q       <= pd_d;",
                     "更新 pd_q")

    if args.check:
        print("补丁自检通过（每处替换都带断言）；未写盘")
        return 0
    write_text(F, t)
    print("已改写 %s" % F.relative_to(REPO))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
