# experiments/

Bench harnesses for the May 2026 local-AI matrix work. The contents of this directory split across two repos:

- **Scripts + aggregate summary matrices** are mirrored to the public bench repo:
  [github.com/rememberthis-ai/local-ai-benchmarks](https://github.com/rememberthis-ai/local-ai-benchmarks).
  This is what external readers of the blog post can reproduce.
- **Per-photo result files, raw bench logs, and the real Dreamer-prompt** live only in this
  private monorepo. They contain personal names, OCR'd documents, and registry data and
  intentionally do not leave the org.

## Single-entry chain (recommended)

```bash
cd experiments && ./bench-all.sh
```

Detects `uname -m` and forwards to the right chain script (Intel → `intel-bench/bench-chain-intel.sh`, Apple Silicon → `swiftlm/bench-chain-silicon.sh`). Each chain runs preflight, pulls models, runs the VLM + LLM sweeps, and writes an aggregate summary plus a morning report at `/tmp/bench-chain-*-report.log`. Both chains accept `preflight` as a first arg if you only want the readiness checks.

## Subdirectory map

| Subdir | What's here | Mirrored public? |
|---|---|---|
| `intel-bench/` | Intel i9-8950HK + AMD Polaris GPU bench (2026-05-13 to 2026-05-15). Scripts + 9-VLM × 30-photo captioning, 7-LLM context sweep, GPU bench via llama.cpp. | Scripts + `*-summary.md`, `extended-summary.md`, `ctxsweep-*-*.md` (PII-clean) |
| `swiftlm/` | M1 Max 64 GB SwiftLM (mlx-swift-lm) vs ollama A/B harness. | Scripts only (no `dreamer_prompt.txt`) |
| `captioning-bench/` | VLM captioning harness with photo-fetch helper. | Scripts only; `photos/` and `results/` stay private |
| `ollama-fork/` | Bench script for tc-mb/ollama Suppport-MiniCPM-o-4.5 fork. | Yes |

## Open work

- `REBENCH-QUEUE.md` — prioritized list of bench gaps left after the May 2026 blog post landed
  (clean re-bench of larger Apple Silicon LLMs, ollama vs SwiftLM at long context, Gemma 4 coherence
  at 64 K, M1 Max VLM quality side-by-side, Claude Code-driven Dreamer real-task bench).
- `intel-bench/results/extended-summary.md` — consolidated phase-1 + phase-2 Intel findings; this
  is the file the blog Intel section was written against.
