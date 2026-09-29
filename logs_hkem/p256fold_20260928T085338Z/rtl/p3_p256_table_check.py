#!/usr/bin/env python3
"""P3 静态检查：FSM 里的 P-256 16 步微码表 vs 模型 MAC_STEPS（逐项，不靠手抄）。

`otbn_mac_bignum_fsm.sv` 的 `P256Steps` 是**微码**（contribution 2.pdf §10.4：「逐拍表就是这个
ROM/case 表的规范」）。本脚本从 .sv 文本里把 16 个 8-bit 项解析回来，按
`{a_qw[1:0], b_qw[1:0], shift_imm[1:0], zero_acc, so128}` 解码，与模型
`run_dir/model/p256_fold_model.py` 的 `MAC_STEPS`（(i, j, shift_bits, zero, shift_out)）逐项比对。

另做三条结构检查：项数 16、写回拍（c27）拉 operation_valid_raw、P-256 表长度 28。

用法：PYTHONUTF8=1 python3 p3_p256_table_check.py
"""
import importlib.util
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
RTL = REPO / "hw/ip/otbn/rtl"

errors = 0


def check(ok, msg):
    global errors
    print(('  OK   ' if ok else '  FAIL ') + msg)
    if not ok:
        errors += 1


def strip_comments(t):
    t = re.sub(r'/\*.*?\*/', '', t, flags=re.S)
    return re.sub(r'//[^\n]*', '', t)


def main():
    fsm = strip_comments((RTL / 'otbn_mac_bignum_fsm.sv').read_text(encoding='utf-8'))
    m = re.search(r"P256Steps\[P256NumSteps\]\s*=\s*'\{([^}]*)\}", fsm, re.S)
    if m is None:
        print('FAIL: 找不到 P256Steps 表')
        return 1
    items = re.findall(r"8'b([01_]{8,})", m.group(1))
    check(len(items) == 16, 'P256Steps 项数 = %d（应为 16）' % len(items))
    if len(items) != 16:
        return 1

    got = []
    for it in items:
        b = it.replace('_', '')
        a = int(b[0:2], 2)
        bb = int(b[2:4], 2)
        sh = int(b[4:6], 2)
        zero = int(b[6])
        so = int(b[7])
        got.append((a, bb, sh * 64, bool(zero), bool(so)))

    spec = importlib.util.spec_from_file_location(
        'm', HERE.parent / 'model' / 'p256_fold_model.py')
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    want = [(i, j, sh, bool(z), bool(so)) for (i, j, sh, z, so) in mod.MAC_STEPS]

    bad = [(c, g, w) for c, (g, w) in enumerate(zip(got, want)) if g != w]
    check(not bad, '16 步逐项 == 模型 MAC_STEPS' + ('' if not bad else '  差异: %s' % bad))

    # 结构检查
    check(bool(re.search(r"predec_p256\[LatencyP256 - 1\]\.operation_valid_raw\s*=\s*1'b1",
                         fsm)), 'c27（LatencyP256-1）拉 operation_valid_raw')
    check(bool(re.search(r'LatencyP256\s*=\s*28', fsm)), 'LatencyP256 = 28（serial，P3）')
    # P4：overlap 表（22 拍，写回/退休 c21）与 serial 表并存，两表在 MAC 干活的 c0…c15 逐项相同。
    check(bool(re.search(r'LatencyP256Ov\s*=\s*22', fsm)), 'LatencyP256Ov = 22（overlap，P4）')
    check(bool(re.search(r"predec_p256_ov\[LatencyP256Ov - 1\]\.operation_valid_raw\s*=\s*1'b1",
                         fsm)), 'c21（LatencyP256Ov-1）拉 operation_valid_raw')
    check(bool(re.search(r"contrl_p256_ov\[cycle\]\s*=\s*contrl_p256\[cycle\]\s*;", fsm)),
          'overlap 表在 MAC 干活的拍上是 serial 表的逐项拷贝（单变量：不靠人抄两遍）')
    check(bool(re.search(r"predec_p256_ov\[cycle\]\s*=\s*predec_p256\[cycle\]\s*;", fsm)),
          '同上（predec 侧）')
    check(bool(re.search(r"contrl_multi\[4\]\[LatencyMax\]", fsm)),
          'contrl_multi 第一维 = 4（vec/mod/p256-overlap/p256-serial）')
    check(bool(re.search(r"p256_serial_i \? 2'd3 : 2'd2", fsm)),
          'mac_mode 四路（row2 = overlap、row3 = serial）')
    check(bool(re.search(r"p256_serial_i \? CycleCountWidth'\(LatencyP256\)", fsm)),
          'current_cycle_oob 按模式判界（含两版 P-256）')

    print('PASS - 0 errors' if not errors else 'SEE FAIL LINES')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
