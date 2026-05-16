# Context-size sweep — ollama llama3.2:3b

Run: 2026-05-15 07:10:59.056183
num_ctx: 40000 | max_tokens: 300 | timeout: 1800s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | first 80 chars of content |
|---|---|---|---|---|---|---|
| 4,000 | 3,187 | 223.4 | 300 | 6.0 | 19.6 | Based on the provided data, I'll answer your questions: 1. Three recurring them… |
| 8,000 | 6,489 | 552.7 | 300 | 3.8 | 13.7 | Based on the provided voice memos and photo captions: 1. Three recurring themes… |
| 16,000 | (err) | — | — | — | — | ERR: TimeoutError('timed out')[:60] |
| 32,000 | (err) | — | — | — | — | ERR: TimeoutError('timed out')[:60] |
