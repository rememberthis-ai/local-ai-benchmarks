#!/usr/bin/env bash
# bench-chain-silicon.sh — single-entry, unattended Apple Silicon bench chain.
#
# Mirrors what experiments/intel-bench/ does for Intel: run all the candidate
# VLMs through the captioning bench, all the candidate LLMs through the
# context-size sweep, and write an aggregate summary at the end. Designed to
# run overnight without supervision.
#
# Usage:
#   ./bench-chain-silicon.sh            # full chain (preflight + pull + VLM + LLM + summary)
#   ./bench-chain-silicon.sh vlm-only   # skip LLM phase
#   ./bench-chain-silicon.sh llm-only   # skip VLM phase
#   ./bench-chain-silicon.sh preflight  # only run the readiness checks, then exit
#
#   ./bench-chain-silicon.sh > /tmp/bench-chain-silicon.log 2>&1 &
#
# Exit codes:
#   0  success
#   1  generic failure
#   2  preflight failed (fix and re-run)
#
# Gotchas this script encodes (see gotchas/ in the public bench repo):
#   - low-power-mode-throttling.md  : M1 Max GPU throttled 5–6× by Low Power Mode
#   - keep-alive-eviction.md        : ollama holds GPU/unified memory across runs;
#                                     force-unload before SwiftLM benches
#
# Constraints:
#   - No extrapolation. If a model can't be benched, it's logged as
#     MODEL_NOT_AVAILABLE / LOAD_ERROR / TIMEOUT in the summary.
#   - Additive only. Calls existing sweep_vlm_phase2.sh + sweep_llm_rebench.sh
#     so any improvements there propagate.

set -uo pipefail
cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"

MODE="${1:-full}"

# ---- Wall-clock caps -------------------------------------------------------
# Per-stage caps so a wedged SwiftLM doesn't eat the whole night.
PREFLIGHT_TIMEOUT=120         # 2 min
PULL_TIMEOUT=$((4 * 60 * 60)) # 4 h — slow Hub on first run
VLM_TIMEOUT=$((10 * 60 * 60)) # 10 h — Phase-2 set ~6–8 h, plus headroom
LLM_TIMEOUT=$((8 * 60 * 60))  # 8 h — six medium/large models × 4 ctx points

# ---- Candidate models ------------------------------------------------------
# Pre-pulled via huggingface-cli before any SwiftLM run. Edit here when
# upstream MLX ids move (community quants rename frequently).
# Source of truth for VLM ids: sweep_vlm_phase2.sh
# Source of truth for LLM ids: sweep_llm_rebench.sh
VLM_MODELS=(
  "mlx-community/Qwen3-VL-2B-Instruct-4bit"
  "mlx-community/Qwen3-VL-4B-Instruct-4bit"
  "mlx-community/gemma-4-e2b-it-4bit"
  "mlx-community/Qwen2.5-VL-3B-Instruct-4bit"
  "mlx-community/InternVL3-2B-4bit"
  "mlx-community/InternVL3-8B-MLX-4bit"
)
LLM_MODELS=(
  "mlx-community/Phi-4-mini-instruct-4bit"
  "mlx-community/Llama-3.2-3B-Instruct-4bit"
  "mlx-community/Qwen3-4B-4bit"
  "mlx-community/Qwen3-8B-4bit"
  "mlx-community/gpt-oss-20b-MXFP4-Q4"
  "mlx-community/Qwen3.6-35B-A3B-4bit"
  "mlx-community/gemma-4-26b-a4b-it-4bit"
  "mlx-community/Qwen3-Coder-30B-A3B-Instruct-MLX-4bit"
  "mlx-community/Qwen3-Next-80B-A3B-Instruct-4bit"
)

LOG_DIR=/tmp
CHAIN_LOG="$LOG_DIR/bench-chain-silicon.log"
REPORT="$LOG_DIR/bench-chain-silicon-report.log"

log() {
  printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$CHAIN_LOG"
}

fail() {
  # $1 = message, $2 = optional exit code (default 1)
  local msg="$1"
  local code="${2:-1}"
  log "FATAL: $msg"
  exit "$code"
}

