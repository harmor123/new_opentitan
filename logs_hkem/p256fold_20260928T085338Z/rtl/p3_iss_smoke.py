#!/usr/bin/env python3
"""P3 Step 2 自检：ISS 侧 `bn.p256mul` 的语义（纯 Python；Windows/Linux 同源）。

被测对象 = `hw/ip/otbn/dv/otbnsim/sim/{isa,insn}.py` 里新增的 ISS 实现。
判据（`04_P3_串行控制基线.md` Step 2）：
  ① 同一条指令在 ISS 上的周期数是常数（与操作数、商 k、校正无关，无早退）；
  ② INSN_CNT 只 +1（本脚本用 `ecall` 代替 P3 的 `ret`，所以期望 E=2）。

外加 `contribution 2` §10.1 的契约项：结果 == Python 参考值、单次写回、
别名安全（wa=wb / wd=wa / wd=wb / 三者相同）、不改 flags、其它 WDR/ISPR 不变、
ACC 被破坏后**保留 c15 的累加值**（RTL 实测；原"置零"判据已按实测改，依据见 `04_P3_*.md` §7.3 #9）。

交叉核对（把 ISS 钉在已经实测过的两个东西上）：
  * 汇编自检：用 insns.yml 现编 5 条指令，与 P3-Step1 在 Linux 实测的机器码逐位比较；
  * 微序列：16 拍 tap 与 P2 单元 TB 用过的向量表（RTL 逐拍比对通过）逐拍一致；
  * 常量：k·d LUT 与 `otbn_p256_fold.sv` 里内嵌的 KD_xx 逐位一致。

用法：PYTHONUTF8=1 python3 p3_iss_smoke.py [--random N] [--out FILE]
"""
import argparse
import os
import random
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent          # logs_hkem/<run>/rtl
REPO = HERE.parents[2]
MODEL = HERE.parent / 'model' / 'p256_fold_model.py'
VECTORS = HERE.parent / 'unit' / 'p2_vectors.json'
RTL = REPO / 'hw/ip/otbn/rtl/otbn_p256_fold.sv'

sys.path.insert(0, str(REPO / 'hw/ip/otbn/dv/otbnsim'))
sys.path.insert(0, str(REPO / 'hw/ip/otbn/util'))

from sim.isa import (INSNS_FILE, P256_D, P256_KD, P256_MAC_STEPS, P256_MASKW,  # noqa: E402
                     P256_P, P256_W, p256_acc_c15, p256_mac, p256_mulmodp)
from sim.decode import MNEM_TO_CLASS, decode_words                                           # noqa: E402
from sim.standalonesim import (StandaloneSim, _TEST_RND_DATA,                 # noqa: E402
                               _TEST_URND_SEED)
from sim.state import FsmState                                                # noqa: E402

# P4：调度可选。serial（P3）= 27 stall + 1 退休 = 28 拍；overlap（P4 主方案）= 21 + 1 = 22 拍。
# 开关与 RTL 的 `p256_serial` plusarg 同源（都由 runner 设置），默认 serial ⇒ P3 的金标与判据原样有效。
MODE = 'overlap' if os.environ.get('OTBN_P256_SERIAL', '1') == '0' else 'serial'
EXPECT = (1, 21, 22) if MODE == 'overlap' else (1, 27, 28)

N = 1 << 256
MASK128 = (1 << 128) - 1
MASK130 = (1 << 130) - 1

# P3 的基线提交（fork 顶端；回归比对用它，不用 HEAD）
BASE_COMMIT = '2d87e79bee06b674129f68229a4b5daf15462cc2'

# P3-Step1 在 Linux 上实测的机器码（汇编往返的 5 条），用来给下面的 asm() 做自检。
STEP1_WORDS = [
    ('bn.p256mul', ('w19', 'w24', 'w25'), 0x019c69ab),
    ('bn.add', ('w2', 'w3', 'w4'), 0x0041812b),
    ('bn.and', ('w2', 'w3', 'w4'), 0x0041a17b),
    ('bn.rshi', ('w2', 'w3', 'w4', 5), 0x0441f17b),
    ('bn.mulv', ('.8s', 'w5', 'w6', 'w7'), 0x007332db),
]

