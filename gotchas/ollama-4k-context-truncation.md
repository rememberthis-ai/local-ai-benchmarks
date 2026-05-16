# ollama silently truncates long prompts to 4,096 tokens

Easy trap, real UX consequences. Default `num_ctx` in ollama is **4,096**. We sent a 79,000-token prompt without overriding it. Ollama returned a response — no warnings, no errors. Inspecting `prompt_eval_count` in the response body: **4,096**. The model never saw 84% of the prompt.

The model duly answered "no photos provided" because it never reached the photo section.

## How this looks in a chat app wired up against ollama

User pastes a long document. App sends it to ollama. ollama answers based on the first ~10% — confidently. The user sees a coherent reply that's completely uninformed about most of what they pasted.

We almost shipped this as the Dreamer feature on Apple Silicon. Caught by inspecting `prompt_eval_count` in the API response, which we wouldn't have done if the bench script weren't watching it for context-sweep purposes.

## The fix

Pass `num_ctx` explicitly on every long-context request:

```bash
curl -s http://127.0.0.1:21434/api/generate -d '{
  "model": "gemma4:e2b",
  "prompt": "...",
  "options": {"num_ctx": 40000}
}'
```

Some models also need a higher value than their tag default. For example, `gemma4:e2b` advertises 32K context but ollama defaults `num_ctx` to 4K *regardless of model*. The model's actual context window is the smaller of `num_ctx` and the model's training window.

## Verifying it worked

Every ollama `/api/generate` response includes `prompt_eval_count` (number of input tokens actually fed to the model). If your prompt is N tokens but `prompt_eval_count` < N, your request was truncated. Add a check.

## SwiftLM does not have this failure mode

SwiftLM uses the model's full context by default. There's no `num_ctx` override needed — the model card's training context is the cap, and you'll get an explicit error if you exceed it.

This is one of the reasons we moved Apple Silicon to SwiftLM in v0.11. The Intel path stays on ollama (it's the only option on Intel), and `num_ctx=40000` is baked into the v0.11 ollama bridge for every Dreamer-class call.
