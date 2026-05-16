#!/usr/bin/env bash
# Benchmark SwiftLM vs ollama on the same model + same prompt.
#
# Plan:
#   - Model pair: ollama qwen3-coder:30b   ↔   MLX lmstudio-community/Qwen3-Coder-30B-A3B-Instruct-MLX-4bit
#   - Prompt: ~500-token coding question (representative of RT's Claude Code use)
#   - Capture: TTFT (first token latency), decode tok/s, total time, RAM @ steady state
#
# Don't kill the user's ollama; it's already running on :21434.
# SwiftLM listens on :5413 (default). Doesn't collide.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"

PROMPT='You are a senior Rust engineer. The following Rust function compiles but crashes at runtime when called concurrently from multiple threads. Identify the bug, explain why it happens, and propose a fix using Tokio primitives.

```rust
use std::collections::HashMap;
use std::sync::Mutex;

pub struct Cache {
    inner: Mutex<HashMap<String, Vec<u8>>>,
}

impl Cache {
    pub async fn get_or_compute<F, Fut>(&self, key: String, f: F) -> Vec<u8>
    where
        F: FnOnce() -> Fut,
        Fut: std::future::Future<Output = Vec<u8>>,
    {
        if let Some(v) = self.inner.lock().unwrap().get(&key) {
            return v.clone();
        }
        let computed = f().await;
        self.inner.lock().unwrap().insert(key, computed.clone());
        computed
    }
}
```

Be precise. Show the fixed code.'

OUT="results-$(date +%Y%m%d-%H%M%S).md"
mkdir -p results

# ---- ollama benchmark ----
echo "[$(date +%H:%M:%S)] ollama: warmup (load model)"
curl -s http://127.0.0.1:21434/api/chat \
  -d "$(jq -n --arg p "warm-up" '{model:"qwen3-coder:30b", messages:[{role:"user",content:$p}], stream:false, options:{num_predict:1}}')" \
  > /dev/null
echo "[$(date +%H:%M:%S)] ollama: benchmark"
OLLAMA_T0=$(python3 -c 'import time;print(time.monotonic())')
curl -s http://127.0.0.1:21434/api/chat \
  -d "$(jq -n --arg p "$PROMPT" '{model:"qwen3-coder:30b", messages:[{role:"user",content:$p}], stream:false}')" \
  > /tmp/ollama-bench-resp.json
OLLAMA_T1=$(python3 -c 'import time;print(time.monotonic())')

# ---- SwiftLM benchmark ----
echo "[$(date +%H:%M:%S)] SwiftLM: starting daemon (will download ~17 GB on first run)"
./SwiftLM \
  --model lmstudio-community/Qwen3-Coder-30B-A3B-Instruct-MLX-4bit \
  --port 5413 \
  --max-tokens 800 \
  > /tmp/swiftlm-stdout.log 2>&1 &
SWIFTLM_PID=$!
echo "  → PID $SWIFTLM_PID, waiting for /health"
for i in $(seq 1 600); do
    if curl -s --max-time 1 http://127.0.0.1:5413/health > /dev/null 2>&1; then
        echo "  → ready after ${i}s"
        break
    fi
    sleep 1
done

echo "[$(date +%H:%M:%S)] SwiftLM: warmup"
curl -s http://127.0.0.1:5413/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg p "warm-up" '{model:"lmstudio-community/Qwen3-Coder-30B-A3B-Instruct-MLX-4bit", messages:[{role:"user",content:$p}], max_tokens:1, stream:false}')" \
  > /dev/null
echo "[$(date +%H:%M:%S)] SwiftLM: benchmark"
SWIFTLM_T0=$(python3 -c 'import time;print(time.monotonic())')
curl -s http://127.0.0.1:5413/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg p "$PROMPT" '{model:"lmstudio-community/Qwen3-Coder-30B-A3B-Instruct-MLX-4bit", messages:[{role:"user",content:$p}], max_tokens:800, stream:false}')" \
  > /tmp/swiftlm-bench-resp.json
SWIFTLM_T1=$(python3 -c 'import time;print(time.monotonic())')
SWIFTLM_RSS=$(ps -o rss= -p $SWIFTLM_PID 2>/dev/null | tr -d ' ' || echo 0)

# ---- shut down SwiftLM cleanly so it doesn't hold GPU memory ----
kill $SWIFTLM_PID 2>/dev/null
wait $SWIFTLM_PID 2>/dev/null

# ---- write report ----
{
  echo "# SwiftLM vs ollama benchmark — Qwen3-Coder-30B-A3B"
  echo
  echo "Run: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "Host: $(uname -mrs)"
  echo
  echo "## Wall-clock time"
  echo
  echo "| Runtime | Wall (s) | Eval count | Eval tok/s |"
  echo "|---|---|---|---|"
  python3 - <<PY
import json
ot0, ot1 = $OLLAMA_T0, $OLLAMA_T1
with open('/tmp/ollama-bench-resp.json') as f: o=json.load(f)
ec = o.get('eval_count', 0)
ed = o.get('eval_duration', 0) / 1e9 if o.get('eval_duration') else 0
print(f"| **ollama** | {ot1-ot0:.1f} | {ec} | {ec/ed:.1f}" if ed else f"| **ollama** | {ot1-ot0:.1f} | {ec} | n/a")

st0, st1 = $SWIFTLM_T0, $SWIFTLM_T1
try:
    with open('/tmp/swiftlm-bench-resp.json') as f: s=json.load(f)
    sec = s.get('usage',{}).get('completion_tokens', 0)
    print(f"| **SwiftLM** | {st1-st0:.1f} | {sec} | {sec/(st1-st0):.1f}" if st1!=st0 else f"| **SwiftLM** | {st1-st0:.1f} | {sec} | n/a")
except Exception as e:
    print(f"| **SwiftLM** | {st1-st0:.1f} | ERR {e} |  |")
PY
  echo
  echo "## ollama response (first 400 chars)"
  echo
  python3 -c "import json; o=json.load(open('/tmp/ollama-bench-resp.json')); print(o.get('message',{}).get('content','')[:400])"
  echo
  echo "## SwiftLM response (first 400 chars)"
  echo
  python3 -c "
import json
try:
    s=json.load(open('/tmp/swiftlm-bench-resp.json'))
    print(s['choices'][0]['message']['content'][:400])
except Exception as e:
    print(f'(parse error: {e})')
    print(open('/tmp/swiftlm-bench-resp.json').read()[:400])
"
  echo
  echo "## SwiftLM RSS at steady state: $SWIFTLM_RSS KB"
} > "$OUT"
echo "[$(date +%H:%M:%S)] wrote $OUT"
