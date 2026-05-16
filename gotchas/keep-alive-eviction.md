# `keep_alive` eviction: the bug that almost shipped wrong numbers

Our first run of the SwiftLM-vs-ollama A/B made SwiftLM look *worse* than ollama on three of four models. The bench script ran ollama, then SwiftLM, back-to-back on the same MoE LLM weights. We were confident in the comparison because it was the same model, same prompt, same hardware.

It was wrong.

## The bug

ollama's default `keep_alive` is **5 minutes**. The model stays loaded in unified memory after the request returns, ready for a follow-up. That's the right default for a chat app — you don't want a 16 GB model paging back in every 30 seconds. But it's the wrong default for a back-to-back bench.

Our timeline looked like this:

```
t=0:   ollama loads Qwen3.6-35B (20 GB resident)
t=5:   ollama request finishes
t=5:   SwiftLM starts (also wants to load Qwen3.6-35B)
       ← ollama is still holding 20 GB. SwiftLM's MLX runtime has to
         share memory bandwidth with a model it isn't using.
t=10:  SwiftLM tries to decode → 3× slower than expected
t=15:  Bench script writes "SwiftLM lost" to the results file
t=305: (only now) ollama would have evicted the weights if we'd waited
```

The first three rows of our results table said SwiftLM was 1.5–3× *slower* than ollama on identical weights. We almost shipped that as the headline.

## How we caught it

`Activity Monitor → Memory` showed both processes' RSS climbing while only one of them was supposed to be active. `pmap` on the SwiftLM PID showed almost no resident memory growth — it was paging while ollama held the page cache.

## The one-line fix

```bash
curl -s http://127.0.0.1:21434/api/generate \
  -d '{"model":"qwen3.6:35b","keep_alive":0}'
```

`keep_alive: 0` forces ollama to unload the model immediately. After applying this between every model swap in the bench loop, every SwiftLM number jumped, and Qwen3.6's apparent regression flipped into a +205% win.

## Generalized rule

**If you bench two GPU-resident runtimes back-to-back on Apple Silicon, force-unload between runs.** This applies to any combination — ollama → SwiftLM, SwiftLM → llama.cpp, llama.cpp → ollama. The runtime that loaded second always loses if the first one is still holding memory.

The unload step is in `swiftlm/sweep_models.sh` for our A/B runs (line ~42, the `pkill -x SwiftLM` block). For ollama specifically, the unload curl above is the cleanest. There's no `pkill ollama` equivalent because ollama is a long-lived daemon — you don't want to kill it, just evict its model.

## What other benchmark suites get this wrong?

Most published "ollama vs X" comparisons we've found online don't unload between runs. If you read a blog claiming runtime X is "1.7× slower than ollama" — check whether they invalidated the cache between runs. If they didn't, the number is meaningless.
