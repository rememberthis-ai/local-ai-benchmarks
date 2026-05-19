# macOS Low Power Mode silently throttles M1 Max GPU by 5–6×

This one almost shipped wrong numbers across an entire blog post. It would have if a re-bench hadn't been triggered for an unrelated reason.

## The original bench (May 8, on battery)

Apple Silicon VLM throughput, M1 Max 64 GB:

| Model | s/photo (May 8) |
|---|---:|
| FastVLM-0.5B-bf16 | 5.5 |
| Gemma-4-26B-A4B-it-4bit | 16.3 |
| Qwen2.5-VL-7B-Instruct-4bit | 16.3 |
| Qwen3-VL-8B-Instruct-4bit | 22.5 |

Those numbers shipped to a blog post. They were 5–6× too slow.

## The re-bench (May 16, plugged in, High Power Mode forced)

| Model | s/photo (May 8) | s/photo (May 16, clean) | Speedup |
|---|---:|---:|---:|
| FastVLM-0.5B-bf16 | 5.5 | **1.10** | 5× |
| Gemma-4-26B-A4B-it-4bit | 16.3 | **2.56** | 6.4× |
| Qwen2.5-VL-7B-Instruct-4bit | 16.3 | **2.72** | 6× |
| Qwen3-VL-8B-Instruct-4bit | 22.5 | **4.05** | 5.5× |

Same hardware. Same SwiftLM build. Same model weights. Same photo set. Same prompt. Same shell environment. The variable was `pmset -g` showing `lowpowermode` set on battery.

## How we found it

While benching a new candidate (Qwen3-VL-4B), the per-photo wall time stepped from 3 s to 10–12 s mid-run, after photo ~8. Initial hypotheses (all wrong):

1. Disk thrash from prefetch hammering page cache → no — pmap stable
2. M1 thermal throttling → no — `pmset -g thermlog` showed no thermal events
3. MLX state accumulation across photos → no — restarting SwiftLM didn't fix it

The actual cause: battery dropped past ~20% during the bench, macOS auto-enabled Low Power Mode, GPU clocks throttled. Re-bench at 35% (still LPM) showed the throttle was already active.

A third re-bench, plugged in with Power Mode manually set to High via System Settings → Battery → Battery → Low Power Mode = Never, produced clean 3.0 s median with no degradation. That triggered the broader re-bench of the May-8 matrix anchors, which revealed the 5–6× tax was systemic.

## The fix

```bash
# Verify before benching
pmset -g | grep lowpowermode    # should show "lowpowermode  0"
pmset -g batt                   # should show "AC Power" not "Battery Power"
```

If you see `lowpowermode 1` or `Battery Power`, the numbers are not comparable to anyone else's. Three ways to fix:

1. **Plug in.** Easiest. macOS still respects manual Low Power Mode settings even on AC, but the auto-switch goes away.
2. **Set Power Mode = High explicitly.** System Settings → Battery → Battery (or Power Adapter) → Low Power Mode → Never. On Macs with the new tri-state Power Mode (M3 Max+, Mac Studio), explicitly select "High Power."
3. **`sudo pmset -b lowpowermode 0`** — disables Low Power Mode while on battery. Per-session only; macOS may re-enable on next charge cycle below 20%.

For bench reproducibility, always log the result of `pmset -g | grep -E 'lowpowermode|Power Mode'` alongside the numbers.

**See also: [sub-5pct-battery-throttle.md](sub-5pct-battery-throttle.md)** — a *separate* macOS throttle that fires below ~5% battery even with High Power Mode forced. The two are independent and additive.

## Why this matters for blog matrices

Every published benchmark claiming Apple Silicon throughput needs to disclose Power Mode + AC vs battery. Most don't. If a benchmark says "16.3 s/photo on M1 Max for Gemma-4-26B" and you re-run on AC + High Power and see 2.6 s, the original wasn't lying — they just didn't know.

## Did our LLM benches catch this too?

Almost certainly. The LLM ctx-sweep run on May 10–12 was on the same laptop, mostly on battery. The numbers from the early-May LLM table (e.g. Qwen3.6-35B at 15.5 tok/s @ 4K) are probably 2–6× understated. A partial re-bench started May 16 produced these clean numbers for the small-LLM tier:

| Model | tok/s @ 4K (May 12 tainted) | tok/s @ 4K (May 16 clean) |
|---|---:|---:|
| Llama-3.2-3B-Instruct-4bit | 22.1 | **54** |
| Phi-4-mini-instruct-4bit | 22.3 | **44** |
| Qwen3-4B-4bit (thinking) | 14.3 | **57** |

Same ~2× pattern. The full LLM re-bench is pending (each model × 4 context sizes is slow). When it lands, expect every Apple Silicon LLM number in any blog post that cites pre-May-16 data to roughly double.
