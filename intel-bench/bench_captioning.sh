#!/usr/bin/env bash
# Captioning bench: each VLM captions the same 25 photos.
# Records per-photo wall time + first 80 chars of caption.
set -uo pipefail
cd "$(dirname "$0")"

# Phase 1 (original baseline) + Phase 2 (extended VLM coverage 2026-05-14).
# Phase 2 includes Qwen-VL family (we tested zero Qwen VLMs in phase 1) and
# a sideloaded moondream3 if it's been installed via sideload_moondream3.sh.
VLMS=(
  # Phase 1 — already benched but re-run is harmless if results dir is fresh:
  "moondream:1.8b"
  "llava:7b"
  "gemma3:4b"
  "minicpm-v:8b"
  # Phase 2 — newer candidates:
  "qwen3-vl:2b"      # smallest Qwen3-VL, direct moondream replacement candidate
  "qwen3-vl:4b"      # replaces gemma3:4b which failed at 4-5 min/photo
  "qwen2.5vl:3b"     # older Qwen-VL family for back-compat reference
  "moondream3:preview"  # MoE 9B/2B-active — needs sideload_moondream3.sh first
  # gemma4 edge models are natively multimodal (vision+audio+tools+thinking):
  "gemma4:e2b"       # edge 2.3B effective, image-capable
  "gemma4:e4b"       # edge 4.5B effective, image-capable
)

# Photo set: needs to exist as base64-encoded files in a sibling directory.
# We reuse the same 25 photos from the captioning-bench dir if available;
# otherwise the user can drop their own ./photos/*.jpg here.
PHOTOS_DIR="../captioning-bench/photos"
if [ ! -d "$PHOTOS_DIR" ]; then
  PHOTOS_DIR="./photos"
fi

mkdir -p results
SUMMARY=results/captioning-summary.md
echo "# Intel captioning bench" > "$SUMMARY"
echo "" >> "$SUMMARY"
echo "Run: $(date)" >> "$SUMMARY"
echo "Photos: $PHOTOS_DIR ($(ls "$PHOTOS_DIR" 2>/dev/null | wc -l | tr -d ' ') images)" >> "$SUMMARY"
echo "" >> "$SUMMARY"
echo "| Model | Photos | Avg/photo (s) | Total (min) | Notes |" >> "$SUMMARY"
echo "|---|---|---|---|---|" >> "$SUMMARY"

PROMPT="Describe this photo concisely in 1-2 sentences. Note any people, places, objects, text in the image, and the apparent setting."

for VLM in "${VLMS[@]}"; do
  SLUG=$(echo "$VLM" | tr ':/' '_')
  OUT="results/captioning-$SLUG.md"
  # Skip if this model isn't actually installed (e.g. moondream3 if user hasn't sideloaded yet)
  if ! curl -s "${OLLAMA_HOST_URL:-http://localhost:11434}/api/tags" \
       | python3 -c "import sys,json; [print(m['name']) for m in json.load(sys.stdin).get('models',[])]" \
       | grep -qx "$VLM"; then
    echo "[$(date +%H:%M:%S)] --- skipping $VLM (not installed) ---"
    printf "| %s | — | — | — | not installed (skip) |\n" "$VLM" >> "$SUMMARY"
    continue
  fi
  echo "[$(date +%H:%M:%S)] === $VLM ==="
  echo "# $VLM" > "$OUT"
  echo "" >> "$OUT"
  echo "| Photo | Wall (s) | First 80 chars |" >> "$OUT"
  echo "|---|---|---|" >> "$OUT"

  TOTAL_WALL=0
  COUNT=0
  shopt -s nullglob nocaseglob
  for IMG in "$PHOTOS_DIR"/*.{jpg,jpeg,png,heic}; do
    [ -e "$IMG" ] || continue
    NAME=$(basename "$IMG")
    # base64-encode for ollama API
    B64=$(base64 -i "$IMG" 2>/dev/null | tr -d '\n')

    T0=$(date +%s.%N)
    RESP=$(curl -s "${OLLAMA_HOST_URL:-http://localhost:11434}/api/generate" -d "{
      \"model\": \"$VLM\",
      \"prompt\": \"$PROMPT\",
      \"images\": [\"$B64\"],
      \"keep_alive\": 0,
      \"stream\": false
    }")
    T1=$(date +%s.%N)
    WALL=$(echo "$T1 - $T0" | bc)
    CAPTION=$(echo "$RESP" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r.get('response','')[:80].replace(chr(10),' ').replace('|','·'))" 2>/dev/null || echo "ERR")

    printf "| %s | %.1f | %s… |\n" "$NAME" "$WALL" "$CAPTION" >> "$OUT"
    echo "  $NAME: ${WALL}s — $CAPTION"

    TOTAL_WALL=$(echo "$TOTAL_WALL + $WALL" | bc)
    COUNT=$((COUNT + 1))
  done

  if [ "$COUNT" -gt 0 ]; then
    AVG=$(echo "scale=1; $TOTAL_WALL / $COUNT" | bc)
    MIN=$(echo "scale=1; $TOTAL_WALL / 60" | bc)
    printf "| %s | %d | %s | %s | see %s |\n" "$VLM" "$COUNT" "$AVG" "$MIN" "$OUT" >> "$SUMMARY"
  else
    printf "| %s | 0 | — | — | no photos found in %s |\n" "$VLM" "$PHOTOS_DIR" >> "$SUMMARY"
    echo "  ❌ No photos found in $PHOTOS_DIR — drop 25 JPGs there and re-run"
    exit 1
  fi
done

echo ""
echo "[$(date +%H:%M:%S)] Done. Summary: $SUMMARY"
cat "$SUMMARY"
