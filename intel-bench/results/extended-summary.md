# Intel Mac inference bench — extended summary (phase 1 + phase 2)

**Hardware**: Intel(R) Core(TM) i9-8950HK @ 2.90 GHz / 32 GB / AMD Radeon Pro 560X 4 GB
**Runtime stack**: ollama 0.21.0 bundled with Remember This v0.10.x, listening on 127.0.0.1:21434
**Phase 1**: 2026-05-13 → 2026-05-14 (4 VLMs + 5 LLMs).
**Phase 2**: 2026-05-14 → 2026-05-15 (3 Qwen-VL + 2 Gemma 4 edge + GPU bench).

The phase-1 summary is preserved in `intel-summary.md`. This file consolidates phase 1 + phase 2 into the recommendations we'd cite in a blog matrix.

## TL;DR — Intel Mac defaults for v0.11+

| Use case | Recommendation | Speed | Why |
|---|---|---:|---|
| Captioning (speed) | `moondream:1.8b` | **25.9 s/photo** | Fastest by 2×; "good enough" gist captions |
| Captioning (quality) | `qwen3-vl:2b` | 53.2 s/photo | Reads Swedish/Finnish OCR, counts people, names objects |
| Captioning (quality, slower) | `qwen3-vl:4b` | 73.5 s/photo | Gold-standard OCR; quotes foreign-language phrases with translations |
| **LLM / Dreamer** ⭐ | **`gemma4:e2b`** | **11.8 / 10.4 / 8.5 / 6.0 tok/s** @ 4K/8K/16K/32K | Only model that reaches 32K on Intel CPU. Best at every ctx ≥ 8K |
| Dual-purpose (LLM + captioning) | `gemma4:e2b` | 63.8 s/photo + 11.8 tok/s | One model does both decently. Multimodal (vision + audio + tools + thinking) |
| **Discrete GPU bench** | **don't bother** | — | Radeon Pro 560X is unusable: tg slower than CPU, hangs on models ≥3 GB |

## Captioning bench — 9 models × 30 photos

| Model | Photos | Avg/photo | Total | Quality verdict |
|---|---:|---:|---:|---|
| **moondream:1.8b** | 30 | **25.9 s** | 12.9 min | Vague but coherent. Misses people counts, no OCR. Speed default. |
| qwen2.5vl:3b | 30 | 52.3 s | 26.1 min | Reads Swedish OCR, identifies funeral notices, gets names |
| **qwen3-vl:2b** ⭐ | 30 | **53.2 s** | 26.6 min | Same quality tier as 2.5vl:3b but slightly better prose. **Quality default.** |
| gemma4:e2b | 30 | 63.8 s | 31.9 min | Reads OCR but doesn't identify context ("Swedish text" vs "funeral notice") |
| minicpm-v:8b | 30 | 71.9 s | 35.9 min | Broken grammar ("three person standing"). No detail. |
| qwen3-vl:4b | 30 | 73.5 s | 36.7 min | **Gold standard.** OCR + people + setting + foreign-language quotes with translations |
| llava:7b | 30 | 74.8 s | 37.4 min | Generic. Hallucinates "performers" on funeral notice |
| gemma4:e4b | 30 | 108.1 s | 54.0 min | Solid (e2b quality + names extracted) but 2× slower for marginal gain |
| gemma3:4b | 30 | 266.6 s | 133.3 min | **Don't use.** 4.4 min/photo + hallucinates "train itinerary" from WhatsApp screenshots |
| moondream3:preview | — | — | — | **Deferred 2026-05-14**: no GGUF quant exists on HuggingFace yet |

The per-photo caption logs are intentionally not published in this repo (they contain personal names + private documents). The aggregate matrices above are derived from those logs; the relative ranking captures the headline.

### Headline: Qwen-VL family is the Intel captioning breakthrough

Phase 1 said "moondream stays default; no challenger beats it on Intel." That was true *only because phase 1 missed the Qwen-VL family.* qwen3-vl:2b at 53 s/photo costs 2× the wall time of moondream but actually reads what's in the photo. For Remember This-class passive memory where caption quality compounds over years of archive, **qwen3-vl:2b is the new default**.

## LLM context sweep — 7 models, 4 context sizes

ollama `/api/generate`, `num_ctx=40000`, `keep_alive=0` between models. Decode rate (tok/s) at each context size:

| Model | 4K | 8K | 16K | 32K | Coherent? |
|---|---:|---:|---:|---:|---|
| **gemma4:e2b** ⭐ | 11.8 | **10.4** | **8.5** | **6.0** | ✅ Only model reaching 32K |
| llama3.2:1b | **12.1** | 6.9 | 4.2 | — | ✅ |
| gemma3:4b | 7.4 | 6.9 | 5.9 | — | ✅ |
| gemma4:e4b | 6.2 | 5.7 | 4.7 | — | ✅ |
| llama3.2:3b | 6.0 | 3.8 | — | — | ✅ |
| qwen3:1.7b | 8.5 | 5.4 | 3.2 | — | ❌ `…` only (broken on ollama) |
| qwen3:8b | 2.6 | 1.7 | — | — | ❌ `…` only |

### gemma4:e2b is the long-context winner

- **Flat degradation curve**: 11.8 → 10.4 → 8.5 → 6.0 = only **49 % drop** from 4K → 32K. Compare llama3.2:1b's 65 % drop from 4K → 16K alone.
- **Reaches 32K** at 6 tok/s — the only model that survived the wall-clock cap.
- **Fastest at 8K/16K**: 10.4 / 8.5 tok/s beats every other model at these contexts.
- Phase 1 verdict ("32 K is not viable on Intel") is **superseded**. gemma4 changed the answer.

