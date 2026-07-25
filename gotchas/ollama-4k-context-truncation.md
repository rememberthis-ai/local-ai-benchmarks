# ollama's 4 K context truncation: still real, but no longer a global default

Easy trap, real UX consequences — and the *mechanism changed under us*, which
made our own earlier writeup misleading. Both halves matter.

## The original trap

We sent a 79,000-token prompt to ollama without overriding `num_ctx`. Ollama
returned a response — no warning, no error. Inspecting `prompt_eval_count` in
the response body: **4,096**. The model never saw 84 % of the prompt, and duly
answered "no photos provided" because it never reached the photo section.

In a chat app this looks like: user pastes a long document, gets a coherent
reply that is confidently uninformed about most of what they pasted.

We almost shipped that as the Dreamer feature on Apple Silicon.

## What changed: it is per-model now, not per-installation

The old explanation — *"ollama defaults `num_ctx` to 4 K regardless of model"* —
**is no longer true**, and repeating it leads you to the wrong diagnosis.

Measured on bundled ollama **0.21.0** (client 0.22.1), two models on the same
server, neither request passing `num_ctx`:

| Model | Declared context | Actually allocated |
|---|---|---|
| `qwen3.6:35b` | 262,144 | **262,144** ✅ |
| `openbmb/minicpm-v4.5` | 40,960 | **4,096** ❌ |

The difference is not the model size, the endpoint, or the ollama version. It
is the **Modelfile**:

```
$ ollama show --parameters qwen3.6:35b
repeat_penalty 1 · temperature 1 · top_k 20 · top_p 0.95 …      # no num_ctx

$ ollama show --parameters openbmb/minicpm-v4.5
num_ctx        4096                                             # ← pinned
temperature    0.7 · top_p 0.9 · stop …
```

Absent a `num_ctx` parameter, modern ollama sizes the window to the model's
declared context (memory permitting). A Modelfile that *explicitly pins*
`num_ctx 4096` still clamps you — and because 4096 was also the old global
default, the symptom is byte-identical to the old bug while the cause is
completely different.

So the trap has moved: it is now a property of **whichever model you pulled**,
and community re-uploads are the ones most likely to carry a stale 4 K pin
while advertising a large window in their model card. `openbmb/minicpm-v4.5`
advertises 40 K and ships 4 K.

The endpoint makes no difference — native `/api/generate` and the
Anthropic-compatible `/v1/messages` both allocated 262,144 for `qwen3.6:35b`.

## The fix, and the diagnostic

Advice is unchanged; the reason for it isn't. Pass `num_ctx` explicitly on any
long-context request rather than trusting either the model card or the default:

```bash
curl -s http://127.0.0.1:21434/api/generate -d '{
  "model": "gemma4:e2b",
  "prompt": "...",
  "options": {"num_ctx": 40000}
}'
```

Two ways to check what you actually got:

- **Per request** — every `/api/generate` response carries `prompt_eval_count`
  (input tokens actually fed to the model). If your prompt is N tokens and
  `prompt_eval_count` < N, you were truncated.
- **Per loaded model** — `GET /api/ps` reports `context_length` for each
  resident model. This is the fastest way to answer "did this model get a real
  window?" without crafting a long prompt, and it's what produced the table
  above.

Check `ollama show --parameters <model>` before assuming a freshly pulled model
behaves like the last one.

## Corollary: a small window can be harmless — measure before alarming

We assumed a 4 K-clamped vision model must be truncating captions. It isn't: a
2048 px JPEG costs **682 tokens** through `openbmb/minicpm-v4.5`, so a
single-image caption uses ~17 % of the 4 K window. The clamp is a real ceiling
(roughly six images, or one long OCR-text prompt) but not a live defect.

`prompt_eval_count` distinguishes "theoretically constrained" from "actually
truncated" in one request. Use it before filing the bug.

## Correction to the earlier version of this note

It used to close by saying `num_ctx=40000` was "baked into the v0.11 ollama
bridge for every Dreamer-class call". That is **not true of the current tree** —
`num_ctx` appears nowhere in `core/`, `core-lib/`, `daemon/` or `macos-app/`,
only in the bench scripts under `experiments/`. Nothing in the shipping product
sets it.

That turns out to be fine rather than alarming, for two independently measured
reasons: the Dreamer's ollama path reaches the model through
`ollama launch claude` → Claude Code → `/v1/messages`, which allocated the full
262,144 for `qwen3.6:35b`; and the VLM path's 4 K clamp has ~6× headroom on a
single image. But it was true by accident, not by design — which is exactly why
the diagnostic (`/api/ps`, `prompt_eval_count`) beats trusting a code comment.

## SwiftLM does not have this failure mode

SwiftLM uses the model's full context by default — no `num_ctx` override, and
you get an explicit error rather than silent truncation when you exceed the
model's training window.
