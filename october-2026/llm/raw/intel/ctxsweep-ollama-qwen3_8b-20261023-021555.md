# Context-size sweep — ollama qwen3:8b

Run: 2026-10-23 02:15:55.804651
num_ctx: 70000 | max_tokens: 200 | timeout: 3600s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | e2e tok/s |
|---|---|---|---|---|---|---|
| 4,000 | 3,441 | 230.6 | 200 | 3.1 | 23.5 | 0.9 |
| 8,000 | 6,971 | 323.8 | 200 | 1.8 | 32.8 | 0.6 |
| 16,000 | 13,948 | 741.4 | 200 | 1.0 | 26.2 | 0.3 |
| 32,000 | 31,958 | 2705.6 | 200 | 0.4 | 14.2 | 0.1 |
