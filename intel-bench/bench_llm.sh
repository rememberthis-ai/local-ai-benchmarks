#!/usr/bin/env bash
# LLM ctx sweep on Intel via ollama. Mirrors experiments/swiftlm/ctx_sweep.py
# methodology but targets ollama's /api/generate instead of SwiftLM.
set -uo pipefail
cd "$(dirname "$0")"

# Phase 1 (original baseline) + Phase 2 (extended LLM coverage 2026-05-14).
# Phase 2 adds Gemma 4 edge variants — these are the "newest small LLMs"
# released ~1 week before this bench. Direct comparison vs llama3.2 + gemma3.
LLMS=(
  # Phase 1 — already benched, re-runs OK if results dir is fresh:
  "qwen3:1.7b"
  "llama3.2:1b"
  "llama3.2:3b"
  "gemma3:4b"
  "qwen3:8b"
  # Phase 2 — newer candidates:
  "gemma4:e2b"       # edge 2.3B effective; expected drop-in for gemma3:4b
  "gemma4:e4b"       # edge 4.5B effective; long-context candidate
)

SIZES=(4000 8000 16000 32000)

# Reuse the dreamer prompt from the swiftlm bench (build it if missing)
PROMPT_FILE=../swiftlm/dreamer_prompt.txt
if [ ! -f "$PROMPT_FILE" ]; then
  echo "[$(date +%H:%M:%S)] dreamer_prompt.txt not found, building it…"
  (cd ../swiftlm && python3 build_dreamer_prompt.py --target-tokens 40000)
fi

mkdir -p results
SUMMARY=results/llm-summary.md
echo "# Intel LLM ctx sweep" > "$SUMMARY"
echo "" >> "$SUMMARY"
echo "Run: $(date)" >> "$SUMMARY"
echo "Hardware: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'unknown') / $(sysctl -n hw.memsize 2>/dev/null | awk '{print $1/1024/1024/1024 " GB"}')" >> "$SUMMARY"
echo "" >> "$SUMMARY"
echo "| Model | 4K decode | 8K decode | 16K decode | 32K decode | Notes |" >> "$SUMMARY"
echo "|---|---|---|---|---|---|" >> "$SUMMARY"

for LLM in "${LLMS[@]}"; do
  SLUG=$(echo "$LLM" | tr ':/' '_')
  echo "[$(date +%H:%M:%S)] === $LLM ==="
  python3 ctx_sweep_ollama.py "$LLM" --sizes "${SIZES[@]}" --prompt-file "$PROMPT_FILE" --out-dir results 2>&1 | tee -a results/raw-$SLUG.log

  # Pull tok/s out of the per-model result file for the summary
  RESULT_MD=$(ls -t results/ctxsweep-ollama-$SLUG-*.md 2>/dev/null | head -1)
  if [ -n "$RESULT_MD" ]; then
    LINE_4K=$(grep -E "^\| 4,000 " "$RESULT_MD" | head -1)
    LINE_8K=$(grep -E "^\| 8,000 " "$RESULT_MD" | head -1)
    LINE_16K=$(grep -E "^\| 16,000 " "$RESULT_MD" | head -1)
    LINE_32K=$(grep -E "^\| 32,000 " "$RESULT_MD" | head -1)
    extract() { echo "$1" | awk -F'|' '{print $6}' | tr -d ' '; }
    printf "| %s | %s | %s | %s | %s | see %s |\n" \
      "$LLM" "$(extract "$LINE_4K")" "$(extract "$LINE_8K")" \
      "$(extract "$LINE_16K")" "$(extract "$LINE_32K")" \
      "$(basename "$RESULT_MD")" >> "$SUMMARY"
  fi

  # Force-unload between models (the keep_alive=0 gotcha from the main post)
  curl -s "${OLLAMA_HOST_URL:-http://localhost:11434}/api/generate" -d "{\"model\":\"$LLM\",\"keep_alive\":0}" > /dev/null
  sleep 3
done

echo ""
echo "[$(date +%H:%M:%S)] Done. Summary: $SUMMARY"
cat "$SUMMARY"
