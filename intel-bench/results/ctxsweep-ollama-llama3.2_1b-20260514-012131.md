# Context-size sweep — ollama llama3.2:1b

Run: 2026-05-14 01:21:31.229434
num_ctx: 40000 | max_tokens: 300 | timeout: 1800s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | first 80 chars of content |
|---|---|---|---|---|---|---|
| 4,000 | 3,187 | 71.7 | 300 | 14.1 | 68.0 | Based on the provided sample data: 1. Three recurring themes that show up acros… |
| 8,000 | 6,489 | 172.4 | 300 | 8.5 | 47.5 | Based on the provided sample data: 1. The recurring themes that show up across … |
| 16,000 | 12,960 | 742.4 | 300 | 5.0 | 19.0 | Based on the provided chronological sample of voice memos and photo captions, he… |
| 32,000 | (err) | — | — | — | — | ERR: TimeoutError('timed out')[:60] |
