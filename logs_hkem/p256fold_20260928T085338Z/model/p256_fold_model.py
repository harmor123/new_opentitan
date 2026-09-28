#!/usr/bin/env python3
"""Bit-exact, deterministic P-256 fold/schedule model; no RTL results implied.
Run: python3 p256_fold_model.py --random 20000 --out verification_results.json
The MAC schedule models the official high-10 order followed by six low products.
All hardware fold arithmetic is checked at a fixed signed width of 260 bits.
Only the golden reference uses arbitrary-precision modular multiplication.
"""
import argparse
import itertools
import json
import random
from pathlib import Path
Q = 1 << 32
B = 1 << 64
N = 1 << 256
P = N - Q**7 + Q**6 + Q**3 - 1
D = N - P
MASK128 = (1 << 128) - 1
W = 260
MASKW = (1 << W) - 1
R256 = D
R320 = Q**7 + Q**5 + Q**4 - Q**2 - Q
R384 = Q**7 - 2*Q**4 - 2*Q**3 + Q + 1
R448 = 3*Q**6 + 2*Q**5 + Q**4 - Q**2 - Q - 1
# Row i is the integer-polynomial remainder of q**(8+i), ascending powers.
MATRIX = [ [1, 0, 0, -1, 0, 0, -1, 1], [1, 1, 0, -1, -1, 0, -1, 0], [0, 1, 1, 0, -1, -1, 0, -1],  [-1, 0, 1, 2, 0, -1, 0, -1], [-1, -1, 0, 2, 2, 0, 0, -1], [-1, -1, -1, 1, 2, 2, 1, -1], [-1, -1, -1, 0, 1, 2, 3, 0], [0, -1, -1, -1, 0, 1, 2, 3], ]
WEIGHTS = [sum(c * Q**j for j, c in enumerate(row)) for row in MATRIX]
# None means a zero word. Every vector is a concatenation, not a word-wise add.
LANES = { 'A': [None, None, None, 3, 4, 5, 6, 7], 'B': [None, None, None, 4, 5, 6, 7, None], 'P': [0, 1, 2, 5, 6, 7, 5, 0], 'Q': [1, 2, 3, None, None, None, 6, 7], 'M0': [3, 4, 5, 0, 1, 2, 0, 2], 'M1': [4, 5, 6, 1, 2, 3, 1, 3], 'M2': [5, 6, 7, 7, None, None, None, 4], 'M3': [6, 7, None, None, None, None, None, 5], }
MAC_STEPS = [ (0, 3, 64, True, False), (1, 2, 64, False, False), (2, 1, 64, False, False), (3, 0, 64, False, True), (1, 3, 0, False, False), (2, 2, 0, False, False), (3, 1, 0, False, False), (2, 3, 64, False, False), (3, 2, 64, False, False), (3, 3, 128, False, False), (0, 0, 0, True, False), (0, 1, 64, False, False), (1, 0, 64, False, True), (0, 2, 0, False, False), (1, 1, 0, False, False), (2, 0, 0, False, False), ]
def signed(x, width=W):
    x &= (1 << width) - 1
    return x - (1 << width) if x >> (width - 1) else x
def checked_add(x, y):
    exact = x + y
    assert -(1 << (W-1)) <= exact < (1 << (W-1))

    got = signed((x & MASKW) + (y & MASKW))
    assert got == exact
    return got
def vectors(h):
    return {name: sum((0 if i is None else h[i]) << (32*j) for j, i in enumerate(indices)) for name, indices in LANES.items()}
def terms(h):
    v = vectors(h)
    return [2*v['A'], 2*v['B'], v['P'], v['Q'], -v['M0'], -v['M1'], -v['M2'], -v['M3']]
def split_raw(high):
    t = [(high >> (64*i)) & (B-1) for i in range(4)]
    return t, R256*t[0] - R320*t[1] - R384*t[2] + R448*t[3]
def mac(a, b, trace=False):
    aa = [(a >> (64*i)) & (B-1) for i in range(4)]
    bb = [(b >> (64*i)) & (B-1) for i in range(4)]
    acc = 0
    events = []
    for cycle, (i, j, sh, zero, so) in enumerate(MAC_STEPS):
        acc = (0 if zero else acc) + ((aa[i]*bb[j]) << sh)
        assert 0 <= acc < N, (cycle, acc)
        if cycle == 3:
            seed = (acc & MASK128) << 128
            assert seed % (1 << 192) == 0
        if cycle == 9:
            high = acc
        if cycle == 12:
            ll = acc & MASK128
        if so:
            acc >>= 128
        if trace:
            events.append({'cycle': cycle, 'product': f'a{i}b{j}', 'shift': sh, 'zero': zero, 'shift_out': so, 'acc_after': hex(acc)})
    low = (acc << 128) | ll
    assert 0 <= low < 3*N
    assert 0 <= seed < N
    assert 0 <= low + seed < 4*N
    assert a*b == low + seed + (high << 256)

    return high, seed, low, events
