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

### Dense conversational audio run — first pass (2026-05-17 AM, **contaminated**)

60 s clip from a 14-minute conversational Evernote recording (private, not reproducible). First pass below; superseded by the clean re-run below it.

| Arm | Wall clock | Sec-per-audio-sec |
|---|---:|---:|
| `cpu_n4` | 242.8 s | 4.05 |
| `metal_n2` | 261.6 s | 4.36 |
| `cpu_n2` | 267.3 s | 4.46 |
| `metal_n4` | 292.7 s | 4.88 |

⚠️ **These numbers are 30-45 % too slow.** Re-bench on the same clip the next morning (clean system, no concurrent sona, no Xcode build) produced 2.68-3.10 s/audio-s across all arms. The contamination story changes the qualitative ranking — see next section.

### Dense conversational audio run — clean re-bench (2026-05-17 morning)

Same 60 s private clip, fully clean system this time:

| Arm | Wall clock | Sec-per-audio-sec |
|---|---:|---:|
| **`cpu_n4`** | 161.06 s | **2.68** |
| **`metal_n4`** | 160.52 s | **2.68** |
| `cpu_n2` | 185.76 s | 3.10 |
| `metal_n2` | 186.07 s | 3.10 |

On this clip, with a clean system, **CPU and Metal are tied at each thread count** — the first-pass finding that "metal_n4 is the worst arm" turned out to be contamination, not a real effect. Higher thread count (4 vs 2) is a clean 15 % win regardless of backend on this dense workload.

### Clean-speech reference run on the canonical LibriVox clip (2026-05-17)

`audio/holmes_clip60.wav` (committed in this repo, public domain — see `audio/README.md`).

| Arm | Wall clock | Sec-per-audio-sec |
|---|---:|---:|
| *(numbers landing as bench finishes — replace this line)* | | |

This is the bench anyone can reproduce on their own hardware. The two runs above used a private personal recording; numbers there are only useful for *qualitative* comparison.

### What we know across all three runs

1. **Contamination dominates.** A second sona process, a cargo build, or Xcode rebuilding in the background changes the answer by 30-45 % — bigger than the difference between any two arms. Always check `pgrep -fl sona`, `pgrep -fl cargo`, and Activity Monitor before claiming a result.
2. **CPU vs Metal on Intel: depends on the audio.** The 2026-04-25 clean voice memo: CPU is 1.7× faster than the fastest Metal arm. The May 17 dense conversational audio (clean re-bench): CPU and Metal are *tied* at each thread count. So "CPU beats Metal on Intel" doesn't generalize — it's true for short bursts of clean speech, less true as audio density grows. The LibriVox clean-speech reference above should settle the comparison.
3. **Wall-clock varies 3-4× with audio density.** Don't compare absolute numbers across audio sources. Compare arms-within-a-run.

### Why the absolute number varies

Whisper's decoder generates one token at a time and the number of tokens scales with the speech rate + content density of the audio. A 60 s monologue may produce 100 tokens; 60 s of a fast-paced conversation with mid-sentence interruptions and proper nouns may produce 250+ tokens. The same 60 s audio file can have a 2-3× ratio in compute time depending on content.

The April **clean voice memo** is closer to the typical Remember This workload (a personal voice memo dictated by one speaker). The May 17 dense audio is closer to what someone would feed My Transcriber for meeting transcription — useful as the "worst-case under typical use" number. The LibriVox clip is studio-narrator-clean — close to the voice memo regime but reproducible on any machine.

## Apple Silicon (M1 Max / 64 GB) — first pass: 60 s clip too short

