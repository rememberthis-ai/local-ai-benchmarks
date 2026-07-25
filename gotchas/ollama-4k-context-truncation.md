# ollama's silent 4 K truncation — and why the old advice about it is wrong

Send ollama a prompt longer than its context window and it does not warn, does
not error, and returns a confident answer based on the part it saw. We hit this
with a 79,000-token prompt: the response looked fine, and `prompt_eval_count`
came back **4,096**. The model never saw 84 % of the input, and answered as if
the missing 84 % didn't exist.

In an app this looks like a user pasting a long document and getting a coherent
reply that is uninformed about nearly all of it.

## The part everyone gets wrong: it is per-model, not a global default

The advice you'll find everywhere — including in the first version of this file —
is *"ollama defaults `num_ctx` to 4 K regardless of model."* **That is no longer
true**, and believing it leads to the wrong diagnosis.

Two models on the same server (ollama 0.21.0), neither request passing
`num_ctx`:

| Model | Declared context | Actually allocated |
|---|---|---|
| `qwen3.6:35b` | 262,144 | **262,144** ✅ |
| `openbmb/minicpm-v4.5` | 40,960 | **4,096** ❌ |

Not the model size, not the endpoint, not the ollama version. The difference is
the **Modelfile**:

```console
$ ollama show --parameters qwen3.6:35b
repeat_penalty 1 · temperature 1 · top_k 20 · top_p 0.95 …     # no num_ctx

$ ollama show --parameters openbmb/minicpm-v4.5
num_ctx        4096                                            # ← pinned
temperature    0.7 · top_p 0.9 · stop …
```

Absent a `num_ctx` parameter, modern ollama sizes the window to the model's
declared context, memory permitting. A Modelfile that *explicitly pins*
`num_ctx 4096` still clamps you — and since 4096 was also the old global
default, the symptom is byte-identical while the cause is completely different.

So the trap has moved: it's now a property of **whichever model you pulled**.
Community re-uploads are the likeliest to carry a stale 4 K pin while
advertising a large window in their model card — `openbmb/minicpm-v4.5`
advertises 40 K and ships 4 K.

The endpoint makes no difference: native `/api/generate` and the
OpenAI/Anthropic-compatible endpoints all allocated 262,144 for `qwen3.6:35b`.

## Checking, and fixing

Pass `num_ctx` explicitly for anything long, rather than trusting the model card
or the default:

```bash
curl -s http://localhost:11434/api/generate -d '{
  "model": "your-model",
  "prompt": "...",
  "options": {"num_ctx": 40000}
}'
```

Two ways to see what you actually got:

- **Per request** — `prompt_eval_count` in the `/api/generate` response is the
  number of input tokens actually fed to the model. Prompt is N tokens and
  `prompt_eval_count` < N? You were truncated. Worth asserting in any harness.
- **Per loaded model** — `GET /api/ps` reports `context_length` for each
  resident model. Fastest way to answer "did this model get a real window?"
  without crafting a long prompt; it's what produced the table above.

```bash
curl -s http://localhost:11434/api/ps | jq '.models[] | {name, context_length}'
```

## A constrained window isn't automatically a truncated one

Worth checking before raising the alarm, because we nearly got this wrong in the
other direction: a 4 K-clamped *vision* model sounds obviously broken, but a
2048 px JPEG costs about **682 tokens** through `openbmb/minicpm-v4.5`. A
single-image prompt uses ~17 % of the window. Real ceiling, no actual
truncation.

`prompt_eval_count` is what separates "theoretically constrained" from "actually
truncating" — measure before concluding.

## Don't trust a claim written months ago, including this one

The first version of this note asserted the 4 K behaviour was universal and that
a safe `num_ctx` was already wired in downstream. Neither survived contact with
`/api/ps`. Model defaults, ollama's sizing behaviour, and whatever your own code
sets are all moving targets — check them at the point you care, rather than
inheriting a conclusion.

## SwiftLM does not have this failure mode

SwiftLM uses the model's full context by default — no `num_ctx` override needed,
and you get an explicit error rather than silent truncation when you exceed the
model's training window.
