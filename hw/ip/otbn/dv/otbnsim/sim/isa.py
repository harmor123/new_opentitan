# Copyright lowRISC contributors (OpenTitan project).
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

import sys
from typing import Dict, Iterator, Optional, Tuple, Callable

from shared.insn_yaml import Insn, DummyInsn, load_insns_yaml

from .state import OTBNState


# Load the insns.yml file at module load time: we'll use its data while
# declaring the classes. The point is that an OTBNInsn below is an instance of
# a particular Insn object from shared.insn_yaml, so we want a class variable
# on the OTBNInsn that points at the corresponding Insn.
try:
    INSNS_FILE = load_insns_yaml()
except RuntimeError as err:
    sys.stderr.write('{}\n'.format(err))
    sys.exit(1)


def insn_for_mnemonic(mnemonic: str, num_operands: int) -> Insn:
    '''Look up the named instruction in the loaded YAML data.

    To make sure nothing's gone really wrong, make sure it has the expected
    number of operands. If we fail to find the right instruction, print a
    message to stderr and exit (rather than raising a RuntimeError: this
    happens on module load time, so it's a lot clearer to the user what's going
    on this way).

    '''
    insn = INSNS_FILE.mnemonic_to_insn.get(mnemonic)
    if insn is None:
        sys.stderr.write('Failed to find an instruction for mnemonic {!r} in '
                         'insns.yml.\n'
                         .format(mnemonic))
        sys.exit(1)

    if len(insn.operands) != num_operands:
        sys.stderr.write('The instruction for mnemonic {!r} in insns.yml has '
                         '{} operands, but we expected {}.\n'
                         .format(mnemonic, len(insn.operands), num_operands))
        sys.exit(1)

    return insn


class OTBNInsn:
    '''A decoded OTBN instruction.

    '''

    # A class variable that holds the Insn subclass corresponding to this
    # instruction.
    insn: Insn = DummyInsn()

    # A class variable that is set by Insn subclasses that represent
    # instructions that affect control flow (and are not allowed at the end of
    # a loop).
    affects_control = False

    # A class variable that is true if this instruction has valid bits. (Set to
    # false by the EmptyInsn subclass)
    has_bits = True

    # A class variable that is true if there will be a cycle of fetch stall
    # after the instruction executes.
    has_fetch_stall = False

    # A class variable that is true if this instruction reads needs the URND
    # permutation to be resampled for it ahead of time.
    samples_urnd = False

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        self.raw = raw
        self.op_vals = op_vals

        # Memoized disassembly for this instruction. We store the PC at which
        # we disassembled too (which should be the same next time around, but
        # it can't hurt to check).
        self._disasm: Optional[Tuple[int, str]] = None

    def execute(self, state: OTBNState) -> Optional[Iterator[None]]:
        '''Execute the instruction

        This may yield (returning an iterator object) if the instruction has
        stalled the processor and will take multiple cycles.

        '''
        raise NotImplementedError('OTBNInsn.execute')

    def disassemble(self, pc: int) -> str:
        '''Generate an assembly listing for this instruction'''
        if self._disasm is not None:
            old_pc, old_disasm = self._disasm
            assert pc == old_pc
            return old_disasm

        disasm = self.insn.disassemble(pc, self.op_vals)
        self._disasm = (pc, disasm)
        return disasm

    @staticmethod
    def to_2s_complement(value: int) -> int:
        '''Interpret the signed value as a 2's complement u32'''
        assert -(1 << 31) <= value < (1 << 31)
        return (1 << 32) + value if value < 0 else value

    def rtl_trace(self, pc: int) -> str:
        '''Return the RTL trace entry for executing this insn'''
        if self.has_bits:
            return (f'E PC: {pc:#010x}, insn: {self.raw:#010x}\n'
                    f'# @{pc:#010x}: {self.insn.mnemonic}')
        else:
            return (f'E PC: {pc:#010x}, insn: ??\n'
                    f'# @{pc:#010x}: ??')


class RV32RegReg(OTBNInsn):
    '''A general class for register-register insns from the RV32I ISA'''
    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.grd = op_vals['grd']
        self.grs1 = op_vals['grs1']
        self.grs2 = op_vals['grs2']


