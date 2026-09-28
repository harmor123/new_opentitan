#!/usr/bin/env python3
"""P3 结构体一致性静态检查（纯 py，Windows/Linux 同源）。

**为什么需要它**：SV 的 `'{...}` 赋值模式对 packed struct 要求 **key 必须是该结构体的成员**
（多一个 key ⇒ Verilator 直接 `%Error: Assignment pattern key ... not found as member`），
而"少填字段"往往只是静默补默认值。P3 增量②a 就栽在这里：三个逐拍字段加进了对外的
`mac_bignum_predec_t`，却忘了加进 FSM 内部的 `mac_bignum_predec_dyn_t` ⇒ 两个仿真都编译失败。

本脚本做两类检查，**类型与字面量的配对写死**（查不出来即报错，不回退到"数量对得上"）：
  ① 每个 `'{...}` 字面量的 key 必须**恰好**等于目标结构体的字段集（多/少都报）；
  ② "逐字段赋值"风格的目标（`x.f = ...`）必须把该结构体的**所有**字段都赋到。

用法：PYTHONUTF8=1 python3 p3_sv_struct_check.py
"""
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
RTL = REPO / "hw/ip/otbn/rtl"

# 结构体定义所在文件，以及"哪个字面量/赋值目标属于哪个结构体"
STRUCT_FILES = {
    'mac_bignum_predec_t': RTL / 'otbn_pkg.sv',
    'mac_bignum_predec_dyn_t': RTL / 'otbn_mac_bignum_fsm.sv',
    'mac_bignum_operation_t': RTL / 'otbn_pkg.sv',
    'insn_dec_bignum_t': RTL / 'otbn_pkg.sv',
}

# (字面量左值, 结构体, 所在文件)
LITERALS = [
    ('predec_o', 'mac_bignum_predec_t', RTL / 'otbn_mac_bignum_fsm.sv'),
    ('PredecDynDefault', 'mac_bignum_predec_dyn_t', RTL / 'otbn_mac_bignum_fsm.sv'),
    ('insn_dec_bignum_o', 'insn_dec_bignum_t', RTL / 'otbn_decoder.sv'),
]

# (赋值目标, 结构体, 所在文件) —— 逐字段 `x.f = ...` 风格
FIELDWISE = [
    ('mac_bignum_predec_raw_o', 'mac_bignum_predec_t', RTL / 'otbn_predecode.sv'),
    ('mac_bignum_operation_o', 'mac_bignum_operation_t', RTL / 'otbn_controller.sv'),
]

_text = {}


def text(path):
    if path not in _text:
        t = path.read_text(encoding='utf-8')
        t = re.sub(r'/\*.*?\*/', '', t, flags=re.S)
        _text[path] = re.sub(r'//[^\n]*', '', t)
    return _text[path]


def struct_fields(name):
    """结构体字段名列表；找不到就抛（不回退）。"""
    t = text(STRUCT_FILES[name])
    m = re.search(r'typedef struct packed \{([^{}]*)\}\s*' + name + r'\s*;', t)
    if m is None:
        raise SystemExit('FAIL: 在 %s 里找不到结构体 %s' % (STRUCT_FILES[name].name, name))
    return [l.strip().split()[-1].rstrip(';')
            for l in m.group(1).splitlines() if l.strip()]


def literal_keys(path, lhs):
    t = text(path)
    m = re.search(re.escape(lhs) + r"\s*=\s*'\{([^{}]*)\}", t, re.S)
    if m is None:
        raise SystemExit('FAIL: 在 %s 里找不到 %s 的 \'{...} 字面量' % (path.name, lhs))
    return [l.strip().split(':')[0].strip() for l in m.group(1).splitlines() if ':' in l]


def fieldwise_assigned(path, lhs):
    return set(re.findall(re.escape(lhs) + r'\.(\w+)\s*=', text(path)))


def main():
    errors = 0
    for lhs, sname, path in LITERALS:
        fields = struct_fields(sname)
        keys = literal_keys(path, lhs)
        extra = [k for k in keys if k not in fields]
        missing = [f for f in fields if f not in keys]
        ok = not extra and not missing
        print('%-20s (%s)  字面量 %2d 字段 / 结构体 %2d 字段  %s%s%s'
              % (lhs, sname, len(keys), len(fields), 'OK' if ok else 'FAIL',
                 '' if not extra else '  多: %s' % extra,
                 '' if not missing else '  少: %s' % missing))
        if not ok:
            errors += 1

    for lhs, sname, path in FIELDWISE:
        fields = struct_fields(sname)
        assigned = fieldwise_assigned(path, lhs)
        missing = [f for f in fields if f not in assigned]
        ok = not missing
        print('%-20s (%s)  逐字段赋值 %2d / %2d  %s%s'
              % (lhs, sname, len(assigned), len(fields), 'OK' if ok else 'FAIL',
                 '' if ok else '  未赋值: %s' % missing))
        if not ok:
            errors += 1

    print('PASS - %d errors' % errors if not errors else 'SEE FAIL LINES')
    return 1 if errors else 0


if __name__ == '__main__':
    sys.exit(main())
