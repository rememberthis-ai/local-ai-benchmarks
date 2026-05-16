#!/usr/bin/env bash
# Run ctx_sweep.py across multiple models, starting/stopping SwiftLM for each.
# Output: one combined results md per model in results-llm/ctxsweep-*.md.
#
# Usage:
#   ./sweep_models.sh
# (no args; model list + ctx points are baked in)

set -uo pipefail
cd "$(dirname "$0")"

# Make sure dreamer_prompt is at full size (sweep slices from this)
python3 build_dreamer_prompt.py --target-tokens 80000 > /dev/null 2>&1

# Model list and per-model ctx points.
# Some models may not handle very long ctx (80B can't), so trim sizes accordingly.
declare -a MODELS=(
  "mlx-community/gemma-4-26b-a4b-it-4bit"
  "mlx-community/Qwen3-Coder-30B-A3B-Instruct-MLX-4bit"
  "mlx-community/gpt-oss-20b-MXFP4-Q4"
  "mlx-community/Qwen3-Next-80B-A3B-Instruct-4bit"
)
declare -a SIZES_DEFAULT=(4000 8000 16000 32000 48000 64000)
declare -a SIZES_80B=(4000 8000 16000 32000)  # 80B is RAM-tight; skip 48K+

LOG=/tmp/sweep_models.log
echo "[$(date +%H:%M:%S)] === multi-model sweep starting ===" > "$LOG"

for MODEL in "${MODELS[@]}"; do
  SLUG=$(echo "$MODEL" | tr '/:' '__')
  echo "[$(date +%H:%M:%S)] === $MODEL ===" | tee -a "$LOG"

  # pick sizes
  if [[ "$MODEL" == *"80B"* ]]; then
    SIZES=("${SIZES_80B[@]}")
  else
    SIZES=("${SIZES_DEFAULT[@]}")
  fi
  echo "  sizes: ${SIZES[*]}" | tee -a "$LOG"

  # Make sure no SwiftLM is running
  pkill -x SwiftLM 2>/dev/null
  sleep 3
  pkill -9 -x SwiftLM 2>/dev/null
  sleep 2

  # Start SwiftLM with this model
  echo "  [$(date +%H:%M:%S)] starting SwiftLM…" | tee -a "$LOG"
  ./SwiftLM \
    --model "$MODEL" \
    --port 5413 \
    --max-tokens 300 \
    --prefill-size 256 \
    --thinking \
    > "/tmp/swiftlm-$SLUG.log" 2>&1 &
  SWIFTLM_PID=$!

  # Wait for ready (max 5 min)
  READY=0
  for i in $(seq 1 60); do
    if curl -sf http://127.0.0.1:5413/v1/models > /dev/null 2>&1; then
      READY=1
      break
    fi
    sleep 5
  done
  if [ "$READY" -ne 1 ]; then
    echo "  ❌ SwiftLM did not become ready within 5 min — skipping" | tee -a "$LOG"
    kill -9 $SWIFTLM_PID 2>/dev/null
    continue
  fi
  echo "  [$(date +%H:%M:%S)] SwiftLM ready" | tee -a "$LOG"
  grep -E "Memory strategy|partition" "/tmp/swiftlm-$SLUG.log" | head -2 | tee -a "$LOG"

  # Run sweep
  echo "  [$(date +%H:%M:%S)] running ctx_sweep…" | tee -a "$LOG"
  python3 ctx_sweep.py "$MODEL" \
    --sizes "${SIZES[@]}" \
    --max-tokens 300 \
    --timeout 1500 \
    >> "$LOG" 2>&1 || echo "  ⚠️ sweep had errors" | tee -a "$LOG"

  # Stop SwiftLM
  echo "  [$(date +%H:%M:%S)] stopping SwiftLM…" | tee -a "$LOG"
  kill $SWIFTLM_PID 2>/dev/null
  sleep 3
  kill -9 $SWIFTLM_PID 2>/dev/null
  sleep 2
  echo "" | tee -a "$LOG"
done

echo "[$(date +%H:%M:%S)] === all done ===" | tee -a "$LOG"
echo "" | tee -a "$LOG"
echo "Result files:" | tee -a "$LOG"
ls -lt results-llm/ctxsweep-2026* 2>/dev/null | head -10 | tee -a "$LOG"
