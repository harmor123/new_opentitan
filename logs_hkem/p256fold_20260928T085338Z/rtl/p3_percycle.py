#!/usr/bin/env python3
"""P3 增量⑤：逐拍 CSV（单元级双调度 + co-sim 级 ACC），并逐条自证。

输入（sha256 全部写进产物头，便于复核）：
  * run_dir/rtl/p3_unit.log        —— P3 双调度单元 TB 的逐拍行：`CYC <vec>#<mode> <cycle> | tb=… | model=… | OK`
  * run_dir/model/p256_fold_model.py —— 位精确模型
  * dv/smoke/p256/p256_fold_test.expected.txt —— co-sim 金标（最终寄存值）
  * [可选] --cosim-trace FILE      —— `Votbn_top_sim --otbn-trace-file=…` 的逐拍 RTL 轨迹

判据（全 ✓ 才 PASS）：
  ① 单元日志每一行 tb == model（0 处不等）
  ② serial 的 c10…c15 必须 hold：F 等于 c3 的 seed —— 这是 P3 相对 P2 的**唯一**调度差异
  ③ 完成拍固定：serial = 27、overlap = 21（无早退）
  ④ 给了 --cosim-trace 时：RTL 逐次 ACC 写 == 模型 `mac()` 的 `acc_after`（按序、逐拍）

用法：
  PYTHONUTF8=1 python3 p3_percycle.py \
      [--unit-log …] [--golden …] [--model …] [--cosim-trace …] [--out-dir …]
"""
import argparse
import hashlib
import importlib.util
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
RUN_DIR = Path(__file__).resolve().parent.parent
CYC_RE = re.compile(r'^CYC (\S+)#(overlap|serial) (\d+) \| tb=(0x[0-9a-fA-F]+) '
                    r'\| model=(0x[0-9a-fA-F]+) \| (OK|\S.*)$')
D0 = 0x1420fc41742102631b76ebe83fdfa3799590ef5db0b2c78121d0a016fe6d1071
X = 0xb5511a6afacdc5461628ce58db6c8bf36ec0c0b2f36b06899773b7b3bfa8c334
WB_CYCLE = {'serial': 27, 'overlap': 21}
HOLD = range(10, 16)          # serial 的 hold 段（相位 4…9 + 6）
SEED_CYCLE = 3

fails = []
checks = 0


def check(ok, msg):
    global checks
    checks += 1
    print(('  OK   ' if ok else '  FAIL ') + msg)
    if not ok:
        fails.append(msg)


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes().replace(b'\r\n', b'\n')).hexdigest()


