# Context-size sweep — ollama gemma3:4b

Run: 2026-05-14 03:17:22.982243
num_ctx: 40000 | max_tokens: 300 | timeout: 1800s

| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | first 80 chars of content |
|---|---|---|---|---|---|---|
| 4,000 | 3,437 | 194.0 | 300 | 8.2 | 22.5 | Okay, here’s an analysis of the user’s data, addressing your questions with spec… |
| 8,000 | 6,939 | 327.0 | 300 | 7.8 | 24.1 | Okay, let’s analyze this data. Here’s my assessment based on the provided voice … |
| 16,000 | 13,937 | 677.5 | 300 | 6.9 | 22.0 | Okay, let’s analyze this data to answer your questions. **1. Recurring Themes:*… |
| 32,000 | (err) | — | — | — | — | ERR: TimeoutError('timed out')[:60] |
