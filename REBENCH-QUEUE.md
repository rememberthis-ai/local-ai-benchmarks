# Re-bench queue — open work as of 2026-05-17

After the May 2026 "Local AI on Mac" blog post landed, several measurement gaps remained. Each entry below is a bench that, if run, would close a specific claim in the post (or fix a known wrong/missing data point).

Run order is rough priority — highest-value first. Numbers under "Effort" are rough wall-clock estimates on M1 Max / 64 GB in clean conditions.

**Progress update 2026-05-16 late evening session** (2 % battery, apples-to-apples runtime A/B):
- ✅ **ollama vs SwiftLM A/B on Llama-3.2-3B (M1 Max).** Ten minutes apart, same model, same hardware, both with `pmset powermode=2`. **ollama beats SwiftLM at every context point** measured: 4K +65 %, 8K +83 %, 16K +185 %, 32K +33 %. The blog's "SwiftLM beats ollama" framing was based on Qwen3-Coder-30B (MoE). For small dense Llama-3.2-3B, ollama wins clearly. Runtime preference is **model-class-dependent** — not a clean "SwiftLM > ollama" win. Partial close of item #1 below.
- ⚠️ **Hidden battery throttle at < 5 %** uncovered in the same session. SwiftLM Llama-3.2-3B in the morning (clean, full battery) hit 54 tok/s @ 4K. In the evening at 2 % battery with `pmset powermode=2` still reading 2: **18.8 tok/s @ 4K**. The 32K row collapsed from 8 → 0.4 tok/s. Means **all previously-published "clean" M1 Max SwiftLM numbers need a `battery > 5 %` qualifier** — macOS appears to enforce a kernel-level GPU throttle below ~5 % battery regardless of user-set Power Mode. The May-8 Low-Power-Mode-taint (5–6× slow) is now revealed to be the *upper bound* of a wider silent-throttling spectrum.

**Progress update 2026-05-16 evening session** (4 % battery, ran what would fit):
- ✅ `Qwen3-8B-4bit` (thinking) — 4K=37, 8K=30, 16K=22 tok/s; 32K errors with RemoteDisconnected (same failure mode as Qwen3-4B; SwiftLM closes the connection past 16K in thinking mode).
- 🟡 `gpt-oss-20b-MXFP4-Q4` — 4K=26 tok/s only. SwiftLM **segfaulted** at 8K (`Segmentation fault: 11`); 16K-64K all `ConnectionRefused`. Needs an isolated re-bench, not part of the bulk script.
- 🟡 `Qwen3.6-35B-A3B-4bit` (thinking) — 4K=42, 8K=33, 16K=23, 32K=13 tok/s captured **from the sweep log only**; ctx_sweep.py writes the result file at the very end, so killing mid-sweep (battery hit 4 %) lost the in-flight 48K row and never wrote the .md. 48K/64K still need re-runs.
- ✅ `gemma-4-e2b-it-4bit` (LLM-mode) — full 4K–64K row landed: 4K=32, 8K=17, 16K=8, 32K=2.8, 48K=1.61 e2e (SwiftLM-internal `predicted_per_second` of 0.4 is anomalously low at 48K; e2e is the consistent metric), 64K=1.1 tok/s. **Cross-arch finding: Intel CPU `gemma4:e2b` via ollama is 6 tok/s @ 32K — M1 Max SwiftLM is ~2× slower at 32K on the same weights.** Decode halves per ctx doubling, sharper degradation past 16K (classic small-MoE pattern). **64K is still coherent in the output snippet** — no Gemma-style collapse at this model size (relevant to item #3 below: the 80K collapse is a 26B-parent phenomenon, not inherent to the gemma4 family). The ollama-on-M1-Max comparison for `gemma4:e2b` is still pending — the model is 7.2 GB and not cached locally.

**Tooling issues uncovered:**

- `ctx_sweep.py` doesn't write the result md incrementally. If the sweep is interrupted (battery, segfault, kill), all per-ctx-point measurements that already returned are lost from disk — they only exist in the captured stdout log. **Fix:** flush the md after each ctx point lands.
- `bench-chain-silicon.sh` preflight rejected hosts in High Power Mode because it only awk'd for the legacy `lowpowermode` key (absent on systems where the user hasn't toggled LPM). Fixed in main-repo commit `adf85e76`: now also reads the newer `powermode` key (0=normal, 1=low, 2=high) and treats absence as "not in LPM". Same commit makes the script prefer `hf` over the deprecated `huggingface-cli`.
- SwiftLM appears to drop the TCP connection rather than return an error response when a thinking-mode model can't fit a 32K prompt — `Qwen3-4B` and `Qwen3-8B` both fail with `RemoteDisconnected` at 32K, not an HTTP 400. Worth investigating whether this is a config issue (KV cache size?) or a SwiftLM bug.

