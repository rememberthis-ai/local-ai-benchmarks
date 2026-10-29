#!/usr/bin/env python3
"""KV-cache quantisation on ollama: decode speed and memory, four arms.

Repeats the 2026-08-31 measurement (docs/ongoing/KV-QUANT-OLLAMA-RESULTS-2026-08-31.md, ollama 0.33.1),
whose script was never committed, on any ollama build:

  A  defaults (what ships)          B  OLLAMA_FLASH_ATTENTION=1, f16
  C  flash attention + q8_0         D  flash attention + q4_0

Each arm restarts that ollama on its own port with the arm's environment (KV type is a server setting,
not a request option). Per model and context: a prompt filling ~45% of the window, 200 tokens,
temperature 0, model unloaded afterwards. Memory is ollama's own size_vram from /api/ps while loaded.

  kv_ollama.py --ollama ~/Dev/ext/ollama-0.40.8/ollama --out results/<dir>/kv
"""
import argparse, datetime, json, os, pathlib, subprocess, time, urllib.request

ARMS = {"A_default": {}, "B_fa_f16": {"OLLAMA_FLASH_ATTENTION": "1"},
        "C_fa_q8_0": {"OLLAMA_FLASH_ATTENTION": "1", "OLLAMA_KV_CACHE_TYPE": "q8_0"},
        "D_fa_q4_0": {"OLLAMA_FLASH_ATTENTION": "1", "OLLAMA_KV_CACHE_TYPE": "q4_0"}}


def call(url, body=None, timeout=1800):
    req = urllib.request.Request(url, data=None if body is None else json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.load(r)


def wait_quiet(limit_s=1800):
    """Wait for a 1-min load average under the performance-core count; say so when it never comes."""
    cores = float(os.environ.get("LOAD_MAX") or subprocess.run(["sysctl", "-n", "hw.perflevel0.physicalcpu"], capture_output=True, text=True).stdout or 8)
    t0 = time.time()
    while True:
        load = float(subprocess.run(["sysctl", "-n", "vm.loadavg"], capture_output=True, text=True).stdout.split()[1])
        if load < cores:
            return f"quiet (load1 {load})"
        if time.time() - t0 > limit_s:
            return f"BUSY (load1 {load} after {limit_s // 60} min)"
        time.sleep(60)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ollama", required=True)
    ap.add_argument("--port", type=int, default=11557)
    ap.add_argument("--models", nargs="+", default=["qwen3.6:35b", "qwen3:4b"])
    ap.add_argument("--ctx", nargs="+", type=int, default=[8192, 32768, 65536])
    ap.add_argument("--prompt-file", default=str(pathlib.Path(__file__).parent.parent / "swiftlm" / "dreamer_prompt.txt"))
    ap.add_argument("--out", required=True)
    ap.add_argument("--arms", nargs="+", default=list(ARMS))
    ap.add_argument("--no-wait", action="store_true", help="skip the quiet-machine wait (smoke tests only)")
    a = ap.parse_args()
    out = pathlib.Path(a.out); out.mkdir(parents=True, exist_ok=True)
    text = pathlib.Path(a.prompt_file).read_text()
    host = f"http://127.0.0.1:{a.port}"
    version = None
    rows = []
    for arm, extra in ((k, ARMS[k]) for k in a.arms):
        env = dict(os.environ, OLLAMA_HOST=f"127.0.0.1:{a.port}", **extra)
        srv = subprocess.Popen([a.ollama, "serve"], env=env, stdout=open(out / f"serve-{arm}.log", "w"), stderr=subprocess.STDOUT)
        try:
            for _ in range(60):
                try:
                    version = call(f"{host}/api/version", timeout=5)["version"]; break
                except Exception:
                    time.sleep(1)
            for model in a.models:
                for ctx in a.ctx:
                    state = "not checked" if a.no_wait else wait_quiet()
                    chars = int(ctx * 0.45 * 4.0)  # ~4 chars per token for this prompt; prompt_tokens is recorded
                    prompt = (text * (chars // len(text) + 1))[:chars] + "\n\nSummarise the three main themes above."
                    r = call(f"{host}/api/generate", {"model": model, "prompt": prompt, "stream": False, "keep_alive": "5m",
                             "options": {"num_ctx": ctx, "num_predict": 200, "temperature": 0}})
                    ps = call(f"{host}/api/ps")["models"]
                    vram = next((m["size_vram"] for m in ps if m["name"] == model), None)
                    call(f"{host}/api/generate", {"model": model, "keep_alive": 0})
                    row = {"arm": arm, "model": model, "ctx": ctx, "prompt_tokens": r.get("prompt_eval_count"),
                           "decode_tps": round(r["eval_count"] / (r["eval_duration"] / 1e9), 1),
                           "prefill_tps": round(r["prompt_eval_count"] / (r["prompt_eval_duration"] / 1e9), 1),
                           "vram_gb": None if vram is None else round(vram / 1e9, 1), "state": state}
                    rows.append(row); print(json.dumps(row), flush=True)
        finally:
            srv.terminate(); srv.wait(timeout=30)
            time.sleep(3)
    summary = {"date": datetime.datetime.now().isoformat(timespec="seconds"), "ollama": version, "rows": rows}
    (out / "kv-ollama.json").write_text(json.dumps(summary, indent=1) + "\n")
    with open(out / "kv-ollama.md", "w") as f:
        f.write(f"# KV-cache quantisation on ollama {version}\n\ndecode tok/s · size_vram GB (prefill tok/s)\n\n")
        for model in a.models:
            f.write(f"## {model}\n\n| ctx | " + " | ".join(ARMS) + " |\n|---|" + "---|" * len(ARMS) + "\n")
            for ctx in a.ctx:
                cells = [next((f"{r['decode_tps']} · {r['vram_gb']} ({r['prefill_tps']})" for r in rows
                               if r["arm"] == arm and r["model"] == model and r["ctx"] == ctx), "—") for arm in ARMS]
                f.write(f"| {ctx:,} | " + " | ".join(cells) + " |\n")
            f.write("\n")


if __name__ == "__main__":
    main()
