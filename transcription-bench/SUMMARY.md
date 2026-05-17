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

### LibriVox Sherlock Holmes — canonical public reference (2026-05-17, corrected)

`audio/holmes_clip60.wav` (committed in this repo via LFS, public domain — see `audio/README.md`). Single audiobook narrator, clean studio recording, moderate pace. Clean system: no concurrent sona, no cargo/Xcode builds, AC + High Power. **Bench harness uses `sona serve --no-gpu` HTTP API** — the same code path RT/MT use in production. (Earlier `sona transcribe --gpu-device -2` runs were silently running Metal regardless of the flag; superseded.)

| Arm | Wall clock | Sec-per-audio-sec | CPU avg / peak |
|---|---:|---:|---:|
| **`cpu_n4`** ★ | 47.78 s | **0.80** | 443 % / 572 % |
| `cpu_n2` | 71.94 s | 1.20 | 335 % / 534 % |
| `metal_n4` | 99.89 s | 1.66 | 209 % / 352 % |
| `metal_n2` | 118.29 s | 1.97 | 198 % / 344 % |

Reproduces the April voice memo result on a completely different (open, reproducible) clip: **CPU is ~2× faster than Metal on Intel Polaris dGPU.** Whisper's mat-mul-heavy decoder is a poor fit for shared-memory dGPU.

Two new findings this clip adds:

1. **`cpu_n4` is faster than `cpu_n2`** on this audio (47s vs 72s, 1.5× win). April voice memo showed n=2 winning n=4 by 3 s — likely sample variance or speech-rate; the gap there was within noise, while here it's decisive. **The current RT/MT default of `n_threads=2` on Intel may be leaving 33 % wall-clock on the table** depending on the workload.
2. **Metal does free the machine.** Metal arms use ~200 % CPU (≈ 2 cores) vs CPU arms at 335–443 %. If you want to keep using the Mac while transcription runs, Metal at `n=2` is the lowest-impact arm. If you want raw throughput, CPU at `n=4` runs **faster than real-time** (0.80 sec/audio-s) — the entire 60 s clip transcribes in 48 s.

### What we know now (post-bug-fix)

1. **Contamination still dominates if you let it happen.** Second sona process, cargo build, or Xcode rebuild changes the answer by 30-45 %. Always check `pgrep -fl sona`, `pgrep -fl cargo`, and Activity Monitor before claiming a result.
2. **CPU beats Metal on Intel — confirmed across two clips now.** April voice memo and May LibriVox Holmes both show CPU ~1.7-2× faster than Metal on i9-8950HK + Polaris. The earlier "audio-dependent" hypothesis was wrong: it was the broken `--gpu-device -2` flag silently running Metal in the "CPU" arms.
3. **Apple Silicon flips the result completely.** Same harness on M1 Max (see Apple Silicon section below): Metal is 8.5× faster than CPU. Unified-memory architecture turns the dGPU bottleneck into an advantage.
4. **Speed vs responsiveness trade-off is real on Intel.** CPU wins wall-clock but uses 3-4 cores; Metal loses wall-clock but only uses ~2 cores. Default to CPU for "transcribe and wait"; choose Metal if you want to keep editing while a long file processes.

### Why the absolute number varies across audio

Whisper's decoder generates one token at a time and the number of tokens scales with the speech rate + content density of the audio. A 60 s monologue may produce 100 tokens; 60 s of a fast-paced conversation with mid-sentence interruptions and proper nouns may produce 250+ tokens. The same 60 s audio file can have a 2-3× ratio in compute time depending on content. The April voice memo and the LibriVox Holmes clip are both in the "clean monologue" regime; they agree closely. Dense conversational audio would land elsewhere — see the FDR clip (different regime) and dense-conversational private-clip findings in the bench-bug retracted-runs appendix.

### Retracted runs (broken `--gpu-device -2`)

The following runs are kept for the audit trail but **superseded by the LibriVox table above.** They all used the now-known-broken `sona transcribe --gpu-device -2` "force CPU" hack, which silently fell through to Metal on this hardware. The numbers labeled "cpu_*" in these tables actually ran Metal:

| Run | Setup | Status |
|---|---|---|
| 2026-05-17 AM dense audio (first pass) | Private Evernote clip, `--gpu-device -2`, contaminated | Bench code was broken; numbers are all-Metal under contamination |
| 2026-05-17 morning dense audio (re-bench) | Private Evernote clip, `--gpu-device -2`, clean | Bench code was broken; "tied at each thread count" was actually Metal-vs-Metal |
| 2026-05-17 LibriVox first pass | Holmes clip, `--gpu-device -2`, clean | Bench code was broken; "Metal wins" finding was Metal-vs-Metal |

The "1.7× CPU advantage" April INTEL-METAL-BENCH.md was unaffected — it used `sona serve --no-gpu` HTTP API (the correct method), same as the corrected harness above.

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

### 60 s clip — re-run with fixed harness (2026-05-17, post-patch)

