#!/usr/bin/env bash
#
# Extended thread-count sweep — same as sona_bench.sh but with five
# n_threads points per backend instead of two. Useful for finding the
# sweet spot on a new machine (where does n_threads stop helping?
# When does HT contention start regressing?).
#
# Reuses every helper from sona_bench.sh — only the arm list differs.
# CSV/per-arm txt go to /tmp/sona_bench_extended.csv by default.
#
# Runtime: ~25-30 min on i9-8950HK with the 60 s holmes clip and
# large-v3-turbo (n=1 arms are the slow ones at ~4-5 min each).
# On Apple Silicon expect substantially less. Run on AC.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULT_CSV="${RESULT_CSV:-/tmp/sona_bench_extended.csv}"
export RESULT_CSV

# Source the main bench script's setup + run_arm definition. The trick:
# we want its helpers but NOT its 4-arm execution at the bottom. So we
# extract everything before the first `run_arm` call.
#
# To keep things simple and avoid sourcing fragility, we just redefine
# the arm list here and re-use the function by inlining the script
# up to (but not including) the existing arm invocations. We do that
# by setting a marker env var so the original script knows to skip.

export SONA_BENCH_DEFINE_ONLY=1
source "${SCRIPT_DIR}/sona_bench.sh"

# 5-point thread sweep on each backend. n=1 is the single-thread
# baseline; n=6 is one thread per i9-8950HK physical core; n=8/12
# probe what HT contention does. On Apple Silicon with more cores,
# adjust the arm list — e.g. add n=10.
run_arm cpu_n1     -2  1
run_arm cpu_n2     -2  2
run_arm cpu_n4     -2  4
run_arm cpu_n6     -2  6
run_arm cpu_n8     -2  8
run_arm cpu_n10    -2 10
run_arm metal_n1    0  1
run_arm metal_n2    0  2
run_arm metal_n4    0  4
run_arm metal_n6    0  6
run_arm metal_n8    0  8
run_arm metal_n10   0 10

echo ""
echo "=== Summary (sec-per-audio-sec, lower is faster) ==="
column -t -s, "$RESULT_CSV"
echo ""
echo "Hardware fingerprint:"
echo "  arch:     $(uname -m)"
echo "  cpu:      $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'unknown')"
echo "  cores:    $(sysctl -n hw.physicalcpu) phys / $(sysctl -n hw.logicalcpu) logical"
echo "  ram:      $(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024)) GB"
echo "  pmset:    $(pmset -g custom 2>/dev/null | grep -E 'powermode' | head -1 | xargs || echo 'unknown')"
echo "  ac:       $(pmset -g batt 2>/dev/null | grep -oE "'(AC|Battery) Power'" | head -1 || echo 'unknown')"
echo "  model:    $(basename "$MODEL")"
echo "  audio:    ${AUDIO_S}s · $(basename "$CLIP")"