# macOS lacks GNU `timeout`. Wrap commands in a watcher-PID timeout.
# If the watcher fires, we also SIGKILL any SwiftLM child that the wrapped
# sweep may have spawned — otherwise a wedged SwiftLM keeps holding GPU
# memory and the next phase starts already-degraded.
run_capped() {
  local secs=$1; shift
  "$@" &
  local pid=$!
  (
    sleep "$secs"
    if kill -0 "$pid" 2>/dev/null; then
      kill -TERM "$pid" 2>/dev/null
      sleep 5
      kill -9 "$pid" 2>/dev/null
      pkill -9 -x SwiftLM 2>/dev/null || true
    fi
  ) >/dev/null 2>&1 &
  local watcher=$!
  wait "$pid" 2>/dev/null
  local rc=$?
  kill "$watcher" 2>/dev/null || true
  wait "$watcher" 2>/dev/null || true
  return "$rc"
}

# Always clean up SwiftLM on exit so a Ctrl-C or chain failure doesn't leave
# a 16+ GB MLX process holding unified memory.
cleanup_on_exit() {
  pkill -x SwiftLM 2>/dev/null || true
  sleep 1
  pkill -9 -x SwiftLM 2>/dev/null || true
}
trap cleanup_on_exit EXIT

# ---- Preflight -------------------------------------------------------------
preflight() {
  log "=== preflight checks ==="

  # 1. uname -m must be arm64
  local arch
  arch="$(uname -m)"
  if [ "$arch" != "arm64" ]; then
    fail "this chain targets Apple Silicon (arm64), but uname -m = '$arch'. Run experiments/intel-bench/bench-chain-intel.sh on Intel rigs." 2
  fi
  log "  arch:        $arch ✓"

  # 2. Power Mode = High. M1 Max GPU throttles 5–6× under Low Power Mode and
  #    almost shipped wrong numbers once. See gotchas/low-power-mode-throttling.md.
  local lpm
  lpm="$(pmset -g 2>/dev/null | awk '/lowpowermode/ {print $2}')"
  if [ "$lpm" != "0" ]; then
    fail "Low Power Mode is engaged (pmset lowpowermode='$lpm'). M1 Max GPU is throttled 5–6× in LPM. Set Power Mode to High in System Settings > Battery, or run: sudo pmset -a lowpowermode 0. See gotchas/low-power-mode-throttling.md in the local-ai-benchmarks repo." 2
  fi
  log "  power mode:  High (lowpowermode=0) ✓"

  # 3. SwiftLM binary present + executable
  if [ ! -x "$SCRIPT_DIR/SwiftLM" ]; then
    cat <<EOF
ERROR: SwiftLM binary not found at $SCRIPT_DIR/SwiftLM

The SwiftLM binary is a release artifact and is NOT checked into this repo
(see experiments/swiftlm/.gitignore: SwiftLM*).

Install one of:
  1. Download a release tarball from the mlx-swift-lm project and extract
     'SwiftLM' here. (Verify upstream releases; see SUMMARY.md for the b644
     version used historically.)
  2. Build from source: clone https://github.com/ml-explore/mlx-swift-examples
     (or the SwiftLM fork) and copy the produced binary to
     $SCRIPT_DIR/SwiftLM
  3. Symlink an existing local copy:
       ln -s /path/to/SwiftLM $SCRIPT_DIR/SwiftLM

Then re-run this chain.
EOF
    exit 2
  fi
  log "  SwiftLM:     $SCRIPT_DIR/SwiftLM ✓"

  # 4. huggingface-cli on PATH (needed for model pulls)
  if ! command -v huggingface-cli >/dev/null 2>&1; then
    fail "huggingface-cli not found on PATH. Install: pip install -U 'huggingface_hub[cli]'  (or: brew install huggingface-cli)" 2
  fi
  log "  hf cli:      $(command -v huggingface-cli) ✓"

  # 5. python3
  if ! command -v python3 >/dev/null 2>&1; then
    fail "python3 not found on PATH" 2
  fi
  log "  python3:     $(command -v python3) ✓"

  # 6. dreamer_prompt.txt or the builder
  if [ ! -f "$SCRIPT_DIR/dreamer_prompt.txt" ]; then
    if [ -f "$SCRIPT_DIR/build_dreamer_prompt.py" ]; then
      log "  dreamer_prompt.txt missing; will build during chain (requires RT registry SQLite)"
    else
      fail "dreamer_prompt.txt missing AND build_dreamer_prompt.py missing — cannot proceed with LLM phase. Skip with: $0 vlm-only" 2
    fi
  else
    local sz
    sz="$(wc -c < "$SCRIPT_DIR/dreamer_prompt.txt" | tr -d ' ')"
    log "  dreamer_prompt.txt: ${sz} bytes ✓"
  fi

  # 7. photo set JSON
  local photo_set="$SCRIPT_DIR/../captioning-bench/photo_set_phase2.json"
  if [ ! -f "$photo_set" ]; then
    fail "photo set JSON missing: $photo_set
This is per-user (built from a real Photos library) and gitignored.
Build with experiments/captioning-bench/bench.py helpers or copy from a prior run.
Skip the VLM phase if you only want LLM numbers: $0 llm-only" 2
  fi
  log "  photo set:   $(basename "$photo_set") ✓"

  # 8. RT Photos HTTP endpoint (needed for bench_swiftlm_vlm.py to fetch photos)
  if ! curl -sf --max-time 5 http://127.0.0.1:21436/health >/dev/null 2>&1; then
    log "  WARN: http://127.0.0.1:21436/health not reachable. Remember This app needs to be running"
    log "        (its daemon serves photos at /photos/:uuid). Launch via:"
    log "          open -a 'Remember This'"
    log "        Continuing — VLM bench will fail per-photo if endpoint stays down."
  else
    log "  RT photos:   127.0.0.1:21436 ✓"
  fi

  # 9. ollama (optional — only used to force-unload before SwiftLM runs)
  if curl -sf --max-time 2 http://127.0.0.1:21434/api/version >/dev/null 2>&1; then
    log "  ollama:      127.0.0.1:21434 ✓ (will force-unload between models)"
    OLLAMA_AVAILABLE=1
  else
    log "  ollama:      not running (skipping force-unload calls — fine on Apple Silicon)"
    OLLAMA_AVAILABLE=0
  fi

  log "=== preflight OK ==="
}

