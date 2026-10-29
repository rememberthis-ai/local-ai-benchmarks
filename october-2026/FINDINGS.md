# Findings, October 2026: the full write-up

Everything we found, in full, with the tables. The two posts on augmentedmind.io tell the same story more briefly: local LLM speed and captioning, and images, video and voice against the hosted APIs.


In May we published [Local LLM speed on a Mac: Apple Silicon vs Intel, tokens per second (May 2026)](/research/local-ai/local-llm-speed-mac-may-2026/), measured on two MacBook Pros: an M1 Max with 64 GB and a 2018 Intel i9-8950HK with 32 GB. This is the follow-up on the same two machines, five months and several ollama releases later. Some of May's numbers are now too low, one of its headline ratios was comparing two things at once, and we ran into a trap with thinking models that makes a captioning benchmark report speeds for captions that were never written. New this time are image, video and speech generation, which in May we did not measure at all, and this time we also ran the same prompts through the best hosted models to see how far behind a Mac is.

Everything below is measured on those two Macs, plugged in, with Low Power Mode off. We have no numbers from an M2, M3 or M4, or from a 16 GB Mac, and if you have one we would love your results (see the end of the post).

## What to run on which Mac (October 2026)

| Mac | LLM for chat or an agent | Speed | Photo captioning | Seconds per photo |
|---|---|---|---|---|
| M1 Max, 64 GB | qwen3.6:35b on ollama | 62 tok/s with 8K of context, 37 tok/s at 64K | Qwen3-VL-8B (MLX 4-bit, through SwiftLM) for the best captions; gemma4:e2b on ollama with thinking off if you want them fast | 3.3 s; 0.9 s |
| Intel i9, 32 GB | gemma4:e2b on ollama | 16 tok/s at 4K, 4 tok/s at 32K | gemma4:e2b on ollama with thinking off | 9.8 s |
| 16 GB Apple Silicon | not measured | | not measured | |

Every number in this table, and every October number below unless it says otherwise, is from ollama 0.40.8 (and SwiftLM for MLX) on the night of 22 to 23 October. The Intel Mac was quiet (load average 1.4 to 5.2). On the M1 Max the GPU was idle before each model while other work kept the CPU at a load average of 10 to 17, and 32 to 52 for the gemma4, Qwen3-VL-8B and MLX caption runs; captioning runs on the GPU, but if anything those numbers are slightly slow. On Intel, gemma4:e2b with thinking off is now the fastest captioner we measured, ahead of moondream:1.8b (11.1 s), and writes longer captions (48 tokens against 31). Caption quality comes from the side-by-side scoring in the May post; we did not re-score captions this time.

## What changed since May

### ollama got about twice as fast on Apple Silicon

The single biggest change since May is the runtime. We ran ollama 0.22.0 and 0.33.1 against each other on the M1 Max, alternating round by round so that whatever else the machine was doing hit both equally, with qwen3.6:35b and a 6,487-token prompt:

| ollama | Prefill (tok/s) | Decode (tok/s) |
|---|---|---|
| 0.22.0 | 367 and 455 | 27.7 and 27.7 |
| 0.33.1 | 700 and 801 | 52.7 and 43.6 |

A background indexer was using a CPU core during both, so the ratio (about 1.8x) is the number to read, not the absolute rates. Part of the jump is that newer ollama runs these models through llama.cpp's server where the older one used ollama's own Go engine, so a version bump can change which engine runs your model.

With nothing else running, on 31 August, qwen3.6:35b on 0.33.1 decoded at 51.8 tok/s with an 8K prompt, 47.6 at 32K and 40.0 at 64K. On 0.40.8 in October it was 61.6, 45.8 and 37.0. The May post had 26.2, 23.7 and 21.1 for the same model and context sizes on the older ollama, so every ollama number in the May matrix is roughly half of what you get today. May's verdict that ollama beats SwiftLM for LLMs on Apple Silicon only got stronger, as far as we can tell from re-measuring the ollama side (we did not re-run SwiftLM).

Newer models also need a newer runtime. qwen3.8:27b refuses to load on anything older than ollama 0.32.12, which answers with HTTP 412 before downloading anything.

### Bigger and newer models, up to 200K of context

We ran the larger models that came out since May on the M1 Max, from 4K up to 200K tokens of context, on ollama 0.40.8 with the GPU idle before each one:

