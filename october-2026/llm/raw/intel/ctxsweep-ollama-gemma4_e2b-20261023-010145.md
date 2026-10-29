# Context-size sweep — ollama gemma4:e2b

Run: 2026-10-23 01:01:45.535193
num_ctx: 70000 | max_tokens: 200 | timeout: 3600s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | e2e tok/s |
|---|---|---|---|---|---|---|
| 4,000 | 3,443 | 66.1 | 200 | 15.9 | 80.5 | 3.0 |
| 8,000 | 6,945 | 70.5 | 200 | 14.8 | 122.2 | 2.8 |
| 16,000 | 13,943 | 170.1 | 200 | 8.6 | 95.0 | 1.2 |
| 32,000 | 30,587 | 543.5 | 200 | 4.3 | 61.6 | 0.4 |
