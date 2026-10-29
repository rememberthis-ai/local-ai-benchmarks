# What a local output costs

Power measured with `powermetrics` during a Z-Image Turbo run on 26 October: 2 W idle and 39 W average while generating (CPU, GPU and Neural Engine together). Wall power assumed 1.3 times that for the rest of the Mac and the charger, at €0.20 per kWh.

| Output | Time | Energy | Electricity |
|---|---|---|---|
| Z-Image Turbo or FLUX 3 Klein still | ~105 s | ~1.4 Wh | ~€0.0003 |
| FLUX.2 klein 4B still | 26 s | ~0.35 Wh | ~€0.0001 |
| LTX-2.5 clip, 4 s | ~150 s | ~2 Wh | ~€0.0004 |
| Wan 2.2 clip, 5 s | 73-86 min | ~60-70 Wh | ~€0.013 |

Extra wear from generating instead of idling is mainly the battery ageing faster in the heat (about €0.005 an hour, assuming 10 °C warmer; not measured) and the fans (about €0.002 an hour). Valuing the Mac's time instead (€2,000 over four years of eight generating hours a night) gives €0.17 an hour, about €0.005 a still.

Hosted, for comparison: $0.01 (Muse Image) to $0.50 (GPT Image 2.5 at max) a still, and $0.036 to $0.34 per second of video.

