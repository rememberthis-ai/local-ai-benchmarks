# Gotchas

Lessons from running the bench harness across two machines for two weeks. Each file is a short, self-contained writeup of one trap we hit — most could quietly publish wrong numbers if you don't know about them.

| File | One-liner |
|---|---|
| [`low-power-mode-throttling.md`](low-power-mode-throttling.md) | macOS Low Power Mode silently throttles M1 Max GPU by 5–6× — almost shipped wrong matrix numbers |
| [`keep-alive-eviction.md`](keep-alive-eviction.md) | ollama's default 5-minute `keep_alive` makes back-to-back runtime A/Bs lie by ~3× |
| [`ollama-4k-context-truncation.md`](ollama-4k-context-truncation.md) | ollama silently truncates long prompts to 4 K by default — no warning, no error |
| [`gemma4-repetition-collapse-80k.md`](gemma4-repetition-collapse-80k.md) | Gemma-4-26B-A4B emits 6,000 chars of `own own own way way way` at 80 K context |
| [`turboquant-slower-than-vanilla.md`](turboquant-slower-than-vanilla.md) | SwiftLM's `--turbo-kv` (3-bit KV compression) is uniformly slower than vanilla on a 64 GB Mac |
| [`polaris-gpu-dead-end.md`](polaris-gpu-dead-end.md) | AMD Radeon Pro 5xx on Intel Macs: tg is slower than CPU + Metal driver hangs |
| [`polaris-whisper-crash-long-audio.md`](polaris-whisper-crash-long-audio.md) | whisper.cpp Metal on Polaris dGPU: SIGABRT on audio ≥10 min — stability bug, not just perf |

The blog post that introduced this work — [Faster Local AI with SwiftLM (May 2026)](https://rememberthis.ai/blog/benchmarks/2026-05-16/faster-local-ai-with-swiftlm) — refers to these but doesn't reproduce them in detail. They live here so the post stays focused on the matrix you'd actually act on.
