#!/usr/bin/env bash
# Run Qwen3-VL-8B, MiniCPM-o-4.5, FastVLM-7B serially. Logs go to /tmp.
set -uo pipefail
cd "$(dirname "$0")/../.."
PY=experiments/captioning-bench/.venv/bin/python
BENCH=experiments/captioning-bench/bench.py

for entry in \
  "qwen3vl:lmstudio-community/Qwen3-VL-8B-Instruct-MLX-4bit" \
  "minicpmo45:andrevp/MiniCPM-o-4_5-MLX-4bit" \
  "fastvlm7b:InsightKeeper/FastVLM-7B-MLX-4bit" ; do
    slug="${entry%%:*}"
    model="${entry#*:}"
    log="/tmp/bench-${slug}.log"
    echo "================================================================"
    echo "[$(date '+%H:%M:%S')] Starting $slug ($model) → $log"
    echo "================================================================"
    "$PY" -u "$BENCH" --model "$model" > "$log" 2>&1
    rc=$?
    echo "[$(date '+%H:%M:%S')] $slug exit=$rc"
    if [ $rc -ne 0 ]; then
        echo "[$(date '+%H:%M:%S')] $slug FAILED — last 30 lines:"
        tail -30 "$log"
    fi
done
echo "[$(date '+%H:%M:%S')] All three runs complete"
