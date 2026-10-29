# October 2026

Everything measured for the two October 2026 posts on augmentedmind.io, including what the posts do not mention:
[Local LLM speed on a Mac, October 2026](https://augmentedmind.io/research/local-ai/local-llm-speed-mac-october-2026/) and
[Generating images, video and voice on a Mac against the best AI APIs](https://augmentedmind.io/research/local-ai/local-vs-hosted-image-video-voice-october-2026/). Two MacBook Pros: an M1 Max with 64 GB (macOS 27) and an Intel i9-8950HK with 32 GB, plugged in, Low Power Mode off.

| Folder | What |
|---|---|
| `llm/` | ollama speed 4K to 200K on both Macs, coherence at long context, KV-cache quantisation; raw sweep tables |
| `captioning/` | seconds per photo, 30 photos, both Macs, ollama and MLX |
| `generation/` | local and hosted images and video, the same people across scenes, voice memos, cost per output |

The prompts behind the LLM and captioning numbers are private (personal notes and photos), so the answers and captions are not here; the scripts that produced them are, in `scripts/`.

Stills and voice memos are in `generation/outputs/`. The video clips (135 MB) are served from the second post's page instead of this repo; `generation/images-and-video.md` links each one.
