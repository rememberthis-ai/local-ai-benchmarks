"""
Caption the photo set via SwiftLM in --vision mode using a VLM (e.g., Qwen2.5-VL).

SwiftLM exposes /v1/chat/completions with OpenAI-style multimodal content:

    {"messages":[{"role":"user","content":[
        {"type":"text","text":"..."},
        {"type":"image_url","image_url":{"url":"data:image/jpeg;base64,..."}}
    ]}]}

Caller must already have launched SwiftLM with `--vision --model <vlm>` on
some port. This script does NOT spawn SwiftLM (we want the daemon kept warm
for an A/B that re-uses one cold start across N photos).
"""
import argparse
import base64
import datetime
import json
import pathlib
import re
import time
import urllib.request

ROOT = pathlib.Path(__file__).parent
CACHE = ROOT.parent / "captioning-bench" / ".photo-cache"
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


def fetch_photo_b64(uuid: str) -> str:
    cache = CACHE / f"{uuid}.jpg"
    if cache.exists() and cache.stat().st_size > 0:
        return base64.b64encode(cache.read_bytes()).decode()
    url = PHOTO_BASE + uuid
    with urllib.request.urlopen(url, timeout=30) as r:
        data = r.read()
    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_bytes(data)
    return base64.b64encode(data).decode()


def chat(host: str, model: str, image_b64: str, max_tokens: int = 600) -> tuple[str, float]:
    body = {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": PROMPT},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"},
                    },
                ],
            }
        ],
        "stream": False,
        "max_tokens": max_tokens,
        "temperature": 0.0,
    }
    req = urllib.request.Request(
        f"http://{host}/v1/chat/completions",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=600) as r:
        d = json.loads(r.read())
    return d["choices"][0]["message"]["content"], time.monotonic() - t0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1:5413")
    ap.add_argument("--model", required=True, help="HF model id matching the running SwiftLM")
    ap.add_argument(
        "--photo-set",
        default=str(ROOT.parent / "captioning-bench" / "photo_set_phase2.json"),
    )
    ap.add_argument("--max-tokens", type=int, default=600)
    args = ap.parse_args()

    photoset = json.loads(pathlib.Path(args.photo_set).read_text())
    rows = []
    for p in photoset["photos"]:
        uuid = p["photo_uuid"]
        print(f"[caption] {p['id']} ({uuid}) via SwiftLM {args.host}", flush=True)
        try:
            img_b64 = fetch_photo_b64(uuid)
            text, dt = chat(args.host, args.model, img_b64, args.max_tokens)
            print(f"  → {dt:.1f}s, {len(text.split())} words", flush=True)
        except Exception as e:
            text, dt = f"[ERROR: {e}]", 0
            print(f"  → ERROR: {e}", flush=True)
        rows.append({**p, "candidate": text.strip(), "gen_seconds": round(dt, 1)})

    date = datetime.date.today().isoformat()
    slug = slugify(args.model.replace("/", "-").replace(":", "-"))
    out = (ROOT.parent / "captioning-bench" / "results" / f"{date}-swiftlm-{slug}.md")
    out.parent.mkdir(exist_ok=True)
    with out.open("w") as f:
        f.write(f"# Caption results — `{args.model}` via SwiftLM ({args.host})\n\n")
        f.write(f"- Run: {datetime.datetime.now().isoformat(timespec='seconds')}\n")
        f.write(f"- Photo set: `{pathlib.Path(args.photo_set).name}` ({len(rows)} photos)\n\n")
        for r in rows:
            f.write(f"## {r['id']}  ({r['photo_uuid']})\n\n")
            f.write(f"**Focus:** {r['expected_focus']}\n\n")
            f.write(f"**v4.5 baseline:**\n\n> {r['v45_caption']}\n\n")
            f.write(f"**Candidate ({args.model}, {r['gen_seconds']}s):**\n\n> {r['candidate']}\n\n")
            f.write("---\n\n")
    print(f"[write] {out}", flush=True)


if __name__ == "__main__":
    main()
