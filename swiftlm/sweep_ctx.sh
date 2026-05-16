#!/usr/bin/env bash
# Sweep context sizes against an already-running SwiftLM instance.
# Regenerates dreamer_prompt.txt at each target_tokens, runs bench_longctx.py
# with --max-tokens 300, saves a result file per size.
#
# Usage: ./sweep_ctx.sh <swiftlm_hf_repo> [sizes...]
# Example: ./sweep_ctx.sh "mlx-community/Qwen3.6-35B-A3B-4bit" 4000 8000 16000 32000 48000 64000

set -uo pipefail
cd "$(dirname "$0")"

SWIFTLM_HF="${1:?swiftlm HF repo required}"
shift
SIZES=("$@")
[ ${#SIZES[@]} -eq 0 ] && SIZES=(4000 8000 16000 32000 48000 64000)

echo "[$(date +%H:%M:%S)] sweep starting: ${SWIFTLM_HF}"
echo "sizes: ${SIZES[*]}"
echo

for SIZE in "${SIZES[@]}"; do
  echo "[$(date +%H:%M:%S)] === target_tokens=$SIZE ==="
  python3 build_dreamer_prompt.py --target-tokens "$SIZE" 2>&1 | tail -3
  echo
  python3 bench_longctx.py \
    --swiftlm "$SWIFTLM_HF" \
    --max-tokens 300 \
    --timeout 1200 \
    --label "ctxsweep-$(printf '%05d' "$SIZE")" 2>&1 | tail -3
  echo
done

echo "[$(date +%H:%M:%S)] sweep done"
echo
echo "=== results ==="
ls -lt results-llm/longctx-*-ctxsweep-* 2>/dev/null | head -10
