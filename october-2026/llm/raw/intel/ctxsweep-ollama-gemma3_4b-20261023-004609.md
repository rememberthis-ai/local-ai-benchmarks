# Context-size sweep — ollama gemma3:4b

Run: 2026-10-23 00:46:09.202315
num_ctx: 70000 | max_tokens: 200 | timeout: 3600s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | e2e tok/s |
|---|---|---|---|---|---|---|
| 4,000 | 3,438 | 97.0 | 200 | 7.9 | 54.1 | 2.1 |
| 8,000 | 6,940 | 97.5 | 200 | 7.3 | 99.1 | 2.1 |
| 16,000 | 13,938 | 185.1 | 200 | 6.3 | 90.9 | 1.1 |
| 32,000 | 30,582 | 476.6 | 200 | 4.7 | 70.5 | 0.4 |