| Model | Decode at 8K | at 64K | at 100K | at 200K | Prefill at 64K | at 200K |
|---|---|---|---|---|---|---|
| qwen3.6:35b | 61.6 | 37.0 | 29.8 | 20.6 | 1198 | 183 |
| gpt-oss:20b | 54.3 | 37.8 | 25.8 | — | 1018 | — |
| flint:40b | 64.8 | 25.0 | 23.5 | 7.8 | 810 | 190 |
| gemma4:26b | 42.6 | 19.8 | 16.1 | 8.4 | 1094 | 240 |
| qwen3-coder:30b | 50.4 | 16.6 | 11.0 | 6.3 | 343 | 47 |
| bonsai-2:27b | 15.8 | 10.3 | 10.7 | 7.7 | 231 | 62 |
| qwen3.8:27b (q4_K_M) | 12.4 | 9.5 | 8.5 | 5.9 | 272 | 52 |
| nemotron-3.5-bolt (74B, 9B active) | 4.9 | 3.6 | 6.0 | 5.0 | 94 | 77 |

(Tokens per second. nemotron crashes on 0.40.8, so its row is from 0.40.10.) qwen3.6:35b is still the one to run on a 64 GB Mac, and the reason is in its architecture rather than its size: it is a mixture of experts, so only a fraction of its 36 billion parameters work on each token, while qwen3.8:27b is dense and uses all 27 billion every time, which makes it four to five times slower to write and four to six times slower to read. At 200K even qwen3.6 takes about 18 minutes to read the prompt, so a conversation that long is something you start and come back to. ollama's own MLX builds of the same models (`qwen3.6:35b-mlx`, `gemma4:26b-mlx`) were no faster than the regular ones, and up to 30% slower to write. Every one that answered stayed coherent at 64K and 200K, with no sign of the repetition collapse gemma4 showed in May; flint:40b is the exception that did not answer at all (see the traps below).

### On an Intel Mac, the new ollama reads long prompts 2 to 5 times faster, and writes at the same speed

We re-ran the Intel sweep on ollama 0.40.8 with the same prompt file. Reading the prompt (prefill) is where the time went in May, and it is where the improvement is:

| Intel i9, model | Prefill at 16K, May | Prefill at 16K, October | Time to read a 16K prompt, May → October |
|---|---|---|---|
| llama3.2:1b | 16.0 tok/s | 115.3 tok/s | 13.5 min → 1.9 min |
| gemma3:4b | 17.2 tok/s | 90.9 tok/s | 13.5 min → 2.6 min |
| gemma4:e2b | 25.8 tok/s | 95.0 tok/s | 9.0 min → 2.4 min |

In May, llama3.2:1b and gemma3:4b both timed out (after 30 minutes) on a 32K prompt. In October both finished, in 9.8 and 7.9 minutes including the answer. Writing the answer (decode) did not get faster: gemma4:e2b went from 11.8 to 15.9 tok/s at 4K, but at 32K it was 6.0 in May and 4.3 now.

The May settings and the October ones differ slightly (num_ctx 40,000 and 300-token answers then, 70,000 and 200 now), which is why we compare prefill rates rather than total time.

### On Intel, ollama does slow down as the conversation grows

May's finding that ollama barely slows down at long context was measured on the M1 Max. On the Intel CPU it does not hold, and the size of the drop depends a lot on the model:

| Intel i9, ollama 0.40.8 | 4K | 8K | 16K | 32K |
|---|---|---|---|---|
| gemma4:e2b | 15.9 | 14.8 | 8.6 | 4.3 |
| llama3.2:1b | 12.9 | 7.5 | 4.1 | 1.7 |
| gemma3:4b | 7.9 | 7.3 | 6.3 | 4.7 |
| qwen3:4b | 4.3 | 2.1 | 1.0 | 0.5 |
| qwen3:8b | 3.1 | 1.8 | 1.0 | 0.4 |

(Decode, tokens per second.) gemma4:e2b is still the one to use on an Intel Mac for short conversations: it is the fastest up to 16K. gemma3:4b starts at half its speed but loses the least as the prompt grows, and at 32K it is slightly ahead (4.7 against 4.3). The qwen3 models are thinking models and spend most of a 200-token answer on reasoning, which at 0.5 tok/s means a 32K conversation takes half an hour per reply. On an Intel Mac that rules them out for anything interactive.

### Thinking models return empty captions through ollama, and the benchmark still reports a speed

