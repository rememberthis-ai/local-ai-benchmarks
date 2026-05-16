# Context-size sweep — ollama qwen3:8b

Run: 2026-05-14 04:07:25.065784
num_ctx: 40000 | max_tokens: 300 | timeout: 1800s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | first 80 chars of content |
|---|---|---|---|---|---|---|
| 4,000 | 3,471 | 450.1 | 300 | 3.2 | 10.1 | … |
| 8,000 | 7,001 | 1026.4 | 300 | 2.1 | 8.0 | … |
| 16,000 | (err) | — | — | — | — | ERR: TimeoutError('timed out')[:60] |
| 32,000 | (err) | — | — | — | — | ERR: TimeoutError('timed out')[:60] |
