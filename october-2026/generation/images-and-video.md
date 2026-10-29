# Image and video generation

Local runs on the M1 Max 64 GB through the MLX ports (mflux, ltx-2-mlx, mlx-video), seed 42, the night of 24 to 25 October with the Mac to itself; hosted runs on 26 October through Replicate and OpenRouter. Same prompts for every model (`prompts.json`). Rank and Elo are from the Artificial Analysis leaderboards, read 26 October 2026. Hosted prices are list prices per image, or per output second of video, as run.

## Local models

| Model | Kind | Licence | Outputs | Median s per output | Peak RSS GB |
|---|---|---|---|---|---|
| Z-Image Turbo 6B, q8, 9 steps | image | Apache-2.0 | 6 | 104 | 13.3 |
| FLUX 3 Image Klein, q8 | image | FLUX Kommunity, free under US$5M revenue | 6 | 106 | 4.5 |
| FLUX.2 klein 4B, q8, 4 steps | image | Apache-2.0 | 6 | 26 | 9.1 |
| LTX-2.5 22B, q8, distilled | video | LTX-2 Community, free under US$10M ARR | 3 | 153 | 15.6 |
| LTX-2.3 22B, q8, distilled | video | LTX-2 Community, free under US$10M ARR | 3 | 144 | 13.3 |
| Wan 2.2 TI2V-5B, 20 steps | video | Apache-2.0 | 1 | 4359 | 10.0 |

## Hosted models

| Model | Rank | Elo | Price | Via |
|---|---|---|---|---|
| GPT Image 2.5 Sunburst (max) | 1 | 1222 | $0.50 | Replicate |
| GPT Image 2.5 Flare (max) | 2 | 1207 | $0.50 | Replicate |
| Nano Banana 2.1 | 4 | 1176 | $0.034 | Replicate |
| MAI-Image-2.6 | 5 | 1166 | ~$0.04 | OpenRouter |
| Grok Imagine Image 2 | 6 | 1166 | $0.04 | Replicate |
| Muse Image (Meta) | 8 | 1127 | $0.01 | OpenRouter |
| MAI-Image-2.6-Flash | 10 | 1119 | ~$0.02 | OpenRouter |
| FLUX 3 Image | 13 | 1117 | $0.024 | Replicate |
| Seedream 5 Pro | 16 | 1100 | $0.045 | Replicate |
| Qwen-Image 3 Pro | 17 | 1095 | $0.04 | Replicate |
| FLUX 1.1 pro (skill default today) | 90 | 870 | $0.04 | Replicate |
| Wan 3.0 (video) | 1 | 1175 | $0.05/s | Replicate |
| HeyGen Video 1 (video) | 3 | 1160 | $0.036/s | OpenRouter |
| MiniMax H3 (video) | 4 | 1158 | $0.08/s | Replicate |
| Seedance 2.5 (video) | 5 | 1158 | $0.23/s | Replicate |
| MiniMax H3 Max (video) | 7 | 1154 | $0.08/s | OpenRouter |
| FLUX 3 (video) (video) | 8 | 1145 | $0.17/s | Replicate |
| Gemini Omni Flash 1.1 (video) | 10 | 1130 | $0.15/s | Replicate |
| Kling 3.0 Pro (board anchor) (video) | 18 | 1000 | $0.336/s | Replicate |

## portrait

> Close-up portrait of an elderly fisherman on a wooden pier, weathered skin, knitted wool cap, overcast soft light, shot on an 85mm lens, shallow depth of field, natural colours

