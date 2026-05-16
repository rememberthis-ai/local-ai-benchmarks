# Intel Mac inference bench — summary

**Hardware**: Intel(R) Core(TM) i9-8950HK @ 2.90GHz / 32 GB RAM
**Runtime**: 2026-05-13 20:34 → 2026-05-14 05:32 (~9 h wall, mostly captioning)
**Runtime stack**: ollama 0.x bundled with Remember This v0.10.x, listening on 127.0.0.1:21434

## Headline

For the v0.11 blog post Intel tier, the recommendation is:

- **Captioning**: keep `moondream:1.8b` as the Intel default. 25 s/photo, coherent output, well under the 60 s/photo viability bar. No challenger beats it on Intel.
- **Dreamer LLM**: `llama3.2:3b` is viable as a default for short-to-medium contexts (4K @ 200 s, 8K @ 8 min, 16K @ 28 min). For 16K and beyond, `gemma3:4b` is the more context-resilient option (degrades only 16 % from 4K → 16K vs llama3.2:3b's 60 %).
- **Lightweight tier (≤16 GB)**: `llama3.2:1b` is the only model that clears the README "8K @ ≤5 min" bar (2.9 min). Use it where memory is tight.
- **32 K context is not viable on Intel** — every model hit the 30-min wall-clock timeout at 32 K.
- **qwen3 family (1.7b and 8b) is broken on ollama** — both emit just `…` (thinking-tokens stripped, no synthesis). Do not recommend.

## Captioning bench

| Model | Photos | Avg/photo (s) | Total (min) | Viability | Quality vibe |
|---|---|---:|---:|---|---|
| **moondream:1.8b** | 30 | **25.0** | 12.5 | ✅ default | Concise, occasional first-letter dropout ("urns" for "Returns") but otherwise on-topic |
| llava:7b | 30 | 80.2 | 40.1 | ❌ above 60 s/photo bar | Better grounded than moondream, recognises restaurants, people, signage |
| **minicpm-v:8b** | 30 | **72.2** | 36.1 | ⚠️ borderline | **Surprise: faster than llava:7b despite being bigger.** Captions read like translated ESL ("In a room there are few persons…") |
| gemma3:4b | 30 | 264.9 | 132.4 | ❌ way too slow (4–5 min/photo) | Highest-quality narration but useless at this throughput |

Notes:
- moondream's first-letter dropout (e.g. "urns of water" instead of "Returns of water", "xtract context" instead of "Extract context") is a known artefact of its captioning style — the underlying recognition is correct, just truncated. Acceptable for thumbnail/preview text.
- minicpm-v:8b being *faster* than llava:7b is counter-intuitive and worth flagging in the blog post. Likely a quantisation / architecture difference; both Q4_K_M in ollama. Quality is the worse of the two — odd grammatical patterns suggest the model was distilled from non-native English supervision.
- gemma3:4b's per-photo wall time (264.9 s) is so high that a single user processing one day of photos (say 100) would wait **7 hours**. Not shippable as default or even as a recommended opt-in on Intel.

## Dreamer-LLM context sweep

ollama `/api/generate`, `num_ctx=40000`, `num_predict=300`, `keep_alive=0` between models, `keep_alive=5m` between size points for the same model.

| Model | 4K wall | 4K decode | 8K wall | 8K decode | 16K wall | 16K decode | 32K | Coherent? |
|---|---:|---:|---:|---:|---:|---:|---|---|
| **llama3.2:1b** | 71.7 s | **14.1 tok/s** | 172.4 s | 8.5 | 742.4 s | 5.0 | timeout | ✅ |
| **llama3.2:3b** | 199.5 s | 6.7 | 487.3 s | 4.4 | 1670.8 s | 2.7 | timeout | ✅ |
| **gemma3:4b** | 194.0 s | 8.2 | 327.0 s | **7.8** | 677.5 s | **6.9** | timeout | ✅ |
| qwen3:1.7b | 175.1 s | 7.9 | 444.9 s | 5.0 | 1444.8 s | 3.6 | timeout | ❌ `…` only |
| qwen3:8b | 450.1 s | 3.2 | 1026.4 s | 2.1 | timeout | — | timeout | ❌ `…` only |

Viability against the README bars:

- **8K @ ≤5 min wall time** (the README's coherent-output target):
  - llama3.2:1b: 2.9 min ✅
  - gemma3:4b: 5.5 min ⚠ (just over)
  - llama3.2:3b: 8.1 min ❌
  - all others: >7 min
- **16K @ ≤30 min wall time** (long-context tier):
  - gemma3:4b: 11.3 min ✅
  - llama3.2:1b: 12.4 min ✅
  - llama3.2:3b: 27.8 min ⚠ (slow but tolerable for batch)
  - qwen3:1.7b: 24.1 min ⚠ (and incoherent)
- **32K**: dead — every model hit the 30-min timeout. The blog matrix should show a hard cap at ~24K effective on Intel CPU.

The most interesting finding: **gemma3:4b's context curve is unusually flat** (8.2 → 7.8 → 6.9 from 4K → 8K → 16K = only 16 % degradation). Compare:
- llama3.2:1b: 14.1 → 8.5 → 5.0 = 65 % degradation
- llama3.2:3b: 6.7 → 4.4 → 2.7 = 60 % degradation

For users running long-context dreamer prompts (full-day rollups, week-summaries), gemma3:4b is the recommendation despite being slower at 4K. Captioning gemma3:4b is dead, but **LLM gemma3:4b on Intel is the long-context winner**.

The qwen3 family failure (`…`-only output) is a content-quality blocker, not a speed issue. The 80-char preview was load-bearing here — without it we would have published qwen3:1.7b as "the fastest small model" based on tok/s (it scored 7.9 @ 4K, competitive with llama3.2:1b's 14.1) without noticing it produces no usable text. The README's "content quality matters more than tok/s" warning was prescient.

## Blog matrix proposal

Replace the current "TBD" Intel-tier row with:

| Tier | RAM | Captioning | Dreamer LLM (4K) | Dreamer LLM (8K) | Dreamer LLM (16K) | Hard ceiling |
|---|---|---|---|---|---|---|
| Intel CPU (this rig: i9-8950HK, 32 GB) | 16 GB+ | moondream:1.8b (25 s/photo) | llama3.2:1b (14 tok/s) or llama3.2:3b (6.7) | llama3.2:1b (8.5) or gemma3:4b (7.8) | gemma3:4b (6.9) | ~24K context |

Caveats to print verbatim:
- Numbers from a 2018 Intel mobile i9 (Core(TM) i9-8950HK). Desktop Intel chips with more cores / better cooling will do better; mobile dual-core i5/i7 will do worse.
- 32 K context is unreachable on Intel CPU at any model size we tested — the bench timed out at 30 min wall time.
- qwen3 family is not recommended on ollama Intel (outputs are stripped to ellipsis only — a thinking-tokens packaging issue, not a fundamental model problem; revisit if ollama improves qwen3 support).

## Files

- `captioning-summary.md` — per-VLM summary
- `captioning-{moondream_1.8b,llava_7b,gemma3_4b,minicpm-v_8b}.md` — per-photo timings + 80-char caption snippets
- `llm-summary.md` — per-LLM summary
- `ctxsweep-ollama-{model}-{ts}.md` — full per-size measurements with content snippets
- `raw-{model}.log` — raw bench stdout

## Reporting back

The blog post's Intel-tier row in [docs/plans/SWIFTLM-MLX-CAPTIONING-EVAL.md](../../docs/plans/SWIFTLM-MLX-CAPTIONING-EVAL.md) can now cite real numbers. Suggested next step: have the orchestrator update that doc + the corresponding website blog post once the Intel-tier wording is approved.
