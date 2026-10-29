#!/usr/bin/env python3
"""Does a model still answer coherently at long context, or collapse into repetition?

May 2026 found gemma-4-26b (SwiftLM) looping at 64K and 80K ("own own own … way way way", longest
repeated 4-gram run 319 of 600 tokens), and ollama's gemma4:26b spending its whole budget on thinking.
This asks for the answer directly (think:false), up to 600 tokens, temperature 0, and measures:

  longest_4gram_run   the most times one 4-word sequence repeats back to back (a collapse is in the
                      tens to hundreds; normal prose is 1)
  distinct_ratio      distinct words / words (prose ~0.5-0.7; a loop drops toward 0.01)

Full answers go to coherence-outputs.jsonl, which is PRIVATE (the prompt is built from personal notes)
and gitignored; the summary holds numbers only.

  coherence.py --host http://127.0.0.1:11555 --out results/<dir>/coherence --runs gemma4:26b:64000:70000 ...
"""
import argparse, json, pathlib, re, urllib.request

Q = re.compile(r"={70,}\s*\n\s*QUESTION\s*\n\s*={70,}\s*\n")


def post(url, body, timeout=14400):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)


def longest_run(words, n=4):
    best = 1
    for start in range(n):  # a loop of period n lines up with one of the n phases
        grams = [tuple(words[i:i + n]) for i in range(start, len(words) - n + 1, n)]
        run = 1
        for a, b in zip(grams, grams[1:]):
            run = run + 1 if a == b else 1
            best = max(best, run)
    # loops of period 1-3 words ("own own own") also show as a repeated 4-gram at step 1
    run = 1
    for i in range(1, len(words) - n + 1):
        run = run + 1 if words[i:i + n] == words[i - 1:i - 1 + n] else 1
        best = max(best, run)
    return best


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="http://127.0.0.1:11555")
    ap.add_argument("--prompt-file", default=str(pathlib.Path(__file__).parent / "dreamer_prompt_long.txt"))
    ap.add_argument("--runs", nargs="+", required=True, help="model:target_tokens:num_ctx")
    ap.add_argument("--max-tokens", type=int, default=600)
    ap.add_argument("--think", action="store_true", help="let the model think (ollama's default) instead of think:false; "
                    "for models such as flint:40b that reason before answering whatever the flag says")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    out = pathlib.Path(a.out); out.mkdir(parents=True, exist_ok=True)
    full = pathlib.Path(a.prompt_file).read_text()
    m = Q.search(full); head, tail = full[:m.start()], full[m.start():]
    rows = []
    for r in a.runs:
        name, tag, size, ctx = r.split(":"); model = f"{name}:{tag}"; size, ctx = int(size), int(ctx)
        prompt = head[:max((size - 500) * 4, 200)] + "\n\n…[truncated]…\n\n" + tail
        try:
            body = {"model": model, "prompt": prompt, "stream": False, "keep_alive": 0,
                    "options": {"num_ctx": ctx, "num_predict": a.max_tokens, "temperature": 0}}
            if not a.think: body["think"] = False
            resp = post(f"{a.host}/api/generate", body)
            text = resp.get("response") or ""
            words = re.findall(r"\w+", text.lower())
            row = {"model": model, "target": size, "num_ctx": ctx, "prompt_tokens": resp.get("prompt_eval_count"),
                   "answer_tokens": resp.get("eval_count"), "answer_chars": len(text),
                   "thinking_chars": len(resp.get("thinking") or ""), "done_reason": resp.get("done_reason"),
                   "longest_4gram_run": longest_run(words) if len(words) >= 8 else None,
                   "distinct_ratio": round(len(set(words)) / len(words), 3) if words else None}
            with open(out / "coherence-outputs.jsonl", "a") as f:
                f.write(json.dumps({**row, "response": text, "thinking": resp.get("thinking") or ""}) + "\n")
        except Exception as e:
            row = {"model": model, "target": size, "num_ctx": ctx, "error": repr(e)}
        rows.append(row); print(json.dumps(row), flush=True)
    (out / "coherence.json").write_text(json.dumps(rows, indent=1) + "\n")


if __name__ == "__main__":
    main()