lines = []
checks = 0
errors = 0


def emit(text=''):
    lines.append(text)
    print(text)


def check(ok, text):
    global checks, errors
    checks += 1
    if not ok:
        errors += 1
    emit(('  OK   ' if ok else '  FAIL ') + text)
    return ok


def section(title):
    emit()
    emit('== ' + title + ' ==')


# ---------------------------------------------------------------------------
# 现编一条指令（不调用外部汇编器；编码来自 insns.yml，与 otbn_as.py 同源）
# ---------------------------------------------------------------------------
def asm(mnemonic, operands=()):
    insn = INSNS_FILE.mnemonic_to_insn[mnemonic]
    op_to_idx = {}
    for operand, value in zip(insn.operands, operands):
        op_type = operand.op_type
        op_val = op_type.str_to_op_val(value) if isinstance(value, str) else value
        op_to_idx[operand.name] = op_type.op_val_to_enc_val(op_val, None)
    return insn.encoding.assemble(op_to_idx)


# ---------------------------------------------------------------------------
# 跑一个程序：到 `ecall` 退休即停（不进 wipe），以便读架构状态
# ---------------------------------------------------------------------------
def run_program(words, wdrs=None, max_cycles=10000):
    sim = StandaloneSim()
    sim.load_program(decode_words(0, [(True, w) for w in words]))
    sim.state.ext_regs.commit()
    sim.start(collect_stats=True)
    for idx, value in (wdrs or {}).items():
        sim.state.wdrs.get_reg(idx).write_unsigned(value)

    sim.state.complete_init_sec_wipe()
    # 与 StandaloneSim.run() 相同的 standalone 约定（无宿主 ⇒ wfi 立即返回）
    sim.state.wfi_enabled = True
    sim.state.wfi_auto_resume = True

    urnd_seed_count = 0
    cycles = 0
    while sim.state.get_fsm_state() not in (FsmState.IDLE, FsmState.LOCKED,
                                            FsmState.PRE_WIPE, FsmState.WIPING):
        if sim.state.ext_regs.read('RND_REQ', True):
            sim.state.wsrs.RND.set_unsigned(next(_TEST_RND_DATA), False, False)
        if sim.state.wsrs.URND.requesting:
            sim.state.wsrs.URND.set_seed(_TEST_URND_SEED[urnd_seed_count])
            urnd_seed_count = (urnd_seed_count + 1) % len(_TEST_URND_SEED)
            if urnd_seed_count == 0:
                sim.state.wsrs.URND.reseed_done = True
        sim.step(False)
        cycles += 1
        if cycles > max_cycles:
            raise RuntimeError('程序未在 %d 拍内结束' % max_cycles)
    return sim, cycles


def state_view(sim):
    """架构状态快照（用于 A/B 比对）。"""
    return {
        'gprs': list(sim.state.gprs.peek_unsigned_values()),
        'wdrs': list(sim.state.wdrs.peek_unsigned_values()),
        'flags': [sim.state.csrs.flags[i].read_unsigned() for i in range(2)],
        'acc': sim.state.wsrs.ACC.read_unsigned(),
        'mod': sim.state.wsrs.MOD.read_unsigned(),
        'insn_cnt': sim.state.ext_regs.read('INSN_CNT', False),
    }


