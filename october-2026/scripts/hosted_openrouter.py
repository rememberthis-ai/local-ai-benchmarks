#!/usr/bin/env python3
"""Hosted side-by-side, part 2: the leaders Replicate does not host, through OpenRouter (26 Oct 2026).
Same prompts.json, same runs.jsonl and output folder as hosted.py. Video job ids are logged the moment
they are created, so a rerun polls instead of paying again. Images are synchronous (POST /api/v1/images).
  OPENROUTER_API_KEY=... python3 hosted_openrouter.py [images|videos|all]"""
import base64, json, os, sys, time, urllib.request, urllib.error
HERE = os.path.dirname(os.path.abspath(__file__))
DATE = os.environ.get("RUN_DATE", time.strftime("%Y%m%d"))
OUT = os.path.expanduser(f"~/Dev/ext/genmedia/out/hosted-{DATE}")
LOG = f"{HERE}/results/hosted-{DATE}/runs.jsonl"
H = {"User-Agent": "rt-genmedia-bench", "Authorization": f"Bearer {os.environ['OPENROUTER_API_KEY']}", "Content-Type": "application/json"}
API = "https://openrouter.ai/api/v1"
IMAGES = {"mai-image-2.6": "microsoft/mai-image-2.6", "mai-image-2.6-flash": "microsoft/mai-image-2.6-flash", "muse-image": "meta/muse-image"}
VIDEOS = {"heygen-video-1": ("heygen/heygen-video-1", "768p"), "minimax-h3-max": ("minimax/hailuo-3-max", "768p")}
SKIP = {"colouring"}

def call(url, body=None, raw=False, timeout=600):
    r = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, headers=H)
    try:
        with urllib.request.urlopen(r, timeout=timeout) as f:
            return f.read() if raw else json.load(f)
    except urllib.error.HTTPError as e:
        return {"error": f"HTTP {e.code}: {e.read().decode()[:400]}"}

def seen():
    d = {}
    if os.path.exists(LOG):
        for l in open(LOG): j = json.loads(l); d.setdefault(j["key"], {}).update(j)
    return d

def log(rec):
    with open(LOG, "a") as f: f.write(json.dumps(rec) + "\n")

def images(prompts):
    s = seen()
    for p in prompts:
        for name, model in IMAGES.items():
            key = f"{name}-{p['id']}"
            if s.get(key, {}).get("status") in ("succeeded", "failed"): continue
            t0 = time.time(); r = call(f"{API}/images", {"model": model, "prompt": p["prompt"], "aspect_ratio": "1:1"})
            rec = {"key": key, "kind": "image", "model": model, "provider": "openrouter", "predict_time": round(time.time() - t0, 1), "t": time.time()}
            data = (r.get("data") or [{}])[0] if isinstance(r, dict) else {}
            if data.get("b64_json") or data.get("url"):
                fn = f"{OUT}/{key}." + (data.get("media_type") or "image/png").split("/")[-1]
                open(fn, "wb").write(base64.b64decode(data["b64_json"]) if data.get("b64_json") else urllib.request.urlopen(data["url"]).read())
                rec.update(status="succeeded", file=fn, cost=(r.get("usage") or {}).get("cost"))
            else:
                rec.update(status="failed", error=str(r.get("error") or r)[:400])
            log(rec); print(rec["status"], key, rec["predict_time"], rec.get("error", ""), flush=True)

def videos(prompts):
    s = seen(); pending = {}
    for p in prompts:
        for name, (model, res) in VIDEOS.items():
            key = f"{name}-{p['id']}"; k = s.get(key, {})
            if k.get("status") in ("succeeded", "failed"): continue
            if k.get("id"): pending[key] = (k["id"], model); continue
            r = call(f"{API}/videos", {"model": model, "prompt": p["prompt"], "duration": 5, "resolution": res, "aspect_ratio": "16:9", "generate_audio": True})
            if not r.get("id"):
                log({"key": key, "kind": "video", "model": model, "provider": "openrouter", "status": "failed", "error": str(r)[:400], "t": time.time()}); print("FAIL", key, r); continue
            log({"key": key, "kind": "video", "model": model, "provider": "openrouter", "id": r["id"], "created": time.time()}); pending[key] = (r["id"], model); print("created", key, r["id"], flush=True)
    while pending:
        time.sleep(15)
        for key, (jid, model) in list(pending.items()):
            r = call(f"{API}/videos/{jid}"); st = r.get("status")
            if st not in ("completed", "failed", "cancelled", "error"): continue
            rec = {"key": key, "kind": "video", "model": model, "provider": "openrouter", "id": jid, "status": "succeeded" if st == "completed" else "failed", "error": r.get("error"), "cost": (r.get("usage") or {}).get("cost"), "t": time.time()}
            if st == "completed":
                fn = f"{OUT}/{key}.mp4"; b = call(f"{API}/videos/{jid}/content", raw=True)
                if isinstance(b, bytes): open(fn, "wb").write(b); rec["file"] = fn
                else: rec.update(status="failed", error=str(b))
            log(rec); del pending[key]; print(rec["status"], key, rec.get("error") or "", flush=True)

if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"; os.makedirs(OUT, exist_ok=True)
    P = json.load(open(f"{HERE}/prompts.json"))
    if what in ("videos", "all"): videos(P["videos"])
    if what in ("images", "all"): images([p for p in P["images"] if p["id"] not in SKIP])
    print("done")