| Model | Time | Output |
|---|---|---|
| **Z-Image Turbo 6B, q8, 9 steps** (local) | 108 s | <img src="outputs/local/zimage-turbo-portrait.jpg" width="300"> |
| **FLUX 3 Image Klein, q8** (local) | 106 s | <img src="outputs/local/flux3-klein-portrait.jpg" width="300"> |
| **FLUX.2 klein 4B, q8, 4 steps** (local) | 26 s | <img src="outputs/local/flux2-klein4b-portrait.jpg" width="300"> |
| GPT Image 2.5 Sunburst (max) (#1, $0.50) | 168 s | <img src="outputs/hosted/gpt-image-2.5-sunburst-max-portrait.jpg" width="300"> |
| GPT Image 2.5 Flare (max) (#2, $0.50) | 63 s | <img src="outputs/hosted/gpt-image-2.5-flare-max-portrait.jpg" width="300"> |
| Nano Banana 2.1 (#4, $0.034) | 16 s | <img src="outputs/hosted/nano-banana-2.1-portrait.jpg" width="300"> |
| MAI-Image-2.6 (#5, ~$0.04) | 27 s | <img src="outputs/hosted/mai-image-2.6-portrait.jpg" width="300"> |
| Grok Imagine Image 2 (#6, $0.04) | 54 s | <img src="outputs/hosted/grok-imagine-image-2-portrait.jpg" width="300"> |
| Muse Image (Meta) (#8, $0.01) | 26 s | <img src="outputs/hosted/muse-image-portrait.jpg" width="300"> |
| MAI-Image-2.6-Flash (#10, ~$0.02) | 12 s | <img src="outputs/hosted/mai-image-2.6-flash-portrait.jpg" width="300"> |
| FLUX 3 Image (#13, $0.024) | 20 s | <img src="outputs/hosted/flux-3-image-portrait.jpg" width="300"> |
| Seedream 5 Pro (#16, $0.045) | 41 s | <img src="outputs/hosted/seedream-5-pro-portrait.jpg" width="300"> |
| Qwen-Image 3 Pro (#17, $0.04) | 57 s | <img src="outputs/hosted/qwen-image-3-pro-portrait.jpg" width="300"> |
| FLUX 1.1 pro (skill default today) (#90, $0.04) | 3 s | <img src="outputs/hosted/flux-1.1-pro-portrait.jpg" width="300"> |

## office

> A small Scandinavian home office at dusk, a laptop on an oak desk, a warm desk lamp, rain on the window, plants on the sill, photographed for an interior magazine

| Model | Time | Output |
|---|---|---|
| **Z-Image Turbo 6B, q8, 9 steps** (local) | 104 s | <img src="outputs/local/zimage-turbo-office.jpg" width="300"> |
| **FLUX 3 Image Klein, q8** (local) | 106 s | <img src="outputs/local/flux3-klein-office.jpg" width="300"> |
| **FLUX.2 klein 4B, q8, 4 steps** (local) | 27 s | <img src="outputs/local/flux2-klein4b-office.jpg" width="300"> |
| GPT Image 2.5 Sunburst (max) (#1, $0.50) | 134 s | <img src="outputs/hosted/gpt-image-2.5-sunburst-max-office.jpg" width="300"> |
| GPT Image 2.5 Flare (max) (#2, $0.50) | 60 s | <img src="outputs/hosted/gpt-image-2.5-flare-max-office.jpg" width="300"> |
| Nano Banana 2.1 (#4, $0.034) | 18 s | <img src="outputs/hosted/nano-banana-2.1-office.jpg" width="300"> |
| MAI-Image-2.6 (#5, ~$0.04) | 26 s | <img src="outputs/hosted/mai-image-2.6-office.jpg" width="300"> |
| Grok Imagine Image 2 (#6, $0.04) | 71 s | <img src="outputs/hosted/grok-imagine-image-2-office.jpg" width="300"> |
| Muse Image (Meta) (#8, $0.01) | 11 s | <img src="outputs/hosted/muse-image-office.jpg" width="300"> |
| MAI-Image-2.6-Flash (#10, ~$0.02) | 11 s | <img src="outputs/hosted/mai-image-2.6-flash-office.jpg" width="300"> |
| FLUX 3 Image (#13, $0.024) | 20 s | <img src="outputs/hosted/flux-3-image-office.jpg" width="300"> |
| Seedream 5 Pro (#16, $0.045) | 57 s | <img src="outputs/hosted/seedream-5-pro-office.jpg" width="300"> |
| Qwen-Image 3 Pro (#17, $0.04) | 70 s | <img src="outputs/hosted/qwen-image-3-pro-office.jpg" width="300"> |
| FLUX 1.1 pro (skill default today) (#90, $0.04) | 3 s | <img src="outputs/hosted/flux-1.1-pro-office.jpg" width="300"> |

## chalkboard

> A cafe chalkboard sign leaning against a brick wall, hand-lettered in white chalk, it reads: Close the books, not the laptop

| Model | Time | Output |
|---|---|---|
| **Z-Image Turbo 6B, q8, 9 steps** (local) | 99 s | <img src="outputs/local/zimage-turbo-chalkboard.jpg" width="300"> |
| **FLUX 3 Image Klein, q8** (local) | 105 s | <img src="outputs/local/flux3-klein-chalkboard.jpg" width="300"> |
| **FLUX.2 klein 4B, q8, 4 steps** (local) | 26 s | <img src="outputs/local/flux2-klein4b-chalkboard.jpg" width="300"> |
| GPT Image 2.5 Sunburst (max) (#1, $0.50) | 152 s | <img src="outputs/hosted/gpt-image-2.5-sunburst-max-chalkboard.jpg" width="300"> |
| GPT Image 2.5 Flare (max) (#2, $0.50) | 59 s | <img src="outputs/hosted/gpt-image-2.5-flare-max-chalkboard.jpg" width="300"> |
| Nano Banana 2.1 (#4, $0.034) | 17 s | <img src="outputs/hosted/nano-banana-2.1-chalkboard.jpg" width="300"> |
| MAI-Image-2.6 (#5, ~$0.04) | 23 s | <img src="outputs/hosted/mai-image-2.6-chalkboard.jpg" width="300"> |
| Grok Imagine Image 2 (#6, $0.04) | 58 s | <img src="outputs/hosted/grok-imagine-image-2-chalkboard.jpg" width="300"> |
| Muse Image (Meta) (#8, $0.01) | 9 s | <img src="outputs/hosted/muse-image-chalkboard.jpg" width="300"> |
| MAI-Image-2.6-Flash (#10, ~$0.02) | 12 s | <img src="outputs/hosted/mai-image-2.6-flash-chalkboard.jpg" width="300"> |
| FLUX 3 Image (#13, $0.024) | 20 s | <img src="outputs/hosted/flux-3-image-chalkboard.jpg" width="300"> |
| Seedream 5 Pro (#16, $0.045) | 44 s | <img src="outputs/hosted/seedream-5-pro-chalkboard.jpg" width="300"> |
| Qwen-Image 3 Pro (#17, $0.04) | 64 s | <img src="outputs/hosted/qwen-image-3-pro-chalkboard.jpg" width="300"> |
| FLUX 1.1 pro (skill default today) (#90, $0.04) | 5 s | <img src="outputs/hosted/flux-1.1-pro-chalkboard.jpg" width="300"> |

## friends

> Two friends laughing while sharing a pizza at a kitchen table, candid photo, natural window light, hands visible, slight motion blur

| Model | Time | Output |
|---|---|---|
| **Z-Image Turbo 6B, q8, 9 steps** (local) | 98 s | <img src="outputs/local/zimage-turbo-friends.jpg" width="300"> |
| **FLUX 3 Image Klein, q8** (local) | 105 s | <img src="outputs/local/flux3-klein-friends.jpg" width="300"> |
| **FLUX.2 klein 4B, q8, 4 steps** (local) | 25 s | <img src="outputs/local/flux2-klein4b-friends.jpg" width="300"> |
| GPT Image 2.5 Sunburst (max) (#1, $0.50) | 162 s | <img src="outputs/hosted/gpt-image-2.5-sunburst-max-friends.jpg" width="300"> |
| GPT Image 2.5 Flare (max) (#2, $0.50) | 69 s | <img src="outputs/hosted/gpt-image-2.5-flare-max-friends.jpg" width="300"> |
| Nano Banana 2.1 (#4, $0.034) | 20 s | <img src="outputs/hosted/nano-banana-2.1-friends.jpg" width="300"> |
| MAI-Image-2.6 (#5, ~$0.04) | 27 s | <img src="outputs/hosted/mai-image-2.6-friends.jpg" width="300"> |
| Grok Imagine Image 2 (#6, $0.04) | 69 s | <img src="outputs/hosted/grok-imagine-image-2-friends.jpg" width="300"> |
| Muse Image (Meta) (#8, $0.01) | 10 s | <img src="outputs/hosted/muse-image-friends.jpg" width="300"> |
| MAI-Image-2.6-Flash (#10, ~$0.02) | 10 s | <img src="outputs/hosted/mai-image-2.6-flash-friends.jpg" width="300"> |
| FLUX 3 Image (#13, $0.024) | 27 s | <img src="outputs/hosted/flux-3-image-friends.jpg" width="300"> |
| Seedream 5 Pro (#16, $0.045) | 35 s | <img src="outputs/hosted/seedream-5-pro-friends.jpg" width="300"> |
| Qwen-Image 3 Pro (#17, $0.04) | 67 s | <img src="outputs/hosted/qwen-image-3-pro-friends.jpg" width="300"> |
| FLUX 1.1 pro (skill default today) (#90, $0.04) | 4 s | <img src="outputs/hosted/flux-1.1-pro-friends.jpg" width="300"> |

## harbour

> Helsinki harbour at blue hour in winter, a ferry with its lights on, reflections on icy water, light snow falling, wide shot

| Model | Time | Output |
|---|---|---|
| **Z-Image Turbo 6B, q8, 9 steps** (local) | 107 s | <img src="outputs/local/zimage-turbo-harbour.jpg" width="300"> |
| **FLUX 3 Image Klein, q8** (local) | 105 s | <img src="outputs/local/flux3-klein-harbour.jpg" width="300"> |
| **FLUX.2 klein 4B, q8, 4 steps** (local) | 24 s | <img src="outputs/local/flux2-klein4b-harbour.jpg" width="300"> |
| GPT Image 2.5 Sunburst (max) (#1, $0.50) | 156 s | <img src="outputs/hosted/gpt-image-2.5-sunburst-max-harbour.jpg" width="300"> |
| GPT Image 2.5 Flare (max) (#2, $0.50) | 61 s | <img src="outputs/hosted/gpt-image-2.5-flare-max-harbour.jpg" width="300"> |
| Nano Banana 2.1 (#4, $0.034) | 17 s | <img src="outputs/hosted/nano-banana-2.1-harbour.jpg" width="300"> |
| MAI-Image-2.6 (#5, ~$0.04) | 24 s | <img src="outputs/hosted/mai-image-2.6-harbour.jpg" width="300"> |
| Grok Imagine Image 2 (#6, $0.04) | 63 s | <img src="outputs/hosted/grok-imagine-image-2-harbour.jpg" width="300"> |
| Muse Image (Meta) (#8, $0.01) | 27 s | <img src="outputs/hosted/muse-image-harbour.jpg" width="300"> |
| MAI-Image-2.6-Flash (#10, ~$0.02) | 10 s | <img src="outputs/hosted/mai-image-2.6-flash-harbour.jpg" width="300"> |
| FLUX 3 Image (#13, $0.024) | 24 s | <img src="outputs/hosted/flux-3-image-harbour.jpg" width="300"> |
| Seedream 5 Pro (#16, $0.045) | 44 s | <img src="outputs/hosted/seedream-5-pro-harbour.jpg" width="300"> |
| Qwen-Image 3 Pro (#17, $0.04) | 54 s | <img src="outputs/hosted/qwen-image-3-pro-harbour.jpg" width="300"> |
| FLUX 1.1 pro (skill default today) (#90, $0.04) | 3 s | <img src="outputs/hosted/flux-1.1-pro-harbour.jpg" width="300"> |

## robot

> Flat vector illustration of a friendly robot sorting paper receipts into labelled folders on a desk, muted pastel palette, clean shapes

| Model | Time | Output |
|---|---|---|
| **Z-Image Turbo 6B, q8, 9 steps** (local) | 101 s | <img src="outputs/local/zimage-turbo-robot.jpg" width="300"> |
| **FLUX 3 Image Klein, q8** (local) | 108 s | <img src="outputs/local/flux3-klein-robot.jpg" width="300"> |
| **FLUX.2 klein 4B, q8, 4 steps** (local) | 25 s | <img src="outputs/local/flux2-klein4b-robot.jpg" width="300"> |
| GPT Image 2.5 Sunburst (max) (#1, $0.50) | 119 s | <img src="outputs/hosted/gpt-image-2.5-sunburst-max-robot.jpg" width="300"> |
| GPT Image 2.5 Flare (max) (#2, $0.50) | 54 s | <img src="outputs/hosted/gpt-image-2.5-flare-max-robot.jpg" width="300"> |
| Nano Banana 2.1 (#4, $0.034) | 15 s | <img src="outputs/hosted/nano-banana-2.1-robot.jpg" width="300"> |
| MAI-Image-2.6 (#5, ~$0.04) | 27 s | <img src="outputs/hosted/mai-image-2.6-robot.jpg" width="300"> |
| Grok Imagine Image 2 (#6, $0.04) | 85 s | <img src="outputs/hosted/grok-imagine-image-2-robot.jpg" width="300"> |
| Muse Image (Meta) (#8, $0.01) | 18 s | <img src="outputs/hosted/muse-image-robot.jpg" width="300"> |
| MAI-Image-2.6-Flash (#10, ~$0.02) | 9 s | <img src="outputs/hosted/mai-image-2.6-flash-robot.jpg" width="300"> |
| FLUX 3 Image (#13, $0.024) | 18 s | <img src="outputs/hosted/flux-3-image-robot.jpg" width="300"> |
| Seedream 5 Pro (#16, $0.045) | 70 s | <img src="outputs/hosted/seedream-5-pro-robot.jpg" width="300"> |
| Qwen-Image 3 Pro (#17, $0.04) | 58 s | <img src="outputs/hosted/qwen-image-3-pro-robot.jpg" width="300"> |
| FLUX 1.1 pro (skill default today) (#90, $0.04) | 5 s | <img src="outputs/hosted/flux-1.1-pro-robot.jpg" width="300"> |

## barista

> A barista pours steamed milk into a cup of coffee, making a leaf pattern, close-up, warm cafe light, the hiss of the steam wand and quiet cafe chatter

| Model | Time | Output |
|---|---|---|
| **LTX-2.5 22B, q8, distilled** (local) | 153 s | [ltx25-barista.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/ltx25-barista.mp4) |
| **LTX-2.3 22B, q8, distilled** (local) | 3113 s | [ltx23-barista.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/ltx23-barista.mp4) |
| **Wan 2.2 TI2V-5B, 20 steps** (local) | 4359 s | [wan22-5b-barista.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/wan22-5b-barista.mp4) |
| Wan 3.0 (#1, $0.05/s) | 130 s | [wan-3-barista.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/wan-3-barista.mp4) |
| HeyGen Video 1 (#3, $0.036/s) |  | [heygen-video-1-barista.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/heygen-video-1-barista.mp4) |
| MiniMax H3 (#4, $0.08/s) | 163 s | [minimax-h3-barista.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/minimax-h3-barista.mp4) |
| Seedance 2.5 (#5, $0.23/s) | 539 s | [seedance-2.5-barista.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/seedance-2.5-barista.mp4) |
| MiniMax H3 Max (#7, $0.08/s) |  | [minimax-h3-max-barista.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/minimax-h3-max-barista.mp4) |
| FLUX 3 (video) (#8, $0.17/s) | 60 s | [flux-3-video-barista.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/flux-3-video-barista.mp4) |
| Gemini Omni Flash 1.1 (#10, $0.15/s) | 36 s | [gemini-omni-1.1-barista.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/gemini-omni-1.1-barista.mp4) |
| Kling 3.0 Pro (board anchor) (#18, $0.336/s) | 128 s | [kling-v3-barista.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/kling-v3-barista.mp4) |

## ferry

> A ferry pulls away from a snowy harbour at blue hour, slow dolly shot along the pier, gulls calling, the low rumble of the engine

| Model | Time | Output |
|---|---|---|
| **LTX-2.5 22B, q8, distilled** (local) | 155 s | [ltx25-ferry.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/ltx25-ferry.mp4) |
| **LTX-2.3 22B, q8, distilled** (local) | 143 s | [ltx23-ferry.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/ltx23-ferry.mp4) |
| Wan 3.0 (#1, $0.05/s) | 124 s | [wan-3-ferry.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/wan-3-ferry.mp4) |
| HeyGen Video 1 (#3, $0.036/s) |  | [heygen-video-1-ferry.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/heygen-video-1-ferry.mp4) |
| MiniMax H3 (#4, $0.08/s) | 152 s | [minimax-h3-ferry.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/minimax-h3-ferry.mp4) |
| Seedance 2.5 (#5, $0.23/s) | 392 s | [seedance-2.5-ferry.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/seedance-2.5-ferry.mp4) |
| MiniMax H3 Max (#7, $0.08/s) |  | [minimax-h3-max-ferry.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/minimax-h3-max-ferry.mp4) |
| FLUX 3 (video) (#8, $0.17/s) | 60 s | [flux-3-video-ferry.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/flux-3-video-ferry.mp4) |
| Gemini Omni Flash 1.1 (#10, $0.15/s) | 37 s | [gemini-omni-1.1-ferry.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/gemini-omni-1.1-ferry.mp4) |
| Kling 3.0 Pro (board anchor) (#18, $0.336/s) | 128 s | [kling-v3-ferry.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/kling-v3-ferry.mp4) |

## dog

> A golden retriever runs across a sunlit meadow toward the camera and jumps to catch a red ball, slow motion, birdsong

| Model | Time | Output |
|---|---|---|
| **LTX-2.5 22B, q8, distilled** (local) | 150 s | [ltx25-dog.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/ltx25-dog.mp4) |
| **LTX-2.3 22B, q8, distilled** (local) | 144 s | [ltx23-dog.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/ltx23-dog.mp4) |
| Wan 3.0 (#1, $0.05/s) | 147 s | [wan-3-dog.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/wan-3-dog.mp4) |
| HeyGen Video 1 (#3, $0.036/s) |  | [heygen-video-1-dog.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/heygen-video-1-dog.mp4) |
| MiniMax H3 (#4, $0.08/s) | 154 s | [minimax-h3-dog.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/minimax-h3-dog.mp4) |
| Seedance 2.5 (#5, $0.23/s) | 410 s | [seedance-2.5-dog.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/seedance-2.5-dog.mp4) |
| MiniMax H3 Max (#7, $0.08/s) |  | [minimax-h3-max-dog.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/minimax-h3-max-dog.mp4) |
| FLUX 3 (video) (#8, $0.17/s) | 63 s | [flux-3-video-dog.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/flux-3-video-dog.mp4) |
| Gemini Omni Flash 1.1 (#10, $0.15/s) | 36 s | [gemini-omni-1.1-dog.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/gemini-omni-1.1-dog.mp4) |
| Kling 3.0 Pro (board anchor) (#18, $0.336/s) | 128 s | [kling-v3-dog.mp4](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/media/vid/kling-v3-dog.mp4) |

The colouring-book prompt was also run but is left out here: it names a film character.