class RV32RegImm(OTBNInsn):
    '''A general class for register-immediate insns from the RV32I ISA'''
    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.grd = op_vals['grd']
        self.grs1 = op_vals['grs1']
        self.imm = op_vals['imm']


class RV32ImmShift(OTBNInsn):
    '''A general class for immediate shift insns from the RV32I ISA'''
    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.grd = op_vals['grd']
        self.grs1 = op_vals['grs1']
        self.shamt = op_vals['shamt']


class BnVecVecAdd(OTBNInsn):
    '''A general class for vector-vector addition/subtraction insns from the vectorized BN ISA'''
    supported_elens = [32]

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.elen = op_vals['elen']


class BnVecVecTrn(OTBNInsn):
    '''A general class for vector-vector transpose insns from the vectorized BN ISA'''
    supported_elens = [32, 64, 128]

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.elen = op_vals['elen']


class BnVecVecMul(OTBNInsn):
    '''A general class for vector-vector multiplication insns from the vectorized BN ISA'''
    supported_elens = [32]
    samples_urnd = True

    def __init__(self, raw: int, op_vals: Dict[str, int]):
        super().__init__(raw, op_vals)
        self.wrd = op_vals['wrd']
        self.wrs1 = op_vals['wrs1']
        self.wrs2 = op_vals['wrs2']
        self.elen = op_vals['elen']


def logical_byte_shift(value: int, shift_type: int, shift_bytes: int) -> int:
    '''Logical shift value by shift_bytes to the left or right.

    value should be an unsigned 256-bit value. shift_type should be 0 (shift
    left) or 1 (shift right), matching the encoding of the big number
    instructions. shift_bytes should be a non-negative number of bytes to shift
    by.

    Returns an unsigned 256-bit value, truncating on an overflowing left shift.
    '''
    mask256 = (1 << 256) - 1
    assert 0 <= value <= mask256
    assert 0 <= shift_type <= 1
    assert 0 <= shift_bytes

    shift_bits = 8 * shift_bytes
    shifted = value << shift_bits if shift_type == 0 else value >> shift_bits
    return shifted & mask256


def shift_vec_elem(value: int, size: int, shift_type: int, shift_bits: int) -> int:
    '''Performs a logical bit shift on an unsigned integer confined to the given bit width.

    With shift_type = 0, the value is shifted left by shift_bits; with shift_type = 1,
    the value is shifted right by shift_bits.

    The resulting shifted value is truncated to size bits.
    '''
    maskSize = (1 << size) - 1
    assert 0 <= value <= maskSize
    assert 0 <= shift_type <= 1
    assert 0 <= shift_bits

    if shift_type == 0:
        result = (value << shift_bits) & maskSize
    else:
        result = (value >> shift_bits) & maskSize

    return result


