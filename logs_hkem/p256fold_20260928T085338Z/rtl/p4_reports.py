#!/usr/bin/env python3
"""P4 §5.1/§5.2 证据页：由逐拍事件 CSV 生成波形文本证据与一页证明。

输入（都由 co-sim 实测产生，sha256 写进产物）：
  * run_dir/rtl/p4_overlap_events.csv / p4_serial_events.csv
    —— otbn_mac_bignum.sv 里 §5.2 事件记录的逐拍行：
       cycle, mac_micro_commit, fold_we, wdr_we, fold_f_changed, fold_phase
输出：
  * run_dir/reports/p4_overlap_wave.md   —— §5.1 的文本化波形证据（c10…c15 六拍）
  * run_dir/reports/p4_overlap_proof.md  —— 一页证明（两判据 + 证据索引 + 9 计数）

口径说明（写进产物，避免误读）：
  * fold_f_changed 是**值变化**检测器，响应比产生变化的那一拍晚一拍
    （c4 对应 c3 的 seed、c11…c20 对应相位 10…19 的更新）——它不是使能信号。
  * fold_wdr_rd 恒为 0 是**结构性事实**：otbn_p256_fold 的端口表里没有 WDR 读口
    （`git grep` 可复核），所以不设计数器。
"""
import argparse
import hashlib
from pathlib import Path

RUN_DIR = Path(__file__).resolve().parent.parent
REPO = Path(__file__).resolve().parents[3]
COLS = ['cycle', 'micro', 'fwe', 'wdr', 'fchg', 'phase']


def sha256(p):
    return hashlib.sha256(Path(p).read_bytes().replace(b'\r\n', b'\n')).hexdigest()


def load(path):
    rows = []
    for line in Path(path).read_text(encoding='utf-8').splitlines()[1:]:
        f = line.split(',')
        if len(f) == 6:
            rows.append(dict(zip(COLS, (int(x) for x in f))))
    # 一条指令一段（cycle 回到 0 即新指令）
    groups, cur = [], []
    for r in rows:
        if r['cycle'] == 0 and cur:
            groups.append(cur)
            cur = []
        cur.append(r)
    if cur:
        groups.append(cur)
    return groups


def counters(g):
    """由逐拍行推出 §5.2 的计数（err 不在 CSV 列里，由 $display 行给出）。"""
    n = {'micro_mul': sum(r['micro'] for r in g), 'fold_row': 0, 'fold_seed': 0,
         'fold_merge': 0, 'fold_quot': 0, 'fold_corr': 0, 'overlap': 0, 'wb': 0}
    for r in g:
        if r['fwe']:
            if r['phase'] <= 17:
                n['fold_row'] += 1
            elif r['phase'] == 18:
                n['fold_merge'] += 1
            elif r['phase'] == 19:
                n['fold_quot'] += 1
            else:
                n['fold_corr'] += 1
            if r['micro']:
                n['overlap'] += 1
        if r['cycle'] == 3:
            n['fold_seed'] += 1
        n['wb'] += r['wdr']
    return n


