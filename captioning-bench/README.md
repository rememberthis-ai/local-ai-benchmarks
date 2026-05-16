# Captioning bench

Test harness for the SwiftLM/MLX VLM evaluation —
[plan](../../docs/plans/SWIFTLM-MLX-CAPTIONING-EVAL.md).

Compares VLM candidates against the v0.10.x default
(`openbmb/minicpm-v4.5`, served by ollama) on a fixed set of photos drawn
from the running Remember This app's registry index.

## Reproduce

The Remember This app must be running so the photo HTTP endpoint
(`127.0.0.1:21436`) is alive.

```bash
# from repo root
python3.13 -m venv experiments/captioning-bench/.venv
experiments/captioning-bench/.venv/bin/pip install mlx-vlm

# Phase 1 — sanity check on Qwen2.5-VL
experiments/captioning-bench/.venv/bin/python \
  experiments/captioning-bench/bench.py \
  --model mlx-community/Qwen2.5-VL-7B-Instruct-4bit

# Phase 2 — full A/B
for model in \
  andrevp/MiniCPM-o-4_5-MLX-4bit \
  mlx-community/Qwen3-VL-8B-Instruct-4bit \
  mlx-community/FastVLM-7B-Instruct-4bit ; do
  experiments/captioning-bench/.venv/bin/python \
    experiments/captioning-bench/bench.py --model "$model"
done
```

Each run writes `results/<date>-<model-slug>.md`. The v4.5 baseline is
already inlined in `photo_set_phase1.json` (read from registry frontmatter).

## Cleanup

- `rm -rf experiments/captioning-bench/.venv` — drop the ~870 MB venv.
- `rm -rf experiments/captioning-bench/.photo-cache` — drop fetched JPEGs.
- `rm -rf ~/.cache/huggingface/hub/models--*` — drop downloaded model
  weights (HF cache; ~4 GB per VLM).
