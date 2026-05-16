#!/usr/bin/env bash
# Run llama-bench (llama.cpp upstream) on the same GGUF files ollama already
# has, with -ngl 99 to push layers onto the discrete GPU. Goal: characterise
# the Radeon Pro 560X (4 GB VRAM, Metal 2, Polaris) on this 2018 Intel
# MacBook Pro and contrast against the CPU-only ollama numbers in
# llm-summary.md.
#
# Why this script exists: ollama 0.21.0 ignores the AMD discrete GPU on Intel
# Macs (open issue ollama/ollama#13591). Bypass via llama.cpp standalone.
#
# Important quirk discovered 2026-05-14: the AMD Bronze (Polaris) driver
# hangs in MTLIOAccelBuffer init during tg (token-generation) workloads.
# pp (prefill) completes cleanly. So we split pp and tg into separate
# invocations, each wrapped in a hard wall-clock cap, and ALWAYS save what
# pp produced even if tg wedges.
set -uo pipefail
cd "$(dirname "$0")"

LLAMA_BENCH="$(pwd)/llama.cpp/build/bin/llama-bench"
RESOLVER="$(pwd)/ollama-blob-resolver.py"

# Models that fit in 4 GB VRAM with room for KV cache.
# gemma3:4b is borderline; we still run it with -ngl 99 and let the driver
# split (it may fall back to partial offload).
MODELS=(
  "moondream:1.8b"   # 0.77 GB
  "llama3.2:1b"      # 1.23 GB
  "qwen3:1.7b"       # 1.27 GB
  "llama3.2:3b"      # 1.88 GB
  "gemma3:4b"        # 3.11 GB — borderline
  "gemma4:e2b"       # if installed via pull_models.sh phase2
)

# Per-stage wall-clock cap (seconds). Long enough for slow models, short
# enough that hangs don't burn 30+ minutes each.
PP_TIMEOUT=300
TG_TIMEOUT=180

# Bash run-with-timeout wrapper (macOS lacks GNU `timeout` by default).
run_capped() {
  local secs=$1; shift
  "$@" &
  local pid=$!
  ( sleep "$secs" && kill -9 "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local watcher=$!
  wait "$pid" 2>/dev/null
  local rc=$?
  kill "$watcher" 2>/dev/null || true
  wait "$watcher" 2>/dev/null || true
  return "$rc"
}

mkdir -p results
OUT=results/llm-gpu-summary.md
{
  echo "# Intel discrete-GPU LLM bench (llama.cpp standalone, Metal)"
  echo ""
  echo "Run: $(date)"
  echo "Hardware: $(sysctl -n machdep.cpu.brand_string) / $(sysctl -n hw.memsize | awk '{printf "%.0f GB\n", $1/1024/1024/1024}')"
  echo "GPU: Radeon Pro 560X 4 GB (Metal 2, Polaris) + Intel UHD 630 1.5 GB (Metal 3)"
  echo "llama.cpp: $(cd llama.cpp && git log -1 --format='%h %s' 2>/dev/null)"
  echo "Caps: pp ${PP_TIMEOUT}s, tg ${TG_TIMEOUT}s. Hangs are recorded as 'TIMEOUT'."
  echo ""
  echo "| Model | Size | pp512 (tok/s) | tg128 (tok/s) | Backend | Notes |"
  echo "|---|---|---|---|---|---|"
} > "$OUT"

# Parse mean tok/s from a llama-bench markdown row of the form:
#   | model... | size | params | backend | threads | pp512 | 38.94 ± 2.38 |
extract_meantps() {
  local raw=$1
  local test_name=$2  # "pp512" or "tg128"
  grep -E "^\|.* ${test_name} " "$raw" 2>/dev/null \
    | head -1 \
    | awk -F'|' '{print $(NF-1)}' \
    | awk '{print $1}'
}

for TAG in "${MODELS[@]}"; do
  SLUG=$(echo "$TAG" | tr ':/' '_')
  echo "[$(date +%H:%M:%S)] === $TAG ==="
  # Resolve GGUF blob path via the ollama manifest
  if ! BLOB_LINE=$(python3 "$RESOLVER" "$TAG" 2>/dev/null); then
    echo "  --- skipping $TAG (not installed via ollama) ---"
    printf "| %s | — | — | — | — | not installed (skip) |\n" "$TAG" >> "$OUT"
    continue
  fi
  read -r _ GGUF SIZE SIZEUNIT <<< "$BLOB_LINE"
  SIZE="${SIZE} ${SIZEUNIT}"
  echo "  blob=$GGUF ($SIZE)"

  PP_RAW="results/llm-gpu-raw-${SLUG}-pp.log"
  TG_RAW="results/llm-gpu-raw-${SLUG}-tg.log"

  # --- pp512 (prefill) — known to work on Polaris ---
  echo "  [$(date +%H:%M:%S)] pp512 (cap ${PP_TIMEOUT}s)…"
  run_capped "$PP_TIMEOUT" "$LLAMA_BENCH" \
    -m "$GGUF" -ngl 99 -p 512 -n 0 -t 8 -r 3 \
    > "$PP_RAW" 2>&1
  PP_RC=$?

  # --- tg128 (decode) — Polaris driver hangs here; cap aggressively ---
  echo "  [$(date +%H:%M:%S)] tg128 (cap ${TG_TIMEOUT}s)…"
  run_capped "$TG_TIMEOUT" "$LLAMA_BENCH" \
    -m "$GGUF" -ngl 99 -p 0 -n 128 -t 8 -r 1 \
    > "$TG_RAW" 2>&1
  TG_RC=$?

  # Extract numbers (mean tok/s)
  PP=$(extract_meantps "$PP_RAW" pp512)
  TG=$(extract_meantps "$TG_RAW" tg128)
  PP_NOTE="OK"; TG_NOTE="OK"
  [ "$PP_RC" -ne 0 ] && { [ -z "$PP" ] && PP="—"; PP_NOTE="rc=$PP_RC (timeout/crash)"; }
  [ "$TG_RC" -ne 0 ] && { [ -z "$TG" ] && TG="TIMEOUT"; TG_NOTE="rc=$TG_RC (timeout/crash)"; }
  PP=${PP:-—}; TG=${TG:-—}

  # Backend detection
  if grep -q 'GPU name.*AMD Radeon' "$PP_RAW" 2>/dev/null; then
    BACKEND=$(grep 'GPU name' "$PP_RAW" | head -1 | sed -E 's/.*GPU name:[[:space:]]*//')
  elif grep -q 'using device.*Metal' "$PP_RAW" 2>/dev/null; then
    BACKEND=$(grep 'using device' "$PP_RAW" | head -1 | sed 's/.*using device //')
  else
    BACKEND="check $PP_RAW"
  fi

  printf "| %s | %s | %s | %s | %s | pp=%s · tg=%s |\n" \
    "$TAG" "$SIZE" "$PP" "$TG" "$BACKEND" "$PP_NOTE" "$TG_NOTE" >> "$OUT"
  echo "  pp=$PP  tg=$TG  ($BACKEND)  pp_rc=$PP_RC tg_rc=$TG_RC"

  # Brief cooldown so the GPU driver gets a chance to reset between models
  sleep 5
done

echo ""
echo "[$(date +%H:%M:%S)] Done. Summary: $OUT"
cat "$OUT"