# ---- Model pulls -----------------------------------------------------------
# Pull MLX models up front so the bench itself measures inference only, not
# Hub download time. Self-skips models whose HF id 404s (community quants
# move) — those will surface as MODEL_NOT_AVAILABLE in the sweep summary.
pull_models() {
  local label="$1"; shift
  local models=("$@")
  log "=== pulling MLX models for $label (${#models[@]} candidates) ==="
  for MODEL in "${models[@]}"; do
    log "  pulling $MODEL"
    # Use snapshot download via huggingface-cli. --quiet keeps the chain log clean;
    # the per-model details land in the cache log. timeout is per-model, not whole-pull.
    if ! run_capped 1800 huggingface-cli download "$MODEL" --quiet >> "$CHAIN_LOG" 2>&1; then
      local rc=$?
      log "    WARN: pull failed for $MODEL (rc=$rc) — sweep will record MODEL_NOT_AVAILABLE if it can't load"
    fi
  done
  log "=== $label pull done ==="
}

# ---- ollama force-unload ---------------------------------------------------
# keep_alive=0 evicts any held model. Apple Silicon shares unified memory
# between ollama and SwiftLM, so leftover ollama state silently halves
# SwiftLM throughput. See gotchas/keep-alive-eviction.md.
force_unload_ollama() {
  [ "${OLLAMA_AVAILABLE:-0}" = "1" ] || return 0
  # Loop over every tag currently loaded
  local tags
  tags=$(curl -s --max-time 3 http://127.0.0.1:21434/api/ps 2>/dev/null \
    | python3 -c "import sys,json;
try:
  d=json.load(sys.stdin)
  [print(m.get('name','')) for m in d.get('models',[])]
except Exception:
  pass" 2>/dev/null)
  for tag in $tags; do
    [ -n "$tag" ] || continue
    curl -s --max-time 2 http://127.0.0.1:21434/api/generate \
      -d "{\"model\":\"$tag\",\"keep_alive\":0}" > /dev/null 2>&1 || true
  done
}

# ---- VLM phase -------------------------------------------------------------
run_vlm() {
  log "=== VLM phase starting (cap ${VLM_TIMEOUT}s) ==="
  force_unload_ollama
  if [ ! -x "$SCRIPT_DIR/sweep_vlm_phase2.sh" ]; then
    fail "sweep_vlm_phase2.sh not found or not executable"
  fi
  # Hand off to the existing per-model loop. It already handles SwiftLM
  # start/stop, ready-wait, load-error skip, and per-model result rows.
  run_capped "$VLM_TIMEOUT" "$SCRIPT_DIR/sweep_vlm_phase2.sh"
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    log "  WARN: VLM phase exited rc=$rc (likely per-stage timeout; partial results retained)"
  fi
  log "=== VLM phase done ==="
}

# ---- LLM phase -------------------------------------------------------------
run_llm() {
  log "=== LLM phase starting (cap ${LLM_TIMEOUT}s) ==="
  force_unload_ollama
  if [ ! -x "$SCRIPT_DIR/sweep_llm_rebench.sh" ]; then
    fail "sweep_llm_rebench.sh not found or not executable"
  fi
  run_capped "$LLM_TIMEOUT" "$SCRIPT_DIR/sweep_llm_rebench.sh"
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    log "  WARN: LLM phase exited rc=$rc (likely per-stage timeout; partial results retained)"
  fi
  log "=== LLM phase done ==="
}

# ---- Aggregate summary -----------------------------------------------------
# Mirrors intel-bench/results/captioning-summary.md + llm-summary.md.
# Reads the per-model results files written by the sub-sweeps.
write_summary() {
  log "=== writing aggregate summary ==="
  mkdir -p "$SCRIPT_DIR/results-chain"
  local out="$SCRIPT_DIR/results-chain/silicon-summary.md"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  {
    echo "# Apple Silicon bench chain — aggregate summary"
    echo ""
    echo "- Run: $ts"
    echo "- Host: $(uname -mrs) / $(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.0f GB", $1/1073741824}')"
    echo "- CPU: $(sysctl -n machdep.cpu.brand_string 2>/dev/null)"
    echo "- Power Mode: High (verified at preflight)"
    echo "- Chain script: bench-chain-silicon.sh"
    echo ""
    echo "## VLM captioning"
    echo ""
    if [ -f "$SCRIPT_DIR/results-vlm-phase2/SUMMARY.md" ]; then
      echo "Per-model rows from \`results-vlm-phase2/SUMMARY.md\`:"
      echo ""
      # Pull just the table portion (skip the doc body around it)
      awk '/^\| Model \|/{flag=1} flag{print} /^$/ && flag>1 {exit} flag{flag++}' \
        "$SCRIPT_DIR/results-vlm-phase2/SUMMARY.md" 2>/dev/null \
        || echo "  (could not parse table — see results-vlm-phase2/SUMMARY.md directly)"
    else
      echo "_No VLM results found at \`results-vlm-phase2/SUMMARY.md\`._"
    fi
    echo ""
    echo "## LLM context-size sweep"
    echo ""
    if compgen -G "$SCRIPT_DIR/results-llm/ctxsweep-*.md" > /dev/null; then
      echo "| Model | 4K decode | 8K decode | 16K decode | 32K decode | 48K decode | 64K decode | Source |"
      echo "|---|---|---|---|---|---|---|---|"
      # Sort by mtime descending, dedupe by model name (keep most recent per model)
      seen=""
      for f in $(ls -t "$SCRIPT_DIR"/results-llm/ctxsweep-*.md 2>/dev/null); do
        local model
        model=$(awk -F'— ' '/^# Context-size sweep/{print $2; exit}' "$f" | tr -d '`')
        [ -z "$model" ] && continue
        case " $seen " in *" $model "*) continue;; esac
        seen="$seen $model"
        # Extract decode tok/s for each ctx size from the per-model table
        extract_ctx() {
          local size_label="$1"
          grep -E "^\| ${size_label} " "$f" 2>/dev/null \
            | head -1 \
            | awk -F'|' '{print $6}' \
            | tr -d ' '
        }
        local d4=$(extract_ctx "4,000")
        local d8=$(extract_ctx "8,000")
        local d16=$(extract_ctx "16,000")
        local d32=$(extract_ctx "32,000")
        local d48=$(extract_ctx "48,000")
        local d64=$(extract_ctx "64,000")
        printf "| %s | %s | %s | %s | %s | %s | %s | %s |\n" \
          "$model" "${d4:-—}" "${d8:-—}" "${d16:-—}" "${d32:-—}" "${d48:-—}" "${d64:-—}" \
          "$(basename "$f")"
      done
    else
      echo "_No LLM results found at \`results-llm/ctxsweep-*.md\`._"
    fi
    echo ""
    echo "## Models considered"
    echo ""
    echo "### VLMs"
    for m in "${VLM_MODELS[@]}"; do echo "- \`$m\`"; done
    echo ""
    echo "### LLMs"
    for m in "${LLM_MODELS[@]}"; do echo "- \`$m\`"; done
    echo ""
    echo "## Notes"
    echo ""
    echo "- Numbers without a value: model wasn't benched (skipped, load error, or timeout). Not extrapolated."
    echo "- Per-model raw outputs and SwiftLM logs in \`/tmp/swiftlm-*.log\` and \`results-vlm-phase2/\` / \`results-llm/\`."
    echo "- Power-mode gotcha: see \`gotchas/low-power-mode-throttling.md\` in local-ai-benchmarks."
    echo "- ollama keep-alive gotcha: see \`gotchas/keep-alive-eviction.md\` in local-ai-benchmarks."
  } > "$out"
  log "  summary: $out"
  log "=== summary done ==="
}

