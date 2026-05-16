#!/usr/bin/env bash
# bench-chain-intel.sh — single-entry, unattended Intel Mac bench chain.
#
# Wraps pull_models.sh + bench_captioning.sh + bench_llm.sh + bench_llm_gpu.sh
# into one overnight run. Same shape as ../swiftlm/bench-chain-silicon.sh so
# experiments/bench-all.sh can dispatch by `uname -m`.
#
# Usage:
#   ./bench-chain-intel.sh                  # full chain
#   ./bench-chain-intel.sh captioning-only  # skip LLM + GPU
#   ./bench-chain-intel.sh llm-only         # skip captioning + GPU
#   ./bench-chain-intel.sh no-gpu           # skip the Polaris GPU bench
#   ./bench-chain-intel.sh preflight        # readiness checks only
#
#   ./bench-chain-intel.sh > /tmp/bench-chain-intel.log 2>&1 &
#
# The individual bench_*.sh scripts already self-skip uninstalled models
# and write per-model summary rows, so this wrapper is mostly orchestration
# + a single morning report at the end.

set -uo pipefail
cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"

MODE="${1:-full}"

# Wall-clock caps per phase (seconds). bench_captioning.sh + bench_llm.sh
# are CPU-bound and slow; bench_llm_gpu.sh already has internal pp/tg caps
# but the outer cap protects against a model-loop wedge.
PULL_TIMEOUT=$((90 * 60))             # 90 min
CAPTIONING_TIMEOUT=$((7 * 60 * 60))   # 7 h
LLM_TIMEOUT=$((4 * 60 * 60))          # 4 h
GPU_TIMEOUT=$((90 * 60))              # 90 min — internal caps are 5 min + 3 min per model