## 1. ollama context-sweep at 4K / 8K / 16K / 32K / 48K / 64K — partially closed

**Status (2026-05-16)**: Llama-3.2-3B A/B done — ollama beats SwiftLM 5–26× at every ctx point. Remaining work is the MoE/large-dense classes where the runtime preference may flip.

**Why**: The blog claims "SwiftLM beats ollama on the short-context A/B." That A/B was ~500-token input only and used MoE models (Qwen3-Coder-30B, gpt-oss-20b, Gemma-4-26B-A4B, Qwen3.6-35B-A3B). Llama-3.2-3B (small dense) now shows the opposite: ollama wins clearly. Runtime preference looks **model-class-dependent** — small dense → ollama, large MoE → SwiftLM (probably; the MoE A/B at long context is the missing piece).

**What to run**: The same five MoE models we already swept with SwiftLM, but through ollama's API instead:

- `qwen3-coder:30b` (ollama tag for Qwen3-Coder-30B-A3B)
- `gpt-oss:20b` (or the MXFP4 variant the SwiftLM bench used)
- `gemma3:26b` or whichever ollama tag matches our `Gemma-4-26B-A4B`
- `qwen3:35b` for Qwen3.6-35B-A3B (verify the tag)
- `qwen3:80b` for Qwen3-Next-80B (no ollama tag last time we checked; skip if still missing)

Also: `gemma4:e2b` via ollama-on-M1-Max — already on the cross-arch comparison wishlist; the model is 7.2 GB and not cached on the test M1 Max yet.

**Method**: Mirror `swiftlm/ctx_sweep.py` but use ollama's `/api/generate` with `keep_alive: 0` between context points. Same Dreamer prompt slicing. Record `eval_count / eval_duration` from each response for ollama's internal decode rate.

**Effort**: ~6–8 hours unattended on M1 Max (was the original estimate; minus ~1 hr for Llama-3.2-3B which is already done).

**Blocked claim**: "SwiftLM beats ollama at long context" — partially refuted for small dense models (Llama-3.2-3B); still unverified for MoE.

## 2. Apple Silicon LLM ctx-sweep re-bench (clean conditions) — pending models

**Why**: The blog's LLM matrix shows three small models with clean 2026-05-16 numbers (`Llama-3.2-3B`, `Phi-4-mini`, `Qwen3-4B`) and five larger models with † markers (Low-Power-Mode tainted, expect 2–6× slow). The † rows need clean re-benches before the matrix can drop the daggers.

**What to run** (pending list from `experiments/swiftlm/results-vlm-phase2/SUMMARY.md`, updated 2026-05-16):

- ~~`mlx-community/Qwen3-8B-4bit`~~ ✅ done (32K is RemoteDisconnected — see status above; 4K/8K/16K clean)
- `mlx-community/gpt-oss-20b-MXFP4-Q4` — **isolated re-bench** (SwiftLM segfaulted in batch run; only 4K landed)
- `mlx-community/Qwen3.6-35B-A3B-4bit` (+`--thinking`) — **48K/64K still pending** (4K-32K captured from log)
- `mlx-community/Gemma-4-26B-A4B-it-4bit` — untouched
- `mlx-community/Qwen3-Coder-30B-A3B-Instruct-MLX-4bit` — untouched
- `mlx-community/Qwen3-Next-80B-A3B-Instruct-4bit` (+`--thinking`) — untouched
- ~~`mlx-community/gemma-4-e2b-it-4bit` (LLM-mode)~~ ✅ **full 4K–64K row done.** Cross-arch finding above.

**Method**: `swiftlm/sweep_llm_rebench.sh` already exists and is set up for this. Resume where it paused. **Wait for the ctx_sweep.py incremental-write patch before doing the large models** — otherwise another battery event loses the in-flight ctx point. Alternatively, run one model at a time and write per-ctx checkpoint logs alongside.

