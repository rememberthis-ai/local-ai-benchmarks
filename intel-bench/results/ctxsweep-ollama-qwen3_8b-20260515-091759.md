# Context-size sweep — ollama qwen3:8b

Run: 2026-05-15 09:17:59.791033
num_ctx: 40000 | max_tokens: 300 | timeout: 1800s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | first 80 chars of content |
|---|---|---|---|---|---|---|
| 4,000 | 3,471 | 538.9 | 300 | 2.6 | 8.4 | … |
| 8,000 | 7,001 | 1191.5 | 300 | 1.7 | 6.9 | … |
| 16,000 | (err) | — | — | — | — | ERR: TimeoutError('timed out')[:60] |
| 32,000 | (err) | — | — | — | — | ERR: TimeoutError('timed out')[:60] |
