"""
Context-size sweep against an already-running SwiftLM instance.
Slices the existing dreamer_prompt.txt to varied byte lengths and posts
each. Records SwiftLM's internal `timings.predicted_per_second` (decode
tok/s) plus wall, prompt_tokens, completion_tokens, and RSS samples.

Usage:
  python3 ctx_sweep.py mlx-community/Qwen3.6-35B-A3B-4bit
"""
import argparse
import datetime
import json
import pathlib
import re
import subprocess
import sys
import time
import urllib.request

ROOT = pathlib.Path(__file__).parent
PROMPT_FILE = ROOT / "dreamer_prompt.txt"
OUT_DIR = ROOT / "results-llm"

# Approx 4 chars / token for English+Swedish mix
CHARS_PER_TOK = 4


def get_rss_kb(pid: int) -> int:
    try:
        out = subprocess.check_output(["ps", "-o", "rss=", "-p", str(pid)]).decode().strip()
        return int(out)
    except Exception:
        return 0


def find_pid(name: str) -> int | None:
    try:
        return int(subprocess.check_output(["pgrep", "-x", name]).decode().strip().split()[0])
    except Exception:
        return None


def slice_prompt(full: str, target_tokens: int) -> str:
    """Return a prompt of approximately target_tokens by slicing `full` and
    appending the synthesis question (which lives at the bottom of full).
    """
    # Find the QUESTION marker in the original
    m = re.search(r"={70,}\s*\n\s*QUESTION\s*\n\s*={70,}\s*\n", full)
    if not m:
        raise RuntimeError("QUESTION marker not found in dreamer_prompt.txt")
    head = full[: m.start()]
    tail = full[m.start():]

    # Reserve ~500 tokens for the question/instructions tail
    head_chars_target = (target_tokens - 500) * CHARS_PER_TOK
    head_chars_target = max(head_chars_target, 200)
    head_sliced = head[:head_chars_target] + "\n\n…[truncated]…\n\n"
    return head_sliced + tail


def post(url, body, timeout):
    req = urllib.request.Request(
        url, data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"}, method="POST",
    )
    t0 = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            data = json.loads(r.read())
        return time.monotonic() - t0, data, None
    except Exception as e:
        return time.monotonic() - t0, None, repr(e)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("model")
    ap.add_argument("--sizes", type=int, nargs="+",
                    default=[4000, 8000, 16000, 32000, 48000, 64000])
    ap.add_argument("--max-tokens", type=int, default=300)
    ap.add_argument("--timeout", type=int, default=1500)
    args = ap.parse_args()

    full = PROMPT_FILE.read_text()
    pid = find_pid("SwiftLM")
    OUT_DIR.mkdir(exist_ok=True)
    ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    out = OUT_DIR / f"ctxsweep-{ts}.md"

    rows = []
    rows.append(f"# Context-size sweep — {args.model}")
    rows.append("")
    rows.append(f"Run: {datetime.datetime.now()}")
    rows.append(f"max_tokens: {args.max_tokens} | timeout: {args.timeout}s")
    rows.append("")
    rows.append("| target_tokens | prompt_tokens | wall (s) | completion | decode tok/s (SwiftLM internal) | end-to-end tok/s | RSS before / after (MB) | first 80 chars of content |")
    rows.append("|---|---|---|---|---|---|---|---|")

    print(f"[{datetime.datetime.now():%H:%M:%S}] sweep starting → {out}", flush=True)

    for size in args.sizes:
        prompt = slice_prompt(full, size)
        print(f"[{datetime.datetime.now():%H:%M:%S}] target={size} sliced_chars={len(prompt):,}", flush=True)
        rss_before = get_rss_kb(pid) if pid else 0
        body = {
            "model": args.model,
            "messages": [{"role": "user", "content": prompt}],
            "stream": False,
            "max_tokens": args.max_tokens,
        }
        wall, resp, err = post(
            "http://127.0.0.1:5413/v1/chat/completions", body, args.timeout
        )
        rss_after = get_rss_kb(pid) if pid else 0
        if err:
            print(f"  ❌ {err}")
            rows.append(f"| {size:,} | (err) | {wall:.1f} | — | — | — | {rss_before/1024:.0f} / {rss_after/1024:.0f} | ERR: {err[:60]} |")
            continue
        u = resp.get("usage", {})
        pt = u.get("prompt_tokens", 0)
        ct = u.get("completion_tokens", 0)
        timings = resp.get("timings", {})
        decode_tps = timings.get("predicted_per_second", 0)
        e2e_tps = ct / wall if wall > 0 else 0
        msg = resp["choices"][0]["message"]
        content = msg.get("content", "") or ""
        snippet = re.sub(r"\s+", " ", content[:80]).replace("|", "·")
        print(f"  prompt={pt:,} wall={wall:.1f}s decode={decode_tps:.1f} e2e={e2e_tps:.2f} rss={rss_before/1024:.0f}→{rss_after/1024:.0f}MB", flush=True)
        rows.append(
            f"| {size:,} | {pt:,} | {wall:.1f} | {ct} | {decode_tps:.1f} | {e2e_tps:.2f} | {rss_before/1024:.0f} / {rss_after/1024:.0f} | {snippet}… |"
        )

    out.write_text("\n".join(rows) + "\n")
    print(f"[{datetime.datetime.now():%H:%M:%S}] wrote {out}")


if __name__ == "__main__":
    main()
