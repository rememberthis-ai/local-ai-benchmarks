# TurboQuant (`--turbo-kv`) is slower than vanilla on a 64 GB Mac

SwiftLM ships two long-context aids we expected to shift the cliff up:

- `--turbo-kv` — 3-bit KV cache compression, activates above 8,192 tokens. The README recommends it for 100 K+.
- `--stream-experts` — streams MoE expert weights from SSD on demand, with optional `--ssd-prefetch`.

Both are off by default. We re-ran the long-context sweep with them on to see if they shift the cliff up. They don't.

## `--turbo-kv` results

Re-ran Qwen3.6 and Qwen3-Next-80B with `--turbo-kv`:

| Context | Qwen3.6 vanilla | +turbo-kv | 80B vanilla | +turbo-kv |
|---|---:|---:|---:|---:|
| 8 K | 8.3 | 3.6 | 5.6 | 2.5 |
| 16 K | 4.1 | 2.0 | 2.7 | 1.3 |
| 32 K | 1.6 | 1.1 | 1.1 | 0.7 |
| 64 K | 0.4 | **0.5** | — | — |

TurboQuant *is* doing what it claims — Qwen3.6's RSS grew steadily 5.4 → 8.5 GB instead of collapsing under pressure like vanilla did, so compressed KV is saving memory. But the per-token compression overhead exceeds the memory-pressure savings at every context ≤64 K we tested. Only at 64 K does TurboQuant finally pull ahead (0.5 vs 0.4 tok/s) — a flicker of the promised win, but already deep in the unusable zone.

The break-even probably arrives earlier on a 24 GB Mac that can't hold everything in RAM. On 64 GB, vanilla wins.

## `--stream-experts` results

Booting SwiftLM with `--stream-experts` on Qwen3-Next-80B prints:

```
Model does not support SSD expert streaming
```

…and falls back to vanilla mmap. Same on Gemma-4-26B-A4B. SwiftLM's expert-streaming implementation only covers a specific set of MoE arches today; `qwen3next` and `gemma4` aren't in it. So the 90-minute timeout we hit at 80 K on the 80 B is the real ceiling on this hardware, not something a flag can fix.

## Net for v0.11

**Plain vanilla SwiftLM full-GPU mode.** Just `--model`, `--port`, `--max-tokens`, `--prefill-size 256`, plus `--thinking` for Qwen models. The numbers in our matrix are what we ship, not "before optimization."

If you have a smaller Mac (16–24 GB) where vanilla SwiftLM swaps under pressure even at 16 K context, TurboQuant is worth retrying — break-even might be lower. We don't have data for that regime.
