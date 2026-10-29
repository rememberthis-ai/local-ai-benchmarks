# The same people across scenes and years

Can a model keep invented people recognisable from photo to photo? Each scene passes the cast portraits from [open-synthetic-identities](https://github.com/rememberthis-ai/open-synthetic-identities) as reference images, one per person, and names what each person wears. 26 October 2026.

## breakfast-2026

> Candid smartphone snapshot from 2026: the adult in image 1 (wearing a navy hoodie) and the adult in image 2 (wearing a plain white t-shirt) eat breakfast at a small kitchen table with the child in image 3 (wearing yellow pyjamas), a Saturday morning in a Berlin apartment, cereal bowls and orange juice, the child laughing, slightly tilted framing, mixed window light, a little motion blur, an ordinary phone photo, not a studio portrait

| Model | Time | Output |
|---|---|---|
| reference 1: alex/age-38 |  | <img src="outputs/cast/alex-age-38.jpg" width="200"> |
| reference 2: sam/canonical |  | <img src="outputs/cast/sam-canonical.jpg" width="200"> |
| reference 3: mira/age-7 |  | <img src="outputs/cast/mira-age-7.jpg" width="200"> |
| flux-3-image | 95 s | <img src="outputs/consistency/flux-3-image-breakfast-2026.jpg" width="360"> |
| flux3-klein-local (local) | 689 s | <img src="outputs/consistency/flux3-klein-local-breakfast-2026.jpg" width="360"> |
| gpt-image-2.5-sunburst-max | 110 s | <img src="outputs/consistency/gpt-image-2.5-sunburst-max-breakfast-2026.jpg" width="360"> |
| mai-image-2.6 | 31 s | refused or failed: HTTP 400: {"error":{"message":"Azure MAI blocked this request through content moderation.","code":400,"metadata":{"provider_name":"Azure"}}} |
| mai-image-2.6-flash | 21 s | refused or failed: HTTP 400: {"error":{"message":"Azure MAI blocked this request through content moderation.","code":400,"metadata":{"provider_name":"Azure"}}} |
| muse-image | 17 s | <img src="outputs/consistency/muse-image-breakfast-2026.jpg" width="360"> |
| nano-banana-2.1 | 35 s | <img src="outputs/consistency/nano-banana-2.1-breakfast-2026.jpg" width="360"> |
| seedream-5-pro | 112 s | <img src="outputs/consistency/seedream-5-pro-breakfast-2026.jpg" width="360"> |

## park-2021

> Candid smartphone snapshot from 2021: the adult in image 1 (wearing a grey wool coat and a knitted scarf) pushes the toddler in image 2 (wearing a red puffer suit and a bobble hat) on a swing in a Berlin playground in late autumn, bare trees, overcast flat light, shot from a slightly low angle by someone standing nearby, ordinary phone photo

| Model | Time | Output |
|---|---|---|
| reference 1: sam/age-32 |  | <img src="outputs/cast/sam-age-32.jpg" width="200"> |
| reference 2: mira/age-2 |  | <img src="outputs/cast/mira-age-2.jpg" width="200"> |
| flux-3-image | 27 s | <img src="outputs/consistency/flux-3-image-park-2021.jpg" width="360"> |
| flux3-klein-local (local) | 454 s | <img src="outputs/consistency/flux3-klein-local-park-2021.jpg" width="360"> |
| gpt-image-2.5-sunburst-max | 120 s | <img src="outputs/consistency/gpt-image-2.5-sunburst-max-park-2021.jpg" width="360"> |
| mai-image-2.6-flash | 18 s | refused or failed: HTTP 400: {"error":{"message":"Azure MAI blocked this request through content moderation.","code":400,"metadata":{"provider_name":"Azure"}}} |
| mai-image-2.6 | 23 s | refused or failed: HTTP 400: {"error":{"message":"Azure MAI blocked this request through content moderation.","code":400,"metadata":{"provider_name":"Azure"}}} |
| muse-image | 15 s | <img src="outputs/consistency/muse-image-park-2021.jpg" width="360"> |
| nano-banana-2.1 | 21 s | <img src="outputs/consistency/nano-banana-2.1-park-2021.jpg" width="360"> |
| seedream-5-pro | 89 s | <img src="outputs/consistency/seedream-5-pro-park-2021.jpg" width="360"> |

## climbing-2015

> Candid smartphone snapshot from 2015: the young adult in image 1 (wearing a faded blue t-shirt and a climbing harness) and the young adult in image 2 (wearing a red softshell jacket) sit on a gritstone boulder in the Peak District drinking from flasks after climbing, rope and chalk bags beside them, windy, low afternoon sun, a slightly overexposed sky, an older-phone photo with soft focus, not a studio portrait

| Model | Time | Output |
|---|---|---|
| reference 1: alex/age-26 |  | <img src="outputs/cast/alex-age-26.jpg" width="200"> |
| reference 2: jonas/age-26 |  | <img src="outputs/cast/jonas-age-26.jpg" width="200"> |
| flux-3-image | 25 s | <img src="outputs/consistency/flux-3-image-climbing-2015.jpg" width="360"> |
| flux3-klein-local (local) | 502 s | <img src="outputs/consistency/flux3-klein-local-climbing-2015.jpg" width="360"> |
| gpt-image-2.5-sunburst-max | 124 s | <img src="outputs/consistency/gpt-image-2.5-sunburst-max-climbing-2015.jpg" width="360"> |
| mai-image-2.6 | 27 s | <img src="outputs/consistency/mai-image-2.6-climbing-2015.jpg" width="360"> |
| mai-image-2.6-flash | 20 s | <img src="outputs/consistency/mai-image-2.6-flash-climbing-2015.jpg" width="360"> |
| muse-image | 25 s | refused or failed: HTTP 400: {"error":{"message":"The response was filtered due to the prompt triggering our content management policy.","code":400,"metadata": |
| nano-banana-2.1 | 15 s | <img src="outputs/consistency/nano-banana-2.1-climbing-2015.jpg" width="360"> |
| seedream-5-pro | 118 s | <img src="outputs/consistency/seedream-5-pro-climbing-2015.jpg" width="360"> |

