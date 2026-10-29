# LLM speed on ollama, October 2026

Decode (writing the answer) and prefill (reading the prompt) in tokens per second, from ollama's own counters, with a 200-token answer to a real long prompt cut to each size. One request per size; the 4K row includes loading the model. Every run here had the GPU idle before it started; the CPU load average at the start is in each raw file's folder log. Raw tables: `llm/raw/`.

## M1 Max 64 GB

**Decode, tok/s**

| Model | ollama | 4K | 8K | 16K | 32K | 48K | 64K |
|---|---|---|---|---|---|---|---|
| qwen3.6:35b | 0.40.8 | 61.3 | 61.6 | 49.7 | 45.8 | 43.3 | 37.0 |
| ornith-1.5:35b (a Qwen3.6 derivative) | 0.40.8 | 56.8 | 50.6 | 48.7 | 42.1 | 38.0 | 34.6 |
| qwen3.6:35b-mlx (ollama's MLX runner) | 0.40.8 | 42.4 | 48.9 | 49.1 | 40.5 | 37.5 | 30.5 |
| flint:40b (thinks before answering) | 0.40.8 | 70.1 | 64.8 | 59.7 | 52.9 | 35.8 | 25.0 |
| gemma4:26b | 0.40.8 | 44.5 | 42.6 | 39.0 | 27.8 | 24.5 | 19.8 |
| gemma4:26b-mlx (ollama's MLX runner) | 0.40.8 | 39.6 | 41.0 | 37.8 | 27.2 | 28.4 | 17.9 |
| gpt-oss:20b | 0.40.8 | 59.4 | 54.3 | 50.3 | 45.6 | 38.7 | 37.8 |
| gemma4:e2b | 0.40.8 | 60.7 | 76.5 | 86.6 | 56.1 | 51.9 | 42.2 |
| qwen3-coder:30b | 0.40.8 | 57.4 | 50.4 | 40.3 | 28.6 | 20.6 | 16.6 |
| bonsai-2:27b (ternary weights) | 0.40.8 | 15.9 | 15.8 | 15.0 | 14.1 | 11.4 | 10.3 |
| qwen3.8:27b-q4_K_M (dense 27B, GGUF tag) | 0.40.8 | 13.1 | 12.4 | 12.2 | 10.8 | 10.4 | 9.5 |
| nemotron-3.5-bolt:74b-a9b (segfaults on 0.40.8) | 0.40.10 | 4.7 | 4.9 | 4.6 | 5.8 | 5.7 | 3.6 |

**Prefill, tok/s**

| Model | 4K | 8K | 16K | 32K | 48K | 64K |
|---|---|---|---|---|---|---|
| qwen3.6:35b | 674 | 1281 | 1275 | 1053 | 1037 | 1198 |
| ornith-1.5:35b (a Qwen3.6 derivative) | 748 | 1272 | 1201 | 918 | 908 | 925 |
| qwen3.6:35b-mlx (ollama's MLX runner) | 320 | 608 | 730 | 673 | 790 | 767 |
| flint:40b (thinks before answering) | 306 | 630 | 732 | 686 | 774 | 810 |
| gemma4:26b | 400 | 612 | 746 | 740 | 961 | 1094 |
| gemma4:26b-mlx (ollama's MLX runner) | 465 | 545 | 658 | 658 | 872 | 983 |
| gpt-oss:20b | 686 | 1319 | 1214 | 934 | 912 | 1018 |
| gemma4:e2b | 1418 | 3135 | 4060 | 3945 | 4952 | 5604 |
| qwen3-coder:30b | 713 | 978 | 716 | 437 | 334 | 343 |
| bonsai-2:27b (ternary weights) | 135 | 195 | 209 | 190 | 194 | 231 |
| qwen3.8:27b-q4_K_M (dense 27B, GGUF tag) | 130 | 210 | 211 | 186 | 215 | 272 |
| nemotron-3.5-bolt:74b-a9b (segfaults on 0.40.8) | 109 | 176 | 99 | 98 | 95 | 94 |

## Intel i9-8950HK 32 GB

**Decode, tok/s**

| Model | ollama | 4K | 8K | 16K | 32K |
|---|---|---|---|---|---|
| gemma4:e2b | 0.40.8 | 15.9 | 14.8 | 8.6 | 4.3 |
| llama3.2:1b | 0.40.8 | 12.9 | 7.5 | 4.1 | 1.7 |
| gemma3:4b | 0.40.8 | 7.9 | 7.3 | 6.3 | 4.7 |
| qwen3:4b | 0.40.8 | 4.3 | 2.1 | 1.0 | 0.5 |
| qwen3:8b | 0.40.8 | 3.1 | 1.8 | 1.0 | 0.4 |

**Prefill, tok/s**

| Model | 4K | 8K | 16K | 32K |
|---|---|---|---|---|
| gemma4:e2b | 80 | 122 | 95 | 62 |
| llama3.2:1b | 121 | 139 | 115 | 65 |
| gemma3:4b | 54 | 99 | 91 | 70 |
| qwen3:4b | 37 | 46 | 34 | 16 |
| qwen3:8b | 24 | 33 | 26 | 14 |

## M1 Max at 100K and 200K

decode tok/s / prefill tok/s / wall time, one request each.

| Model | 100K | 200K |
|---|---|---|
| qwen3.6:35b | 29.8 / 318 / 325 s | 20.6 / 183 / 1094 s |
| ornith-1.5:35b | 29.5 / 308 / 336 s | 20.6 / 183 / 1091 s |
| qwen3.6:35b-mlx | 29.6 / 309 / 330 s | 22.5 / 129 / 1542 s |
| flint:40b | 23.5 / 328 / 306 s | 7.8 / 190 / 1047 s |
| gemma4:26b | 16.1 / 352 / 293 s | 8.4 / 240 / 852 s |
| gemma4:26b-mlx | 16.7 / 372 / 278 s | 8.6 / 287 / 714 s |
| gpt-oss:20b | 25.8 / 269 / 356 s | — |
| gemma4:e2b | 51.8 / 1799 / 61 s | — |
| qwen3-coder:30b | 11.0 / 85 / 1209 s | 6.3 / 47 / 4409 s |
| bonsai-2:27b | 10.7 / 88 / 1124 s | 7.7 / 62 / 3188 s |
| qwen3.8:27b-q4_K_M | 8.5 / 78 / 1281 s | 5.9 / 52 / 3804 s |
| nemotron-3.5-bolt:74b-a9b | 6.0 / 90 / 1260 s | 5.0 / 76 / 2769 s |

Not measured at these sizes: gemma4:e2b at 200K and gpt-oss:20b at 200K (outside their context window). qwen3-coder:30b and bonsai-2:27b are slow at both sizes on every night they ran.

## Runs measured and left out

| Raw file | Why it is not used |
|---|---|
| ctxsweep-ollama-qwen3.8_27b-20261024-233652 | default tag is now an nvfp4 build; ollama 0.40.8 and 0.40.9 refuse it (missing layer norms) |
| ctxsweep-ollama-qwen3.8_27b-20261025-005302 | same nvfp4 refusal |
| ctxsweep-ollama-qwen3.8_27b-20261025-005309 | same nvfp4 refusal |
| ctxsweep-ollama-qwen3.8_27b-q4_K_M-20261026-230032 | Mac busy (load 33-53); rerun 27 Oct |
| ctxsweep-ollama-qwen3.8_27b-q4_K_M-20261026-232329 | Mac busy (load 107-195); rerun 27 Oct |
| ctxsweep-ollama-qwen3.8_27b-q4_K_M-20261027-000751 | killed by macOS at 200K under load; rerun 27 Oct |
| ctxsweep-ollama-nemotron-3.5-bolt_74b-a9b-20261024-234543 | segfaults on ollama 0.40.8 |
| ctxsweep-ollama-nemotron-3.5-bolt_74b-a9b-20261025-013935 | segfaults on ollama 0.40.8 |
| ctxsweep-ollama-nemotron-3.5-bolt_74b-a9b-20261025-013946 | segfaults on ollama 0.40.8 |
| ctxsweep-ollama-bonsai-2_27b-20261025-091856 | daytime repeat of the 100K run (9.2 decode at load 33-53); kept the night figure |