**Effort**: ~4–5 hours unattended (was ~6 — three models already benched).

**Blocked claim**: The Apple Silicon LLM matrix as a whole — half the numbers carry † today, dropping to ~40 % after the 2026-05-16 session.

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

## 7. Apple Silicon transcription bench — match the Intel-Mac result

**Why**: The "Local AI on Mac (May 2026)" Remember This blog post claims an Audio
Transcription tier matrix, but only the Intel-Mac side has actual numbers (from
`docs/technical/INTEL-METAL-BENCH.md`, 2026-04-25 clean system). Apple Silicon row
currently says "M1 Max not yet benched" — which is honest but the gap is awkward
given we have a hard Intel data point with surprising results (CPU+n=2 beats Metal on
Intel iGPU by ~1.7×).

**What to run**: Mirror the Intel bench's 4-arm design on M1 Max:

| Arm | Backend | Threads | Expected |
|---|---|---:|---|
| 1 | Metal (GPU) | 4 | likely winner — UMA flips the Intel result |
| 2 | Metal (GPU) | 2 | second |
| 3 | CPU (`--no-gpu`) | 4 | slow path |
| 4 | CPU (`--no-gpu`) | 2 | slowest |

Use the same 85 s voice memo + `ggml-large-v3-turbo.bin` as the Intel bench so the
sec-per-audio-sec numbers compare apples-to-apples. Report wall clock, sona %CPU
peak/avg, and **transcribe-seconds-per-audio-second** (the user-facing metric).

**Method**: Same shape as the Intel bench — spawn `sona serve [--no-gpu] -p 0`, POST
to `/v1/models/load`, then `/v1/audio/transcriptions` with `language=auto` and
`n_threads=N`. Sample sona `%cpu` at 1 Hz. Clean system (no MT/RT daemons running,
no concurrent backfills) — the Intel bench notes the 2.6× contamination penalty
when a second sona is competing for cores.

**Effort**: ~1 hour once the M1 Max is freed up + on AC + at High Power.

**Blocked claim**: The Audio Transcription row in the blog matrix has Apple Silicon
listed as "pending". Filling that in lets the Audio Transcription section drop the
"M1 Max number pending" caveat and present a clean two-row comparison.

## 8. Document the < 5 % battery silent throttle (new gotcha)

**Why**: 2026-05-16 late-evening session uncovered that M1 Max silently throttles GPU clocks below ~5 % battery *even when `pmset powermode=2` reads 2 (High Power)*. Same SwiftLM run on same hardware: 54 → 18.8 tok/s @ 4K, 8 → 0.4 tok/s @ 32K — purely from battery dropping below 5 %. The existing `gotchas/low-power-mode-throttling.md` only covers the explicit-LPM case (5–6× slowdown). This is a separate sub-5%-battery silent throttle of roughly 3× at low ctx, growing at high ctx.

**What to do**: Add `gotchas/sub-5pct-battery-throttle.md` with the timestamped morning vs evening A/B numbers from 2026-05-16. Cross-link from `gotchas/low-power-mode-throttling.md`. Cite in any future SwiftLM bench summary that doesn't include a `battery > 5 %` qualifier.

**Method**: Documentation only — the data is already captured in `experiments/swiftlm/results-vlm-phase2/SUMMARY.md` (apples-to-apples follow-up section).

**Effort**: ~20 minutes.

**Blocked claim**: All SwiftLM "clean" numbers in the blog matrix carry an implicit "battery > 5 %" caveat. The gotcha lets the matrix qualifier link out instead of inlining a paragraph.

## Bonus: power-mode-aware product settings (Remember This + My Transcriber)

Not a bench, but a product change worth queueing: when on battery + Low Power Mode, background processing (VLM captioning backfill, in particular) is 5–6× slower than on AC + High Power. Possible v0.11+ behavior:

- Always-on (regardless of power state): voice memo transcription, real-time captioning of the last 24 hours of photos
- AC-only or High-Power-only (configurable): big backfill VLM jobs, long Dreamer sessions
- Settings UI: a "Background processing power policy" toggle per workload class

Not blocked by anything benchmarking-wise; just a product decision to make ahead of v0.11.
