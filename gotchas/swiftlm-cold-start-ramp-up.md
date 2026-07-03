# SwiftLM's first real request after model load is 3x+ slower than steady-state

Distinct from the battery-throttle gotchas — this one hits every request pattern, on any battery level, on any Mac.

## The finding (2026-05-24, M1 Max, Qwen3-Next-80B-A3B-Instruct-4bit)

Fresh SwiftLM load, `--thinking` mode, three requests at increasing context in the same process:

| Ctx | Note | e2e tok/s |
|-----|---|---:|
| 4K  | first request after load | **3.44** |
| 8K  | second request | **11.82** |
| 16K | third request | **10.27** |

The first request is context-independent slow — 4K should decode *faster* than 8K/16K (less prompt to process, similar decode budget), not 3.4x slower. Something about the first real generation costs extra wall time that has nothing to do with prompt or completion length.

## Root cause: Metal kernel JIT compilation, not warmup in the caching sense

MLX (and by extension SwiftLM) lazily compiles Metal compute kernels the first time a given operation shape is actually executed. Model *loading* doesn't trigger this — only running inference through the full forward+decode path does. So the first generation pays a one-time tax while MLX JIT-compiles kernels for that model's architecture, on top of normal token generation.

A naive fix — firing a tiny "warmup" request (a few tokens) right after load, before serving real traffic — **doesn't fully work**:

| Run | e2e tok/s |
|---|---:|
| Cold 4K (no warmup) | 3.44 |
| Warm 4K (after an 8-token warmup ping) | 6.71 |
| Steady-state (8K/16K average) | ~11 |

The warm re-run only closed about half the gap. An 8-token generation doesn't exercise the same code paths — thinking-mode branching, longer sequence lengths, whatever kernel variants get selected for a real 1500-token generation — that a full-size request does. **A trivial warmup ping is not sufficient; the warmup request needs to look like a real request** (similar `max_tokens`, similar mode flags) to fully amortize the compile cost.

## Practical implication for RT/MT

Any product surface that spins up SwiftLM on demand (Dreamer sessions, captioning backfill after idle) will see its first real user-facing request run several times slower than the rest of the session. Two mitigations, neither free:

1. **Eat it as a one-time UX cost** — acceptable if the first request is already expected to be slow for other reasons (cold model load itself takes tens of seconds).
2. **Fire a full-size dummy request during the "warming" phase** (matching `max_tokens`, `--thinking` if applicable) rather than a token-8 ping, so the compile cost lands before the user's first real request instead of during it. Costs extra wall time during warmup, but that phase is already shown as a loading state in the UI.

## Why this wasn't caught earlier

Most of this repo's context-sweeps run sequentially through increasing context sizes on a freshly-loaded model, which means **every single-model ctx-sweep in this repo has an artificially slow first row.** Earlier sweeps (Llama-3.2-3B, Qwen3-8B, gemma-4-e2b, etc.) likely undercount their 4K numbers by a similar ratio — worth flagging when reading any "4K tok/s" cell in the matrix as a possible mix of cold-start tax and genuine short-context decode speed. The gap is proportionally largest on models where steady-state itself is already fast (the compile tax is roughly constant regardless of model size, so it dominates more on fast models); on slow models like this 80B it's still a clear 3x effect.

**Fix for future sweeps**: prepend a full-size warmup request (same shape as the first real ctx-sweep point) before starting the timed sweep, and don't count it. `ctx_sweep.py` doesn't currently do this — worth adding.