# ---------------------------------------------------------------------------
# 16 拍 MAC 微步的逐拍重放（与 P2 向量表的 tap 对照）
# ---------------------------------------------------------------------------
def mac_replay(a, b):
    aa = [(a >> (64 * i)) & 0xffffffffffffffff for i in range(4)]
    bb = [(b >> (64 * i)) & 0xffffffffffffffff for i in range(4)]
    acc = 0
    pre_so, acc_after = [], []
    seed = high = ll = 0
    for cycle, (i, j, shift, zero_acc, shift_out) in enumerate(P256_MAC_STEPS):
        acc = (0 if zero_acc else acc) + (aa[i] * bb[j] << shift)
        if cycle == 3:
            seed = (acc & MASK128) << 128
        elif cycle == 9:
            high = acc
        elif cycle == 12:
            ll = acc & MASK128
        pre_so.append(acc)
        if shift_out:
            acc >>= 128
        acc_after.append(acc)
    return pre_so, acc_after, seed, high, ll, acc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--random', type=int, default=200)
    ap.add_argument('--out', type=Path, default=HERE / 'p3_iss_smoke.log')
    args = ap.parse_args()

    emit('P3 Step 2 自检：ISS 侧 bn.p256mul（%s）' % HERE.name)
    emit('ISS 实现: hw/ip/otbn/dv/otbnsim/sim/{isa,insn}.py；'
         'P=%d bit，W=%d bit，微步 %d 拍' % (P256_P.bit_length(), P256_W, len(P256_MAC_STEPS)))

    # --- 0. 汇编自检（与 Linux 实测的机器码逐位比较） -----------------------
    section('0. 汇编自检（insns.yml 现编 == P3-Step1 在 Linux 实测的机器码）')
    for mnemonic, operands, want in STEP1_WORDS:
        got = asm(mnemonic, operands)
        check(got == want, '%-12s %-18s = 0x%08x（期望 0x%08x）'
              % (mnemonic, ', '.join(str(o) for o in operands), got, want))

    # --- 1. k·d LUT 与 RTL 内嵌常量逐位一致 --------------------------------
    section('1. 常量：k·d LUT（ISS）== otbn_p256_fold.sv 的 KD_xx')
    txt = RTL.read_text(encoding='utf-8')
    m_p = re.search(r"P260\s*=\s*W'\(260'h([0-9a-f]+)\)", txt)
    check(m_p is not None and int(m_p.group(1), 16) == P256_P,
          'P260 == 2^256 - 2^224 + 2^192 + 2^96 - 1')
    kd = {}
    for m_ in re.finditer(r"KD_(\d\d)\s*=\s*W'\(260'h([0-9a-f]+)\);\s*//\s*k=\s*(-?\d+)", txt):
        kd[int(m_.group(3)) & 0xf] = int(m_.group(2), 16)
    check(kd == P256_KD, '12 项 KD LUT 逐位一致（键 = F[259:256] 位型）')
    check(len(P256_KD) == 12, 'LUT 项数 = %d' % len(P256_KD))
    check(all(P256_KD[k & 0xf] == (k * P256_D) & P256_MASKW for k in range(-4, 8)),
          '每项 == k*d mod 2^260')

    # --- 2. 微序列 + 值：对 P2 向量表（RTL 逐拍比对通过） ------------------
    section('2. 对照 P2 向量表（RTL 已逐拍比对通过）：16 拍 tap + 采样点 + 结果')
    vectors = [v for v in __import__('json').loads(VECTORS.read_text(encoding='utf-8'))['vectors']
               if v['source'] == 'mac']
    tap_ok = tap_bad = 0
    val_ok = val_bad = 0
    for v in vectors:
        a, b = int(v['a'], 16), int(v['b'], 16)
        pre_so, acc_after, seed, high, ll, acc = mac_replay(a, b)
        want_pre = [int(x, 16) for x in v['mac_taps']['pre_so']]
        want_aft = [int(x, 16) for x in v['mac_taps']['acc_after']]
        same = (pre_so == want_pre and acc_after == want_aft
                and seed == int(v['H'], 16) and high == int(v['high'], 16)
                and ll == int(v['LL'], 16) and (acc & MASK130) == int(v['ACC130'], 16))
        tap_ok += same
        tap_bad += (not same)
        got = p256_mulmodp(a, b)
        good = got == int(v['result'], 16)
        val_ok += good
        val_bad += (not good)
        if not (same and good):
            emit('       [%s] tap=%s value=%s' % (v['name'], same, good))
    check(tap_bad == 0, '16 拍 tap（pre_so+acc_after）逐拍一致：%d/%d 条向量'
          % (tap_ok, len(vectors)))
    check(val_bad == 0, '结果 == RTL 实测的 result 字段：%d/%d 条向量' % (val_ok, len(vectors)))
    check(p256_mac(*[int(vectors[0]['a'], 16), int(vectors[0]['b'], 16)])
          == (int(vectors[0]['high'], 16), int(vectors[0]['H'], 16),
              (int(vectors[0]['ACC130'], 16) << 128) | int(vectors[0]['LL'], 16)),
          'p256_mac() 与逐拍重放同源（high/seed/low 三项相等）')

    # --- 3. 值域：随机 + 定向输入 == (a*b) mod p ---------------------------
    section('3. 值域：p256_mulmodp(a, b) == (a*b) mod p（p 域内输入）')
    rng = random.Random(20260928)
    directed = [0, 1, 2, P256_P - 1, P256_P - 2, P256_P // 2, (1 << 128), (1 << 192),
                (1 << 255), (1 << 256) - 1, ((1 << 256) - 1) // P256_P * P256_P % P256_P]
    bad = 0
    tested = 0
    for a in directed:
        for b in directed:
            tested += 1
            try:
                bad += (p256_mulmodp(a, b) != (a * b) % P256_P)
            except AssertionError:
                bad += 1
    for _ in range(args.random):
        a = rng.randrange(P256_P)
        b = rng.randrange(P256_P)
        tested += 1
        bad += (p256_mulmodp(a, b) != (a * b) % P256_P)
    check(bad == 0, '定向 %d 组 + 随机 %d 组：%d 组不符' % (len(directed) ** 2, args.random, bad))
    p1 = P256_P - 1
    check(p256_mulmodp(p1, p1) == 1, '(p-1)^2 mod p == 1')
    check(p256_mulmodp(P256_P - 1, P256_P - 1) == 1, '(p-1)*(p-1) 同上（显式常量）')

    # --- 4. ISS 运行判据：单次退休 + 周期常数 + 写回值 ---------------------
    section('4. ISS 运行：单次退休、本指令的周期贡献（常数）、写回值、ACC')
    base_runs = []
    for _ in range(3):
        sim_b, cycles_b = run_program([asm('ecall')])
        base_runs.append((cycles_b, sim_b.stats.get_insn_count(), sim_b.stats.stall_count))
    check(len(set(base_runs)) == 1, '基线（仅 ecall）三次运行逐项相同：'
          'cycles=%d insn=%d stall=%d' % base_runs[0])
    base_cycles, base_insn, base_stall = base_runs[0]

    prog_words = [asm('bn.p256mul', ('w19', 'w24', 'w25')), asm('ecall')]
    cases = [(0, 0), (1, 1), (3, 5), (P256_P - 1, P256_P - 1), (P256_P - 2, 12345),
             (rng.randrange(P256_P), rng.randrange(P256_P)),
             (rng.randrange(P256_P), rng.randrange(P256_P))]
    deltas = set()
    for a, b in cases:
        sim, cycles = run_program(prog_words, {24: a, 25: b})
        view = state_view(sim)
        want = (a * b) % P256_P
        delta = (sim.stats.get_insn_count() - base_insn,
                 sim.stats.stall_count - base_stall,
                 cycles - base_cycles)
        deltas.add(delta)
        check(delta == EXPECT, '本指令贡献 ΔE=+%d ΔS=+%d Δcycles=+%d'
              '（期望 +1 / +%d / +%d；输入 %d×%d bit）'
              % (delta[0], delta[1], delta[2], EXPECT[1], EXPECT[2],
                 a.bit_length(), b.bit_length()))
        check(view['insn_cnt'] == 2, 'INSN_CNT == 2（新指令 + ecall，硬件寄存器口径）')
        check(view['wdrs'][19] == want, 'wd = (a*b) mod p')
        check(view['acc'] == p256_acc_c15(a, b), 'ACC = c15 累加器值（不是 0）')
    check(deltas == {EXPECT}, '周期贡献是常数（%d 组输入同值）：%s'
          % (len(cases), sorted(deltas)))

    # ACC 末值的第二来源：`hw/ip/otbn/dv/smoke/p256/` 的 co-sim 中，RTL 对该指令写了 16 次 ACC，
    # 末次 = 0x53e1c506_e60b078f_800c9476_43557020（官方向量 d0×x）⇒ 用这个实测常量钉住，
    # 避免上面的关系式退化成"ISS 自己与自己一致"。
    d0_vec = 0x1420fc41742102631b76ebe83fdfa3799590ef5db0b2c78121d0a016fe6d1071
    x_vec = 0xb5511a6afacdc5461628ce58db6c8bf36ec0c0b2f36b06899773b7b3bfa8c334
    sim_vec, _ = run_program(prog_words, {24: d0_vec, 25: x_vec})
    check(state_view(sim_vec)['acc'] == 0x53e1c506e60b078f800c947643557020,
          'ACC 末值 == RTL co-sim 实测常量 0x…43557020（第二来源）')

    # --- 5. 别名安全 ------------------------------------------------------
    section('5. 别名：wa=wb / wd=wa / wd=wb / 三者相同')
    a, b = 0x1234567890abcdef, (P256_P - 7)
    want = (a * b) % P256_P
    alias_cases = [
        ('wd=wa  ', [asm('bn.p256mul', ('w24', 'w24', 'w25')), asm('ecall')], 24, want, 25, b),
        ('wd=wb  ', [asm('bn.p256mul', ('w25', 'w24', 'w25')), asm('ecall')], 25, want, 24, a),
        ('三相同 ', [asm('bn.p256mul', ('w24', 'w24', 'w24')), asm('ecall')], 24, (a * a) % P256_P, 24, None),
        ('wa=wb  ', [asm('bn.p256mul', ('w19', 'w24', 'w24')), asm('ecall')], 19, (a * a) % P256_P, 24, a),
    ]
    for name, words, rd, want_d, rkeep, keep in alias_cases:
        sim, cycles = run_program(words, {24: a, 25: b})
        view = state_view(sim)
        ok = view['wdrs'][rd] == want_d
        if rkeep is not None and keep is not None:
            ok = ok and view['wdrs'][rkeep] == keep
        check(ok, '%s：w%d == 期望值%s' % (name, rd,
              '' if rkeep is None else '，且 w%d 保持源值' % rkeep))
        check(cycles - base_cycles == EXPECT[2], '%s：Δcycles = %d（期望 %d，模式 %s）'
              % (name, cycles - base_cycles, EXPECT[2], MODE))

    # --- 6. 无副作用（A/B：除 wd 与 ACC 外全部架构状态相同） ---------------
    section('6. 无副作用：与「不含新指令」的对照程序逐位比较架构状态')
    seed_word = asm('bn.addi', ('w17', 'w0', 0x123))
    ref_words = [seed_word, asm('ecall')]
    new_words = [seed_word, asm('bn.p256mul', ('w19', 'w24', 'w25')), asm('ecall')]
    ref, _ = run_program(ref_words, {24: a, 25: b})
    new, _ = run_program(new_words, {24: a, 25: b})
    rv, nv = state_view(ref), state_view(new)
    check(rv['flags'] == nv['flags'], 'FG0/FG1 逐位不变（对照程序先被 bn.addi 置过）')
    check(rv['gprs'] == nv['gprs'], '全部 GPR 不变')
    check(rv['mod'] == nv['mod'], 'MOD（模数 WSR）不变')
    diff = [i for i in range(32) if i != 19 and rv['wdrs'][i] != nv['wdrs'][i]]
    check(not diff, '除 w19 外 31 个 WDR 全部不变（差异寄存器: %s）' % (diff or '无'))
    check(nv['wdrs'][19] == (a * b) % P256_P, 'w19 == (a*b) mod p')
    check(nv['insn_cnt'] - rv['insn_cnt'] == 1, 'INSN_CNT 只 +1（%d → %d，'
          '对照程序 = bn.addi + ecall）' % (rv['insn_cnt'], nv['insn_cnt']))

    # --- 7. 契约外输入（a 或 b ≥ p）的实测行为 ----------------------------
    section('7. 契约外输入（≥ p）的实测：与 RTL 同一套不变式检查')
    out_of_contract = 0
    for _ in range(200):
        a2 = rng.randrange(P256_P, N)
        b2 = rng.randrange(0, N)
        try:
            p256_mulmodp(a2, b2)
        except AssertionError:
            out_of_contract += 1
    emit('  实测：200 组随机 256-bit 输入中，%d 组触发不变式（%s）'
         % (out_of_contract, '与 RTL 命名断言同口径' if out_of_contract else '全部通过'))

    # --- 8. 解码表回归：与基线（HEAD 版 insn.py）逐项比较 ------------------
    section('8. 解码表回归：MNEM_TO_CLASS 的旧项与基线逐项相同，只多一条新指令')
    from sim.decode import MNEM_TO_CLASS
    from sim.insn import (BNMULV, BNMULVML, BNMULVM, BNP256MUL,  # noqa: F401
                          INSN_CLASSES)

    import subprocess
    rel = 'hw/ip/otbn/dv/otbnsim/sim/insn.py'
    # 基线提交写死（= P3 的基线上游 fork 顶端），不用 HEAD：否则本提交之后重跑会
    # 把新指令也算进「基线」，判据失效。
    base_src = subprocess.run(['git', 'show', BASE_COMMIT + ':' + rel], cwd=str(REPO),
                              capture_output=True, text=True, check=True).stdout
    base_classes = re.search(r'^INSN_CLASSES = \[(.*?)^\]', base_src,
                             re.S | re.M).group(1)
    base_names = re.findall(r'\b([A-Z][A-Z0-9_]*)', base_classes)
    base_map = {}
    for name in base_names:
        m_ = re.search(r'^class %s\(.*?\):\n(.*?)^\S' % name, base_src, re.S | re.M)
        mnem = re.search(r"insn_for_mnemonic\('([^']+)'", m_.group(1))
        base_map[name] = mnem.group(1) if mnem else None
    live_map = {cls.__name__: cls.insn.mnemonic for cls in INSN_CLASSES}
    check(len(base_names) == len(set(base_names)), '基线类名无重复（%d 项）' % len(base_names))
    changed = [n for n in base_names if live_map.get(n) != base_map[n]]
    check(not changed, '基线 %d 个指令类：助记符映射逐项未变（差异: %s）'
          % (len(base_names), changed or '无'))
    added = [n for n in live_map if n not in base_map]
    check(added == ['BNP256MUL'], '只新增 1 个类：%s' % added)
    mnems = list(live_map.values())
    check(len(mnems) == len(set(mnems)), '助记符无重复（%d 项，不会互相遮蔽）' % len(mnems))
    check(MNEM_TO_CLASS['bn.p256mul'] is BNP256MUL, "MNEM_TO_CLASS['bn.p256mul'] → BNP256MUL")
    check(MNEM_TO_CLASS['bn.mulv'] is BNMULV and MNEM_TO_CLASS['bn.mulvm'] is BNMULVM
          and MNEM_TO_CLASS['bn.mulvml'] is BNMULVML,
          'bn.mulv / bn.mulvm / bn.mulvml 仍指向原类（§10.1 点名项）')

    # --- 汇总 -------------------------------------------------------------
    emit()
    emit('PASS - %d errors / %d checks' % (errors, checks))
    args.out.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print('日志写入 %s' % args.out)
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
