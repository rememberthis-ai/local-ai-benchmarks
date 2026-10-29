# KV-cache quantisation on ollama 0.40.8 (23 Oct)

decode tok/s · size_vram GB (prefill tok/s)

## qwen3.6:35b

| ctx | A_default | B_fa_f16 | C_fa_q8_0 | D_fa_q4_0 |
|---|---|---|---|---|
| 8,192 | 50.9 · 22.8 (824.0) | 61.1 · 1.0 (807.5) | 43.0 · 1.0 (689.1) | 54.6 · 0.9 (754.5) |
| 32,768 | 57.4 · 23.4 (738.8) | 55.9 · 1.6 (732.1) | 27.0 · 1.4 (781.1) | 43.4 · 1.2 (783.7) |
| 65,536 | 49.1 · 24.1 (634.7) | 48.3 · 2.4 (634.3) | 18.6 · 1.7 (630.5) | 32.6 · 1.4 (629.5) |

## qwen3:4b

| ctx | A_default | B_fa_f16 | C_fa_q8_0 | D_fa_q4_0 |
|---|---|---|---|---|
| 8,192 | 63.3 · 3.9 (783.3) | 63.8 · 3.9 (781.7) | 52.2 · 3.3 (745.2) | 51.3 · 3.0 (770.5) |
| 32,768 | 45.9 · 7.6 (526.1) | 46.2 · 7.6 (526.5) | 33.3 · 5.4 (509.6) | 34.5 · 4.1 (509.0) |
| 65,536 | 34.9 · 12.9 (355.8) | 35.2 · 12.9 (352.5) | 24.8 · 8.3 (344.9) | 24.8 · 5.9 (345.8) |


⚠️ `size_vram` for qwen3.6:35b in arms B to D (0.9 to 2.4 GB) cannot be the model's real footprint; ollama reports it that way when the KV cache is quantised, so read those memory figures as unknown.

The August runs on ollama 0.33.1 (the table in the post) are in `../SINCE-MAY-2026.md`.

