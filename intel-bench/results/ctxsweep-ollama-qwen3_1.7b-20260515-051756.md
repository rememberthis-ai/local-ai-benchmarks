# Context-size sweep — ollama qwen3:1.7b

Run: 2026-05-15 05:17:56.318754
num_ctx: 40000 | max_tokens: 300 | timeout: 1800s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | first 80 chars of content |
|---|---|---|---|---|---|---|
| 4,000 | 3,471 | 153.8 | 300 | 8.5 | 31.6 | … |
| 8,000 | 7,001 | 404.0 | 300 | 5.4 | 20.1 | … |
| 16,000 | 13,978 | 1448.6 | 300 | 3.2 | 10.3 | … |
| 32,000 | (err) | — | — | — | — | ERR: TimeoutError('timed out')[:60] |
