"""
Caption the same 5 photos via an ollama /api/chat endpoint (used to drive the
tc-mb fork on a non-default port). Writes a markdown report parallel to
experiments/captioning-bench/results/.
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
    cache = ROOT.parent / "captioning-bench" / ".photo-cache" / f"{uuid}.jpg"
    if cache.exists():
        return base64.b64encode(cache.read_bytes()).decode()
    url = PHOTO_BASE + uuid
    with urllib.request.urlopen(url, timeout=30) as r:
        data = r.read()
    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_bytes(data)
    return base64.b64encode(data).decode()


def chat(host: str, model: str, image_b64: str, no_think: bool = False) -> tuple[str, float]:
    messages = []
    if no_think:
        # Qwen3-family convention: /no_think system prompt suppresses <think> blocks
        messages.append({"role": "system", "content": "/no_think"})
    messages.append({"role": "user", "content": PROMPT, "images": [image_b64]})
    body = {
        "model": model,
        "messages": messages,
        "stream": False,
        "options": {"temperature": 0.0, "num_predict": 600},
    }
    req = urllib.request.Request(
        f"http://{host}/api/chat",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=600) as r:
        d = json.loads(r.read())
    return d.get("message", {}).get("content", ""), time.monotonic() - t0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1:21435")
    ap.add_argument("--model", default="openbmb/minicpm-o4.5:latest")
    ap.add_argument(
        "--photo-set",
        default=str(ROOT.parent / "captioning-bench" / "photo_set_phase1.json"),
    )
    ap.add_argument("--no-think", action="store_true", help="Send /no_think system prompt to suppress thinking-mode")
    ap.add_argument("--label", default="", help="Optional label appended to output filename slug")
    args = ap.parse_args()

    photoset = json.loads(pathlib.Path(args.photo_set).read_text())
    results = []
    for p in photoset["photos"]:
        uuid = p["photo_uuid"]
        print(f"[caption] {p['id']} ({uuid}) via {args.host}", flush=True)
        try:
            img_b64 = fetch_photo_b64(uuid)
            text, dt = chat(args.host, args.model, img_b64, no_think=args.no_think)
            print(f"  → {dt:.1f}s, {len(text.split())} words", flush=True)
        except Exception as e:
            text, dt = f"[ERROR: {e}]", 0
            print(f"  → ERROR: {e}", flush=True)
        results.append({**p, "candidate": text.strip(), "gen_seconds": round(dt, 1)})

    date = datetime.date.today().isoformat()
    slug = slugify(args.model.replace("/", "-").replace(":", "-"))
    label = ("-" + slugify(args.label)) if args.label else ("-nothink" if args.no_think else "")
    out = (ROOT.parent / "captioning-bench" / "results" / f"{date}-fork-{slug}{label}.md")
    out.parent.mkdir(exist_ok=True)
    with out.open("w") as f:
        f.write(f"# Caption results — `{args.model}` via tc-mb ollama fork ({args.host})\n\n")
        f.write(f"- Run: {datetime.datetime.now().isoformat(timespec='seconds')}\n\n")
        for r in results:
            f.write(f"## {r['id']}  ({r['photo_uuid']})\n\n")
            f.write(f"**Focus:** {r['expected_focus']}\n\n")
            f.write(f"**v4.5 baseline:**\n\n> {r['v45_caption']}\n\n")
            f.write(f"**Candidate ({args.model}, {r['gen_seconds']}s):**\n\n> {r['candidate']}\n\n")
            f.write("---\n\n")
    print(f"[write] {out}", flush=True)


if __name__ == "__main__":
    main()
