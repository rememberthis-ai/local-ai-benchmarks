# Context-size sweep — ollama qwen3:1.7b

Run: 2026-05-14 00:17:02.848493
num_ctx: 40000 | max_tokens: 300 | timeout: 1800s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | first 80 chars of content |
|---|---|---|---|---|---|---|
| 4,000 | 3,471 | 175.1 | 300 | 7.9 | 26.6 | … |
| 8,000 | 7,001 | 444.9 | 300 | 5.0 | 18.2 | … |
| 16,000 | 13,978 | 1444.8 | 300 | 3.6 | 10.3 | … |
| 32,000 | (err) | — | — | — | — | ERR: TimeoutError('timed out')[:60] |
