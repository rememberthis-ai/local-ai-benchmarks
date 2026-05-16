#!/usr/bin/env bash
#
# Transcription bench for Remember This / My Transcriber.
#
# Sona (whisper.cpp wrapper) runs the matrix: {CPU, Metal} × {n=2, n=4}
# on a fixed audio clip. Reports seconds-to-transcribe-1-second-of-audio
# — the user-facing metric the blog post uses — for each arm.
#
# Default audio is a 60 s clip the caller provides at $CLIP. Generate
# one from any voice memo:
#
#   ffmpeg -y -i input.m4a -ss 0 -t 60 -ar 16000 -ac 1 /tmp/clip60.wav
#
# Default model is `ggml-large-v3-turbo.bin` from Remember This's data
# dir. Override via env vars (SONA, MODEL, CLIP, AUDIO_S).
#
# On Intel dual-GPU MacBooks (e.g. MBP15 2018 with Radeon Pro 560X),
# Metal lands on the **discrete** GPU regardless of `--gpu-device`
# index — macOS doesn't expose the iGPU as a separate Metal device
# when the dGPU is present. So the "Metal" arms below measure
# the dGPU on these machines, not the iGPU. On Apple Silicon Macs
# Metal goes to the unified-memory GPU.
#
# Pre-flight (run these before the bench):
#
#   1. Power Mode: `pmset -g custom | grep powermode` → 2 (High Power).
#      Or plug in AC if you can't toggle Power Mode on this machine.
#   2. No concurrent sona: `pgrep -fl sona` should be empty. Quit
#      My Transcriber + Remember This (or at least Stop Processing
#      in both) — a second sona process steals 100-200% CPU and
#      contaminates the result by 2-3×.
#   3. No daemon backfill: optionally `pkill -fl rememberthis-daemon`
#      if you want to be paranoid (the MCP server child is fine).
#
# Output: prints summary table to stdout + leaves a CSV at
# $RESULT_CSV (default /tmp/sona_bench.csv). Per-arm transcript text
# at /tmp/sona_${arm}.txt, stderr at /tmp/sona_${arm}.stderr — keep
# these PII-clean if sharing, the transcript contains your voice memo.
#
# Add new arms / hardware by appending `run_arm` calls below.

set -euo pipefail

# Configurable via env vars; defaults to RT install.
SONA="${SONA:-/Applications/Remember This.app/Contents/MacOS/sona}"
MODEL="${MODEL:-$HOME/Library/Application Support/RememberThis/models/ggml-large-v3-turbo.bin}"
CLIP="${CLIP:-/tmp/clip60.wav}"
AUDIO_S="${AUDIO_S:-60}"
RESULT_CSV="${RESULT_CSV:-/tmp/sona_bench.csv}"
LANGUAGE="${LANGUAGE:-en}"

if [[ ! -x "$SONA" ]]; then
  echo "error: sona binary not found at $SONA" >&2
  echo "  set SONA=/path/to/sona to override" >&2
  exit 1
fi
if [[ ! -f "$MODEL" ]]; then
  echo "error: whisper model not found at $MODEL" >&2
  echo "  set MODEL=/path/to/ggml-*.bin to override" >&2
  exit 1
fi
if [[ ! -f "$CLIP" ]]; then
  echo "error: audio clip not found at $CLIP" >&2
  echo "  generate one with ffmpeg first; see header" >&2
  exit 1
fi

if pgrep -fl "sona serve" >/dev/null 2>&1; then
  echo "warning: another sona is running — bench will be contaminated" >&2
  pgrep -fl "sona serve" | head -3 >&2
  echo "  quit My Transcriber + Remember This first, or set SKIP_PFLIGHT=1 to bypass" >&2
  if [[ "${SKIP_PFLIGHT:-0}" != "1" ]]; then
    exit 2
  fi
fi

run_arm() {
  local label="$1" gpu="$2" threads="$3"
  echo "=== ${label} (gpu_device=${gpu}, threads=${threads}) ==="
  local t0=$(date +%s.%N)
  "$SONA" transcribe \
    --gpu-device "$gpu" \
    --threads "$threads" \
    --language "$LANGUAGE" \
    "$MODEL" "$CLIP" \
    > "/tmp/sona_${label}.txt" 2> "/tmp/sona_${label}.stderr"
  local t1=$(date +%s.%N)
  local wall=$(awk -v t0="$t0" -v t1="$t1" 'BEGIN{printf "%.2f", t1-t0}')
  local sps=$(awk -v w="$wall" -v a="$AUDIO_S" 'BEGIN{printf "%.2f", w/a}')
  echo "wall=${wall}s · audio=${AUDIO_S}s · sec-per-audio-sec=${sps}"
  echo "$label,$gpu,$threads,$wall,$sps" >> "$RESULT_CSV"
}

echo "label,gpu_device,threads,wall_s,sec_per_audio_s" > "$RESULT_CSV"

# `--gpu-device -2` is sona's "force CPU" idiom (no valid index, falls
# back to CPU). `--gpu-device 0` is the first Metal device — on Intel
# dual-GPU it's the dGPU; on Apple Silicon it's the unified GPU.
run_arm cpu_n2     -2 2
run_arm cpu_n4     -2 4
run_arm metal_n2    0 2
run_arm metal_n4    0 4

echo ""
echo "=== Summary (sec-per-audio-sec, lower is faster) ==="
column -t -s, "$RESULT_CSV"
echo ""
echo "Hardware fingerprint:"
echo "  arch:     $(uname -m)"
echo "  cpu:      $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo 'unknown')"
echo "  ram:      $(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024)) GB"
echo "  pmset:    $(pmset -g custom 2>/dev/null | grep -E 'powermode' | head -1 | xargs || echo 'unknown')"
echo "  ac:       $(pmset -g batt 2>/dev/null | grep -oE "'(AC|Battery) Power'" | head -1 || echo 'unknown')"
echo "  model:    $(basename "$MODEL")"
echo "  audio:    ${AUDIO_S}s · $(basename "$CLIP")"