def load_model(path):
    spec = importlib.util.spec_from_file_location('p256foldmodel', path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def parse_unit_log(path):
    rows = []
    for line in Path(path).read_text(encoding='utf-8').splitlines():
        m = CYC_RE.match(line.strip())
        if m:
            vec, mode, cyc, tb, mod, verdict = m.groups()
            rows.append({'vector': vec, 'mode': mode, 'cycle': int(cyc),
                         'tb': int(tb, 16), 'model': int(mod, 16), 'ok': verdict == 'OK'})
    return rows


def parse_cosim_trace(path):
    """从 `--otbn-trace-file` 产物里取 ACC 写与它们的拍号。

    每行形如 `<cycle> > ACC: 0x…`（见 dv/tracer 的 listener）；行内按需取第一个 ACC 量。
    """
    acc = []
    for line in Path(path).read_text(encoding='utf-8', errors='replace').splitlines():
        m = re.search(r'^(\d+)\s+.*>\s*ACC:\s*(0x[0-9a-fA-F_]+)', line)
        if m:
            acc.append((int(m.group(1)), int(m.group(2).replace('_', ''), 16)))
    return acc


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--unit-log', type=Path, default=RUN_DIR / 'rtl' / 'p3_unit.log')
    ap.add_argument('--golden', type=Path,
                    default=REPO / 'hw/ip/otbn/dv/smoke/p256/p256_fold_test.expected.txt')
    ap.add_argument('--model', type=Path, default=RUN_DIR / 'model' / 'p256_fold_model.py')
    ap.add_argument('--cosim-trace', type=Path)
    ap.add_argument('--out-dir', type=Path, default=RUN_DIR / 'rtl')
    args = ap.parse_args()

    print('== 1. 单元级逐拍（p3_unit.log）==')
    rows = parse_unit_log(args.unit_log)
    check(bool(rows), '日志解析到逐拍行：%d 行' % len(rows))
    bad = [r for r in rows if not r['ok'] or r['tb'] != r['model']]
    check(not bad, 'tb == model（%d 行）' % len(rows) if not bad else '出现 %d 处不等' % len(bad))

    by = {}
    for r in rows:
        by.setdefault((r['vector'], r['mode']), []).append(r)
    serial_keys = sorted(k for k in by if k[1] == 'serial')
    check(len(serial_keys) == 21, 'serial 覆盖全部 21 条向量：%d' % len(serial_keys))

    hold_bad, comp_bad = [], []
    for (vec, mode), rs in by.items():
        rs.sort(key=lambda r: r['cycle'])
        comp = rs[-1]['cycle']
        if comp != WB_CYCLE[mode]:
            comp_bad.append((vec, mode, comp))
        if mode == 'serial':
            seed = next((r['tb'] for r in rs if r['cycle'] == SEED_CYCLE), None)
            for r in rs:
                if r['cycle'] in HOLD and seed is not None and r['tb'] != seed:
                    hold_bad.append((vec, r['cycle']))
    check(not comp_bad, '完成拍固定（serial 27 / overlap 21）：%d 处不符' % len(comp_bad))
    check(not hold_bad, 'serial 的 c10…c15 hold（F == c3 的 seed）：%d 处不符' % len(hold_bad))

    print('== 2. 模型自洽（ACC 序列与 fold 轨迹）==')
    m = load_model(args.model)
    high, seed, low, events = m.mac(D0, X, trace=True)
    check(len(events) == 16, '模型 mac() 步数 = %d' % len(events))
    acc_seq = [int(e['acc_after'], 16) for e in events]

    print('== 3. co-sim 级逐拍 ACC ==')
    if args.cosim_trace:
        cosim = parse_cosim_trace(args.cosim_trace)
        check(bool(cosim), '轨迹解析到 ACC 写：%d 次' % len(cosim))
        if cosim:
            got = [v for _c, v in cosim]
            n = min(len(got), len(acc_seq))
            check(n == 16, 'RTL 的 ACC 写次数 = %d（期望 16）' % len(got))
            for k in range(n):
                check(got[k] == acc_seq[k],
                      'ACC[%02d] @cycle %s == 模型第 %d 步 %s' %
                      (k, cosim[k][0], k, hex(acc_seq[k])))
    else:
        print('  （未给 --cosim-trace：本次只出单元级逐拍；给了再补 co-sim 段）')

    print('== 4. 产出 ==')
    args.out_dir.mkdir(parents=True, exist_ok=True)
    csv_path = args.out_dir / 'p3_percycle.csv'
    with csv_path.open('w', encoding='utf-8', newline='\n') as f:
        f.write('vector,mode,cycle,tb_F,model_F,equal\n')
        for r in sorted(rows, key=lambda r: (r['vector'], r['mode'], r['cycle'])):
            f.write('%s,%s,%d,0x%x,0x%x,%s\n' % (r['vector'], r['mode'], r['cycle'],
                                                 r['tb'], r['model'],
                                                 'yes' if r['ok'] and r['tb'] == r['model'] else 'NO'))
    check(csv_path.stat().st_size > 0, '写出 %s（%d 行）' % (csv_path.name, len(rows) + 1))

    md = args.out_dir / 'p3_percycle.md'
    verdict = 'PASS' if not fails else 'FAIL'
    with md.open('w', encoding='utf-8', newline='\n') as f:
        f.write('# P3 增量⑤：逐拍记录（单元级 + co-sim 级）\n\n')
        f.write('- 结论：**%s - %d errors / %d checks**\n' % (verdict, len(fails), checks))
        f.write('- 单元日志：`%s`（sha256(LF) `%s`，逐拍 %d 行）\n'
                % (args.unit_log.name, sha256(args.unit_log), len(rows)))
        f.write('- 模型：`%s`（sha256(LF) `%s`）\n' % (args.model.name, sha256(args.model)))
        f.write('- co-sim 金标：`%s`（sha256(LF) `%s`）\n'
                % (args.golden.name, sha256(args.golden)))
        if args.cosim_trace:
            f.write('- co-sim 轨迹：`%s`（sha256(LF) `%s`）\n'
                    % (args.cosim_trace.name, sha256(args.cosim_trace)))
        f.write('\n## 对齐约定（本文档的坐标定义）\n\n')
        f.write('| 量 | 坐标 | 说明 |\n|---|---|---|\n')
        f.write('| 单元 TB `CYC … <cycle>` | **模块自己的拍号** | 与 MAC FSM 的 `current_cycle` 同拍同号'
                '（启动脉冲在取指拍给出，比执行早一拍） |\n')
        f.write('| 模型 `light()` 的 phase | 同表 cycle | serial 模式 = 拍号 − 6（`TailShift`）；'
                'overlap 模式 = 拍号 |\n')
        f.write('| co-sim 轨迹 `<cycle>` | **指令内拍号**（c0 = 0） | `--otbn-trace-file` 的第十进制首字段 |\n')
        f.write('\n## 单元级：serial 逐拍要点\n\n')
        f.write('| 项 | 判据 | 实测 |\n|---|---|---|\n')
        f.write('| 逐拍相等 | 每行 tb == model | %d 行全等 ✓ |\n' % (len(rows) - len(bad)))
        f.write('| c10…c15 hold | F == c3 的 seed | %d 处不符 |\n' % len(hold_bad))
        f.write('| 完成拍 | serial 27 / overlap 21 | %d 处不符 |\n' % len(comp_bad))
        f.write('| 向量覆盖 | 21 条 × 2 模式 | %d 组 |\n' % len(by))
        f.write('\n逐拍全量在 `p3_percycle.csv`（%d 行 + 表头）。\n' % len(rows))
        if args.cosim_trace:
            f.write('\n## co-sim 级：RTL 逐次 ACC 写 vs 模型 `mac()`\n\n')
            f.write('| # | cycle | RTL ACC | 模型 acc_after | equal |\n|---|---|---|---|---|\n')
            cosim = parse_cosim_trace(args.cosim_trace)
            for k, (c, v) in enumerate(cosim[:16]):
                want = acc_seq[k] if k < len(acc_seq) else -1
                f.write('| %d | %d | 0x%064x | 0x%064x | %s |\n'
                        % (k, c, v, want, 'yes' if v == want else 'NO'))
    check(md.stat().st_size > 0, '写出 %s' % md.name)

    print('\n%s - %d errors / %d checks' % (verdict, len(fails), checks))
    return 0 if not fails else 1


if __name__ == '__main__':
    raise SystemExit(main())