def quotient_fold(x):
    q, lo = divmod(x, N)  # floor division, including negative values
    assert -4 <= q <= 7
    t = checked_add(lo, q*D)  # q*D is a fixed 12-entry LUT in hardware
    assert -P < t < 2*P
    return t, q
def correction(t):
    # One shared add/sub plus sign-controlled selection. No early exit.
    candidate = checked_add(t, P if t < 0 else -P)
    result = candidate if t < 0 or candidate >= 0 else t
    assert 0 <= result < P
    assert result == t % P
    return result
def light(h, seed, low, trace=False):
    f = seed
    rows = [{'cycle': 3, 'op': 'seed H', 'F': hex(f)}] if trace else []
    for cycle, (name, x) in enumerate(zip( ['+2A', '+2B', '+P', '+Q', '-M0', '-M1', '-M2', '-M3'], terms(h)), 10):
        f = checked_add(f, x)
        if trace:
            rows.append({'cycle': cycle, 'op': name, 'F': hex(f)})
    f = checked_add(f, low)
    r = f
    if trace:
        rows.append({'cycle': 18, 'op': '+L0', 'F': hex(f)})
    f, quotient = quotient_fold(f)
    t = f
    if trace:
        rows.append({'cycle': 19, 'op': 'fold q', 'q': quotient, 'F': hex(f)})
    f = correction(f)
    if trace:
        rows += [{'cycle': 20, 'op': 'conditional +/-p', 'F': hex(f)}, {'cycle': 21, 'op': 'WDR commit', 'F': hex(f)}]
    return f, {'R': r, 'q': quotient, 'T': t, 'trace': rows}
def csa(a, b, c):
    a &= MASKW
    b &= MASKW
    c &= MASKW

    s = a ^ b ^ c
    k = ((a & b) | (a & c) | (b & c)) << 1
    k &= MASKW
    assert (s + k) & MASKW == (a + b + c) & MASKW
    return s, k
def fast(h, seed, low):
    v = vectors(h)
    inputs = [2*v['A'], 2*v['B'], v['P'], v['Q']]
    inputs += [(~v[f'M{i}']) & MASKW for i in range(4)]
    s, k = seed, 4  # Four one's-complement negative operands need +4.
    for i in range(0, 8, 2):  # cycles 10..13
        s, k = csa(s, k, inputs[i])
        s, k = csa(s, k, inputs[i+1])
    f = signed(s+k)          # cycle 14: high-side CPA before L0 is ready
    assert f == seed + sum(terms(h))
    f = checked_add(f, low)  # cycle 16: merge L0
    f, _ = quotient_fold(f)  # cycle 17
    return correction(f)    # cycle 18; writeback cycle 19
def verify_algebra():
    assert [R256, R320, R384, R448] == [ pow(2, 256, P), (-pow(2, 320, P)) % P, (-pow(2, 384, P)) % P, pow(2, 448, P)]
    polys = []
    for k in range(16):
        if k < 8:
            row = [int(j == k) for j in range(8)]
        else:
            row = [sum(sign*polys[d][j] for d, sign in [(k-1, 1), (k-2, -1), (k-5, -1), (k-8, 1)]) for j in range(8)]
        polys.append(row)
    assert polys[8:] == MATRIX
    for i in range(8):
        h = [int(i == j) for j in range(8)]
        assert sum(terms(h)) == WEIGHTS[i]
        assert WEIGHTS[i] % P == pow(Q, 8+i, P)
    cmin = -(B-1)*(R320+R384)
    cmax = (B-1)*(R256+R448)
    assert -(1 << 289) < cmin < -(1 << 288)
    assert 1 << 288 < cmax < 1 << 289
    # Exact extrema of a linear function on the independent 32-bit word box.
    cpmin = (Q-1)*sum(min(0, w) for w in WEIGHTS)
    cpmax = (Q-1)*sum(max(0, w) for w in WEIGHTS)
    assert -4*N < cpmin <= cpmax < 4*N

    assert 4*D < P and 7*D < P
    return {'raw_C_min': str(cmin), 'raw_C_max': str(cmax), 'raw_signed_width': 290, 'prefold_C_min': str(cpmin), 'prefold_C_max': str(cpmax), 'prefold_signed_width': 259, 'accumulator_width': W}
