#!/usr/bin/env bash
# Pre-pull all bench candidates. Run this once.
# Phase 1 (~10 GB): the original 8-model baseline.
# Phase 2 (~14 GB): newer VLMs + LLMs added 2026-05-14 for the extended matrix.
set -euo pipefail

# --- Phase 1: baseline (May 2026 first-pass) -------------------------------
PHASE1_VLMS=(
  "moondream:1.8b"
  "llava:7b"
  "gemma3:4b"
  "minicpm-v:8b"
)
PHASE1_LLMS=(
  "qwen3:1.7b"
  "llama3.2:1b"
  "llama3.2:3b"
  "gemma3:4b"
  "qwen3:8b"
)

# --- Phase 2: extended (newer models we missed) ----------------------------
# VLMs to add: Qwen3-VL family + Qwen2.5-VL 3b (we tested zero Qwen VLMs).
# LLMs to add: Gemma 4 edge variants (replace older Gemma 3 in long-context).
# Note: moondream3-preview is sideloaded separately via sideload_moondream3.sh
# because it's not in the official ollama library yet.
PHASE2_VLMS=(
  "qwen3-vl:2b"      # 1.9 GB — direct moondream replacement candidate
  "qwen3-vl:4b"      # 3.3 GB — replaces failed gemma3:4b
  "qwen2.5vl:3b"     # 3.2 GB — older Qwen-VL, edge-AI tuned
)
PHASE2_LLMS=(
  "gemma4:e2b"       # 7.2 GB — edge 2.3B effective
  "gemma4:e4b"       # 9.6 GB — edge 4.5B effective
)

PHASE="${1:-all}"   # all | phase1 | phase2

case "$PHASE" in
  phase1) MODELS=("${PHASE1_VLMS[@]}" "${PHASE1_LLMS[@]}") ;;
  phase2) MODELS=("${PHASE2_VLMS[@]}" "${PHASE2_LLMS[@]}") ;;
  all)    MODELS=("${PHASE1_VLMS[@]}" "${PHASE1_LLMS[@]}" "${PHASE2_VLMS[@]}" "${PHASE2_LLMS[@]}") ;;
  *)      echo "usage: $0 [all|phase1|phase2]"; exit 2 ;;
esac

# Dedup (gemma3:4b appears in both VLM and LLM lists; gemma4 only in LLM)
MODELS=($(printf "%s\n" "${MODELS[@]}" | awk '!seen[$0]++'))

echo "About to pull ${#MODELS[@]} ollama models (phase=$PHASE)."
for m in "${MODELS[@]}"; do echo "  - $m"; done
echo ""

for m in "${MODELS[@]}"; do
  echo "[$(date +%H:%M:%S)] === pulling $m ==="
  ollama pull "$m"
done

echo ""
echo "[$(date +%H:%M:%S)] All models pulled. Available locally:"
ollama list
