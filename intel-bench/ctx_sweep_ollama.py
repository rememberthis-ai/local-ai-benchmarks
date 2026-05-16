"""
Context-size sweep against an already-running ollama server.
Mirrors experiments/swiftlm/ctx_sweep.py but targets ollama's
/api/generate instead of SwiftLM, and uses ollama's own
eval_count/eval_duration for decode tok/s.

Usage:
  python3 ctx_sweep_ollama.py llama3.2:3b \\
    --sizes 4000 8000 16000 32000 \\
    --prompt-file ../swiftlm/dreamer_prompt.txt \\
    --out-dir results
"""
import argparse
import datetime
import json
import os
import pathlib
import re
import time
import urllib.request

OLLAMA_HOST_URL = os.environ.get("OLLAMA_HOST_URL", "http://127.0.0.1:11434")

CHARS_PER_TOK = 4
QUESTION_MARKER = re.compile(r"={70,}\s*\n\s*QUESTION\s*\n\s*={70,}\s*\n")


def slice_prompt(full: str, target_tokens: int) -> str:
    m = QUESTION_MARKER.search(full)
    if not m:
        raise RuntimeError("QUESTION marker not found in dreamer_prompt.txt")
    head = full[: m.start()]
    tail = full[m.start():]
    head_chars_target = max((target_tokens - 500) * CHARS_PER_TOK, 200)
    return head[:head_chars_target] + "\n\n…[truncated]…\n\n" + tail


def post(url: str, body: dict, timeout: int):
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"}, method="POST",
    )
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        data = json.loads(r.read())
    return time.monotonic() - t0, data


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("model")
    ap.add_argument("--sizes", type=int, nargs="+", default=[4000, 8000, 16000, 32000])
    ap.add_argument("--prompt-file", required=True)
    ap.add_argument("--out-dir", default="results")
    ap.add_argument("--max-tokens", type=int, default=300)
    ap.add_argument("--timeout", type=int, default=1800)  # 30 min for slow Intel
    ap.add_argument("--num-ctx", type=int, default=40_000,
                    help="ollama's num_ctx — must exceed largest --size or ollama truncates silently!")
    args = ap.parse_args()

    full = pathlib.Path(args.prompt_file).read_text()
    out_dir = pathlib.Path(args.out_dir)
    out_dir.mkdir(exist_ok=True)
    slug = args.model.replace(":", "_").replace("/", "_")
    ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    out = out_dir / f"ctxsweep-ollama-{slug}-{ts}.md"

    rows = [
        f"# Context-size sweep — ollama {args.model}",
        "",
        f"Run: {datetime.datetime.now()}",
        f"num_ctx: {args.num_ctx} | max_tokens: {args.max_tokens} | timeout: {args.timeout}s",
        "",
        "| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s | prefill tok/s | first 80 chars of content |",
        "|---|---|---|---|---|---|---|",
    ]

    print(f"[{datetime.datetime.now():%H:%M:%S}] sweep starting → {out}", flush=True)
    for size in args.sizes:
        prompt = slice_prompt(full, size)
        print(f"[{datetime.datetime.now():%H:%M:%S}] target={size:,} chars={len(prompt):,}", flush=True)
        body = {
            "model": args.model,
            "prompt": prompt,
            "stream": False,
            "keep_alive": "5m",   # keep loaded between size points (same model)
            "options": {
                "num_ctx": args.num_ctx,
                "num_predict": args.max_tokens,
            },
        }
        try:
            wall, resp = post(f"{OLLAMA_HOST_URL}/api/generate", body, args.timeout)
        except Exception as e:
            print(f"  ❌ {e!r}")
            rows.append(f"| {size:,} | (err) | — | — | — | — | ERR: {e!r}[:60] |")
            continue
        pt = resp.get("prompt_eval_count", 0)
        ct = resp.get("eval_count", 0)
        pdur_ns = resp.get("prompt_eval_duration", 1)
        edur_ns = resp.get("eval_duration", 1)
        prefill_tps = pt / (pdur_ns / 1e9) if pdur_ns else 0
        decode_tps = ct / (edur_ns / 1e9) if edur_ns else 0
        content = (resp.get("response") or "")
        snippet = re.sub(r"\s+", " ", content[:80]).replace("|", "·")
        print(f"  prompt={pt:,} wall={wall:.1f}s decode={decode_tps:.1f} prefill={prefill_tps:.1f}", flush=True)
        rows.append(
            f"| {size:,} | {pt:,} | {wall:.1f} | {ct} | {decode_tps:.1f} | {prefill_tps:.1f} | {snippet}… |"
        )

    out.write_text("\n".join(rows) + "\n")
    print(f"[{datetime.datetime.now():%H:%M:%S}] wrote {out}")


if __name__ == "__main__":
    main()
