# transcription-bench

Whisper-via-sona transcription bench for Remember This + My Transcriber. Reports the user-facing metric **seconds-to-transcribe-1-second-of-audio** across a 4-arm matrix: `{CPU, Metal} × {n_threads=2, n_threads=4}`. Cross-arch — runs on both Intel and Apple Silicon Macs.

## Quick start

```bash
# Prep audio (any voice memo, m4a/wav/mp3, picks the first 60s):
ffmpeg -y -i /path/to/voice-memo.m4a -ss 0 -t 60 -ar 16000 -ac 1 /tmp/clip60.wav

# Quit My Transcriber + Remember This first (sona contention).
# Plug in AC, set Power Mode to High Power if available.

./sona_bench.sh
```

Output: a 4-row summary table + per-arm transcripts in `/tmp/sona_<arm>.txt` + a CSV at `/tmp/sona_bench.csv`. Hardware fingerprint printed at the bottom — copy this into the result row when adding to `SUMMARY.md`.

## Environment overrides

| Var | Default | Notes |
|---|---|---|
| `SONA` | `/Applications/Remember This.app/Contents/MacOS/sona` | Path to bundled sona binary. Use My Transcriber's copy if RT isn't installed. |
| `MODEL` | `~/Library/Application Support/RememberThis/models/ggml-large-v3-turbo.bin` | Whisper GGUF. Try `medium`/`small` for memory-tight machines. |
| `CLIP` | `/tmp/clip60.wav` | 16 kHz mono WAV. Sona accepts m4a too but WAV avoids ffmpeg dependency at bench time. |
| `AUDIO_S` | `60` | Audio length in seconds — used to compute sec-per-audio-sec. **Must match the actual clip duration.** |
| `LANGUAGE` | `en` | Whisper language code. `auto` works but adds ~10 % overhead. |
| `RESULT_CSV` | `/tmp/sona_bench.csv` | Output CSV path. |
| `SKIP_PFLIGHT` | `0` | Set to `1` to bypass the "another sona is running" warning. Don't unless you're deliberately measuring contention. |

## What the arms mean

| Arm | `--gpu-device` | `--threads` | What it measures |
|---|---:|---:|---|
| `cpu_n2` | -2 | 2 | CPU-only with 2 worker threads. Sona's idiom for "force CPU" is an invalid gpu-device index. |
| `cpu_n4` | -2 | 4 | CPU-only with 4 worker threads. |
| `metal_n2` | 0 | 2 | Metal device 0 with 2 worker threads. On Intel dual-GPU MacBooks this is the discrete GPU (macOS hides the iGPU when a dGPU is present). On Apple Silicon it's the unified-memory GPU. |
| `metal_n4` | 0 | 4 | Metal device 0 with 4 worker threads. |

The unintuitive result the May 2026 blog post highlights is **CPU beats Metal on Intel Macs** — Whisper's mat-mul-heavy decoder hates the discrete GPU's shared memory bus. Apple Silicon flips this because unified memory removes the bottleneck. Validate on whatever Mac you're benching by comparing `cpu_n2` vs `metal_n2`.

## Numbers from the canonical Intel bench (2026-04-25)

i9-8950HK / 32 GB / Radeon Pro 560X / 85 s voice memo / `large-v3-turbo`, clean system at High Power:

| Arm | Wall clock | Sec-per-audio-sec |
|---|---:|---:|
| `cpu_n2` (default for fresh Intel installs) | 115 s | **1.35** |
| `cpu_n4` | 118 s | 1.39 |
| `metal_n2` | 216 s | 2.54 |
| `metal_n4` | 197 s | 2.32 |

If your numbers are 2-3× worse than these on the same hardware: contamination. The most common cause is a second sona running (My Transcriber or Remember This in the background) stealing 100-200% CPU. `pgrep -fl sona` to confirm.

## Apple Silicon — pending

Apple Silicon row is pending bench — see `../REBENCH-QUEUE.md` item #7. Expected to favor Metal heavily; numbers TBD.

## Adding new arms

Append a `run_arm` call at the bottom of `sona_bench.sh`. Example: measure Sona with `--gpu-device 0 --threads 1` (single-thread Metal, useful for measuring per-core overhead):

```bash
run_arm metal_n1    0 1
```

The script is intentionally short — flat list of arms, no for-loop, so adding hardware-specific variants stays one-line each.

## Pre-flight checklist

Before claiming a clean number:

- [ ] `pgrep -fl sona` empty
- [ ] `pgrep -fl rememberthis-daemon` shows only MCP servers (passive)
- [ ] `pmset -g custom | grep powermode` returns `powermode 2` (High Power) on Macs that support it
- [ ] AC plugged in (Battery Power messes with Power Mode interactions)
- [ ] Same audio clip across arms — never compare arms run on different files

## Related

- Canonical Intel results: `docs/technical/INTEL-METAL-BENCH.md` in the private monorepo (links to this script when it lands)
- Blog post that cites these numbers: `website/src/routes/(marketing)/blog/(posts)/benchmarks/2026-05-17/local-ai-on-mac-may-2026/+page.svelte`
- Apple Silicon counterpart bench: pending — see `../REBENCH-QUEUE.md` item #7
- Sona itself: [thewh1teagle/sona](https://github.com/thewh1teagle/sona)
