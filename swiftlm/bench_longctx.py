"""
Long-context bench (Python — robust against large prompts and long timeouts).

Runs the dreamer_prompt.txt against either ollama or SwiftLM (or both) and
captures: prefill speed, decode speed, RSS peak, content + reasoning_content.

Usage:
  python3 bench_longctx.py --ollama gemma4:26b --num-ctx 131072
  python3 bench_longctx.py --swiftlm "mlx-community/gemma-4-26b-a4b-it-4bit"
  python3 bench_longctx.py --ollama gemma4:26b --swiftlm "..." --num-ctx 131072
"""
import argparse
import datetime
import json
import os
import pathlib
import subprocess
import sys
import time
import urllib.request

ROOT = pathlib.Path(__file__).parent
PROMPT_FILE = ROOT / "dreamer_prompt.txt"
OUT_DIR = ROOT / "results-llm"


def post_json(url: str, body: dict, timeout: float):
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    t0 = time.monotonic()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            body = r.read()
    except Exception as e:
        return time.monotonic() - t0, None, repr(e)
    return time.monotonic() - t0, json.loads(body), None


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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ollama", help="ollama tag", default=None)
    ap.add_argument("--swiftlm", help="SwiftLM HF repo", default=None)
    ap.add_argument("--num-ctx", type=int, default=131072)
    ap.add_argument("--max-tokens", type=int, default=600)
    ap.add_argument("--timeout", type=int, default=2400, help="HTTP timeout in seconds")
    ap.add_argument("--label", default="")
    args = ap.parse_args()

    prompt = PROMPT_FILE.read_text()
    print(f"prompt: {len(prompt):,} bytes ≈ {len(prompt)//4:,} rough tokens")

    OUT_DIR.mkdir(exist_ok=True)
    ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    label_part = f"-{args.label}" if args.label else ""
    out = OUT_DIR / f"longctx-{ts}{label_part}.md"

    lines = [
        f"# Long-context bench — {args.label or 'no-label'}",
        "",
        f"Prompt: {len(prompt):,} bytes",
        f"num_ctx: {args.num_ctx} | max_tokens: {args.max_tokens} | timeout: {args.timeout}s",
        f"Run: {datetime.datetime.now()}",
        "",
    ]

    # --- ollama ---
    if args.ollama:
        print(f"[{datetime.datetime.now():%H:%M:%S}] ollama bench: {args.ollama}", flush=True)
        body = {
            "model": args.ollama,
            "messages": [{"role": "user", "content": prompt}],
            "stream": False,
            "options": {"num_ctx": args.num_ctx, "num_predict": args.max_tokens},
        }
        wall, resp, err = post_json("http://127.0.0.1:21434/api/chat", body, args.timeout)
        lines.append(f"## ollama ({args.ollama}) — num_ctx={args.num_ctx}")
        lines.append("")
        if err:
            lines.append(f"- ❌ ERROR: `{err}`")
            lines.append(f"- wall: {wall:.1f}s")
        else:
            pec = resp.get("prompt_eval_count", 0)
            ec = resp.get("eval_count", 0)
            pd_ns = resp.get("prompt_eval_duration", 0)
            ed_ns = resp.get("eval_duration", 0)
            prefill = pec / (pd_ns / 1e9) if pd_ns else 0
            decode = ec / (ed_ns / 1e9) if ed_ns else 0
            msg = resp.get("message", {})
            content = msg.get("content", "")
            thinking = msg.get("thinking", "")
            lines.append(f"- wall: {wall:.1f}s")
            lines.append(f"- prompt_eval_count: **{pec:,}** tokens")
            lines.append(f"- eval_count: {ec:,} tokens")
            lines.append(f"- **prefill speed: {prefill:.1f} tok/s**")
            lines.append(f"- **decode speed: {decode:.1f} tok/s**")
            lines.append(f"- prefill wall (computed): {pd_ns/1e9:.1f}s")
            lines.append(f"- decode wall (computed): {ed_ns/1e9:.1f}s")
            lines.append(f"- content len: {len(content)} chars")
            lines.append(f"- thinking len: {len(thinking)} chars")
            lines.append("")
            lines.append("### content (first 1200 chars)")
            lines.append("")
            lines.append("```")
            lines.append(content[:1200] if content else "(empty)")
            lines.append("```")
            if thinking:
                lines.append("")
                lines.append("### thinking (first 800 chars)")
                lines.append("")
                lines.append("```")
                lines.append(thinking[:800])
                lines.append("```")
        lines.append("")
        # Free GPU
        try:
            urllib.request.urlopen(
                urllib.request.Request(
                    "http://127.0.0.1:21434/api/generate",
                    data=json.dumps({"model": args.ollama, "keep_alive": 0}).encode(),
                    headers={"Content-Type": "application/json"},
                    method="POST",
                ),
                timeout=10,
            ).read()
        except Exception:
            pass
        time.sleep(5)

    # --- SwiftLM ---
    if args.swiftlm:
        print(f"[{datetime.datetime.now():%H:%M:%S}] swiftlm bench: {args.swiftlm}", flush=True)
        rss_before = 0
        pid = find_pid("SwiftLM")
        if pid:
            rss_before = get_rss_kb(pid)
        body = {
            "model": args.swiftlm,
            "messages": [{"role": "user", "content": prompt}],
            "stream": False,
            "max_tokens": args.max_tokens,
        }
        wall, resp, err = post_json(
            "http://127.0.0.1:5413/v1/chat/completions", body, args.timeout
        )
        rss_after = get_rss_kb(pid) if pid else 0
        lines.append(f"## SwiftLM ({args.swiftlm})")
        lines.append("")
        if err:
            lines.append(f"- ❌ ERROR: `{err}`")
            lines.append(f"- wall: {wall:.1f}s")
        else:
            u = resp.get("usage", {})
            pt = u.get("prompt_tokens", 0)
            ct = u.get("completion_tokens", 0)
            msg = resp["choices"][0]["message"]
            content = msg.get("content", "")
            rc = msg.get("reasoning_content", "")
            lines.append(f"- wall: {wall:.1f}s")
            lines.append(f"- prompt_tokens: **{pt:,}**")
            lines.append(f"- completion_tokens: {ct:,}")
            lines.append(
                f"- **end-to-end speed (output / wall): {ct/wall:.1f} tok/s**"
            )
            lines.append(
                f"  (note: SwiftLM /v1/chat/completions doesn't break out prefill vs decode)"
            )
            lines.append(f"- RSS before / after: {rss_before/1024:.1f} MB / {rss_after/1024:.1f} MB")
            lines.append(f"- content len: {len(content)} chars")
            lines.append(f"- reasoning_content len: {len(rc)} chars")
            lines.append("")
            lines.append("### content (first 1200 chars)")
            lines.append("")
            lines.append("```")
            lines.append(content[:1200] if content else "(empty)")
            lines.append("```")
            if rc:
                lines.append("")
                lines.append("### reasoning_content (first 800 chars)")
                lines.append("")
                lines.append("```")
                lines.append(rc[:800])
                lines.append("```")
        lines.append("")

    out.write_text("\n".join(lines))
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
