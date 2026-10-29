#!/usr/bin/env python3
"""Hosted side-by-side: the same prompts as the local bench (prompts.json), through the leaders Replicate
hosts (read 26 Oct 2026 off the Artificial Analysis boards). Every prediction id is logged the moment it is
created, so a rerun resumes it instead of paying again. Outputs go to ~/Dev/ext/genmedia/out/hosted-<date>/.
  REPLICATE_API_TOKEN=... python3 hosted.py [images|videos|all]"""
import json, os, sys, time, urllib.request, urllib.error
HERE = os.path.dirname(os.path.abspath(__file__))
DATE = os.environ.get("RUN_DATE", time.strftime("%Y%m%d"))
OUT = os.path.expanduser(f"~/Dev/ext/genmedia/out/hosted-{DATE}")
LOG = f"{HERE}/results/hosted-{DATE}/runs.jsonl"
TOK = os.environ["REPLICATE_API_TOKEN"]
UA = {"User-Agent": "rt-genmedia-bench", "Authorization": f"Bearer {TOK}", "Content-Type": "application/json"}

IMAGES = {  # name: (model, input extras); square, ~1 MP, like the local runs
  "gpt-image-2.5-sunburst-max": ("openai/gpt-image-2.5-sunburst", {"quality": "max", "aspect_ratio": "1024x1024", "output_format": "png"}),
  "gpt-image-2.5-flare-max": ("openai/gpt-image-2.5-flare", {"quality": "max", "aspect_ratio": "1024x1024", "output_format": "png"}),
  "nano-banana-2.1": ("google/nano-banana-2.1", {"resolution": "1K", "aspect_ratio": "1:1", "output_format": "png"}),
  "grok-imagine-image-2": ("xai/grok-imagine-image-2", {"resolution": "1k", "aspect_ratio": "1:1"}),
  "flux-3-image": ("black-forest-labs/flux-3-image", {"resolution": "1k", "aspect_ratio": "1:1", "output_format": "png"}),
  "seedream-5-pro": ("bytedance/seedream-5-pro", {"size": "1K", "aspect_ratio": "1:1", "output_format": "png"}),
  "qwen-image-3-pro": ("alibaba/qwen-image-3-pro", {"aspect_ratio": "1:1"}),
  "flux-1.1-pro": ("black-forest-labs/flux-1.1-pro", {"aspect_ratio": "1:1", "output_format": "png"}),
}
VIDEOS = {  # 5 s, 720p-class, 16:9, sound on where the model has it
  "wan-3": ("alibaba/wan-3", {"duration": 5, "resolution": "720p", "aspect_ratio": "16:9"}),
  "minimax-h3": ("minimax/h3", {"duration": 5, "resolution": "768P"}),
  "seedance-2.5": ("bytedance/seedance-2.5", {"duration": 5, "resolution": "720p", "aspect_ratio": "16:9", "generate_audio": True}),
  "flux-3-video": ("black-forest-labs/flux-3", {"duration": "5", "resolution": "720p", "aspect_ratio": "16:9", "generate_audio": True}),
  "gemini-omni-1.1": ("google/gemini-omni-1.1", {"resolution": "720p", "aspect_ratio": "16:9"}),
  "kling-v3": ("kwaivgi/kling-v3-video", {"duration": 5, "mode": "pro", "aspect_ratio": "16:9", "generate_audio": True}),
}

def req(url, body=None):
    for attempt in range(30):
        r = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, headers=UA)
        try:
            return json.load(urllib.request.urlopen(r, timeout=120))
        except urllib.error.HTTPError as e:
            txt = e.read().decode()[:400]
            if e.code == 429:
                time.sleep((json.loads(txt).get("retry_after", 10) if txt.startswith("{") else 10) + 1); continue
            if e.code >= 500 and attempt < 5: time.sleep(10); continue
            return {"status": "failed", "error": f"HTTP {e.code}: {txt}"}
        except Exception as e:
            if attempt < 5: time.sleep(10); continue
            return {"status": "failed", "error": repr(e)}

def logged():
    d = {}
    if os.path.exists(LOG):
        for l in open(LOG):
            j = json.loads(l); d.setdefault(j["key"], {}).update(j)
    return d

def log(rec):
    with open(LOG, "a") as f: f.write(json.dumps(rec) + "\n")

def run(kind, table, prompts):
    os.makedirs(OUT, exist_ok=True); os.makedirs(os.path.dirname(LOG), exist_ok=True)
    seen = logged(); pending = {}
    for p in prompts:
        for name, (model, extra) in table.items():
            key = f"{name}-{p['id']}"
            s = seen.get(key, {})
            if s.get("status") in ("succeeded", "failed"): continue
            if s.get("id"): pending[key] = (s["id"], name, model); continue   # resume, never re-pay
            pr = req(f"https://api.replicate.com/v1/models/{model}/predictions", {"input": {"prompt": p["prompt"], **extra}})
            if not pr.get("id"):
                log({"key": key, "kind": kind, "model": model, "status": "failed", "error": pr.get("error"), "t": time.time()}); print("FAIL create", key, pr.get("error")); continue
            log({"key": key, "kind": kind, "model": model, "id": pr["id"], "created": time.time()}); pending[key] = (pr["id"], name, model)
            print("created", key, pr["id"], flush=True); time.sleep(2)
    while pending:
        time.sleep(10)
        for key, (pid, name, model) in list(pending.items()):
            pr = req(f"https://api.replicate.com/v1/predictions/{pid}")
            st = pr.get("status")
            if st not in ("succeeded", "failed", "canceled"): continue
            rec = {"key": key, "kind": kind, "model": model, "id": pid, "status": st, "error": pr.get("error"),
                   "predict_time": (pr.get("metrics") or {}).get("predict_time"), "t": time.time()}
            if st == "succeeded":
                o = pr.get("output"); url = o[0] if isinstance(o, list) else o
                ext = os.path.splitext(url.split("?")[0])[1] or (".mp4" if kind == "video" else ".png")
                fn = f"{OUT}/{key}{ext}"
                urllib.request.urlretrieve(url, fn); rec["file"] = fn
            log(rec); del pending[key]; print(st, key, rec.get("predict_time"), rec.get("error") or "", flush=True)

if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    P = json.load(open(f"{HERE}/prompts.json"))
    if what in ("images", "all"): run("image", IMAGES, P["images"])
    if what in ("videos", "all"): run("video", VIDEOS, P["videos"])
    print("done")