This is the trap that cost us the most this round. gemma4 and qwen3-vl are thinking models, and ollama returns their reasoning in a separate `thinking` field. The reasoning counts against the output limit you set, so with a cap of 120 tokens they spent all 120 on thinking and the caption itself (the `response` field) came back empty. Our first October run timed 30 photos per model like that on both Macs, and it looked perfectly healthy: plausible seconds per photo, no errors, every request answered.

We reproduced it on a synthetic test image with ollama 0.40.2 on the M1 Max:

| Model | Request | Tokens used | Caption returned | Thinking returned |
|---|---|---|---|---|
| qwen3-vl:2b | default | 120 | 0 characters | 512 characters |
| qwen3-vl:2b | `think: false` | 120 | 0 characters | 512 characters |
| gemma4:e2b | default | 120 | 0 characters | 448 characters |
| gemma4:e2b | `think: false` | 41 | 190 characters | none |

gemma4 respects `think: false` and then writes a normal caption. qwen3-vl ignores it and thinks anyway, so for captioning use its `-instruct` tags (`qwen3-vl:2b-instruct`, `4b-instruct`, `8b-instruct`), which do not think. If you run any vision benchmark through ollama, check that the captions are not empty before you trust the timings; our harness now counts empty captions and refuses to treat them as results.

The captioning numbers below are from a re-run with gemma4 on `think: false` and qwen3-vl through its instruct tags.

### Apple Silicon captions 9 to 20 times faster than Intel on the same runtime

May's headline said photo captioning runs 15 to 24 times faster on Apple Silicon. That compared Intel with ollama against the M1 Max with MLX, so it mixed two changes: the chip and the runtime. This time we ran the same 30 photos, the same prompt, the same 120-token cap and the same warm-up on both Macs, with ollama 0.40.8 on both, which isolates the chip:

| Model (ollama) | Intel i9 | M1 Max | Intel ÷ M1 Max |
|---|---|---|---|
| moondream:1.8b | 11.1 s | 0.73 s | 15x |
| llava:7b | 45.9 s | 2.32 s | 20x |
| qwen2.5vl:3b | 49.6 s | 3.22 s | 15x |
| minicpm-v:8b | 33.1 s | 2.32 s | 14x |
| gemma3:4b | 39.2 s | 3.04 s | 13x |
| openbmb/minicpm-v4.5 | 47.1 s | 4.70 s | 10x |
| gemma4:e2b (thinking off) | 9.8 s | 0.88 s | 11x |
| gemma4:e4b (thinking off) | 13.8 s | 1.51 s | 9x |
| qwen3-vl:2b-instruct | 34.8 s | 1.81 s | 19x |
| qwen3-vl:4b-instruct | 52.7 s | 3.49 s | 15x |
| qwen3-vl:8b-instruct | 83.1 s | 7.56 s | 11x |

(Median seconds per photo, model already loaded.) On the same runtime the M1 Max is between 9 and 20 times faster, around 14 for a typical model (the median of these eleven). Switching to MLX on the M1 Max adds a further factor on top for some models (next section), which is how May got to its larger range.

### MLX against ollama for captioning on the M1 Max

| Model | ollama (default tag) | MLX 4-bit through SwiftLM | Mean caption length, ollama / MLX |
|---|---|---|---|
| Qwen2.5-VL-3B | 3.22 s | 1.14 s | 52 / 43 tokens |
| Qwen3-VL-2B (ollama `-instruct` tag) | 1.81 s | 1.38 s | 67 / 54 tokens |
| Qwen3-VL-4B (ollama `-instruct` tag) | 3.49 s | 2.21 s | 66 / 62 tokens |
| Qwen3-VL-8B (ollama `-instruct` tag) | 7.56 s | 3.27 s | 67 / 68 tokens |

