# Context-size sweep — ollama gemma4:e2b

Run: 2026-05-15 10:46:54.169232
num_ctx: 40000 | max_tokens: 300 | timeout: 1800s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | first 80 chars of content |
|---|---|---|---|---|---|---|
| 4,000 | 3,447 | 127.9 | 300 | 11.8 | 39.0 | … |
| 8,000 | 6,952 | 248.1 | 300 | 10.4 | 31.9 | … |
| 16,000 | 13,948 | 576.4 | 300 | 8.5 | 25.8 | … |
| 32,000 | 30,595 | 1782.1 | 300 | 6.0 | 17.7 | … |
