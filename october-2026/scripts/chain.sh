#!/usr/bin/env bash
# October 2026 re-bench for the follow-up to the May post. One script, both Macs:
#
#   chain.sh llm        LLM context sweep, May parameters (num_ctx 70000, 200 tokens)
#   chain.sh caption    photo captioning, same 30 photos and prompt on every Mac
#   chain.sh mlx        captioning through SwiftLM (MLX), Apple Silicon only
#   chain.sh all        llm, caption, mlx (mlx skipped on Intel)
#
# Settings come from the environment so the same file runs on both Macs:
#   OLLAMA_HOST_URL  ollama to measure        (default http://127.0.0.1:11434)
#   LLM_MODELS       space-separated tags     (default: the May M1 Max set)
#   LLM_SIZES        prompt sizes in tokens   (default 4000 … 64000)
#   VLM_MODELS       ollama captioning tags
#   MLX_MODELS       mlx-community repos for SwiftLM
#   OUT              results folder           (default results/<host>-<date>)
#   NOTHINK_MODELS   captioning tags sent think:false (thinking models otherwise
#                    spend the whole token cap thinking and return EMPTY captions)
#   LOAD_MAX         wait before each model until the 1-min load average is below
#                    this and the GPU is idle (default: performance-core count)
#   WAIT_MAX_MIN     longest wait per model (default 45); past it the run goes
#                    ahead and the log says BUSY, so the number can be thrown away
#
# Before every model it logs load average, GPU residency (when sudo -n works)
# and pageouts, because a busy Mac is the usual reason a number is wrong.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP="$(cd "$HERE/.." && pwd)"
WHAT="${1:?usage: chain.sh llm|caption|mlx|all}"
OLLAMA_HOST_URL="${OLLAMA_HOST_URL:-http://127.0.0.1:11434}"
HOST="$(scutil --get LocalHostName 2>/dev/null || hostname)"
OUT="${OUT:-$HERE/results/$HOST-$(date +%Y%m%d)}"
PROMPT_FILE="${PROMPT_FILE:-$EXP/swiftlm/dreamer_prompt.txt}"
LLM_MODELS="${LLM_MODELS:-gemma4:e2b gemma4:26b gpt-oss:20b qwen3.6:35b qwen3-coder:30b}"
LLM_SIZES="${LLM_SIZES:-4000 8000 16000 32000 48000 64000}"
VLM_MODELS="${VLM_MODELS:-moondream:1.8b llava:7b gemma3:4b minicpm-v:8b openbmb/minicpm-v4.5 qwen2.5vl:3b qwen3-vl:2b-instruct qwen3-vl:4b-instruct qwen3-vl:8b-instruct gemma4:e2b gemma4:e4b}"
NOTHINK_MODELS="${NOTHINK_MODELS:-gemma4:e2b gemma4:e4b}"  # qwen3-vl ignores think:false; its -instruct tags do not think
LOAD_MAX="${LOAD_MAX:-$(sysctl -n hw.perflevel0.physicalcpu 2>/dev/null || sysctl -n hw.physicalcpu)}"
WAIT_MAX_MIN="${WAIT_MAX_MIN:-45}"
MLX_MODELS="${MLX_MODELS:-mlx-community/Qwen3-VL-2B-Instruct-4bit mlx-community/Qwen3-VL-4B-Instruct-4bit lmstudio-community/Qwen3-VL-8B-Instruct-MLX-4bit mlx-community/Qwen2.5-VL-3B-Instruct-4bit}"  # gemma-4 MLX never loads in SwiftLM b644
mkdir -p "$OUT"
LOG="$OUT/chain.log"
exec > >(tee -a "$LOG") 2>&1

say() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
state() {
  local a b gpu
  a=$(vm_stat | awk '/Pageouts/{print $NF}' | tr -d '.'); sleep 10
  b=$(vm_stat | awk '/Pageouts/{print $NF}' | tr -d '.')
  gpu=$(sudo -n powermetrics --samplers gpu_power -i 1000 -n 2 2>/dev/null | grep -m1 "GPU HW active residency" | awk '{print $5}')
  say "state: $(sysctl -n vm.loadavg) gpu=${gpu:-unknown} pageouts/10s=$((b-a)) power=$(pmset -g batt | head -1 | sed "s/.*'\(.*\)'.*/\1/")"
}
gpu_pct() {  # GPU active residency over 3 s; empty when powermetrics is unavailable (unknown, never "idle")
  sudo -n powermetrics --samplers gpu_power -i 1000 -n 3 2>/dev/null | awk '/GPU HW active residency/{gsub("%","",$5); s+=$5; n++} END{if(n) printf "%d", s/n}'
}
quiet() {  # wait until the Mac is quiet enough to measure; never refuses, but says BUSY
  local t0=$SECONDS l g
  while :; do
    l=$(sysctl -n vm.loadavg | awk '{print $2}'); g=$(gpu_pct)
    if awk -v l="$l" -v m="$LOAD_MAX" 'BEGIN{exit !(l<m)}' && { [ -z "$g" ] || [ "$g" -lt 15 ]; }; then
      say "quiet: load1=$l gpu=${g:-unknown}% after $(( (SECONDS-t0)/60 )) min"; return 0; fi
    if [ $((SECONDS-t0)) -ge $((WAIT_MAX_MIN*60)) ]; then
      say "BUSY: load1=$l gpu=${g:-unknown}% after ${WAIT_MAX_MIN} min, running anyway; treat this model's numbers as suspect"; return 0; fi
    sleep 60
  done
}
unload() {  # every model this ollama has resident, so models never share memory
  curl -s "$OLLAMA_HOST_URL/api/ps" | python3 -c 'import json,sys
for m in json.load(sys.stdin).get("models",[]): print(m["name"])' 2>/dev/null | while read -r n; do
    curl -s "$OLLAMA_HOST_URL/api/generate" -d "{\"model\":\"$n\",\"keep_alive\":0}" >/dev/null
  done
}

say "chain $WHAT on $HOST ($(sysctl -n machdep.cpu.brand_string), $(( $(sysctl -n hw.memsize) / 1073741824 )) GB), ollama $(curl -s "$OLLAMA_HOST_URL/api/version")"
caffeinate -i -s -w $$ &

run_llm() {
  for m in $LLM_MODELS; do
    unload; quiet; state
    say "llm $m"
    # shellcheck disable=SC2086
    OLLAMA_HOST_URL="$OLLAMA_HOST_URL" python3 "$EXP/intel-bench/ctx_sweep_ollama.py" "$m" \
      --sizes $LLM_SIZES --prompt-file "$PROMPT_FILE" --out-dir "$OUT/llm" \
      --max-tokens 200 --num-ctx 70000 --timeout 3600 || say "llm $m FAILED"
  done
  unload
}

run_caption() {
  for m in $VLM_MODELS; do
    unload; quiet; state
    local nt=""; case " $NOTHINK_MODELS " in *" $m "*) nt=--no-think;; esac
    say "caption ollama $m $nt"
    python3 "$EXP/captioning-bench/bench_v2.py" --backend ollama --host "$OLLAMA_HOST_URL" \
      --model "$m" --out "$OUT/caption" $nt ${PHOTOS:+--photos "$PHOTOS"} || say "caption $m FAILED"
  done
  unload
}

run_mlx() {
  [ "$(uname -m)" = arm64 ] || { say "mlx: skipped (not Apple Silicon)"; return; }
  local bin="$EXP/swiftlm/SwiftLM" port=5413
  for m in $MLX_MODELS; do
    unload; pkill -x SwiftLM 2>/dev/null; sleep 3; quiet; state
    say "caption mlx $m"
    "$bin" --vision --model "$m" --port $port --max-tokens 600 > "$OUT/swiftlm-$(echo "$m" | tr '/' '_').log" 2>&1 &
    local pid=$! ok=0
    for _ in $(seq 1 240); do curl -sf "127.0.0.1:$port/v1/models" >/dev/null && { ok=1; break; }; kill -0 $pid 2>/dev/null || break; sleep 5; done
    if [ $ok = 1 ]; then
      python3 "$EXP/captioning-bench/bench_v2.py" --backend openai --host "http://127.0.0.1:$port" \
        --model "$m" --out "$OUT/caption" ${PHOTOS:+--photos "$PHOTOS"} || say "mlx $m FAILED"
    else
      say "mlx $m: SwiftLM never became ready (see its log)"
    fi
    kill $pid 2>/dev/null; sleep 3; kill -9 $pid 2>/dev/null
  done
}

case "$WHAT" in
  llm) run_llm ;; caption) run_caption ;; mlx) run_mlx ;;
  all) run_llm; run_caption; run_mlx ;;
  *) echo "unknown: $WHAT" >&2; exit 2 ;;
esac
say "chain $WHAT done"