The two routes use different quantisations (ollama's default tag against MLX 4-bit), so this compares them the way you would actually use them rather than the runtimes in isolation. Watch the caption length column: a model that writes longer captions takes longer per photo, and when one runtime's answers are much longer the per-photo time says more about verbosity than about speed. For Qwen3-VL the lengths are close, and MLX is 1.3 to 2.3 times faster than ollama for the same model on the same Mac (2.3 times for the 8B, which is the one worth running for quality). Qwen2.5-VL-3B is 2.8 times faster on MLX. So on Apple Silicon, MLX is still the faster way to caption, and for LLMs ollama is.

Two MLX models did not run at all: gemma-4-e2b and gemma-4-e4b never finished loading in SwiftLM (build b644).

### Quantising the KV cache makes ollama slower, and helps mlx-lm at long context

Quantising the KV cache (the memory that holds the conversation so far) is supposed to save memory and, at long context, time. On ollama 0.33.1 (`OLLAMA_KV_CACHE_TYPE`, M1 Max, 31 August) it saved some memory and cost a lot of speed. qwen3.6:35b, decode tok/s, with the prompt at about 45% of the window:

| Context | Default | Flash attention, f16 | q8_0 | q4_0 |
|---|---|---|---|---|
| 8K | 51.8 | 54.9 | 37.6 | 43.5 |
| 32K | 47.6 | 47.7 | 18.2 | 25.9 |
| 64K | 40.0 (24.2 GB) | 41.0 | 10.9 (23.6 GB) | 16.7 |

Quantised, it was 1.8 to 3.7 times slower, the penalty grows with context, and q4_0 beat q8_0 in every pair. Flash attention on its own changed almost nothing. The trade is real on a small model, though: qwen3:4b at 64K went from 12.9 GB to 5.9 GB of memory with q4_0, at 14.6 instead of 26.1 tok/s, which is worth it on a Mac that would otherwise not fit the conversation.

mlx-lm (0.31.3, Qwen3-0.6B-8bit, a 131,076-token prompt, three repeats) went the other way: `kv_bits=4` decoded at 31.7 tok/s against 18.4 to 18.7 for fp16, and cut the KV cache from 15.1 to 4.2 GB. At 32K the gain was 1.5x, so it grows with context. With mlx-lm's default `prefill_step_size` of 2048, peak memory rose to 23 GB instead of falling, because the quantised attention path builds a large fp32 score tensor; set `prefill_step_size=256` when you quantise. 8-bit output was clean and 4-bit was degraded but on topic.

We also tried the third-party [turboquant-mlx](https://github.com/arozanov/turboquant-mlx) implementation, and none of its four modes gave a usable result for us: symmetric 3-bit produced word salad, the fused modes ran at 0.04 to 0.06 times normal speed, V-only produced identical output with 61% more memory, and the hybrid mode produced no tokens.

### ollama caches your prompt even when the client says 0%

On ollama's Anthropic-compatible `/v1/messages` endpoint, an 8,115-token prefix took 20.0 s the first time and 0.32 s when resent. The cache works; the response simply carries no cache fields, so a client like Claude Code shows "0% cache" over a cache that is doing its job. `cache_control` markers are ignored.

The one place it breaks is when a conversation fills `num_ctx`. ollama then shifts the window, every position moves, and the cached prefix is gone: in one agent session the time to read each turn went from 33 s to 182 s on the turn the window filled, and stayed there. Size `num_ctx` for the whole conversation, and remember ollama allocates all of it up front. At the full 262,144-token window qwen3:4b took 53.6 GB of memory, more than qwen3.6:35b (29.1 GB), so memory at long context depends on the model's architecture far more than on its parameter count.

### A local model can drive a real Claude Code session

The May post asked how much context an agent actually uses. We ran Claude Code against a local model (`ollama launch claude`) on a multi-step writing task over a 76-file synthetic notes folder: read the notes, then write a biography and a timeline.

| Model | Runs | Wall time | Turns | Context, start → peak |
|---|---|---|---|---|
| Hosted Claude, for reference | 1 | 4.9 min | 53 | 34K → 105K |
| qwen3.6:35b, ollama 0.33.1, M1 Max | 6 | 7.4 to 13.5 min (mean 9.8) | 33 to 73 | 57K → 76K to 103K |

A session peaks around 100K tokens, so 32K of context is not enough and 64K is borderline. Identical runs varied from 33 to 73 turns, which means one run tells you almost nothing about speed; run each configuration at least three times. We compared speed only, not the quality of what each model wrote.

`ollama launch claude` sets all four of Claude Code's model variables (the Haiku, Sonnet and Opus slots and the subagent model) to your model, which matters because background calls otherwise ask for a model ollama does not have and fail. Claude Code's auto mode also shows a one-time billing notice on a non-Anthropic endpoint that waits for Enter, and its safety classifier cannot run there, so some shell commands are refused without a message.

### Apple's SpeechAnalyzer transcribes twice as fast as whisper, and less accurately

Speech was May's clearest Apple Silicon win, and macOS 26 added a second engine. On a 65-minute audiobook chapter on the M1 Max, whisper large-v3-turbo (through sona, on Metal) took 129.9 s and Apple's SpeechAnalyzer took 64.4 s. On short test clips whisper was as accurate or better everywhere both engines work (English word error rate 7.7 to 12.9% for whisper against 13.6 to 23.1%, German 3.1% against 9.4%, Spanish equal at 2.4%), and SpeechAnalyzer does not support Finnish or Swedish at all. Those clips are 11 to 20 seconds each, so read the error rates as a direction rather than a measurement.

Two whisper servers on the same file and settings also differed more than we expected: vibe-server 0.6.10 took 204 to 214 s where sona 0.2.1 took 134 to 155 s, with the same word error rates on five of six test clips.

## Image and video generation on the M1 Max

The open-weight image and video models got good enough this year that we wanted to know whether a Mac can run them at a speed you would put up with. We ran three image models and three video models on the M1 Max with the same synthetic prompts for every model (six for stills: a portrait, an interior, a hand-lettered chalkboard sign, two people at a kitchen table, a harbour at dusk and a flat vector illustration; three for video: a barista pouring latte art, a ferry leaving a snowy harbour and a dog catching a ball), seed 42, through the MLX ports rather than ComfyUI. ComfyUI on Apple Silicon runs through PyTorch's MPS backend, which cannot load the fp8 files these models ship as, and the official two-stage LTX workflow produced NaN there for other people before us; the MLX ports avoid both. The night run on 25 October had the Mac to itself (GPU idle before the start).

| Model | Licence | Output | Time per output |
|---|---|---|---|
| FLUX.2 klein 4B, q8, 4 steps (mflux 0.23) | Apache-2.0 | 1024×1024 still | 26 s |
| Z-Image Turbo, q8, 9 steps (mflux) | Apache-2.0 | 1024×1024 still | 102 s |
| FLUX 3 Image Klein, q8 (mflux) | FLUX Kommunity, free under US$5M revenue | 1024×1024 still | 106 s |
| LTX-2.3, q8, distilled ([ltx-2-mlx](https://github.com/dgrauet/ltx-2-mlx)) | LTX-2 Community, free under US$10M ARR | 4 s at 768×512 with sound | 143 s |
| LTX-2.5, q8, distilled (ltx-2-mlx) | LTX-2 Community | 4 s at 768×512 with sound | 153 s |
| LTX-2.5, q8, distilled (ltx-2-mlx) | LTX-2 Community | 10 s at 576×1024 with sound | 577 s |
| Wan 2.2 TI2V-5B, 20 steps ([mlx-video](https://github.com/Blaizzy/mlx-video)) | Apache-2.0 | 5 s at 1280×704, no sound | 73 min |

(Median wall time per output for the stills, including loading the model each time, since every image was its own process.) The ltx-2-mlx README reports 563 s for the 10-second clip on an M1 Max from a starting image; ours, from text alone, took 577 s, so its number holds up. LTX peaked at about 27 GB of Metal memory for the 4-second clips and 31 GB for the 10-second one, so a 32 GB Mac is the floor for it. Z-Image Turbo peaked at 13 GB and Wan 2.2 at 10 GB.

We also ran everything once by day while the Mac was in use, and the four stills we compared were pixel-identical to the night run with the same seed, so on MLX the seed determines the picture and only the time changes.

What the models are like, from looking at the outputs rather than measuring them:

- **Z-Image Turbo** is the most photographic: the kitchen-table scene reads as a candid photo, and it wrote the chalkboard text exactly. It ignores an instruction like "black and white line art only" and adds colour anyway.
- **FLUX 3 Image Klein** has the best texture and lettering (the chalk looks like chalk), but its people pose with staged, exaggerated expressions. It follows "line art only" best of the three.
- **FLUX.2 klein 4B** is four times faster than the other two and draws clean, simple shapes, but loses detail and drifts away from specific subjects you name.
- **LTX-2.5** gives good light and a believable lens, with sound in the same pass, but the physics slips (in our barista clip the milk pours out of the steam wand), and the sound came out very quiet.
- **Wan 2.2 5B** got the physics of the pour right where LTX-2.5 did not, but at 73 minutes for 5 seconds it is something you start before bed rather than iterate with.

For a Mac with 64 GB, our pick is Z-Image Turbo for photos and FLUX 3 Image Klein when the picture has lettering, and LTX-2.5 for video. The Apache-licensed ones (Z-Image Turbo, FLUX.2 klein 4B and Wan 2.2) are free to use commercially; check the FLUX and LTX licences against your revenue. The Intel Mac cannot run any of them usefully, since there is no MLX and no Metal diffusion path for it.

### Against the hosted leaders

We then sent the same prompts to the models at the top of the Artificial Analysis leaderboards (read on 26 October), through Replicate and, for the ones Replicate does not carry, OpenRouter:

| Model | Leaderboard Elo | Price per image | Time per image |
|---|---|---|---|
| GPT Image 2.5 Sunburst, max quality | 1222 | $0.50 | about 150 s |
| Nano Banana 2.1 | 1176 | $0.034 | about 17 s |
| Muse Image (Meta) | 1127 | $0.01 | about 15 s |
| FLUX 3 Image | 1117 | $0.024 | about 25 s |
| Seedream 5 Pro | 1100 | $0.045 | about 100 s |
| Z-Image Turbo on the M1 Max | not ranked | about €0.0003 of electricity | 102 s |

On these prompts the gap is smaller than the leaderboard suggests. Z-Image Turbo's portrait and kitchen-table scene hold up next to the hosted ones, and every model, local or hosted, wrote the chalkboard sentence correctly. Where the hosted models pull ahead is places: Nano Banana drew a recognisable Helsinki harbour, while Seedream and the local models drew a generic one. Muse Image at one cent was, to our eyes, as good as models fifty times its price on most prompts. GPT Image 2.5 at maximum quality has the most detail and costs 50 cents and two and a half minutes a picture.

For video the Mac loses less on time than we expected. The hosted models returned 5 seconds at 720p with sound in 36 seconds (Gemini Omni Flash) to 9 minutes (Seedance 2.5), most of them in one to three minutes, and LTX-2.5 makes 4 seconds at 768×512 on the M1 Max in about two and a half. What you pay for is resolution and the model: a clip cost $0.09 on HeyGen Video 1 (measured through OpenRouter), $0.25 on Wan 3 and $1.68 on Kling 3 Pro. We have not judged the motion and sound of the hosted clips side by side yet; they are in the repo for anyone who wants to.

What a local picture costs is mostly the Mac's time rather than electricity. We measured 39 W while generating against 2 W idle, which is about €0.0003 of electricity per still and about €0.013 for a 73-minute Wan clip. If you count the Mac itself (say €2,000 over four years of eight generating hours a night), an hour of generation is worth about €0.17, so about half a cent per still, still a fraction of the cheapest hosted image.

### The same people across photos

We also tested something we need for our own test data: can a model keep invented people recognisable from one photo to the next, across years? Each prompt passed portraits of the people in the scene as reference images, one per person, and named what each of them wore. GPT Image 2.5, Nano Banana 2.1, FLUX 3 Image, Seedream 5 Pro and Muse Image all kept everybody recognisable and dressed them as asked. Locally, FLUX 3 Image Klein (through mflux's edit command, which takes several reference images) did the same in 8 to 11 minutes a picture by day, while FLUX.2 klein 4B merged two people into one. Two traps: without clothing in the prompt, the models copy the outfit from the reference portrait, so everybody wears the same thing for twelve years, and MAI-Image 2.6 refused every scene with a child in it, which rules it out for a family photo library.

## Speech: reading a voice memo

Last, text to speech. We had every model read three short memos, one in English and two in German, in an invented voice described in a sentence (or the closest preset where a model cannot design a voice), and checked each take by transcribing it with whisper and comparing it with the script:

| Model | Where | Word error rate, English / German / German |
|---|---|---|
| Ming-3.0 TTS 0.5B | M1 Max | 0% / 0% / 0% |
| Qwen3-TTS 1.7B VoiceDesign | M1 Max | 0% / 0% / 0% |
| Chatterbox multilingual (cloning the Qwen3 voice) | M1 Max | 0% / 0% / 0% |
| Voxtral 4B | M1 Max | 2% / 3% / 0% |
| Fish Audio Drama 3 (cloning the Qwen3 voice) | M1 Max | 56% / 0% / 2% |
| ElevenLabs v4 | hosted | 2% / 0% / 0% |
| MiniMax Speech 2.8 HD | hosted | 0% / 0% / 0% |
| Inworld Realtime TTS-2 | hosted | 0% / 0% / 0% |
| Gemini 3.8 Flash TTS (description under a heading) | hosted | 9% / 0% / 0% |

(A few percent is whisper's own error.) For reading a script, the local models are as accurate as the hosted ones, and once the model is loaded a 15-to-25-second memo took 7 seconds (Kokoro) to 40 seconds (Qwen3-TTS) on the M1 Max, and up to two minutes for Fish Audio Drama 3. Ming-3.0, the top open-weight model on the speech leaderboard, needs only 1.5 GB and designed all three voices from the description. How natural they sound is a matter of taste, so the recordings are in the repo. Two things went wrong: Fish Audio Drama 3 stopped its English memo after two sentences and filled the rest with noise, and Gemini, when we put the voice description in the same paragraph as the text, read the description out loud before the memo. Putting the description under its own heading fixed it. ElevenLabs' free plan does not allow designing a voice through the API, so it read with a stock voice.

Traps we hit getting there:

- **mflux crashes at import with Pillow 13** on Python 3.13 (`numbers._IntegralLike` exists only in Python 3.15). Install it with `pillow<13`.
- **ltx-2-mlx downloads the whole model repository before every run**, so deleting the files you do not use (the dev transformer and LoRAs, about 33 GB) only means they come back on the next run, which then spends most of an hour downloading.
- **macOS kills a long GPU job while you are using the screen.** One daytime LTX run failed with `kIOGPUCommandBufferCallbackErrorImpactingInteractivity`; it succeeded when rerun. Long video renders belong at night.
- **The Metal shader compiler service can go away**, and then every MLX job fails with `Unable to reach MTLCompilerService` until it comes back. Run a tiny MLX matrix multiply before a long queue.
- **Wan 2.2's MLX conversion needs PyTorch** to read the original `.pth` files, and a failed conversion leaves an empty folder behind that looks like a finished one.

## The traps that make local AI numbers wrong

Most of these are in the May post and the [gotchas folder](https://github.com/rememberthis-ai/local-ai-benchmarks/tree/main/gotchas) of the harness. The ones we hit this round:

- **A busy Mac.** Our first October sweep of the M1 Max ran while other work kept the load average between 15 and 75, and the numbers came out non-monotonic: gemma4:26b decoded at 21.9 tok/s with a 32K prompt and 34.5 with a 48K one, which a quiet machine does not do. Nothing in the output marks a run like that, so log the load before every model (our harness does now) and throw the run away if it was busy. We left that sweep out of this post.
- **Thinking models with an output cap**, above: the benchmark measures thinking and reports it as captioning. It happens with text too. flint:40b answered a short question normally, but with a 64K prompt it spent all of a 600-token answer thinking, and still had not started answering after 8,000 tokens; with `think: false` ollama generated the tokens and returned nothing at all.
- **A model tag that changes underneath you.** `qwen3.8:27b` now points at an nvfp4 build that ollama 0.40.8 and 0.40.9 both refuse to load ("missing layer norms"), where in August the same tag was a GGUF that ran. Pin the exact tag (`qwen3.8:27b-q4_K_M`) and note it next to the numbers.
- **A captioning number that hides how long the answers were.** A model that writes 120 tokens per photo looks slower than one that writes 40, so report caption length next to seconds per photo.
- **Low Power Mode and a battery below about 5%.** Both slow the Apple Silicon GPU without telling you, 5 to 6 times and another 2 to 3 times. Bench plugged in.
- **ollama's `:cloud` tags** run on ollama's servers and return no `eval_duration`, so a script that divides by it reports nonsense; measured end to end they ran at 76 to 96 tok/s whatever the model, because the network sets the speed.
- **`sona --gpu-device -2`** does not force CPU on Apple Silicon. It still runs on Metal.

## Run it on your own Mac

The scripts that produced every table here are in [github.com/rememberthis-ai/local-ai-benchmarks](https://github.com/rememberthis-ai/local-ai-benchmarks), in the `october-2026` folder, with every number we measured including the ones this post leaves out, and the pictures, clips and voice memos from every model so you can judge them yourself: the LLM context sweep, the captioning bench (bring your own 30 photos; we keep ours private), the generation scripts for the local and hosted models, and the gotcha write-ups. We measured exactly one M1 Max and one Intel i9, so the most useful thing you could add is a run on an M2, M3 or M4, especially one with 16 or 24 GB of memory, where we have nothing at all. Open a pull request with your results and we will add them here.

The results feed the model defaults in [Remember This](https://rememberthis.ai), one of our apps that runs this kind of model on your own Mac.