def run(nrandom):
    proofs = verify_algebra()
    corners = 0
    qset = set()
    corrections = {'add_p': 0, 'sub_p': 0, 'keep': 0}
    # Box vertices plus independent legal upper envelopes for the low input.
    for h in itertools.product([0, Q-1], repeat=8):
        high = sum(x << (32*i) for i, x in enumerate(h))
        _, c = split_raw(high)
        cp = sum(terms(h))
        assert cp == c - (h[1]-h[3]-h[5])*P
        for seed in [0, N-(1 << 192)]:
            for low in [0, 3*N-1]:
                got, st = light(h, seed, low)
                assert got == fast(h, seed, low) == (seed+low+(high << 256)) % P
                qset.add(st['q'])
                corners += 1
    vals = sorted(set([0, 1, 2, B-1, B, (1 << 128)-1, 1 << 128, 1 << 160, (1 << 192)-1, 1 << 192, 1 << 224, P-2, P-1, P, N-2, N-1]))
    pairs = list(itertools.product(vals, repeat=2))
    rng = random.Random(0x2560960224)
    pairs += [(rng.randrange(P), rng.randrange(P)) for _ in range(nrandom)]
    observed = {'C_min': None, 'C_max': None, 'L_max': 0, 'R_min': None, 'R_max': None}
    negative_example = None
    for a, b in pairs:
        high, seed, low, _ = mac(a, b)
        h = [(high >> (32*i)) & (Q-1) for i in range(8)]
        t, c = split_raw(high)
        cp = sum(terms(h))
        assert cp == c - (h[1]-h[3]-h[5])*P
        assert (seed + low + c) % P == (a*b) % P
        got, st = light(h, seed, low)
        assert got == fast(h, seed, low) == (a*b) % P
        qset.add(st['q'])
        typ = 'add_p' if st['T'] < 0 else 'sub_p' if st['T'] >= P else 'keep'
        corrections[typ] += 1
        for key, val, fn in [('C_min', c, min), ('C_max', c, max), ('L_max', seed+low, max), ('R_min', st['R'], min), ('R_max', st['R'], max)]:

            observed[key] = val if observed[key] is None else fn(observed[key], val)
        if c < -(1 << 288) and negative_example is None and a < P and b < P:
            negative_example = {'a': hex(a), 'b': hex(b), 'C': hex(c)}
    for t in [-4*D, -1, 0, 1, P-1, P, P+1, N-1, N+7*D-1]:
        assert correction(t) == t % P
    a = b = P-1
    high, seed, low, events = mac(a, b, True)
    h = [(high >> (32*i)) & (Q-1) for i in range(8)]
    got, st = light(h, seed, low, True)
    result = { 'status': 'PASS: Python arithmetic/cycle model only; no integrated RTL simulation or PPA', 'seed': '0x2560960224', 'random_pairs': nrandom, 'directed_pairs': len(vals)**2, 'independent_word_corner_cases': corners, 'algebra': proofs, 'observed_q_values': sorted(qset), 'product_case_correction_counts': corrections, 'observed_product_ranges_not_exhaustive': {k: str(v) for k, v in observed.items()}, 'actual_reduced_operand_example_requiring_290_signed_bits': negative_example, 'schedules': {'area_light': {'compute_cycles': 21, 'writeback_cycles': 1, 'result_wdr_end_cycle': 21, 'ret_cycles': 1, 'assumed_new_fetch_cycles': 1, 'call_cycles': 24}, 'csa': {'compute_cycles': 19, 'writeback_cycles': 1, 'result_wdr_end_cycle': 19, 'ret_cycles': 1, 'assumed_new_fetch_cycles': 1, 'call_cycles': 22}}, 'projections': [], 'example_p_minus_one_squared': {'result': hex(got), 'mac': events, 'fold': st['trace']}, }
    for latency in [30, 24, 22]:
        mt = 9602*latency
        et = 84966+mt
        result['projections'].append({'call_cycles': latency, 'mul_modp_cycles': mt, 'ecdh_cycles': et, 'cycle_reduction_pct': 100*(603474-et)/603474, 'ecdh_speedup': 603474/et, 'type': 'analytical projection, not measurement'})
    return result
if __name__ == '__main__':
    ap = argparse.ArgumentParser()

    ap.add_argument('--random', type=int, default=20000)
    ap.add_argument('--out', type=Path)
    args = ap.parse_args()
    result = run(args.random)
    if args.out:
        args.out.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k: result[k] for k in ['status', 'random_pairs', 'directed_pairs', 'independent_word_corner_cases', 'observed_q_values', 'product_case_correction_counts', 'schedules', 'projections']}, indent=2))
