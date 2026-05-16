"""
Caption-quality A/B for the SwiftLM/MLX VLM evaluation.

Reads experiments/captioning-bench/photo_set_phase1.json, fetches each photo
from the running Remember This app's photo HTTP endpoint, captions it with
the model passed via --model, and writes a markdown table to
experiments/captioning-bench/results/<date>-<model-slug>.md.

Usage:
  .venv/bin/python bench.py --model mlx-community/Qwen2.5-VL-7B-Instruct-4bit
  .venv/bin/python bench.py --model mlx-community/Qwen2.5-VL-7B-Instruct-4bit \\
      --photo-set photo_set_phase1.json --max-tokens 200 --temperature 0.0
"""
import argparse
import datetime
import json
import os
import pathlib
import re
import sys
import time
import urllib.request

ROOT = pathlib.Path(__file__).parent
PHOTO_BASE = "http://127.0.0.1:21436/photos/"
PROMPT = (
    "Caption this photo in 2-3 sentences for a personal life-log timeline. "
    "Describe what's happening, who or what is in the frame, the setting, "
    "and any notable details. If there is text in the image, transcribe key "
    "phrases verbatim. Use the language of the visible text where applicable; "
    "otherwise English."
)


def slugify(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def fetch_photo(uuid: str, dest: pathlib.Path) -> pathlib.Path:
    if dest.exists() and dest.stat().st_size > 0:
        return dest
    url = PHOTO_BASE + uuid
    with urllib.request.urlopen(url, timeout=30) as r:
        data = r.read()
    dest.write_bytes(data)
    return dest


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True, help="HF MLX VLM repo id")
    ap.add_argument("--photo-set", default="photo_set_phase1.json")
    ap.add_argument("--max-tokens", type=int, default=200)
    ap.add_argument("--temperature", type=float, default=0.0)
    args = ap.parse_args()

    from mlx_vlm import load, generate
    from mlx_vlm.prompt_utils import apply_chat_template
    from mlx_vlm.utils import load_config

    photoset = json.loads((ROOT / args.photo_set).read_text())
    cache = ROOT / ".photo-cache"
    cache.mkdir(exist_ok=True)
    results_dir = ROOT / "results"
    results_dir.mkdir(exist_ok=True)

    print(f"[load] {args.model}", flush=True)
    t0 = time.monotonic()
    model, processor = load(args.model)
    config = load_config(args.model)
    load_s = time.monotonic() - t0
    print(f"[load] done in {load_s:.1f}s", flush=True)

    rows = []
    for p in photoset["photos"]:
        uuid = p["photo_uuid"]
        path = fetch_photo(uuid, cache / f"{uuid}.jpg")
        print(f"[caption] {p['id']} ({uuid})", flush=True)
        t1 = time.monotonic()
        formatted = apply_chat_template(processor, config, PROMPT, num_images=1)
        out = generate(
            model,
            processor,
            formatted,
            image=[str(path)],
            max_tokens=args.max_tokens,
            temperature=args.temperature,
            verbose=False,
        )
        # mlx-vlm 0.5+ returns a GenerateResponse object with .text + perf fields
        text = getattr(out, "text", None) or str(out)
        gen_s = time.monotonic() - t1
        rows.append(
            {
                "id": p["id"],
                "photo_uuid": uuid,
                "expected_focus": p["expected_focus"],
                "v45_baseline": p["v45_caption"],
                "candidate": text.strip(),
                "gen_seconds": round(gen_s, 1),
            }
        )
        print(f"  → {gen_s:.1f}s, {len(text.split())} words", flush=True)

    date = datetime.date.today().isoformat()
    slug = slugify(args.model.split("/")[-1])
    out_path = results_dir / f"{date}-{slug}.md"
    with out_path.open("w") as f:
        f.write(f"# Caption results — `{args.model}`\n\n")
        f.write(f"- Run: {datetime.datetime.now().isoformat(timespec='seconds')}\n")
        f.write(f"- Photo set: `{args.photo_set}`\n")
        f.write(f"- Prompt: `{PROMPT}`\n")
        f.write(f"- max_tokens={args.max_tokens}, temperature={args.temperature}\n")
        f.write(f"- Model load: {load_s:.1f}s\n\n")
        for r in rows:
            f.write(f"## {r['id']}  ({r['photo_uuid']})\n\n")
            f.write(f"**Focus:** {r['expected_focus']}\n\n")
            f.write(f"**v4.5 baseline:**\n\n> {r['v45_baseline']}\n\n")
            f.write(
                f"**Candidate ({args.model}, {r['gen_seconds']}s):**\n\n> {r['candidate']}\n\n"
            )
            f.write("---\n\n")
    print(f"[write] {out_path}", flush=True)


if __name__ == "__main__":
    main()
