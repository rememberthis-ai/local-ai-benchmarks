#!/usr/bin/env bash
# Long-context A/B: Dreamer-style ~80K-token prompt against
# ollama (with explicit num_ctx) and SwiftLM (already loaded).
#
# Usage: ./bench_longctx.sh <ollama_tag> <swiftlm_hf_repo> <num_ctx>
# Skip ollama side: pass "skip" as first arg.
# Skip swiftlm side: pass "skip" as second arg.
set -uo pipefail
OLLAMA_TAG="${1:-skip}"
SWIFTLM_HF="${2:-skip}"
NUM_CTX="${3:-131072}"

cd "$(dirname "$0")"
PROMPT_FILE="dreamer_prompt.txt"
[ -f "$PROMPT_FILE" ] || { echo "missing $PROMPT_FILE — run build_dreamer_prompt.py first"; exit 1; }
PROMPT="$(cat "$PROMPT_FILE")"
mkdir -p results-llm
OUT="results-longctx-$(date +%Y%m%d-%H%M%S).md"

{
  echo "# Long-context bench — ~80K tokens"
  echo
  echo "Prompt: $PROMPT_FILE ($(wc -c < "$PROMPT_FILE") bytes)"
  echo "num_ctx: $NUM_CTX"
  echo "Run: $(date)"
  echo
} > "results-llm/$OUT"

# ---- ollama ----
if [ "$OLLAMA_TAG" != "skip" ]; then
  echo "[$(date +%H:%M:%S)] ollama: bench $OLLAMA_TAG (num_ctx=$NUM_CTX)"
  T0=$(python3 -c 'import time;print(time.monotonic())')
  curl -s --max-time 1800 http://127.0.0.1:21434/api/chat \
    -d "$(jq -n --arg p "$PROMPT" --arg m "$OLLAMA_TAG" --argjson n $NUM_CTX \
      '{model:$m, messages:[{role:"user",content:$p}], stream:false, options:{num_ctx:$n, num_predict:600}}')" \
    > /tmp/ollama-longctx-resp.json
  T1=$(python3 -c 'import time;print(time.monotonic())')
  python3 - <<PY >> "results-llm/$OUT"
import json, time
t0,t1=$T0,$T1
d=json.load(open('/tmp/ollama-longctx-resp.json'))
pec=d.get('prompt_eval_count', 0)
ec=d.get('eval_count', 0)
pd_ns=d.get('prompt_eval_duration', 0)
ed_ns=d.get('eval_duration', 0)
prefill=pec/(pd_ns/1e9) if pd_ns else 0
decode=ec/(ed_ns/1e9) if ed_ns else 0
print(f"## ollama ($OLLAMA_TAG)")
print()
print(f"- wall: {t1-t0:.1f}s")
print(f"- prompt_eval_count: {pec:,} tokens")
print(f"- eval_count: {ec:,} tokens")
print(f"- prefill speed: {prefill:.1f} tok/s")
print(f"- decode speed:  {decode:.1f} tok/s")
print()
msg = d.get('message',{})
content = msg.get('content','')
thinking = msg.get('thinking','')
print(f"- content len: {len(content)} chars")
print(f"- thinking len: {len(thinking)} chars")
print()
print('### content (first 800 chars)')
print()
print(content[:800] if content else '(empty)')
PY
  echo "[$(date +%H:%M:%S)] ollama: done"
  # free GPU
  curl -s http://127.0.0.1:21434/api/generate \
    -d "$(jq -n --arg m "$OLLAMA_TAG" '{model:$m,keep_alive:0}')" > /dev/null
  sleep 5
fi

# ---- SwiftLM ----
if [ "$SWIFTLM_HF" != "skip" ]; then
  echo "[$(date +%H:%M:%S)] swiftlm: bench $SWIFTLM_HF"
  S0=$(python3 -c 'import time;print(time.monotonic())')
  curl -s --max-time 1800 http://127.0.0.1:5413/v1/chat/completions \
    -H 'Content-Type: application/json' \
    -d "$(jq -n --arg p "$PROMPT" --arg m "$SWIFTLM_HF" \
      '{model:$m, messages:[{role:"user",content:$p}], stream:false, max_tokens:600}')" \
    > /tmp/swiftlm-longctx-resp.json
  S1=$(python3 -c 'import time;print(time.monotonic())')
  python3 - <<PY >> "results-llm/$OUT"
import json
t0,t1=$S0,$S1
try:
    d=json.load(open('/tmp/swiftlm-longctx-resp.json'))
    u=d.get('usage',{})
    pt=u.get('prompt_tokens',0)
    ct=u.get('completion_tokens',0)
    msg=d['choices'][0]['message']
    content = msg.get('content','')
    rc = msg.get('reasoning_content','')
    print(f"## SwiftLM ($SWIFTLM_HF)")
    print()
    print(f"- wall: {t1-t0:.1f}s")
    print(f"- prompt_tokens: {pt:,}")
    print(f"- completion_tokens: {ct:,}")
    print(f"- decode speed (output / wall): {ct/(t1-t0):.1f} tok/s")
    print(f"  (note: SwiftLM doesn't break out prefill/decode separately; this includes prefill time)")
    print()
    print(f"- content len: {len(content)} chars")
    print(f"- reasoning_content len: {len(rc)} chars")
    print()
    print('### content (first 800 chars)')
    print()
    print(content[:800] if content else '(empty)')
except Exception as e:
    print(f"## SwiftLM ($SWIFTLM_HF) — ERROR")
    print()
    print(f"{e}")
    print(open('/tmp/swiftlm-longctx-resp.json').read()[:600])
PY
  echo "[$(date +%H:%M:%S)] swiftlm: done"
fi

# Memory snapshot (RSS at end-of-bench)
ps -o pid,rss,command -p $(pgrep -x SwiftLM) 2>/dev/null | awk '/SwiftLM/ {print "## SwiftLM RSS at bench end\n\n"$0"\n"}' >> "results-llm/$OUT"

echo "[$(date +%H:%M:%S)] wrote results-llm/$OUT"
