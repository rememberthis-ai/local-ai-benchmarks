#!/usr/bin/env bash
#
# Transcription bench for Remember This / My Transcriber.
#
# Sona (whisper.cpp wrapper) runs the matrix: {CPU, Metal} × {n=2, n=4}
# on a fixed audio clip. Reports seconds-to-transcribe-1-second-of-audio
# — the user-facing metric the blog post uses — for each arm.
#
# Default audio is the public-domain LibriVox Sherlock Holmes clip
# committed to this repo at audio/holmes_clip60.wav (60 s, 16 kHz mono
# WAV). Pull via git-lfs first, or override $CLIP with your own audio.
#
# To generate the same clip from scratch instead of pulling LFS:
#
#   curl -sLo /tmp/holmes_ch1.mp3 \
#     https://archive.org/download/adventures_holmes/adventureholmes_01_doyle_64kb.mp3
#   ffmpeg -y -i /tmp/holmes_ch1.mp3 -ss 0 -t 60 -ar 16000 -ac 1 audio/holmes_clip60.wav
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
# Resolve default clip relative to this script so it works from any cwd.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIP="${CLIP:-${SCRIPT_DIR}/audio/holmes_clip60.wav}"
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
  local cpu_log="/tmp/sona_${label}.cpu"
  : > "$cpu_log"
  local t0=$(date +%s.%N)
  "$SONA" transcribe \
    --gpu-device "$gpu" \
    --threads "$threads" \
    --language "$LANGUAGE" \
    "$MODEL" "$CLIP" \
    > "/tmp/sona_${label}.txt" 2> "/tmp/sona_${label}.stderr" &
  local sona_pid=$!
  # 1 Hz %cpu sampler — covers all sona threads.
  (
    while kill -0 "$sona_pid" 2>/dev/null; do
      ps -o %cpu= -p "$sona_pid" 2>/dev/null | awk '{printf "%s\n", $1}' >> "$cpu_log"
      sleep 1
    done
  ) &
  local sampler_pid=$!
  wait "$sona_pid"
  local sona_rc=$?
  kill "$sampler_pid" 2>/dev/null || true
  local t1=$(date +%s.%N)
  if [[ $sona_rc -ne 0 ]]; then
    echo "warning: sona exited with code $sona_rc (see /tmp/sona_${label}.stderr)" >&2
  fi
  local wall=$(awk -v t0="$t0" -v t1="$t1" 'BEGIN{printf "%.2f", t1-t0}')
  local sps=$(awk -v w="$wall" -v a="$AUDIO_S" 'BEGIN{printf "%.2f", w/a}')
  local cpu_avg cpu_peak n
  read cpu_avg cpu_peak n < <(awk '
    { sum += $1; if ($1 > peak) peak = $1; n++ }
    END {
      if (n == 0) print "0 0 0"
      else printf "%.0f %.0f %d\n", sum/n, peak, n
    }' "$cpu_log")
  echo "wall=${wall}s · audio=${AUDIO_S}s · sec-per-audio-sec=${sps} · cpu_avg=${cpu_avg}% · cpu_peak=${cpu_peak}% (n=${n})"
  echo "$label,$gpu,$threads,$wall,$sps,$cpu_avg,$cpu_peak,$n" >> "$RESULT_CSV"
}

echo "label,gpu_device,threads,wall_s,sec_per_audio_s,cpu_avg_pct,cpu_peak_pct,cpu_samples" > "$RESULT_CSV"

# `sona_bench_extended.sh` sources this file for the helpers but runs
# its own arm list — skip the default sweep when that's the case.
if [[ "${SONA_BENCH_DEFINE_ONLY:-0}" == "1" ]]; then
  return 0
fi

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
