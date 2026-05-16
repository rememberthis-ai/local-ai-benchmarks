# Transcription bench — results

Whisper-via-sona on the 4-arm matrix `{CPU, Metal} × {n_threads=2, n_threads=4}` for `large-v3-turbo`. Reported in **seconds-to-transcribe-1-second-of-audio** — the user-facing metric the May 2026 blog post uses.

## Intel Mac (i9-8950HK / 32 GB / Radeon Pro 560X)

Two clean runs on the same hardware, different audio sources. Both confirm the same qualitative result: **CPU beats Metal on Intel** — the Polaris dGPU's shared memory bus is a poor fit for Whisper's mat-mul-heavy decoder. Numbers vary with audio density (denser speech = more decoder iterations = longer compute time).

### Reference clean run — clean voice memo (2026-04-25)

85 s voice memo, conversational but clean speech.

| Arm | Wall clock | Sec-per-audio-sec | Notes |
|---|---:|---:|---|
| **`cpu_n2`** ★ | 115 s | **1.35** | Default for fresh Intel installs. |
| `cpu_n4` | 118 s | 1.39 | |
| `metal_n4` | 197 s | 2.32 | Polaris dGPU. |
| `metal_n2` | 216 s | 2.54 | Polaris dGPU. |

Source: `docs/technical/INTEL-METAL-BENCH.md` in the private monorepo. CPU is **1.7×** faster than Metal here. Same machine.

### Dense conversational audio run (2026-05-17)

60 s clip from a 14-minute conversational Evernote recording (multiple speakers, fast pace, lots of acronyms — much denser than a voice memo). Sona at v0.1.4 (bundled in RT v0.10).

| Arm | Wall clock | Sec-per-audio-sec | Notes |
|---|---:|---:|---|
| **`cpu_n4`** ★ | 242.8 s | **4.05** | Best on dense audio. |
| `polaris_n2` | 261.6 s | 4.36 | Metal-on-dGPU competitive at low thread count. |
| `cpu_n2` | 267.3 s | 4.46 | |
| `polaris_n4` | 292.7 s | 4.88 | Worst — Metal + n=4 over-subscribes the tokenizer-side CPU. |

Reproduce with `./sona_bench.sh` after generating a clip via the `ffmpeg` snippet in `README.md`. Clean system: no concurrent sona, AC + macOS Power Mode irrelevant on this Intel Mac (no Power Mode setting exposed).

### What stays true across both runs

1. **CPU beats Metal on Intel.** The April clean voice memo: CPU is ~1.7× faster than the fastest Metal arm. The May 17 dense audio: CPU is still faster, but the margin narrows to ~1.07× — Metal-Polaris closes the gap when the workload is more compute-heavy and the dGPU's memory bandwidth bottleneck matters less relative to total compute.
2. **`metal_n4` is the worst arm.** True on both runs. Don't run Metal at n_threads=4 on Intel — the CPU is doing tokenization + beam search and competing with itself.
3. **Wall-clock varies 3-4× with audio density.** Don't compare absolute numbers across audio sources. Compare arms-within-a-run, or report both numbers.

### Why the absolute number varies

Whisper's decoder generates one token at a time and the number of tokens scales with the speech rate + content density of the audio. A 60 s monologue may produce 100 tokens; 60 s of a fast-paced conversation with mid-sentence interruptions and proper nouns may produce 250+ tokens. The same 60 s audio file can have a 2-3× ratio in compute time depending on content.

The April **clean voice memo** is closer to the typical Remember This workload (a personal voice memo dictated by one speaker). Use those numbers as the "expected" baseline. The May 17 dense audio is closer to what someone would feed My Transcriber for meeting transcription — useful as the "worst-case under typical use" number.

## Apple Silicon (M1 Max / 64 GB) — pending

See `../REBENCH-QUEUE.md` item #7 for the spec. Expected to favor Metal heavily (unified memory removes the dGPU bus bottleneck). Numbers TBD.

## Discrete-GPU note for dual-GPU Intel MacBooks

On the i9-8950HK MacBook Pro 15-inch tested here, `--gpu-device 0|1|2|-1` all land on the **AMD Radeon Pro 560X (Polaris)**. macOS does not expose the Intel UHD 630 iGPU as a separate Metal device when a dGPU is present, even though the system has both physically installed. So "Metal" on this machine means "discrete Polaris GPU." The blog post's framing matches this: when we say "Metal on Intel" we mean the discrete GPU on machines that have one.

The `gotchas/polaris-gpu-dead-end.md` note in this repo specifically calls out that **whisper.cpp uses simpler Metal kernels than llama.cpp** — whisper works on Polaris (the numbers above confirm) while llama.cpp LLM inference does not. So Polaris is viable for whisper transcription, just not the *fastest* path.
