# Photo captioning, October 2026

30 personal photos (kept private), the same prompt and a 120-token cap on both Macs, ollama 0.40.8 unless the row says MLX; nemotron on ollama 0.40.10. Median seconds per photo with the model loaded. The caption text describes private photos and is not published; the per-model summaries are in `m1max/` and `intel/`.

| Model | Intel i9 | M1 Max | Mean tokens | Empty captions | At the cap |
|---|---|---|---|---|---|
| bonsai-2:4b (thinking off) | — | 1.68 s | 67.5 | 0 | 1 |
| bonsai-2:9b (thinking off) | — | 2.95 s | 66.5 | 0 | 0 |
| gemma3:4b | 39.21 s | 3.04 s | 63.4 | 0 | 0 |
| gemma4:e2b (thinking off) | 9.83 s | 0.88 s | 45.3 | 0 | 0 |
| gemma4:e4b (thinking off) | 13.78 s | 1.51 s | 54.3 | 0 | 0 |
| llava:7b | 45.94 s | 2.32 s | 74.9 | 0 | 2 |
| minicpm-v:8b | 33.14 s | 2.32 s | 46.3 | 0 | 2 |
| moondream:1.8b | 11.14 s | 0.73 s | 33.9 | 0 | 3 |
| nemotron-3.5-bolt:74b-a9b (thinking off) | — | 18.6 s | 49.6 | 0 | 0 |
| openbmb/minicpm-v4.5 | 47.06 s | 4.7 s | 119.8 | 0 | 29 |
| qwen2.5vl:3b | 49.64 s | 3.22 s | 52.0 | 0 | 0 |
| qwen3-vl:2b-instruct | 34.84 s | 1.81 s | 66.9 | 0 | 0 |
| qwen3-vl:4b-instruct | 52.65 s | 3.49 s | 65.8 | 0 | 0 |
| qwen3-vl:8b-instruct | 83.07 s | 7.56 s | 66.6 | 0 | 0 |
| lmstudio-community/Qwen3-VL-8B-Instruct-MLX-4bit · MLX via SwiftLM | — | 3.27 s | 68.1 | 0 | 1 |
| mlx-community/Qwen2.5-VL-3B-Instruct-4bit · MLX via SwiftLM | — | 1.14 s | 42.6 | 0 | 0 |
| mlx-community/Qwen3-VL-2B-Instruct-4bit · MLX via SwiftLM | — | 1.38 s | 53.7 | 0 | 0 |
| mlx-community/Qwen3-VL-4B-Instruct-4bit · MLX via SwiftLM | — | 2.21 s | 61.5 | 0 | 0 |