After patching the harness to use `sona serve --no-gpu` HTTP API instead of `sona transcribe --gpu-device -2` (the latter is a no-op on Apple Silicon — see Findings #1 above and `gotchas/sona-gpu-device-2-noop.md`), the same 60 s clip now produces meaningful per-arm differences:

| Arm | Wall (s) | Sec-per-audio-sec | CPU avg / peak (%) |
|---|---:|---:|---:|
| `cpu_n1`        | 52.19  | 0.87  | 104 / 110 |
| `cpu_n2` ⚠️     | 208.27 | **3.47** | 120 / 153 |
| `cpu_n4`        | 16.66  | 0.28  | 125 / 205 |
| `cpu_n6`        | 12.26  | 0.20  | 127 / 207 |
| **`cpu_n8`** ★  | 10.44  | **0.17** | 125 / 206 |
| `cpu_n10`       | 11.90  | 0.20  | 111 / 127 |
| `metal_n1`      | 1.46   | 0.02  | 43 / 73  |
| `metal_n2`      | 1.41   | 0.02  | 42 / 71  |
| **`metal_n4`** ★| 1.39   | **0.02** | 42 / 71 |
| `metal_n6`      | 1.38   | 0.02  | 42 / 73  |
| `metal_n8`      | 1.38   | 0.02  | 36 / 60  |
| `metal_n10`     | 1.38   | 0.02  | 39 / 67  |

**Findings (corrected):**

1. **Metal is 8.5× faster than the best CPU arm on M1 Max** (0.02 vs 0.17 s/audio-s). The earlier "all arms tied" result was the harness bug, not a hardware property. This matches Apple-Silicon expectations — unified memory makes the GPU path strictly better for whisper inference.
2. **CPU sweet spot is `--threads 8`** (one thread per M1 Max performance core; the chip has 8 perf + 2 efficiency cores). n=10 regresses slightly — pulling efficiency cores into the pool adds contention without adding compute.
3. **Metal arms still tie at 60 s** (1.38-1.46 s across all 6) — Metal inference is so fast on M1 Max that even 60 s of audio is dominated by ~1.4 s of fixed model-load + Metal kernel compilation. Per-arm Metal CPU usage of ~42 % is the whisper-side tokenizer/beam-search overhead, NOT inference. Thread count below n=8 doesn't matter for Metal because the CPU side is light.
4. **🚨 cpu_n2 anomaly**: 3.47 s/audio-s is wildly out of line vs n=1 (0.87) and n=4 (0.28). Likely transient contention from a background process (Spotlight/sleep wake/etc.) during the cpu_n2 arm. Re-run to confirm — but n=1 and n=4 onward form a clean curve.
5. **Production setting (RT/MT `cpu_only_transcription`) is effective**. The setting flows through `core-lib/src/integrations/transcription/whisper.rs` → `SonaProcess::spawn(no_gpu=true)` → `sona serve --no-gpu`, which is the only working CPU-disable on Apple Silicon. Verified: enabling it changes inference from Metal (0.02 s/audio-s) to CPU (0.17 s/audio-s at n=8) — an 8.5× slowdown.

### Cross-arch summary (clean LibriVox clip, both clean systems, post-bug-fix harness)

| Hardware | Best arm | Sec-per-audio-sec | Notes |
|---|---|---:|---|
| Intel i9-8950HK + Polaris dGPU | **`cpu_n4`** | **0.80** | CPU 2× faster than Metal (Polaris dGPU is a bottleneck) |
| M1 Max (Apple Silicon) | **`metal_n4`** | **0.02** | Metal 8.5× faster than CPU (unified memory wins) |

**Cross-arch headline: M1 Max Metal is 40× faster than Intel's best path (CPU+n=4).** Apple Silicon flips both the answer ("use Metal" vs "use CPU") AND wins the absolute speed race by a large margin.

(Earlier draft of this table said "Intel metal_n4 1.70 → M1 Max 85× faster than Intel best" — that cited the now-superseded broken-harness Intel numbers where the "CPU" arms were silently running Metal. The corrected Intel numbers above are from the same `sona serve --no-gpu` HTTP harness as the M1 Max data, so the 40× cross-arch comparison is apples-to-apples.)

### Full-chapter follow-up (queued, not yet run)

The full ~65 min Holmes chapter mp3 (`/tmp/holmes_full.mp3`, 31 MB) is downloaded but not yet bench-run. Useful to confirm: (a) whether Metal arms diverge on a longer clip (still overhead-dominated at 60 s); (b) whether the cpu_n2 anomaly reproduces or was a one-off. **Setup cost for the long clip is the same ~1.4 s, so per-arm Metal time should grow from 1.38 s by ~(audio_length/60) × 0.02 s — for 65 min audio ~80 s wall, vs CPU at n=8 ~660 s wall.**

## Discrete-GPU note for dual-GPU Intel MacBooks

On the i9-8950HK MacBook Pro 15-inch tested here, `--gpu-device 0|1|2|-1` all land on the **AMD Radeon Pro 560X (Polaris)**. macOS does not expose the Intel UHD 630 iGPU as a separate Metal device when a dGPU is present, even though the system has both physically installed. So "Metal" on this machine means "discrete Polaris GPU." The blog post's framing matches this: when we say "Metal on Intel" we mean the discrete GPU on machines that have one.

The `gotchas/polaris-gpu-dead-end.md` note in this repo specifically calls out that **whisper.cpp uses simpler Metal kernels than llama.cpp** — whisper works on Polaris (the numbers above confirm) while llama.cpp LLM inference does not. So Polaris is viable for whisper transcription, just not the *fastest* path.
