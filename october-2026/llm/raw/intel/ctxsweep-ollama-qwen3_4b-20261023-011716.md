# Context-size sweep — ollama qwen3:4b

Run: 2026-10-23 01:17:16.472229
num_ctx: 70000 | max_tokens: 200 | timeout: 3600s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | e2e tok/s |
|---|---|---|---|---|---|---|
| 4,000 | 3,441 | 154.5 | 200 | 4.3 | 36.9 | 1.3 |
| 8,000 | 6,971 | 246.4 | 200 | 2.1 | 45.6 | 0.8 |
| 16,000 | 13,948 | 595.9 | 200 | 1.0 | 34.4 | 0.3 |
| 32,000 | 31,958 | 2442.2 | 200 | 0.5 | 15.9 | 0.1 |
