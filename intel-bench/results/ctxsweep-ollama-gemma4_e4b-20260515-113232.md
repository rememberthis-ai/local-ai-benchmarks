# Context-size sweep — ollama gemma4:e4b

Run: 2026-05-15 11:32:32.268828
num_ctx: 40000 | max_tokens: 300 | timeout: 1800s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | first 80 chars of content |
|---|---|---|---|---|---|---|
| 4,000 | 3,447 | 245.0 | 300 | 6.2 | 19.3 | … |
| 8,000 | 6,952 | 430.3 | 300 | 5.7 | 18.5 | … |
| 16,000 | 13,948 | 987.3 | 300 | 4.7 | 15.1 | … |
| 32,000 | (err) | — | — | — | — | ERR: TimeoutError('timed out')[:60] |
