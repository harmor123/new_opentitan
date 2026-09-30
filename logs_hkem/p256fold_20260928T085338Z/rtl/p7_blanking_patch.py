#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""P7 Step 3 查 5 的缺件修复：给 fold 的新状态补 blanking（§10.6 / SEC_CM: DATA_REG_SW.SCA）。

背景（实测）：`prim_blanker` 计数基线 57 → 本分支仍 57（未增加），而文档 §3 Step 3 查 5 明令
「新增 Fold 状态后这个数字**必须增加**（F/h/LL 的清理），不增加即为遗漏」；PDF §10.6 要求
「F(260)/h(256)/LL(128) 共 644 bit 全量进入 blanking 与 wipe」，且「清零 ≠ 侧信道安全」。

做法：**只掩消费路径**（送进 CPA / k / 写回的那些读），寄存器自身的保持路径（`f_d = f_q`）与
DV 事件流（`P256EV` / `f_o/h_o/ll_o`）继续用原值 —— 否则状态会被自己清掉、且会改动设备证据。

消费相位（逐个从 RTL 读出，不是猜）：
  · F      : phase ≥ 10 —— `cpa_a` 的默认值就是 F（10…18 的 F←F+t_*），19 用 `f_q[255:0]` 作 x
             与 `k_c19`（kd_lut/k_d），20 用 `f_q[W-1]` 定 ±p，21 写回 `wd_d`
  · h      : phase 10…17 —— 八个 row addend `t_2a/t_2b/t_p0/t_p1/t_n0…t_n3` 由 v_* 拼出，v_* 来自 h_q
  · LL/ACC130 : phase 18 —— `t_l0 = {ACC[129:0], LL[127:0]}`（`A_L0_no_truncate` 的守卫同为 phase 18）

用法：python3 logs_hkem/p256fold_20260928T085338Z/rtl/p7_blanking_patch.py [--check]
"""
import argparse
import pathlib

BS, CR = chr(92), chr(13)
F = pathlib.Path("hw/ip/otbn/rtl/otbn_p256_fold.sv")


def main():
    raw = F.read_bytes().decode("utf-8")
    nl = CR + chr(10) if raw.count(CR + chr(10)) else chr(10)
    t = raw.replace(CR + chr(10), chr(10))
    n_edit = 0

    def sub(old, new, what, count=1):
        nonlocal t, n_edit
        n = t.count(old)
        assert n == count, "%s：期望 %d 次，实际 %d 次" % (what, count, n)
        t = t.replace(old, new, count)
        n_edit += count

    # ① 声明 blanked 视图 + 4 个 prim_blanker（插在状态声明之后、`f_o` 赋值之前）
    sub(
        "  assign f_o        = f_q;\n",
        """  // ---------------------------------------------------------------------------
  // §10.6 / SEC_CM: DATA_REG_SW.SCA —— 新状态的 **blanking**（与 OTBN 其余 57 处同构）
  // ---------------------------------------------------------------------------
  // 只掩**消费路径**：寄存器自身的保持路径（`f_d = f_q` 等）与 DV 输出/事件流继续用原值，
  // 否则状态会被自己清掉，且会改动 `P256EV` 事件（那是设备侧证据）。
  // en = 该状态**真被消费**的相位（相位→消费者的映射见 cpa_a/cpa_b 的 mux 与 t_* 的拼法）：
  //   F        : phase >= 10（cpa_a 默认就是 F；19 的 x/k；20 的 ±p 符号；21 的写回）
  //   h        : phase 10..17（t_2a/2b/p0/p1/n0..n3 八个 row addend）
  //   LL/ACC130: phase 18（t_l0 = {ACC[129:0], LL[127:0]}）
  logic [W-1:0]     f_blanked;
  logic [255:0]     h_blanked;
  logic [127:0]     ll_blanked;
  logic [AW-1:0]    acc130_blanked;

  prim_blanker #(.Width(W))   u_blank_f      (.in_i(f_q),      .en_i(busy_q && (phase >= 5'd10)),
                                              .out_o(f_blanked));
  prim_blanker #(.Width(256)) u_blank_h      (.in_i(h_q),      .en_i(busy_q && (phase >= 5'd10) &&
                                                                       (phase <= 5'd17)),
                                              .out_o(h_blanked));
  prim_blanker #(.Width(128)) u_blank_ll     (.in_i(ll_q),     .en_i(busy_q && (phase == 5'd18)),
                                              .out_o(ll_blanked));
  prim_blanker #(.Width(AW))  u_blank_acc130 (.in_i(acc130_q), .en_i(busy_q && (phase == 5'd18)),
                                              .out_o(acc130_blanked));

  assign f_o        = f_q;
