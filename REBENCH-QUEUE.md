# Re-bench queue — open work as of 2026-05-17

After the May 2026 "Local AI on Mac" blog post landed, several measurement gaps remained. Each entry below is a bench that, if run, would close a specific claim in the post (or fix a known wrong/missing data point).

Run order is rough priority — highest-value first. Numbers under "Effort" are rough wall-clock estimates on M1 Max / 64 GB in clean conditions.

## 1. ollama context-sweep at 4K / 8K / 16K / 32K / 48K / 64K

**Why**: The blog claims "SwiftLM beats ollama on the short-context A/B." That A/B was ~500-token input only. We never ran ollama at higher contexts, so the claim "SwiftLM wins at long context" isn't supported by data — it could be true, false, or flip at some context size. We currently can't tell.

**What to run**: The same five MoE models we already swept with SwiftLM, but through ollama's API instead:

- `qwen3-coder:30b` (ollama tag for Qwen3-Coder-30B-A3B)
- `gpt-oss:20b` (or the MXFP4 variant the SwiftLM bench used)
- `gemma3:26b` or whichever ollama tag matches our `Gemma-4-26B-A4B`
- `qwen3:35b` for Qwen3.6-35B-A3B (verify the tag)
- `qwen3:80b` for Qwen3-Next-80B (no ollama tag last time we checked; skip if still missing)

**Method**: Mirror `swiftlm/ctx_sweep.py` but use ollama's `/api/generate` with `keep_alive: 0` between context points. Same Dreamer prompt slicing. Record `eval_count / eval_duration` from each response for ollama's internal decode rate.

**Effort**: ~6–8 hours unattended on M1 Max.

**Blocked claim**: "SwiftLM beats ollama at long context" — currently unverified.

## 2. Apple Silicon LLM ctx-sweep re-bench (clean conditions) — pending models

**Why**: The blog's LLM matrix shows three small models with clean 2026-05-16 numbers (`Llama-3.2-3B`, `Phi-4-mini`, `Qwen3-4B`) and five larger models with † markers (Low-Power-Mode tainted, expect 2–6× slow). The † rows need clean re-benches before the matrix can drop the daggers.

**What to run** (pending list from `experiments/swiftlm/results-vlm-phase2/SUMMARY.md`):

- `mlx-community/Qwen3-8B-4bit`
- `mlx-community/gpt-oss-20b-MXFP4-Q4`
- `mlx-community/Qwen3.6-35B-A3B-4bit` (+`--thinking`)
- `mlx-community/Gemma-4-26B-A4B-it-4bit`
- `mlx-community/Qwen3-Coder-30B-A3B-Instruct-MLX-4bit`
- `mlx-community/Qwen3-Next-80B-A3B-Instruct-4bit` (+`--thinking`)

**Method**: `swiftlm/sweep_llm_rebench.sh` already exists and is set up for this. Resume where it paused.

**Effort**: ~6 hours unattended.

**Blocked claim**: The Apple Silicon LLM matrix as a whole — half the numbers carry † today.

## 3. Gemma-4-26B coherence at 64 K (targeted)

**Why**: We claim "Gemma-4-26B collapses into repetition at 80 K" — that's from running an 80 K Dreamer prompt through it. Our LLM context-sweep table shows Gemma-4-26B at 64 K decoding at 0.8 tok/s, but the sweep doesn't measure coherence — it just measures speed and writes the first 80 chars of output to the result file. So "Gemma-4 at 64 K" might or might not be coherent; we don't know.

**What to run**: Slice the Dreamer prompt to exactly 64 K and feed it to Gemma-4-26B-A4B via SwiftLM. Read the full output. If it's the same repetition garbage as the 80 K test, document it. If it's coherent, update the matrix and note Gemma 4 is viable up to ~64 K.

**Method**: `swiftlm/ctx_sweep.py` already slices the Dreamer prompt; just point it at Gemma 4 with `--sizes 64000` and inspect the output file's content snippet (or read the full content from the SwiftLM response). One model, one context size.

