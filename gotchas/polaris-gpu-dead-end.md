# AMD Radeon Pro 5xx on Intel Macs: tg is slower than CPU

Intel MacBook Pros from 2016–2019 ship a discrete AMD GPU (Radeon Pro 5xx series) with 2–8 GB dedicated VRAM. Ollama's internal llama.cpp build doesn't detect it ([ollama/ollama#13591](https://github.com/ollama/ollama/issues/13591)), but a standalone llama.cpp build with `GGML_METAL=ON` reaches it as `MTL0 (AMD Radeon Pro 560X)`. We benched.

| Model (weights) | pp512 GPU | tg128 GPU | tg128 CPU (same model) | Status |
|---|---:|---:|---:|---|
| moondream:1.8b (0.77 GB) | 81.5 t/s | 3.16 t/s | — | runs |
| llama3.2:1b (1.23 GB) | 100.2 t/s | 4.62 t/s | **12.1 t/s** | runs — CPU 2.6× faster |
| qwen3:1.7b (1.27 GB) | 91.6 t/s | 2.09 t/s | 8.5 t/s | runs |
| llama3.2:3b (1.88 GB) | 58.2 t/s | 2.46 t/s | 6.0 t/s | runs |
| gemma3:4b (3.11 GB) | — | TIMEOUT | 7.4 t/s | exceeds 4 GB VRAM |
| gemma4:e2b (6.67 GB) | — | TIMEOUT | 11.8 t/s | exceeds 4 GB VRAM |

Three problems compound:

## 1. Decode is slower on GPU than on CPU at every size

llama3.2:1b's tg128 is 4.62 tok/s on the GPU vs 12.1 tok/s on the CPU (~2.6× slower). The Polaris architecture (AMD "Bronze" tier) lacks `simdgroup matrix mul`, `bfloat`, and unified memory, so llama.cpp's `MTL,BLAS` backend keeps the actual matmul on the CPU's Accelerate BLAS — GPU is essentially decorative during decode.

## 2. 4 GB VRAM ceiling

Everything from gemma3:4b upward (the models that actually matter for v0.11 Dreamer on Intel) can't even attempt the GPU path. They exceed the dedicated VRAM and timeout on first attempt.

## 3. The AMD Bronze driver wedges

We hit `MTLIOAccelBuffer initWithDevice:` hangs in the `tg` stage that needed SIGKILL after 30 minutes. The stack trace tail:

```
0   libsystem_kernel.dylib  mach_msg2_trap
1   libsystem_kernel.dylib  mach_msg2_internal
2   IOSurface               IOSurfaceLookupFromMachPort
3   Metal                   _MTLAcceleratorIOService_Lookup
4   AMDMTLBronzeDriver      __6-[MTLIOAccelBuffer ...]_block_invoke
5   libdispatch.dylib       _dispatch_client_callout
6   libdispatch.dylib       _dispatch_lane_serial_drain
```

Our final `bench_llm_gpu.sh` wraps every llama-bench invocation in a wall-clock cap (pp: 300s, tg: 180s) and records `TIMEOUT` instead of letting hangs eat 30 minutes per model.

## Verdict

**Intel Mac → CPU only for LLM workloads.** The discrete GPU is the wrong tier — works in principle, fails in practice. Save the 4 GB VRAM for the Photos app and system services that actually benefit from it.

This is the inverse story from Apple Silicon, where MLX + unified memory + Metal-on-M-series wins decisively. On Intel, the discrete GPU was a dead end for LLM workloads even before MLX showed up. The exception: whisper.cpp uses simpler Metal kernels that *do* work on Polaris, so transcription stays on GPU on Intel Macs. But for any LLM-shaped workload, CPU is correct.

## If ollama adds a Vulkan backend

Future-looking: there's discussion in [ollama/ollama#13591](https://github.com/ollama/ollama/issues/13591) about a Vulkan compute backend that could in principle reach AMD on Intel Macs through a different driver path. If that lands and avoids the Bronze driver entirely, the picture might change. As of 2026-05, it's not in mainline ollama.
