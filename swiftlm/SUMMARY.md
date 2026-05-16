# SwiftLM vs ollama — Track B summary

## What

Same model, same prompt, two runtimes:

- **Model**: Qwen3-Coder-30B-A3B (MoE, 30B params / ~3B active, 4-bit)
  - ollama tag: `qwen3-coder:30b` (Q4_K_M, 17.7 GB on disk)
  - SwiftLM HF id: `lmstudio-community/Qwen3-Coder-30B-A3B-Instruct-MLX-4bit` (16 GB on disk)
- **Prompt**: ~500-token Rust async/Mutex bug-hunt task (representative of
  RT's Claude Code use case)
- **Output**: ~750–800 token explanation + fixed code
- **Host**: M1 Max, 64 GB unified memory

## Steady-state numbers

| Runtime | Wall (s) | Output tokens | Decode tok/s | Quality |
|---|---|---|---|---|
| **ollama** 0.22.1 | 55.3 | 748 | **14.5** | Correct — identifies the deadlock |
| **SwiftLM** b644 | 40.7 | 783 | **19.2** | Correct — identifies the blocking mutex |

**SwiftLM is ~32% faster** on decode tok/s, ~26% faster on wall-clock. Both
runtimes produce competent technical answers.

## Cold start

This is where SwiftLM lost badly:

- **ollama**: ~16 s warmup (model already in disk cache; pre-loaded into RAM)
- **SwiftLM**: ~8–10 minutes to "ready"
  - Of that, ~5–7 min was HuggingFace Hub rate-limited download (no token)
  - Even with weights fully cached on disk, post-download initialization took
    multiple minutes before the listening socket opened on `:5413`
  - Two earlier bench runs failed because the bench script's 600 s
    `/health` wait expired before SwiftLM was ready, then fired requests
    against a not-yet-listening daemon

## Memory

| Runtime | RSS at idle | Self-reported |
|---|---|---|
| **ollama** | not measured | n/a |
| **SwiftLM** | 16.4 GB RSS | 16.4 GB active GPU memory, 0.4 GB KV cache, "estimated 16.9 tok/s" (real: 19.2 — beat its own estimate) |

## Implications for RT

The user's specific complaint was: *"ollama-based claude code with local
models is superslow"*. On this benchmark:

- **The "slow" complaint is partially confirmed** — ollama's 14.5 tok/s
  on a 30B-MoE model is meaningfully slower than SwiftLM's 19.2 tok/s for
  the same weights.
- **But the gap is ~30%, not 4×** as SwiftLM's marketing copy claims
  ("4.2x faster than ollama"). The 4× number presumably refers to a
  different workload (probably MoE expert streaming on bigger models with
  SSD spilling — see SwiftLM's headline benchmark on Gemma 4-26B).
- **For the user's actual use case** (local Claude Code), the wall-clock
  improvement is ~14 s saved per ~1k-token completion. That's noticeable
  but not transformative.

## Cold start matters more than steady-state

SwiftLM's 8–10 min cold start, even with cached weights, would be a serious
UX regression for the RT app's Claude Code feature. Users would not tolerate
a multi-minute wait before the first response. Ollama keeps a model warm
across requests, and re-loading a model takes seconds, not minutes.

Possible mitigations:
- Run SwiftLM as a long-lived daemon (one cold start at app launch, then
  warm forever). RT app could spawn SwiftLM at startup like it spawns the
  daemon today.
- Use SwiftLM's `--info` (dry-run) at app install to pre-warm the model
  cache before first user use.
- The cold start may be partly a SwiftLM b644 bug — the docs imply
  warm reload should be fast, but my second bench run also took 10+ min
  *after* the model was already 5 GB cached on disk. Worth filing an issue.

## Bundling assessment (separate from speed)

| | ollama (current) | SwiftLM |
|---|---|---|
| Binary size | ~600 MB bundled (Go + CGo + llama.cpp dylibs) | **~180 MB** (61 MB binary + 120 MB metallib) |
| Architecture | x86 + arm64 universal | arm64 only (no Intel Mac support) |
| iOS path | None — ollama doesn't run on iOS | **Native** — same `mlx-swift` runs on iOS, SwiftLM ships an iOS app example |
| Codesigning quirks | Many CGo dylibs to sign | One Mach-O + one metallib |
| Ecosystem maturity | 100K+ users, many models | Newer, fewer corner cases worked through |
| Native LLM coverage | Anything llama.cpp supports | Anything mlx-swift-lm supports (broad but lags upstream by weeks) |
| Native VLM coverage | MiniCPM-V 4.5, Qwen2.5-VL, LLaVA, etc. | Qwen2.5-VL/3-VL, Gemma 4, FastVLM, Pixtral, etc. — **no MiniCPM family** |

## Recommendation

1. **For the v0.10.x hot-fix:** keep ollama. The captioning question
   ([Track A](../captioning-bench/results/SUMMARY.md)) recommends staying
   on v4.5 anyway; no urgent need for a runtime swap.

2. **For RT v0.11+ (longer-term):** SwiftLM is a real candidate worth
   investing in, *especially* given the iOS angle. The 30% speed win is
   nice, but the strategic win is a single bundle that runs both
   macOS and iOS inference. That said:
   - Need to validate cold-start is fixable (long-lived daemon model).
   - Need to confirm the VLM bundle question separately — SwiftLM's
     supported VLMs don't include MiniCPM, so if RT stays on
     MiniCPM-V 4.5 for captions, SwiftLM-for-VLM is blocked
     until either we switch VLM family or someone ports MiniCPMV
     to mlx-swift-lm.
   - Watch for ollama's own MLX-engine migration; if mainline ollama
     ships an MLX-backed path with comparable speed, the case for
     SwiftLM shrinks (still has the iOS angle though).

3. **Don't change RT's local-Claude-Code default today.** The 30%
   speed improvement isn't enough to justify swapping the daemon
   architecture for a hot-fix. Defer to a v0.11 plan.