### llama3.2:1b stays the snappy low-tier choice

12.1 tok/s @ 4K (slightly beats gemma4:e2b's 11.8) and 2 GB weights vs gemma4:e2b's 7.2 GB. For 16 GB Intel Macs with tight RAM and short-context queries, llama3.2:1b is still the right choice.

### qwen3 family is still broken on ollama

Both qwen3:1.7b and qwen3:8b emit only `…` characters — thinking-tokens stripped, no synthesis. Independent of context size. Phase 1 finding holds; do not recommend.

## Discrete GPU bench — Radeon Pro 560X via llama.cpp

| Model | Size | pp512 (tok/s) | tg128 (tok/s) | Status |
|---|---:|---:|---:|---|
| moondream:1.8b | 0.77 GB | 81.5 | 3.16 | both stages OK |
| llama3.2:1b | 1.23 GB | 100.2 | 4.62 | both stages OK |
| qwen3:1.7b | 1.27 GB | 91.6 | 2.09 | both stages OK |
| llama3.2:3b | 1.88 GB | 58.2 | 2.46 | both stages OK |
| gemma3:4b | 3.11 GB | — | TIMEOUT | exceeds 4 GB VRAM |
| gemma4:e2b | 6.67 GB | — | TIMEOUT | exceeds 4 GB VRAM |

### Verdict: discrete GPU is unusable for LLM workloads on this hardware

- **tg is *slower* on GPU than CPU at every size.** llama3.2:1b on GPU is 4.62 tok/s; on CPU it's 12.1 tok/s — GPU is ~2.6× *slower* for token generation.
- **4 GB VRAM ceiling**: gemma3:4b and gemma4:e2b can't fit, both timeout on first attempt.
- **Polaris driver hang in tg** (well-documented in `../README.md`): `MTLIOAccelBuffer initWithDevice:` wedges in AMD Bronze driver. We worked around it with per-stage timeouts. Even when it runs, the result is slower.

Net: **Intel Mac → CPU only**. Discrete GPU is the wrong tier — works in principle, fails in practice. Save the 4 GB VRAM for the Photos.app / system services that actually benefit from it.

For Apple Silicon comparison: this is the inverse story. Apple Silicon's unified memory + Metal-on-M-series + MLX flat-out wins. The Intel Mac discrete-GPU story is "discrete GPU was a dead end for LLM workloads even before MLX showed up."

## Hardware matrix for the blog

| Tier | Hardware | Captioning default | Captioning quality option | LLM default | Hard ceiling |
|---|---|---|---|---|---|
| Intel Mac (16 GB+) | Mobile / desktop Intel + AMD Polaris | moondream:1.8b (25 s) | qwen3-vl:2b (53 s) | **gemma4:e2b** (11.8 / 10.4 / 8.5 / 6.0 @ 4K / 8K / 16K / 32K) | 32 K context reachable, ~6 tok/s |

Numbers are from a 2018 Intel mobile i9 (i9-8950HK, 6 cores @ 2.9 GHz, 4 GB Polaris). Desktop Intel chips with more cores will do better; mobile dual-core i5 will do worse.

## Why gemma4:e2b matters for Intel

Three findings make gemma4:e2b uniquely valuable on Intel:

1. **Only Intel-CPU model that reaches 32 K context.** Every phase-1 model timed out before 32K. gemma4:e2b runs 32K at 6 tok/s — slow but usable for Dreamer-class long-context synthesis.
2. **Multimodal (vision + audio + tools + thinking).** Same weights do captioning (63 s/photo), LLM chat, voice transcription (Whisper-class), and tool calling. One model in RAM, not three.
3. **Edge-optimised**: 2.3 B effective parameters via Google's edge-MoE design. Compute-light on CPU; the 7.2 GB on-disk weight is 4-bit quant.

The trade-off: it's not the *best* at any single task. moondream is faster for captioning, qwen3-vl:2b is better at OCR, llama3.2:1b is snappier at 4 K. But the dual-purpose story matters for memory-constrained Intel Macs where loading two separate models for captioning + LLM blows the 16 GB budget.

## Known issues that survived this bench

- **qwen3 family on ollama**: still emits `…` only. Filed under "fix needed in ollama qwen3 thinking-token handling". Don't recommend.
- **moondream3:preview**: deferred. No GGUF quant on HuggingFace yet. Revisit when bartowski / lmstudio-community publish one.
- **Discrete GPU on Intel via llama.cpp**: documented in [`../README.md`](../README.md) GPU caveats section. Driver hangs, sub-CPU tg performance, 4 GB VRAM ceiling.

## Files referenced

- `captioning-summary.md` — 9-row VLM matrix
- `llm-summary.md` — 7-row LLM matrix
- `ctxsweep-ollama-{model}-{ts}.md` — full per-size measurements with first-80-char content snippets (generic, no PII)
- `llm-gpu-summary.md` — Radeon Pro 560X via llama.cpp results
- `llm-gpu-raw-{model}-{pp|tg}.log` — raw llama-bench output per stage
- `intel-summary.md` — phase 1 standalone summary (kept for historical context)
- `../README.md` — bench scripts + GPU caveats

Per-photo caption logs are not published here; they contained personal names and private documents. The aggregate matrices in this file are derived from those logs and capture the headline finding.