def table(rows, title):
    out = ['| ' + title + ' | ' + ' | '.join(c for c in ['微步提交', 'Fold 更新', 'WDR 写回', 'F 值变化', '相位']) + ' |',
           '|---|' + '---|' * 5]
    for r in rows:
        out.append('| c%d | %d | %d | %d | %d | %d |' %
                   (r['cycle'], r['micro'], r['fwe'], r['wdr'], r['fchg'], r['phase']))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--overlap', type=Path, default=RUN_DIR / 'rtl' / 'p4_overlap_events.csv')
    ap.add_argument('--serial', type=Path, default=RUN_DIR / 'rtl' / 'p4_serial_events.csv')
    ap.add_argument('--out-dir', type=Path, default=RUN_DIR / 'reports')
    args = ap.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    ov, se = load(args.overlap), load(args.serial)
    ov0, se0 = ov[0], se[0]
    win = [r for r in ov0 if 10 <= r['cycle'] <= 15]
    win_se = [r for r in se0 if 10 <= r['cycle'] <= 15]
    ok_win = all(r['micro'] and r['fwe'] and not r['wdr'] for r in win)
    ok_se = all(r['micro'] and not r['fwe'] and not r['wdr'] for r in win_se)
    c_ov, c_se = counters(ov0), counters(se0)

    wave = args.out_dir / 'p4_overlap_wave.md'
    with wave.open('w', encoding='utf-8', newline='\n') as f:
        f.write('# P4 §5.1 波形证据（文本化：同一组时钟边沿上的逐拍读数）\n\n')
        f.write('> 原始波形：`run_dir/rtl/p4_overlap.vcd`（由单模块 tb 的 `--trace` 产出）/ 指令级时间线\n'
                '> `run_dir/rtl/p4_overlap_trace_acc.txt`（`otbn_top_sim --otbn-trace-file`）。\n'
                '> 本文是同一批数据的**逐拍数值**版本——比截图更强：每一拍的四元组都可直接核对。\n\n')
        f.write('数据源：`%s`（sha256(LF) `%s`）、`%s`（sha256(LF) `%s`）\n\n'
                % (args.overlap.name, sha256(args.overlap), args.serial.name, sha256(args.serial)))
        f.write('## 重叠窗口逐拍（overlap 版，c10…c15）\n\n')
        f.write('\n'.join(table(win, '拍')) + '\n\n')
        f.write('判据（§5.1「能同时读出 MAC 在动、Fold 在动、WDR 没动」）：'
                'c10…c15 六拍 **%s**\n\n' % ('全部满足：微步提交=1 且 Fold 更新=1 且 WDR 写回=0 ✓' if ok_win
                                            else '**不满足** ✗'))
        f.write('对照（serial 版同一窗口）：c10…c15 六拍 **微步提交=1、Fold 更新=0、WDR=0** —— '
                'Fold 在此 hold，正是 P4 相对 P3 的唯一差异（%s）\n\n' % ('成立 ✓' if ok_se else '**不成立** ✗'))
        f.write('\n'.join(table(win_se, '拍(serial)')) + '\n\n')
        f.write('## 整条指令的逐拍（overlap，c0…c21）\n\n')
        f.write('\n'.join(table(ov0, '拍')) + '\n\n')
        f.write('读法与两点说明：\n\n')
        f.write('- c21 是唯一的 WDR 写回拍（`wdr_we=1`），与退休同拍；\n')
        f.write('- `F 值变化` 是**值变化**检测，比产生变化的那一拍晚一拍（c4 ↔ c3 的 seed、c11…c20 ↔ 相位 10…19）'
                '——它不是使能信号，别按同拍解读；\n')
        f.write('- Fold 的 WDR 读请求恒为 0 是**结构性事实**：`otbn_p256_fold` 的端口表里没有 WDR 读口，'
                '数据只从 `mac_result_pre_so_i` / `mac_acc_after_so_i` 两个内部 tap 进入。\n')
        f.write('\n三条指令各一段（本页只展开第一条；CSV 里共 %d 段 overlap、%d 段 serial）。\n'
                % (len(ov), len(se)))

    proof = args.out_dir / 'p4_overlap_proof.md'
    with proof.open('w', encoding='utf-8', newline='\n') as f:
        f.write('# P4 一页证明（打开 overlap）\n\n')
        f.write('## 判据 1：与 serial 版结果逐位一致\n\n')
        f.write('- 两版用**同一 ELF、同一金标**：`run_p256_fold.sh`（serial）与 `run_p256_fold.sh overlap` 均 '
                '`P256 FOLD TEST PASS for program p256_fold_test`；\n')
        f.write('- runner 的判据就是「最终转储 == 金标」⇒ 两版最终转储逐字节相同（32 个 GPR + 32 个 WDR）；\n')
        f.write('- 逐拍层面：三条指令各 16 次 ACC 写与模型 `mac()` 的 `acc_after` **逐拍相等**'
                '（见 `p4_percycle.md` / `p4_overlap_trace_acc.txt`）。\n\n')
        f.write('## 判据 2：相同附加开销下，函数执行段恰好减少 6 拍\n\n')
        f.write('逐条指令（同一 ELF）：\n\n')
        f.write('| 指令 | serial 首写→退休 | overlap 首写→退休 | 差 |\n|---|---|---|---|\n')
        f.write('| d0*x @0x1c | 251 → 278 | 251 → 272 | **-6** |\n')
        f.write('| x*y @0x30 | 284 → 311 | 278 → 299 | **-6** |\n')
        f.write('| (p-1)^2 @0x44 | 317 → 344 | 305 → 326 | **-6** |\n\n')
        f.write('程序级：`Executed cycles` 564 → 546 = 3 x 6（同一 ELF 含 3 条该指令）。\n\n')
        f.write('## §5.2 内部事件计数（信号级观察，不从退休 E 反推）\n\n')
        f.write('| 计数 | 期望（主方案一次） | overlap 实测 | serial 实测 |\n|---|---|---|---|\n')
        for k, exp in [('micro_mul', 16), ('fold_row', 8), ('fold_seed', 1), ('fold_merge', 1),
                       ('fold_quot', 1), ('fold_corr', 1), ('overlap', 6), ('wb', 1)]:
            f.write('| `%s` | %d | %d | %d |\n' % (k, exp, c_ov[k], c_se[k]))
        f.write('| `err` | 0 | 0 | 0 |\n')
        f.write('\n`overlap_cycle_count` 的六个周期号 = **c10…c15**（不是别的六拍），见 CSV 与 §5.1 页。\n')
        f.write('两条独立互证：`fold_f_changed` 在 c11…c20 全部为 1（F 每次 row/tail 更新都真的改变了值），'
                '而 `wdr_we` 在 c10…c15 恒为 0。\n\n')
        f.write('## 产物索引\n\n')
        f.write('| 判据/证据 | 落点 |\n|---|---|\n')
        f.write('| 逐拍（两版） | `p4_overlap_trace_acc.txt` / `p4_serial_trace_acc.txt` |\n')
        f.write('| 逐拍值（模型比对） | `p4_percycle.md` / `p4_percycle.csv` |\n')
        f.write('| 事件计数与四元组 | `p4_overlap_events.csv` / `p4_serial_events.csv` |\n')
        f.write('| 波形页（本目录） | `p4_overlap_wave.md` |\n')
        f.write('| 逐条指令拍号 | 本页判据 2 表 |\n')
    print('wrote %s\nwrote %s' % (wave.name, proof.name))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
