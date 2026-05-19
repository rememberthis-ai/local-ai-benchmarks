# macOS silently throttles M1 Max GPU below ~5% battery — even with High Power Mode forced

Sibling to [low-power-mode-throttling.md](low-power-mode-throttling.md), but a different mechanism with a different fix.

Low Power Mode is *one* macOS GPU throttle. There's at least one more, triggered purely by battery percentage, that fires below ~5% battery even when **`pmset -g` shows `powermode 2` (High Power) and Low Power Mode is explicitly disabled**.

## The A/B (2026-05-16, same hardware, same day, same SwiftLM build)

`mlx-community/Llama-3.2-3B-Instruct-4bit` via SwiftLM, `pmset powermode=2` throughout, battery-only (no AC):

| Context | Battery 27% (morning) | Battery 2% (evening) | Slowdown |
|---:|---:|---:|---:|
| 4K  | **54 tok/s** | 18.8 tok/s | 2.9× |
| 8K  | 41 tok/s    | 11.5 tok/s | 3.6× |
| 16K | 22 tok/s    | 4.4 tok/s  | 5.0× |
| 32K | 8 tok/s     | 0.4 tok/s  | 20× |

Same model, same hardware, same Power Mode reading. The only variable is battery percentage. The throttle is steeper at higher context — a 3× tax at 4K becomes 20× at 32K.

## How we found it

Two months after the May-8 LPM gotcha was supposedly the lower bound on macOS GPU throttling, an evening re-bench at 2% battery on `Llama-3.2-3B` returned numbers that didn't match the morning's `54 tok/s @ 4K`. They were ~3× slower across the board. `pmset -g` still read `powermode 2`. Low Power Mode was off. AC was disconnected (but had been disconnected in the morning too).

A third run later that night, after plugging in to 27% battery, returned to the morning's clean numbers exactly. The variable was battery percentage. Specifically: crossing the ~5% threshold.

## The mechanism (best guess)

macOS appears to have a separate, undocumented kernel-level GPU clock throttle that activates below some low-battery threshold (~5%) regardless of user-set Power Mode. This is distinct from Low Power Mode:

| Throttle | Trigger | Severity | User-controllable |
|---|---|---|---|
| Low Power Mode | `pmset lowpowermode=1` OR macOS auto-enable on long-battery use | 5–6× across all ctx | Yes — `pmset` + System Settings |
| Sub-5% battery | Battery dropping below ~5% | 3× at low ctx, growing to 20× at high ctx | **No** — only fix is AC |

The two are independent. You can have clean numbers in High Power Mode at 30% battery (no throttle), Low Power Mode at 30% battery (5–6× throttle), and High Power Mode at 2% battery (3–20× throttle, depending on ctx). Both throttles together is presumably worse, but we didn't measure that combination.

## The fix

```bash
# Verify before benching:
pmset -g batt | grep -oE '\d+%'        # should report > 5%
```

If under 5%, plug in. There is no software-only workaround — `pmset` doesn't expose this knob.

For bench reproducibility, log battery % alongside `pmset -g` output in every result file. The existing `pmset powermode=2` check is insufficient; it doesn't catch this case.

## What this means for the May 2026 LLM matrix

Any "clean" Apple Silicon SwiftLM number published with only a Power Mode disclosure is implicitly assuming `battery > 5%`. If the bench harness didn't log battery %, the number may be 3–20× slower than the actual capability. The May-12 LLM ctx sweep run on this laptop was almost certainly affected by both throttles (LPM and sub-5%) intermittently — the May-16 clean re-bench shows ~2× faster numbers at 4K, but the sweep ran across multiple battery levels and the noise pattern is consistent with a mix of regimes.

Cross-link: [low-power-mode-throttling.md](low-power-mode-throttling.md) — the explicit-LPM cousin of this gotcha. Same outcome (artificially slow numbers), different trigger, additive penalty when both fire.

## Why we kept benching at low battery instead of plugging in

Operator error / battery anxiety underestimating how late "5%" really is on a 7-hour-runtime laptop. The fix in the bench harness is to refuse to start at < 10% battery on AC=disconnected, similar to the LPM preflight check.
