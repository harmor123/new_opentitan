#!/usr/bin/env bash
# P5（Ibex 侧）：把设备路径（chip sim）那一次运行的证据收拢成一个小文件 + 拷出 UART 日志。
#
# 用法（在 Linux 构建机仓库根执行）：
#   bash logs_hkem/p256fold_20260928T085338Z/rtl/p5_collect_device_evidence.sh
#
# 前置：刚跑过
#   bazel test //test_hybrid_kem_otbn_prompt_ver1_1:test_p256_only_sim_verilator $CHIP
#
# 产出（都可由本脚本重跑覆盖）：
#   logs_hkem/p256fold_20260928T085338Z/rtl/p5_device_evidence.txt          证据摘要（入库）
#   logs_hkem/p256fold_20260928T085338Z/rtl/test_p256_only.ver1_1app.uart0.log  UART 原文（入库）
# 不产出：完整 sim.log / otbn_p256_events.csv（几十 MB 级，可从 bazel 重建，不入库）
set -euo pipefail

VER=ver1_2
PKG=test_hybrid_kem_otbn_prompt_$VER
TEST=test_p256_only_sim_verilator
RUN=logs_hkem/p256fold_20260928T085338Z
L="bazel-testlogs/$PKG/$TEST/test.log"
O="$RUN/rtl/p5_device_evidence.$VER.txt"
U="$RUN/rtl/test_p256_only.$VER.uart0.log"
RUNFILES="bazel-bin/$PKG/$TEST.bash.runfiles/_main"

cd "$(git rev-parse --show-toplevel)"

if [ ! -f "$L" ]; then
  echo "找不到测试日志 $L —— 先跑那条 bazel test 命令" >&2
  exit 1
fi

{
  echo "# P5 设备路径证据：chip sim（Verilator）+ 本版 P-256 app（serial 档，无 +p256_serial 覆盖）"
  echo "# 测试目标：//$PKG:$TEST"
  echo "# 采集时间（UTC）：$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# 源日志：$L"
  echo
  echo "## 四个 op 的 OTBN 指令数与 Ibex 跨度"
  grep -E "OTBN instruction count|MEASURE|passed|PASS|FAIL" "$L" || true
  echo
  echo "## 每次 op 边界处累计的 P256EV 行数（一行 = 一条本版 bn.p256mul 退休）"
  grep -E "P256EV|Generating P-256|Computing shared secret|OTBN instruction count" "$L" |
    awk '/P256EV/{n++; next} {printf "[folds so far = %-6d] %s\n", n, $0}'
  echo
  echo "## 形态分布（rows=fold 行数/条、err=写回期不变式违例、wb=写回次数、micro_mul=MAC 微操作数、overlap=重叠拍数）"
  for k in rows err wb micro_mul overlap; do
    echo -n "$k: "
    grep -o "$k=[0-9]*" "$L" | sort | uniq -c | tr '\n' ' '
    echo
  done
  echo
  echo "## P256EV 行总数"
  grep -c P256EV "$L" || true
} > "$O"

if [ -f "$RUNFILES/uart0.log" ]; then
  cp "$RUNFILES/uart0.log" "$U"
else
  echo "注意：没找到 $RUNFILES/uart0.log，跳过拷贝" >&2
fi

wc -l "$O"
ls -l "$O" "$U" 2>/dev/null || true