""", "① blanker 与声明")

    # ② 消费路径改读 blanked 视图
    sub("  assign k_c19      = f_q[W-1 -: 4];", "  assign k_c19      = f_blanked[W-1 -: 4];", "② k_c19")
    # v_* 八条：把 h_q 换成 h_blanked（只在这些行内）
    n_h = t.count("h_q[32*")
    assert n_h > 0, "找不到 h_q 的 v_* 拼法"
    t = t.replace("h_q[32*", "h_blanked[32*")
    n_edit += n_h
    sub("  assign t_l0 = {{(W-AW-128){1'b0}}, acc130_q, ll_q};",
        "  assign t_l0 = {{(W-AW-128){1'b0}}, acc130_blanked, ll_blanked};", "② t_l0")
    sub("    cpa_a   = f_q;\n", "    cpa_a   = f_blanked;\n", "② cpa_a 默认")
    sub("          cpa_a = {{(W-256){1'b0}}, f_q[255:0]};",
        "          cpa_a = {{(W-256){1'b0}}, f_blanked[255:0]};", "② cpa_a@19")
    sub("          cpa_b   = f_q[W-1] ? P260 : ~P260;", "          cpa_b   = f_blanked[W-1] ? P260 : ~P260;", "② cpa_b@20")
    sub("          cpa_sub = ~f_q[W-1];", "          cpa_sub = ~f_blanked[W-1];", "② cpa_sub@20")
    sub("        f_d = (f_q[W-1] || !cpa_ext[W-1]) ? cpa_ext[W-1:0] : f_q;",
        "        f_d = (f_blanked[W-1] || !cpa_ext[W-1]) ? cpa_ext[W-1:0] : f_q;", "② f_d@20（保持分支仍用原值）")
    sub("        wd_d = f_q[255:0];", "        wd_d = f_blanked[255:0];", "② wd_d@21")

    # ③ blanking 不变量（与 OTBN 的 BlankingBignumRegRead_A 同型）
    sub("    // c19（相位）的 k 合法域",
        """    // §10.6：blanking 的两条不变量（未使能必须为 0；使能必须透传）
    if (!(busy_q && (phase >= 5'd10))) begin
    A_f_blanked_idle: assert (f_blanked == '0)
      else $error("A_f_blanked_idle: F 未使能时未被掩到 0");
    end
    if (!(busy_q && (phase >= 5'd10) && (phase <= 5'd17))) begin
    A_h_blanked_idle: assert (h_blanked == '0)
      else $error("A_h_blanked_idle: h 未使能时未被掩到 0");
    end
    if (!(busy_q && (phase == 5'd18))) begin
    A_l0_blanked_idle: assert ({ll_blanked, acc130_blanked} == '0)
      else $error("A_l0_blanked_idle: LL/ACC130 未使能时未被掩到 0");
    end
    if (busy_q && (phase >= 5'd10)) begin
    A_f_blanked_pass: assert (f_blanked == f_q)
      else $error("A_f_blanked_pass: 使能时 F 未透传");
    end
    if (busy_q && (phase >= 5'd10) && (phase <= 5'd17)) begin
    A_h_blanked_pass: assert (h_blanked == h_q)
      else $error("A_h_blanked_pass: 使能时 h 未透传");
    end
    if (busy_q && (phase == 5'd18)) begin
    A_l0_blanked_pass: assert ({ll_blanked, acc130_blanked} == {ll_q, acc130_q})
      else $error("A_l0_blanked_pass: 使能时 LL/ACC130 未透传");
    end

    // c19（相位）的 k 合法域""", "③ blanking 断言")

    if not args.check:
        F.write_bytes(t.replace("\n", nl).encode("utf-8"))
    print("%s：改动 %d 处；CRLF=%d LF=%d %s"
          % (F.name, n_edit, t.replace("\n", nl).encode("utf-8").count(CR.encode() + b"\n"),
             t.replace("\n", nl).encode("utf-8").count(b"\n"),
             "(check only)" if args.check else "(written)"))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    main()