**Effort**: ~30–60 minutes.

**Blocked claim**: "Gemma 4 is the captioner winner but not the Dreamer LLM" — partly justified by 80 K collapse, but the actual threshold could be 32 K or 80 K or anywhere in between. Important for the matrix.

## 4. M1 Max VLM caption-quality side-by-side eval

**Why**: The blog's "All VLMs benched" table now has a Caption quality column. The Intel rows are filled with qualitative tags from our earlier eval; the M1 Max rows all say "pending side-by-side" because the quality eval hasn't run.

**What to run**: Generate captions for all 25 photos × 9 M1 Max VLMs using the existing bench harness output (we have the .md per-model files). Build a side-by-side HTML comparison page (the `experiments/captioning-bench/build_comparison_phase2.py` script in your last push looks designed for this).

**Method**: Run `build_comparison_phase2.py` against `experiments/captioning-bench/results/*-swiftlm-*.md`. Score each model qualitatively against the 4 quality dimensions from the original blog (OCR accuracy, setting accuracy, multilingual handling, hallucination rate).

**Effort**: ~1 hour (script already exists; the work is the qualitative scoring).

**Blocked claim**: The M1 Max half of the VLM quality column is empty.

## 5. Claude Code-driven Dreamer real-task bench

**Why**: The blog says "We haven't yet measured how much context a typical Dreamer session actually consumes. 32 K might be plenty for the common case; 64 K might be the floor. Open question." This is the actual question the matrix's LLM column depends on.

**What to run**: A new harness, not a re-bench of existing scripts. Steps:

1. Run SwiftLM with one of the candidate LLMs (`Qwen3.6-35B-A3B-4bit` + `--thinking` is the obvious first try).
2. Start Claude Code locally, point it at the SwiftLM endpoint (`OPENAI_API_BASE=http://127.0.0.1:5413/v1`, no API key needed).
3. Fire 3–5 representative Dreamer tasks (e.g. "summarize this week's photos and voice memos into a journal entry").
4. Capture: total context used by end of session, total tokens generated, total wall time, number of tool calls.
5. Compare across LLM candidates if first one looks viable.

**Method**: Brand new. Probably 4–8 hours to set up the harness + run a few tasks + write up findings.

**Effort**: Half a day to a full day.

**Blocked claim**: The whole "LLM for Claude Code-driven Dreamer" section is hypothesis until this runs.

## 6. Transcription bench (My Transcriber blog post)

**Why**: Separate workstream from the Local AI matrix. The MT blog needs its own benchmark covering:

- Intel CPU (Whisper Large v3 Turbo)
- M1 Max with Metal acceleration
- Discrete AMD Polaris GPU on Intel Macs (whisper.cpp uses simpler Metal kernels that *do* work on Polaris, per the `gotchas/polaris-gpu-dead-end.md` aside)
- Real-time factor (seconds of audio per second of wall time)
- Low Power Mode vs High Power Mode columns for each rig

**What to run**: Pick a representative audio corpus (different lengths, languages, voice quality). Time `rememberthis transcribe <file>` (the CLI exposes this) under each rig × Power Mode combination.

**Method**: New bench script in `experiments/` (mt-transcription-bench/?). Doesn't share much with the existing VLM/LLM harnesses.

**Effort**: ~1–2 days including writing the harness, running the matrix, and drafting the MT blog post.

**Blocked content**: The My Transcriber blog post equivalent of this Remember This post.

## Bonus: power-mode-aware product settings (Remember This + My Transcriber)

Not a bench, but a product change worth queueing: when on battery + Low Power Mode, background processing (VLM captioning backfill, in particular) is 5–6× slower than on AC + High Power. Possible v0.11+ behavior:

- Always-on (regardless of power state): voice memo transcription, real-time captioning of the last 24 hours of photos
- AC-only or High-Power-only (configurable): big backfill VLM jobs, long Dreamer sessions
- Settings UI: a "Background processing power policy" toggle per workload class

Not blocked by anything benchmarking-wise; just a product decision to make ahead of v0.11.
