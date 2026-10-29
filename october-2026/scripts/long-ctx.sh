#!/usr/bin/env bash
# Context sweep past 64K: one run per "model:target:num_ctx" (num_ctx must cover the prompt plus the
# answer, and stay within the model's own limit). The notes in dreamer_prompt.txt hold ~80K tokens, so
# dreamer_prompt_long.txt repeats them (build it as in the commit that added this script; it is
# gitignored because the notes are private). Speed depends on length, not on content.
#   RUNS="qwen3.6:35b:120000:131072 qwen3.6:35b:240000:262144" OUT=... long-ctx.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; EXP="$(cd "$HERE/.." && pwd)"
H="${OLLAMA_HOST_URL:-http://127.0.0.1:11555}"; OUT="${OUT:?}"; mkdir -p "$OUT/llm-long"
exec >> "$OUT/chain.log" 2>&1
say() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
"$HERE/serve-ollama.sh" || exit 1
caffeinate -i -s -w $$ &
for r in $RUNS; do
  IFS=: read -r name tag size ctx <<<"$r"; m="$name:$tag"
  curl -s "$H/api/ps" | python3 -c 'import json,sys
for x in json.load(sys.stdin).get("models",[]): print(x["name"])' | while read -r n; do curl -s "$H/api/generate" -d "{\"model\":\"$n\",\"keep_alive\":0}" >/dev/null; done
  say "long ctx $m target=$size num_ctx=$ctx load=$(sysctl -n vm.loadavg)"
  OLLAMA_HOST_URL="$H" python3 "$EXP/intel-bench/ctx_sweep_ollama.py" "$m" --sizes "$size" \
    --prompt-file "$HERE/dreamer_prompt_long.txt" --out-dir "$OUT/llm-long" --max-tokens 200 \
    --num-ctx "$ctx" --timeout "${TIMEOUT:-14400}" || say "long ctx $m $size FAILED"
  curl -s "$H/api/ps" | python3 -c 'import json,sys
for x in json.load(sys.stdin).get("models",[]): print("  resident:", x["name"], "context_length", x.get("context_length"), "size_vram_GB", round(x.get("size_vram",0)/1e9,1))'
done
say "long ctx done"
