#!/usr/bin/env bash
# Sideload moondream3-preview into ollama from HuggingFace.
#
# moondream3 is a 9B-total / 2B-active MoE — inference cost ≈ moondream2's
# 1.8B because only 2B params activate per token. As of 2026-05 it's not in
# the official ollama library yet, so we pull GGUF + mmproj quants from
# HuggingFace and register a local Modelfile.
#
# Ollama 0.5+ supports `ollama pull hf.co/<repo>` directly for GGUFs that
# include all required files (template, params, etc.). For moondream3 we
# need the mmproj (vision-projector) sidecar, so we do a manual fetch.
#
# Run after `pull_models.sh phase2`. ~5 GB download.
set -euo pipefail
cd "$(dirname "$0")"

# Adjust the repo if the community quants move. As of 2026-05 the canonical
# preview is at moondream/moondream3-preview; community Q4 quants are at
# bartowski/moondream3-preview-GGUF (verify before running).
HF_REPO="${HF_REPO:-bartowski/moondream3-preview-GGUF}"
QUANT="${QUANT:-Q4_K_M}"
MODEL_FILE="${MODEL_FILE:-moondream3-preview-${QUANT}.gguf}"
MMPROJ_FILE="${MMPROJ_FILE:-mmproj-moondream3-preview-Q8_0.gguf}"
WORK="$HOME/.ollama-sideload/moondream3"
mkdir -p "$WORK"

curl_dl() {
  local url=$1 dest=$2
  if [ -f "$dest" ] && [ -s "$dest" ]; then
    echo "  ✓ $dest already present ($(du -h "$dest" | cut -f1))"
    return
  fi
  echo "  → fetching $url"
  curl -L --fail --retry 3 -o "$dest" "$url" || { echo "  ❌ download failed"; return 1; }
}

echo "[$(date +%H:%M:%S)] === sideload moondream3-preview ($QUANT) ==="
echo "Target HF repo: https://huggingface.co/$HF_REPO"
echo "Work dir: $WORK"
echo ""
echo "If these URLs 404 (community quants move around), open:"
echo "  https://huggingface.co/$HF_REPO/tree/main"
echo "and update MODEL_FILE / MMPROJ_FILE env vars accordingly."
echo ""

BASE="https://huggingface.co/$HF_REPO/resolve/main"
curl_dl "$BASE/$MODEL_FILE" "$WORK/model.gguf"
curl_dl "$BASE/$MMPROJ_FILE" "$WORK/mmproj.gguf"

cat > "$WORK/Modelfile" <<EOF
FROM $WORK/model.gguf
# Vision projector (multimodal sidecar required for image input)
PARAMETER mmproj $WORK/mmproj.gguf

TEMPLATE """{{ if .System }}<system>
{{ .System }}
</system>

{{ end }}{{ if .Prompt }}<user>
{{ .Prompt }}
</user>

{{ end }}<assistant>
{{ .Response }}"""

PARAMETER temperature 0.0
PARAMETER stop "<user>"
PARAMETER stop "<assistant>"
EOF

echo ""
echo "[$(date +%H:%M:%S)] Registering with ollama as moondream3:preview…"
OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:21434}" \
  ollama create moondream3:preview -f "$WORK/Modelfile"

echo ""
echo "[$(date +%H:%M:%S)] Verifying:"
OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:21434}" ollama list | grep moondream3 || {
  echo "❌ moondream3:preview did not register — check the Modelfile and re-run."
  exit 1
}

echo ""
echo "Done. bench_captioning.sh will pick up moondream3:preview automatically."