# ---- Morning report --------------------------------------------------------
morning_report() {
  {
    echo "================================================================"
    echo " Apple Silicon bench chain — morning report"
    echo " Finished: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "================================================================"
    echo ""
    echo "Mode: $MODE"
    echo "Chain log: $CHAIN_LOG"
    echo ""
    echo "--- Aggregate summary ---"
    if [ -f "$SCRIPT_DIR/results-chain/silicon-summary.md" ]; then
      cat "$SCRIPT_DIR/results-chain/silicon-summary.md"
    else
      echo "(no summary written)"
    fi
    echo ""
    echo "--- Last 30 lines of chain log ---"
    tail -30 "$CHAIN_LOG" 2>/dev/null
  } > "$REPORT"
  log "morning report: $REPORT"
}

# ---- Main ------------------------------------------------------------------
: > "$CHAIN_LOG"
log "=== bench-chain-silicon.sh starting (mode=$MODE) ==="

case "$MODE" in
  preflight)
    preflight
    log "preflight-only mode — exiting"
    exit 0
    ;;
  full|vlm-only|llm-only)
    preflight
    ;;
  *)
    fail "unknown mode '$MODE'. Use: full | vlm-only | llm-only | preflight" 2
    ;;
esac

if [ "$MODE" = "full" ] || [ "$MODE" = "vlm-only" ]; then
  pull_models VLM "${VLM_MODELS[@]}"
  run_vlm
fi

if [ "$MODE" = "full" ] || [ "$MODE" = "llm-only" ]; then
  pull_models LLM "${LLM_MODELS[@]}"
  run_llm
fi

write_summary
morning_report

log "=== bench-chain-silicon.sh DONE ==="
echo ""
echo "Morning report: $REPORT"
echo "Aggregate summary: $SCRIPT_DIR/results-chain/silicon-summary.md"
