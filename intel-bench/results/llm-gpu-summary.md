# Intel discrete-GPU LLM bench (llama.cpp standalone, Metal)

Run: Fri May 15 12:30:18 EEST 2026
Hardware: Intel(R) Core(TM) i9-8950HK CPU @ 2.90GHz / 32 GB
GPU: Radeon Pro 560X 4 GB (Metal 2, Polaris) + Intel UHD 630 1.5 GB (Metal 3)
llama.cpp: 834a243 ggml-webgpu: Enable NVIDIA self-hosted CI (#22976)
Caps: pp 300s, tg 180s. Hangs are recorded as 'TIMEOUT'.

| Model | Size | pp512 (tok/s) | tg128 (tok/s) | Backend | Notes |
|---|---|---|---|---|---|
| moondream:1.8b | 0.77 GB | 81.51 | 3.16 | MTL0 (AMD Radeon Pro 560X) | pp=OK · tg=OK |
| llama3.2:1b | 1.23 GB | 100.17 | 4.62 | MTL0 (AMD Radeon Pro 560X) | pp=OK · tg=OK |
| qwen3:1.7b | 1.27 GB | 91.64 | 2.09 | MTL0 (AMD Radeon Pro 560X) | pp=OK · tg=OK |
| llama3.2:3b | 1.88 GB | 58.23 | 2.46 | MTL0 (AMD Radeon Pro 560X) | pp=OK · tg=OK |
| gemma3:4b | 3.11 GB | — | TIMEOUT | MTL0 (AMD Radeon Pro 560X) | pp=rc=1 (timeout/crash) · tg=rc=1 (timeout/crash) |
| gemma4:e2b | 6.67 GB | — | TIMEOUT | MTL0 (AMD Radeon Pro 560X) | pp=rc=1 (timeout/crash) · tg=rc=1 (timeout/crash) |
