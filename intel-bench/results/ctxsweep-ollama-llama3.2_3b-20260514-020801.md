# Context-size sweep — ollama llama3.2:3b

Run: 2026-05-14 02:08:01.800983
num_ctx: 40000 | max_tokens: 300 | timeout: 1800s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | first 80 chars of content |
|---|---|---|---|---|---|---|
| 4,000 | 3,187 | 199.5 | 300 | 6.7 | 21.8 | I've read through all the voice memos and photo captions. Here are the answers t… |
| 8,000 | 6,489 | 487.3 | 300 | 4.4 | 15.5 | Based on the provided data, here are the answers to your questions: 1. Three re… |
| 16,000 | 12,960 | 1670.8 | 300 | 2.7 | 8.3 | Based on the provided voice memos and photo captions: 1. Three recurring themes… |
| 32,000 | (err) | — | — | — | — | ERR: TimeoutError('timed out')[:60] |
