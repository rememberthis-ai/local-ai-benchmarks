#!/usr/bin/env bash
# Compare ollama vs SwiftLM on the same MoE model + same Rust async/Mutex prompt.
# Usage: ./bench_llm.sh <ollama_tag> <swiftlm_hf_repo>
set -uo pipefail
OLLAMA_TAG="${1:?ollama tag required}"
SWIFTLM_HF="${2:?swiftlm HF repo required}"

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

slug=$(echo "$OLLAMA_TAG" | tr '/:' '__')
OUT="results-llm-${slug}-$(date +%Y%m%d-%H%M%S).md"
mkdir -p "$(dirname "$0")/results-llm" 2>/dev/null
cd "$(dirname "$0")"
mkdir -p results-llm

# ---- ollama bench ----
echo "[$(date +%H:%M:%S)] ollama: warmup $OLLAMA_TAG"
curl -s http://127.0.0.1:21434/api/chat \
  -d "$(jq -n --arg p "warm" --arg m "$OLLAMA_TAG" '{model:$m, messages:[{role:"user",content:$p}], stream:false, options:{num_predict:1}}')" \
  > /dev/null
echo "[$(date +%H:%M:%S)] ollama: bench"
T0=$(python3 -c 'import time;print(time.monotonic())')
curl -s http://127.0.0.1:21434/api/chat \
  -d "$(jq -n --arg p "$PROMPT" --arg m "$OLLAMA_TAG" '{model:$m, messages:[{role:"user",content:$p}], stream:false, options:{num_predict:800}}')" \
  > /tmp/ollama-llm-resp.json
T1=$(python3 -c 'import time;print(time.monotonic())')

# ---- Stop ollama model to free GPU memory before SwiftLM bench ----
echo "[$(date +%H:%M:%S)] stopping ollama model (free GPU)"
curl -s http://127.0.0.1:21434/api/generate \
  -d "$(jq -n --arg m "$OLLAMA_TAG" '{model:$m, keep_alive:0}')" \
  > /dev/null
sleep 5  # let GPU memory release

# ---- SwiftLM bench (assumes daemon already loaded with $SWIFTLM_HF) ----
echo "[$(date +%H:%M:%S)] swiftlm: warmup"
curl -s http://127.0.0.1:5413/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg p "warm" --arg m "$SWIFTLM_HF" '{model:$m, messages:[{role:"user",content:$p}], stream:false, max_tokens:1}')" \
  > /dev/null
echo "[$(date +%H:%M:%S)] swiftlm: bench"
S0=$(python3 -c 'import time;print(time.monotonic())')
curl -s http://127.0.0.1:5413/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d "$(jq -n --arg p "$PROMPT" --arg m "$SWIFTLM_HF" '{model:$m, messages:[{role:"user",content:$p}], stream:false, max_tokens:800}')" \
  > /tmp/swiftlm-llm-resp.json
S1=$(python3 -c 'import time;print(time.monotonic())')

# ---- write report ----
{
  echo "# ollama vs SwiftLM — $OLLAMA_TAG vs $SWIFTLM_HF"
  echo
  echo "Run: $(date '+%Y-%m-%d %H:%M:%S')"
  echo
  echo "| Runtime | Wall (s) | Tokens | Tok/s |"
  echo "|---|---|---|---|"
  python3 - <<PY
import json
ot0,ot1=$T0,$T1
o=json.load(open('/tmp/ollama-llm-resp.json'))
ec=o.get('eval_count',0)
ed=o.get('eval_duration',0)/1e9 if o.get('eval_duration') else 0
print(f"| **ollama** ($OLLAMA_TAG) | {ot1-ot0:.1f} | {ec} | {ec/ed:.1f} |" if ed else f"| **ollama** ($OLLAMA_TAG) | {ot1-ot0:.1f} | {ec} | n/a |")
st0,st1=$S0,$S1
try:
    s=json.load(open('/tmp/swiftlm-llm-resp.json'))
    sec=s.get('usage',{}).get('completion_tokens',0)
    print(f"| **SwiftLM** ($SWIFTLM_HF) | {st1-st0:.1f} | {sec} | {sec/(st1-st0):.1f} |")
except Exception as e:
    print(f"| **SwiftLM** ($SWIFTLM_HF) | {st1-st0:.1f} | ERR {e} | |")
PY
  echo
  echo "## ollama answer (first 600 chars)"
  echo
  python3 -c "import json;print(json.load(open('/tmp/ollama-llm-resp.json'))['message']['content'][:600])"
  echo
  echo "## SwiftLM answer (first 600 chars)"
  echo
  python3 -c "
import json
try:
    s=json.load(open('/tmp/swiftlm-llm-resp.json'))
    print(s['choices'][0]['message']['content'][:600])
except Exception as e:
    print(f'(parse err: {e})')
    print(open('/tmp/swiftlm-llm-resp.json').read()[:600])
"
} > "results-llm/$OUT"
echo "[$(date +%H:%M:%S)] wrote results-llm/$OUT"