def extract_vec_elem(value: int, elem: int, size: int) -> int:
    '''Returns the elem-th vector element from a 256-bit vector of size-bit elements interpreted as
    unsigned integer.
    '''
    assert 0 <= value < (1 << 256)
    assert 0 <= elem < (256 // size)
    return (value >> (elem * size)) & ((1 << size) - 1)


def extract_quarter_word(value: int, qwsel: int) -> int:
    '''Extracts a 64-bit quarter word from a 256-bit value.'''
    assert 0 <= qwsel <= 3
    return extract_vec_elem(value, qwsel, 64)


def lower_d_bits(value: int, d: int) -> int:
    '''Extracts the lower d bits of the value.'''
    assert 0 <= d
    assert 0 <= value
    return value & ((1 << d) - 1)


def upper_d_bits(value: int, d: int) -> int:
    '''Extracts the upper d bits of the value and shifts them down by d.'''
    assert 0 <= d
    assert 0 <= value
    return lower_d_bits(value >> d, d)


def element_length_in_bits(elen: int) -> int:
    '''Returns the corresponding bit width for a given ELEN encoding.

    Encoding | ELEN | Size in bits
    0        | .8s  |  32
    1        | .4d  |  64
    2        | .2q  | 128
    '''
    assert 0 <= elen <= 2
    return 32 * (1 << elen)


def map_elems(op: Callable[[int, int], int], size: int, vec_a: int, vec_b: int) -> int:
    '''Applies the operation op to each pair of elements for the given element size.

    The vectors are expected to be 256-bit numbers where `size`-bit elements are extracted from.
    The op function takes two vector elements, performs the desired operation and is expected to
    return a non-negative value.

    The results are concatenated and returned as a 256-bit number.'''
    result = 0
    for elem in range(256 // size):
        elem_a = extract_vec_elem(vec_a, elem, size)
        elem_b = extract_vec_elem(vec_b, elem, size)

        elem_c = op(elem_a, elem_b)
        elem_c = elem_c & ((1 << size) - 1)
        result |= elem_c << (elem * size)
    return result


def montgomery_mul_no_cond_subtraction(a: int, b: int, q: int, mu: int, size: int) -> int:
    '''Performs a Montgomery multiplication but without the final conditional subtraction.

    The inputs a and b are in Montgomery space.
    The result is also in Montgomery space.

    Algorithm (where []_d are the lower d bits, []^d are the higher d bits):
       r = [c + [[c]_d * mu]_d * q]^d
       # Skipped conditional subtraction step:
       # if r >= q:
       #     r -= q
       return r
    '''
    reg_c = a * b
    reg_tmp = lower_d_bits(reg_c, size)
    reg_tmp = lower_d_bits(reg_tmp * mu, size)
    r = upper_d_bits(reg_c + reg_tmp * q, size)
    return r


# ---------------------------------------------------------------------------
# P-256 fold multiplier (the fused multi-cycle instruction of `contribution 2`,
# sections 5, 6 and 8).
#
# The instruction replaces the software `mul_modp()` sequence: the MAC evaluates
# the 16 partial products of the 256x256 product in the same order as the
# official high-10 / low-6 schedule and the fold unit reduces the result modulo
# the P-256 prime.  The helpers below mirror the bit-exact Python model of the
# fold unit: a fixed signed width of 260 bits, the 4-bit quotient field
# k = signed'(F[259:256]) and the 12-entry k*d constant LUT.
# ---------------------------------------------------------------------------

P256_W = 260
P256_MASKW = (1 << P256_W) - 1
P256_MASK128 = (1 << 128) - 1

# p = 2^256 - 2^224 + 2^192 + 2^96 - 1 and d = 2^256 - p.
P256_P = (1 << 256) - (1 << 224) + (1 << 192) + (1 << 96) - 1
P256_D = (1 << 256) - P256_P

# The 12 compiled k*d constants, keyed by the 4-bit field F[259:256] (two's
# complement, so 0b1100..0b0111 are k = -4..7).  Out-of-range keys (0b1000..
# 0b1011, k = -8..-5) select zero, matching the safe default of the RTL LUT.
P256_KD = {k & 0xf: (k * P256_D) & P256_MASKW for k in range(-4, 8)}

# MAC schedule of the instruction's cycles c0..c15, one entry per cycle:
# (limb index in a, limb index in b, addend shift, zero ACC first, shift out 128).
P256_MAC_STEPS = (
    (0, 3, 64, True, False),
    (1, 2, 64, False, False),
    (2, 1, 64, False, False),
    (3, 0, 64, False, True),
    (1, 3, 0, False, False),
    (2, 2, 0, False, False),
    (3, 1, 0, False, False),
    (2, 3, 64, False, False),
    (3, 2, 64, False, False),
    (3, 3, 128, False, False),
    (0, 0, 0, True, False),
    (0, 1, 64, False, False),
    (1, 0, 64, False, True),
    (0, 2, 0, False, False),
    (1, 1, 0, False, False),
    (2, 0, 0, False, False))

# The eight row vectors of cycles c16..c23.  Each row is a concatenation of
# words of the captured high half h0..h7 (word i at bit 32*i); None is a zero
# word.  Rows 0 and 1 are doubled (the '+2A' and '+2Bv' updates of the schedule).
P256_ROWS = (
    ([None, None, None, 3, 4, 5, 6, 7], 2),
    ([None, None, None, 4, 5, 6, 7, None], 2),
    ([0, 1, 2, 5, 6, 7, 5, 0], 1),
    ([1, 2, 3, None, None, None, 6, 7], 1),
    ([3, 4, 5, 0, 1, 2, 0, 2], -1),
    ([4, 5, 6, 1, 2, 3, 1, 3], -1),
    ([5, 6, 7, 7, None, None, None, 4], -1),
    ([6, 7, None, None, None, None, None, 5], -1))


def p256_signed(x: int) -> int:
    '''Interpret the low 260 bits of x as a signed 260-bit value.'''
    x &= P256_MASKW
    return x - (1 << P256_W) if x >> (P256_W - 1) else x


def p256_checked_add(x: int, y: int) -> int:
    '''Add two signed 260-bit values.

    The exact sum must fit in 260 bits: this is the per-cycle check of the fold
    unit (`contribution 2`, section 10.3), i.e. the exact 261-bit sum has to stay
    in [-2^259, 2^259).

    '''
    exact = p256_signed(x) + p256_signed(y)
    assert -(1 << (P256_W - 1)) <= exact < (1 << (P256_W - 1))

    got = p256_signed((x & P256_MASKW) + (y & P256_MASKW))
    assert got == exact
    return got


def p256_mac(a: int, b: int) -> Tuple[int, int, int]:
    '''Run the 16 MAC micro-operations of a fused P-256 multiply.

    Returns (high, seed, low), where high is the captured high half h0..h7, seed
    is the value latched into F on c3 and low is L0 = {ACC[129:0], LL[127:0]},
    the 258-bit row-merge operand of c24 (never truncated to 256 bits).

    '''
    limbs_a = [(a >> (64 * i)) & 0xffffffffffffffff for i in range(4)]
    limbs_b = [(b >> (64 * i)) & 0xffffffffffffffff for i in range(4)]

    acc = 0
    seed = 0
    high = 0
    ll = 0
    for cycle, (i, j, shift, zero_acc, shift_out) in enumerate(P256_MAC_STEPS):
        acc = (0 if zero_acc else acc) + (limbs_a[i] * limbs_b[j] << shift)
        assert 0 <= acc < (1 << 256)

        if cycle == 3:
            seed = (acc & P256_MASK128) << 128
        elif cycle == 9:
            high = acc
        elif cycle == 12:
            ll = acc & P256_MASK128

        if shift_out:
            acc >>= 128

    low = (acc << 128) | ll
    assert 0 <= low < 3 * (1 << 256)
    assert a * b == low + seed + (high << 256)
    return high, seed, low


def p256_mulmodp(a: int, b: int) -> int:
    '''Multiply two 256-bit values modulo the P-256 prime.

    This is the value the fused instruction writes back: the 16 MAC micro-ops
    (c0..c15), the eight row addends (c16..c23), the L0 merge (c24), the
    quotient fold (c25) and one conditional +/- p (c26).  The sequence is fixed:
    no operand, k or correction value can shorten it and there is no early exit.

    '''
    high, seed, low = p256_mac(a, b)
    words = [(high >> (32 * i)) & 0xffffffff for i in range(8)]

    f = seed
    for indices, scale in P256_ROWS:
        row = sum((0 if i is None else words[i]) << (32 * j)
                  for j, i in enumerate(indices))
        f = p256_checked_add(f, scale * row)
    f = p256_checked_add(f, low)                    # c24: F = R'

    # c25, quotient fold: x = F[255:0] is the first CPA operand and k*d the
    # second one (selected by k = signed'(F[259:256]) from the constant LUT).
    k = (f >> 256) & 0xf
    f = p256_checked_add(f & ((1 << 256) - 1), P256_KD.get(k, 0))

    # c26, one conditional +/- p: the sign of T picks the operand, so no wide
    # comparison is needed.  T < 0 takes the candidate; otherwise it is taken
    # only if it is non-negative.
    candidate = p256_checked_add(f, P256_P if f < 0 else -P256_P)
    result = candidate if f < 0 or candidate >= 0 else f
    assert 0 <= result < P256_P
    return result
