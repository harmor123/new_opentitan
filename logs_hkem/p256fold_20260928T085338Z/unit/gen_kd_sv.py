#!/usr/bin/env python3
"""从模型生成 SV 的 KD LUT（k=−4…7 的 260-bit 二补码常量）。
用法：python3 gen_kd_sv.py   # 打印 SV 代码行（粘进 otbn_p256_fold.sv 的 KD LUT）
附录 A 原文：如需生成 KD case 常量，在同一 Python 模块环境中对 k=−4…7 计算 (k*D) & MASKW，
格式为 65 位 hex 即 260 bit；负 k 的 case 标签取其 4-bit 二补码。用自动脚本生成并审阅，不手工从十进制抄写。
"""
import importlib.util
from pathlib import Path
HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("m", HERE.parent / "model" / "p256_fold_model.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print("  // 由 run_dir/unit/gen_kd_sv.py 从 p256_fold_model.py 生成（不手抄）；k=−4…7，260-bit 二补码")
print("  // 索引 = k+4（0..11）；标签 = k & 0xF（4-bit 二补码）")
for k in range(-4, 8):
    print("  localparam logic [W-1:0] KD_%02d = W'(260'h%065x);  // k=%2d, tag=4'h%x"
          % (k + 4, (k * m.D) & m.MASKW, k, k & 0xF))
