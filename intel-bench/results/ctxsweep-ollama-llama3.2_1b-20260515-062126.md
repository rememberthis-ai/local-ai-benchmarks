# Context-size sweep — ollama llama3.2:1b

Run: 2026-05-15 06:21:26.365936
num_ctx: 40000 | max_tokens: 300 | timeout: 1800s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | first 80 chars of content |
|---|---|---|---|---|---|---|
| 4,000 | 3,187 | 82.9 | 300 | 12.1 | 59.2 | Based on the provided sample data, three recurring themes that show up across th… |
| 8,000 | 6,489 | 205.5 | 300 | 6.9 | 40.2 | Based on the provided data: 1. Three recurring themes that show up across the v… |
| 16,000 | 12,960 | 880.7 | 300 | 4.2 | 16.0 | Based on the provided data: 1. The recurring themes include: - **Concern for… |
| 32,000 | (err) | — | — | — | — | ERR: TimeoutError('timed out')[:60] |
