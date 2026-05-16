# Intel Mac inference bench

Goal: get real numbers for what's actually feasible on an Intel Mac
running ollama, so the v0.11 Intel tier in the blog post matrix stops
being labeled "first-party benches pending."

Background: SwiftLM (the MLX-based runtime we benched on M1 Max for the
[main post](https://rememberthis.ai/blog/benchmarks/2026-05-16/faster-local-ai-with-swiftlm))
is Apple-Silicon-only. Intel Macs stay on ollama. On Intel, ollama
runs on the CPU (Intel iGPUs are too weak for useful LLM inference);
the real constraint is total system RAM and CPU throughput, not iGPU
VRAM.

We want to answer three concrete questions:

1. **Captioning**: is `moondream:1.8b` still the right default? Or does
   ollama on Intel CPU run a slightly bigger VLM (e.g. `gemma3:4b`) at
   acceptable speed?
2. **Dreamer LLM**: what's the biggest LLM that produces coherent
   on-topic synthesis at ~8–16 K context within a reasonable wall-clock
   budget on Intel? Likely `llama3.2:3b` or smaller.
3. **Where's the cliff?** Same ctx-vs-tok/s curve we ran on M1 Max,
   re-measured on Intel CPU.

## How to run

Prerequisites:
- Intel Mac with at least 16 GB RAM (32 GB recommended)
- ollama installed and running (`ollama serve` in another terminal, or
  Remember This v0.10.x running which auto-starts ollama)
- Python 3.10+
- About 90 minutes of free machine time

```bash
cd experiments/intel-bench

# 0. ollama on RT-bundled port + binary on PATH
export OLLAMA_HOST=127.0.0.1:21434
export OLLAMA_HOST_URL=http://127.0.0.1:21434
export PATH="/Applications/Remember This.app/Contents/Resources/ollama:$PATH"

# 1. Pull the candidate models
./pull_models.sh phase1   # ~10 GB — original 4 VLMs + 5 LLMs
./pull_models.sh phase2   # ~14 GB — Qwen-VL family + Gemma 4 edge (extended)
./pull_models.sh all      # both at once

# 2. Sideload moondream3 (MoE 9B/2B-active; not in official ollama library yet)
./sideload_moondream3.sh                 # community Q4_K_M + mmproj GGUFs required

# 3. CPU captioning bench (extended VLM list, ~5 h)
./bench_captioning.sh

# 4. CPU LLM context-size sweep (extended LLM list, ~2-3 h)
./bench_llm.sh

# 5. GPU bench via llama.cpp standalone (Radeon Pro 560X, ~30-60 min)
#    Requires llama.cpp/build/bin/llama-bench (build instructions below).
./bench_llm_gpu.sh
```

Results land in `results/` as Markdown tables, one per model. The
existing `experiments/swiftlm/results-llm/` directory follows the same
format so we can compare side-by-side once both are filled in.

For the **single-entry unattended chain**, run
[`./bench-chain-intel.sh`](bench-chain-intel.sh) (or [`../bench-all.sh`](../bench-all.sh)
which auto-dispatches by `uname -m`). Each phase has a wall-clock cap so a wedged
run doesn't eat hours.

### Building llama.cpp (one-time, for the GPU bench)

```bash
# In experiments/intel-bench/
git clone --depth=1 https://github.com/ggml-org/llama.cpp.git
cd llama.cpp
cmake -B build -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --target llama-bench llama-cli -j 8
```

Needs `brew install cmake`. ~10 min build on an i9. The Metal backend
compiles fine on Intel Macs — but see the **GPU bench caveats** section
below for the Polaris driver-hang issue.

## What gets measured

### Captioning (`bench_captioning.sh`)

Runs each candidate VLM against the 25-photo test set used in the main
post. For each model, records:

- Per-photo wall time (seconds)
- Total wall time for all 25 photos
- First 80 chars of each caption (so we can spot quality regressions)

Candidate VLMs (in order of size):

| Model | Weights | Why |
|---|---|---|
| `moondream:1.8b` | ~1.8 GB | Current default, baseline |
| `llava:7b` | ~4 GB | LLaMA-based, well-supported in ollama |
| `gemma3:4b` | ~3 GB | Newer, smaller than minicpm, may run at acceptable speed |
| `minicpm-v:8b` | ~5 GB | The bigger-better captioner we benched on M1 Max, see if it's tolerable on Intel CPU |

If a model takes >60 s/photo we'll call that "not viable for default,
but available as opt-in." The 25-photo total is the load-bearing
metric — if it's over an hour, users will notice.

### Long-context LLM sweep (`bench_llm.sh`)

Same dreamer prompt sliced to 4K / 8K / 16K / 32K target tokens.
Records:

- Decode tok/s (ollama's `eval_count / eval_duration`)
- Prefill tok/s (`prompt_eval_count / prompt_eval_duration`)
- Wall time
- First 80 chars of `response`

Candidate LLMs (small-first):

| Model | Weights | Why |
|---|---|---|
| `qwen3:1.7b` | ~1.1 GB | Smallest viable Qwen |
| `llama3.2:1b` | ~0.7 GB | Smallest viable Llama |
| `llama3.2:3b` | ~2 GB | What we predict will be the Intel default |
| `gemma3:4b` | ~3 GB | Larger, may be too slow on CPU |
| `qwen3:8b` | ~5 GB | Upper bound — expect very slow but want a data point |

Critical: **content quality matters more than tok/s.** A model that
emits 1.5 tok/s of real synthesis beats a model that emits 5 tok/s
of `"Apologies, but I cannot assist..."`. The 80-char preview tells
us which is which.

## What "good enough" looks like

For the Intel matrix we want at least:

- **Captioning** model that does 25 photos in ≤30 min (≤72 s/photo)
- **LLM** that produces coherent output at 8 K context in ≤5 min
  wall time

If we hit both bars, the Intel tier graduates from "TBD" to a
recommendation. If we don't, we publish the numbers anyway so users
know what to expect.

## Reporting back

When you're done, paste the contents of `results/intel-summary.md`
(auto-generated by `bench_llm.sh`) and any captioning result file
into the [main eval doc](../../docs/plans/SWIFTLM-MLX-CAPTIONING-EVAL.md).
The Intel-tier row in the blog matrix will be updated to cite real
numbers + your Intel Mac's CPU spec, replacing the current placeholder.

## Caveats worth noting upfront

- **First-run wall time is dominated by model download**, not
  inference. The pull script does all downloads up front so the bench
  itself measures inference only.
- **Background processes matter on Intel even more than Apple Silicon**
  because there's no unified memory cushion. Quit Chrome / Slack /
  Obsidian before running the LLM sweep for clean numbers.
- **Thermal throttling**: a 90-min CPU-bound bench on Intel will heat
  the machine. If you see decode rates degrade over time, the CPU is
  probably down-clocking. Note the ambient temperature in your report
  if it's hot.
- **ollama's `keep_alive`**: this script sets `keep_alive: 0` so the
  model unloads between runs (same gotcha we hit on the M1 bench). If
  you skip that, the second model will look much slower than it
  actually is.

## GPU bench caveats (Polaris / Radeon Pro 5xx + llama.cpp)

Durable findings about the Intel-Mac discrete-GPU path, learned the hard
way during phase 1. If you (or a future Claude session) reach for the
discrete GPU again, read this first.

**Setup at the time of measurement**: 2018 MacBook Pro 15", i9-8950HK (6
cores / 12 threads), 32 GB RAM, Radeon Pro 560X (4 GB VRAM, **Metal 2,
Polaris/Bronze architecture**, 2017-era) + Intel UHD 630 (1.5 GB shared,
Metal 3, too weak for LLM use). macOS 15.7.5.

### ollama doesn't see the GPU at all

ollama 0.21.0 (bundled in RT v0.10.x) does **not** detect the AMD discrete
GPU on Intel Macs. Tracking issue: [ollama/ollama#13591](https://github.com/ollama/ollama/issues/13591).
Known non-solutions: `GGML_METAL=1`, `OLLAMA_NUM_GPU=1`, `pmset` graphics
switching. Phase-1 CPU numbers in [llm-summary.md](results/llm-summary.md)
and [captioning-summary.md](results/captioning-summary.md) are therefore
clean CPU measurements — the 4 GB Radeon sat idle the entire 9-hour
sweep.

### llama.cpp standalone *can* see the GPU but it's not useful

Build with `-DGGML_METAL=ON` and llama.cpp picks the higher-perf device:

```
ggml_metal_device_init: GPU name:   MTL0 (AMD Radeon Pro 560X)
ggml_metal_device_init: simdgroup reduction   = false
ggml_metal_device_init: simdgroup matrix mul. = false
ggml_metal_device_init: has unified memory    = false
ggml_metal_device_init: has bfloat            = false
ggml_metal_device_init: recommendedMaxWorkingSetSize  =  4294.97 MB
```

Polaris is too old for modern llama.cpp kernels. The `MTL,BLAS` backend
label means *split* — Metal handles only the few ops it can; BLAS
(Accelerate.framework = CPU) handles the rest. Net effect during a
benchmark with `-ngl 99`:

| Metric | Observed |
|---|---|
| GPU utilization | 0–5% |
| GPU VRAM used | ~150 MB (out of 4 GB) |
| CPU usage | ~80% (still pegged) |
| llama-bench CPU% | 700%+ (7+ cores fully busy) |
| GPU power draw | +17 W on top of CPU |
| llama3.2:1b tg decode | **3.5 tok/s GPU** vs **14.1 tok/s CPU-only ollama** |

So we get **worse tok/s, no CPU savings, AND extra power draw**. Worst of
all three worlds.

### Decode hangs the AMD driver

pp (prefill) completes cleanly. tg (token-generation) wedges inside
`MTLIOAccelBuffer initWithDevice:` and never returns. Sample of the
hung stack:

```
ggml_backend_sched_graph_compute_async
  ggml_metal_buffer_set_tensor
    -[BronzeMtlDevice newBufferWithBytesNoCopy:length:options:deallocator:]
      -[BronzeMtlBuffer initInternalWithDevice:...]
        -[MTLIOAccelBuffer initWithDevice:...]
          -[MTLIOAccelResource initWithDevice:options:args:argsSize:]
```

The process stays at 0% CPU forever; the GPU power-states down to idle;
only SIGKILL clears it. Reproduced on `moondream:1.8b` (Q4) with
`-ngl 99 -p 512 -n 128`. That's why `bench_llm_gpu.sh` runs pp and tg
as separate llama-bench invocations and wraps each in a hard wall-clock
cap (pp 300 s, tg 180 s) — TIMEOUT gets recorded cleanly instead of
burning 30+ minutes per model.

### Whisper IS GPU-accelerated on the same hardware

This is the source of confusion when reading "does Metal work on Intel
Macs?" online — the answer depends entirely on the kernel demands of the
workload. `whisper-rs` / `whisper.cpp` use a simpler Metal kernel set and
run fine on Polaris. Code path in
`core-lib/src/integrations/transcription/whisper.rs` (config flags
`gpu_only_transcription` / `cpu_only_transcription`). The
[`e65ab15` commit](https://github.com/rememberthis-ai/rememberthis/commit/e65ab15)
captures the arch-aware defaults RT uses for Whisper on this rig.

### Implications for the v0.11 blog matrix

Discrete GPU on Intel Mac is a **footnote/sidebar to the Intel-CPU row,
not its own tier**. Recommended wording for the post:

> *ollama leaves the discrete GPU idle on Intel Macs. Forcing GPU use
> via llama.cpp standalone is slower than CPU on Polaris/Radeon Pro 5xx
> and hangs the AMD driver during decode. The same GPU works fine for
> Whisper transcription because whisper.cpp uses simpler Metal kernels.
> Newer Intel-Mac GPUs (Vega 16/20, Radeon Pro 5300M/5500M/5600M) may
> behave differently, but ollama's open issue
> [#13591](https://github.com/ollama/ollama/issues/13591) suggests the
> "GPU undetected" problem extends across the family.*

### Where to look in the repo

- `bench_llm_gpu.sh` — timeout-wrapped GPU bench (per-stage caps).
- `llama.cpp/build/bin/llama-bench` — built with `GGML_METAL=ON`.
- `results/llm-gpu-raw-moondream_1.8b.log` — first GPU run, pp512 = 80.99
  tok/s succeeded, tg128 wedged (the wedge is the durable finding).
