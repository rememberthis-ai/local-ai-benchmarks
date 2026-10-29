# Context-size sweep — ollama llama3.2:1b

Run: 2026-10-23 00:30:18.069327
num_ctx: 70000 | max_tokens: 200 | timeout: 3600s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | e2e tok/s |
|---|---|---|---|---|---|---|
| 4,000 | 3,187 | 46.7 | 200 | 12.9 | 120.7 | 4.3 |
| 8,000 | 6,489 | 73.3 | 200 | 7.5 | 139.4 | 2.7 |
| 16,000 | 12,960 | 161.6 | 200 | 4.1 | 115.3 | 1.2 |
| 32,000 | 30,445 | 589.8 | 200 | 1.7 | 64.8 | 0.3 |