**Setup**: macOS Power Mode = High (powermode=2). Battery 20 %, on battery (laptop's normal AC charger was elsewhere — caveat noted but the bench is not GPU-throttled at this %). No concurrent sona, RT/MT GUI apps not running. 12-arm extended sweep against `audio/holmes_clip60.wav`.

### 60 s clip — all 12 arms tied (2026-05-17)

| Arm | Wall (s) | Sec-per-audio-sec | CPU avg / peak (%) |
|---|---:|---:|---:|
| `cpu_n1`     | 1.91 | 0.03 | 11 / 23 |
| `cpu_n2`     | 1.87 | 0.03 | 10 / 20 |
| `cpu_n4`     | 1.84 | 0.03 | 9 / 17 |
| `cpu_n6`     | 1.84 | 0.03 | 12 / 23 |
| `cpu_n8`     | 1.82 | 0.03 | 10 / 21 |
| `cpu_n10`    | 1.82 | 0.03 | 8 / 17 |
| `metal_n1`   | 1.90 | 0.03 | 11 / 22 |
| `metal_n2`   | 1.85 | 0.03 | 9 / 18 |
| `metal_n4`   | 1.82 | 0.03 | 11 / 23 |
| `metal_n6`   | 1.82 | 0.03 | 10 / 21 |
| `metal_n8`   | 1.81 | 0.03 | 8 / 16 |
| `metal_n10`  | 1.83 | 0.03 | 11 / 22 |

**Findings:**

1. **🚨 sona's `--gpu-device -2` "force CPU" idiom DOES NOT WORK on M1 Max.** Verbose run of the CPU arm shows `use gpu = 1`, `gpu_device = 0`, `ggml_metal_device_init: GPU name: Apple M1 Max` — Metal initializes regardless. **All 12 arms in this run actually ran on Metal.** That's why CPU and Metal results are identical at every thread count. The script's `cpu_n*` arms are mislabeled on Apple Silicon; the "force CPU" idiom only works on Intel sona.
2. **60 s is below the M1 Max bench's resolution.** Every arm lands in 1.81–1.91 s (~5 % spread, well within noise). The bench is dominated by ~1.8 s of fixed model-load + Metal kernel compilation (the verbose run shows ~15 separate `ggml_metal_library_compile_pipeline` lines), then inference itself is < 200 ms.
3. **CPU usage 8–12 % across all arms** — because every arm was actually Metal. The whisper-side CPU work (tokenizer + beam search) is light; the heavy lifting is on the GPU. Thread count (`--threads N`) only affects the CPU-side wrappers, not Metal inference — which is why n=1 and n=10 are within 5 % of each other.
4. **Cross-arch**: Intel CPU `cpu_n2` clean voice memo (April) = 1.35 s/audio-s. M1 Max Metal = 0.03 s/audio-s on the same clip class. **~45 × speedup.** That's the real story for the matrix.
5. **Open**: figure out how to actually force CPU on M1 Max sona (or accept that "CPU vs Metal" isn't a real choice on Apple Silicon — Metal is always available and always used). Until then, the M1 Max rows of the matrix only have one meaningful number: "Metal, regardless of thread count, ~0.03 s/audio-s on clean speech."

### Full-chapter follow-up (in progress)

Re-running against the full ~65 min Holmes chapter mp3 so per-arm inference time dominates over fixed setup overhead. Numbers landing as bench finishes — will replace this paragraph with the table.

## Discrete-GPU note for dual-GPU Intel MacBooks

On the i9-8950HK MacBook Pro 15-inch tested here, `--gpu-device 0|1|2|-1` all land on the **AMD Radeon Pro 560X (Polaris)**. macOS does not expose the Intel UHD 630 iGPU as a separate Metal device when a dGPU is present, even though the system has both physically installed. So "Metal" on this machine means "discrete Polaris GPU." The blog post's framing matches this: when we say "Metal on Intel" we mean the discrete GPU on machines that have one.

The `gotchas/polaris-gpu-dead-end.md` note in this repo specifically calls out that **whisper.cpp uses simpler Metal kernels than llama.cpp** — whisper works on Polaris (the numbers above confirm) while llama.cpp LLM inference does not. So Polaris is viable for whisper transcription, just not the *fastest* path.
