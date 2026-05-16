# Gemma-4-26B-A4B emits repetition garbage at 80 K context

SwiftLM's published throughput table claims vanilla full-GPU mode hits 15.7 tok/s at 100 K context on M2 Ultra. Two of our candidate MoE models on the actual Dreamer prompt told a different story on M1 Max 64 GB:

| Model (SwiftLM, vanilla full-GPU mode) | Wall | tok/s | Output quality |
|---|---:|---:|---|
| Gemma-4-26B-A4B | 22.8 min | 1.1 | ❌ **Repetition collapse**: 6,000 chars of `own own own ... way way way` |
| Qwen3.6-35B-A3B (`--thinking`) | 23.1 min | 1.1 | ✅ Coherent narrative — pulls specific dates, places, people |
| Qwen3-Next-80B-A3B (`--thinking`) | >90 min (timeout) | — | ❌ Did not complete — 80 B + 80 K KV pushed past the swap cliff on 64 GB |

The 26 B and 35 B ran at the same 1.1 tok/s end-to-end, not the 15.7 tok/s SwiftLM's table promised. macOS pushed the model out of physical RAM because the 80 K KV cache + the rest of the system collectively blew the memory budget. **Once you're swap-bound at 80 K, model architecture stops mattering for speed.** Different failure modes converge to the same bad outcome.

## The Gemma 4 collapse mode

Same prompt, identical hardware, default sampling. At 80 K context, gemma-4-26b-a4b-it-4bit produces 1,500 tokens of pure repetition. Snippet:

```
... the way the way the way the way own own own own own way way way way way
own way own way own way way way own own own own way way way way way ...
```

It's not "thinking out loud and never converging" — it's structurally collapsed. ollama's `gemma4:26b` at the same length burns its entire output budget on `<thinking>` blocks and produces zero visible content. Different failure modes, same outcome: **Gemma 4 is not a viable Dreamer-tier model on default sampling at 80 K, on either runtime.**

We didn't sweep alternate sampling configurations. `repeat_penalty=1.2` or similar might fix the collapse — try it if you're invested in Gemma 4 for long context. We picked Qwen3.6 instead and moved on.

## Why Qwen3.6 doesn't collapse here

Qwen3.6-35B-A3B with `--thinking` produces real, on-topic analysis at the same 80 K length. Its interleaved sliding-window attention seems to hold up where Gemma 4's interleaved-local-global pattern doesn't, at least on default sampling. We didn't isolate the root cause, but the empirical difference was reproducible across three runs.

## v0.11 decision

For Apple Silicon Dreamer (long-context synthesis), v0.11 ships Qwen3.6-35B-A3B with `--thinking`. Gemma-4-26B-A4B stays as the captioning model on 32 GB+ tiers (no captioning prompt ever approaches 80 K). Two models bundled means more disk; the alternative is shipping a Dreamer that returns garbage 100% of the time.