LOG_DIR=/tmp
CHAIN_LOG="$LOG_DIR/bench-chain-intel.log"
REPORT="$LOG_DIR/bench-chain-intel-report.log"

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
run_capped() {
  local secs=$1; shift
  "$@" &
  local pid=$!
  ( sleep "$secs" && kill -TERM "$pid" 2>/dev/null && sleep 5 && kill -9 "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local watcher=$!
  wait "$pid" 2>/dev/null
  local rc=$?
  kill "$watcher" 2>/dev/null || true
  wait "$watcher" 2>/dev/null || true
  return "$rc"
}

preflight() {
  log "=== preflight checks ==="
  local arch
  arch="$(uname -m)"
  if [ "$arch" != "x86_64" ]; then
    fail "this chain targets Intel Macs (x86_64), but uname -m = '$arch'. Run experiments/swiftlm/bench-chain-silicon.sh on Apple Silicon." 2
  fi
  log "  arch:        $arch ✓"

  # ollama on RT-bundled port. Default ollama port is 11434; RT v0.10.x
  # bundles its own on 21434 to avoid colliding with user installs.
  export OLLAMA_HOST="${OLLAMA_HOST:-127.0.0.1:21434}"
  export OLLAMA_HOST_URL="${OLLAMA_HOST_URL:-http://127.0.0.1:21434}"
  if ! curl -sf --max-time 3 "$OLLAMA_HOST_URL/api/version" >/dev/null 2>&1; then
    fail "ollama not reachable at $OLLAMA_HOST_URL. Launch Remember This (its bundled ollama listens on :21434), or 'ollama serve' on whichever port matches OLLAMA_HOST_URL." 2
  fi
  log "  ollama:      $OLLAMA_HOST_URL ✓"

  # ollama binary on PATH (for pull_models.sh which uses `ollama pull`)
  if ! command -v ollama >/dev/null 2>&1; then
    # Try RT's bundled binary
    local bundled="/Applications/Remember This.app/Contents/Resources/ollama"
    if [ -x "$bundled" ]; then
      export PATH="/Applications/Remember This.app/Contents/Resources:$PATH"
      log "  ollama bin:  using RT-bundled $bundled ✓"
    else
      fail "ollama binary not found on PATH and RT's bundled copy missing at $bundled" 2
    fi
  else
    log "  ollama bin:  $(command -v ollama) ✓"
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    fail "python3 not found on PATH" 2
  fi
  log "  python3:     $(command -v python3) ✓"

  # photo set for captioning bench
  if [ ! -d "$SCRIPT_DIR/../captioning-bench/photos" ] && [ ! -d "$SCRIPT_DIR/photos" ]; then
    log "  WARN: no photo dir at ../captioning-bench/photos OR ./photos — captioning bench will abort. Skip with: $0 llm-only"
  else
    log "  photos:      present ✓"
  fi

  # llama.cpp build (only if GPU phase will run)
  if [ "$MODE" = "full" ] || [ "$MODE" = "gpu-only" ]; then
    if [ ! -x "$SCRIPT_DIR/llama.cpp/build/bin/llama-bench" ]; then
      log "  WARN: $SCRIPT_DIR/llama.cpp/build/bin/llama-bench not built — GPU phase will be skipped"
      log "        Build with the recipe in README.md ('Building llama.cpp')."
      GPU_BUILD_OK=0
    else
      log "  llama.cpp:   built ✓"
      GPU_BUILD_OK=1
    fi
  fi

  log "=== preflight OK ==="
}

run_pull() {
  log "=== pulling ollama models ==="
  run_capped "$PULL_TIMEOUT" "$SCRIPT_DIR/pull_models.sh" all
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    log "  WARN: pull exited rc=$rc — chain continues; missing models will be SKIPPED downstream"
  fi
  log "=== pull done ==="
}

run_captioning() {
  log "=== captioning bench (cap ${CAPTIONING_TIMEOUT}s) ==="
  run_capped "$CAPTIONING_TIMEOUT" "$SCRIPT_DIR/bench_captioning.sh"
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    log "  WARN: captioning bench exited rc=$rc"
  fi
}

run_llm() {
  log "=== LLM ctx sweep (cap ${LLM_TIMEOUT}s) ==="
  run_capped "$LLM_TIMEOUT" "$SCRIPT_DIR/bench_llm.sh"
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    log "  WARN: LLM bench exited rc=$rc"
  fi
}

run_gpu() {
  if [ "${GPU_BUILD_OK:-0}" != "1" ]; then
    log "=== GPU bench skipped (llama-bench not built) ==="
    return 0
  fi
  log "=== GPU bench (cap ${GPU_TIMEOUT}s) ==="
  run_capped "$GPU_TIMEOUT" "$SCRIPT_DIR/bench_llm_gpu.sh"
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    log "  WARN: GPU bench exited rc=$rc (Polaris driver hang on tg is recorded as TIMEOUT; see results/llm-gpu-summary.md)"
  fi
}

morning_report() {
  {
    echo "================================================================"
    echo " Intel Mac bench chain — morning report"
    echo " Finished: $(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "================================================================"
    echo ""
    echo "Mode: $MODE"
    echo "Chain log: $CHAIN_LOG"
    echo ""
    for f in \
      "$SCRIPT_DIR/results/captioning-summary.md" \
      "$SCRIPT_DIR/results/llm-summary.md" \
      "$SCRIPT_DIR/results/llm-gpu-summary.md"; do
      if [ -f "$f" ]; then
        echo "--- $(basename "$f") ---"
        cat "$f"
        echo ""
      fi
    done
    echo "--- Last 30 lines of chain log ---"
    tail -30 "$CHAIN_LOG" 2>/dev/null
  } > "$REPORT"
  log "morning report: $REPORT"
}

: > "$CHAIN_LOG"
log "=== bench-chain-intel.sh starting (mode=$MODE) ==="

case "$MODE" in
  preflight)
    preflight
    log "preflight-only mode — exiting"
    exit 0
    ;;
  full|captioning-only|llm-only|gpu-only|no-gpu)
    preflight
    ;;
  *)
    fail "unknown mode '$MODE'. Use: full | captioning-only | llm-only | gpu-only | no-gpu | preflight" 2
    ;;
esac

case "$MODE" in
  full)
    run_pull
    run_captioning
    run_llm
    run_gpu
    ;;
  captioning-only)
    run_pull
    run_captioning
    ;;
  llm-only)
    run_pull
    run_llm
    ;;
  gpu-only)
    run_gpu
    ;;
  no-gpu)
    run_pull
    run_captioning
    run_llm
    ;;
esac

morning_report
log "=== bench-chain-intel.sh DONE ==="
echo ""
echo "Morning report: $REPORT"
