# Context-size sweep — ollama gemma3:4b

Run: 2026-05-15 08:23:58.955747
num_ctx: 40000 | max_tokens: 300 | timeout: 1800s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | first 80 chars of content |
|---|---|---|---|---|---|---|
| 4,000 | 3,437 | 198.9 | 300 | 7.4 | 22.7 | Okay, here’s an analysis of the user’s data, answering your questions with speci… |
| 8,000 | 6,939 | 378.2 | 300 | 6.9 | 20.8 | Okay, here’s an analysis of the user’s voice memos and photo captions, addressin… |
| 16,000 | 13,937 | 860.2 | 300 | 5.9 | 17.2 | Okay, let’s analyze this dataset of voice memos and photo captions to answer you… |
| 32,000 | (err) | — | — | — | — | ERR: TimeoutError('timed out')[:60] |
