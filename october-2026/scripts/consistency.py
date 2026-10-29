#!/usr/bin/env python3
"""Consistency test (26 Oct 2026): can a model keep the SAME invented people across scenes and years?
Each scene passes the cast portraits from open-synthetic-identities as reference images, one per person,
and names clothing so the portraits' outfits are not simply copied. Hosted (Replicate + OpenRouter) here;
the local FLUX 3 Klein runs use the same SCENES via `python3 consistency.py --print-local`.
Logs to results/consistency-<date>/runs.jsonl; outputs to ~/Dev/ext/genmedia/out/consistency-<date>/.
  REPLICATE_API_TOKEN=... OPENROUTER_API_KEY=... python3 consistency.py"""
import base64, io, json, os, sys, time, urllib.request, urllib.error
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
CAST = os.path.normpath(f"{HERE}/../../open-synthetic-identities/generate/photos/cast")
DATE = os.environ.get("RUN_DATE", time.strftime("%Y%m%d"))
OUT = os.path.expanduser(f"~/Dev/ext/genmedia/out/consistency-{DATE}"); LOG = f"{HERE}/results/consistency-{DATE}/runs.jsonl"

SCENES = {
  "breakfast-2026": (["alex/age-38", "sam/canonical", "mira/age-7"],
    "Candid smartphone snapshot from 2026: the adult in image 1 (wearing a navy hoodie) and the adult in image 2 "
    "(wearing a plain white t-shirt) eat breakfast at a small kitchen table with the child in image 3 (wearing "
    "yellow pyjamas), a Saturday morning in a Berlin apartment, cereal bowls and orange juice, the child laughing, "
    "slightly tilted framing, mixed window light, a little motion blur, an ordinary phone photo, not a studio portrait"),
  "park-2021": (["sam/age-32", "mira/age-2"],
    "Candid smartphone snapshot from 2021: the adult in image 1 (wearing a grey wool coat and a knitted scarf) pushes "
    "the toddler in image 2 (wearing a red puffer suit and a bobble hat) on a swing in a Berlin playground in late "
    "autumn, bare trees, overcast flat light, shot from a slightly low angle by someone standing nearby, ordinary phone photo"),
  "climbing-2015": (["alex/age-26", "jonas/age-26"],
    "Candid smartphone snapshot from 2015: the young adult in image 1 (wearing a faded blue t-shirt and a climbing "
    "harness) and the young adult in image 2 (wearing a red softshell jacket) sit on a gritstone boulder in the Peak "
    "District drinking from flasks after climbing, rope and chalk bags beside them, windy, low afternoon sun, a "
    "slightly overexposed sky, an older-phone photo with soft focus, not a studio portrait"),
}
REPLICATE = {  # name: (model, refs-field, extra input)
  "gpt-image-2.5-sunburst-max": ("openai/gpt-image-2.5-sunburst", "input_images", {"quality": "max", "aspect_ratio": "1536x1152", "output_format": "png"}),
  "nano-banana-2.1": ("google/nano-banana-2.1", "image_input", {"resolution": "1K", "aspect_ratio": "4:3", "output_format": "png"}),
  "flux-3-image": ("black-forest-labs/flux-3-image", "images", {"resolution": "1k", "aspect_ratio": "4:3", "output_format": "png"}),
  "seedream-5-pro": ("bytedance/seedream-5-pro", "image_input", {"size": "1K", "aspect_ratio": "4:3", "output_format": "png"}),
}
OPENROUTER = {"mai-image-2.6": "microsoft/mai-image-2.6", "mai-image-2.6-flash": "microsoft/mai-image-2.6-flash", "muse-image": "meta/muse-image"}

def ref_uri(rel):
    im = Image.open(f"{CAST}/{rel}.png").convert("RGB"); im.thumbnail((768, 768)); b = io.BytesIO(); im.save(b, "JPEG", quality=90)
    return "data:image/jpeg;base64," + base64.b64encode(b.getvalue()).decode()

def http(url, body=None, headers=None, raw=False, timeout=600):
    for attempt in range(20):
        r = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, headers=headers)
        try:
            with urllib.request.urlopen(r, timeout=timeout) as f: return f.read() if raw else json.load(f)
        except urllib.error.HTTPError as e:
            t = e.read().decode()[:400]
            if e.code == 429: time.sleep(12); continue
            if e.code >= 500 and attempt < 4: time.sleep(10); continue
            return {"status": "failed", "error": f"HTTP {e.code}: {t}"}
        except Exception as e:
            if attempt < 4: time.sleep(10); continue
            return {"status": "failed", "error": repr(e)}

def log(rec):
    with open(LOG, "a") as f: f.write(json.dumps(rec) + "\n")
def done():
    s = {}
    if os.path.exists(LOG):
        for l in open(LOG): j = json.loads(l); s.setdefault(j["key"], {}).update(j)
    return s

def main():
    os.makedirs(OUT, exist_ok=True); os.makedirs(os.path.dirname(LOG), exist_ok=True)
    s = done(); RH = {"User-Agent": "rt-genmedia-bench", "Authorization": f"Bearer {os.environ['REPLICATE_API_TOKEN']}", "Content-Type": "application/json"}
    OH = {"User-Agent": "rt-genmedia-bench", "Authorization": f"Bearer {os.environ['OPENROUTER_API_KEY']}", "Content-Type": "application/json"}
    pending = {}
    for scene, (cast, prompt) in SCENES.items():
        refs = [ref_uri(c) for c in cast]
        for name, (model, field, extra) in REPLICATE.items():
            key = f"{name}-{scene}"; k = s.get(key, {})
            if k.get("status") in ("succeeded", "failed"): continue
            if k.get("id"): pending[key] = k["id"]; continue
            pr = http(f"https://api.replicate.com/v1/models/{model}/predictions", {"input": {"prompt": prompt, field: refs, **extra}}, RH)
            if not pr.get("id"): log({"key": key, "model": model, "status": "failed", "error": pr.get("error")}); print("FAIL", key, pr.get("error")); continue
            log({"key": key, "model": model, "provider": "replicate", "id": pr["id"]}); pending[key] = pr["id"]; print("created", key, flush=True)
    for scene, (cast, prompt) in SCENES.items():
        refs = [{"type": "image_url", "image_url": {"url": ref_uri(c)}} for c in cast]
        for name, model in OPENROUTER.items():
            key = f"{name}-{scene}"
            if s.get(key, {}).get("status") in ("succeeded", "failed"): continue
            t0 = time.time(); r = http("https://openrouter.ai/api/v1/images", {"model": model, "prompt": prompt, "aspect_ratio": "4:3", "input_references": refs}, OH)
            d = (r.get("data") or [{}])[0] if isinstance(r, dict) else {}
            rec = {"key": key, "model": model, "provider": "openrouter", "predict_time": round(time.time() - t0, 1), "cost": (r.get("usage") or {}).get("cost")}
            if d.get("b64_json"):
                fn = f"{OUT}/{key}." + (d.get("media_type") or "image/png").split("/")[-1]; open(fn, "wb").write(base64.b64decode(d["b64_json"]))
                rec.update(status="succeeded", file=fn)
            else: rec.update(status="failed", error=str(r.get("error") or r)[:400])
            log(rec); print(rec["status"], key, rec["predict_time"], rec.get("cost"), rec.get("error", ""), flush=True)
    while pending:
        time.sleep(10)
        for key, pid in list(pending.items()):
            pr = http(f"https://api.replicate.com/v1/predictions/{pid}", headers=RH); st = pr.get("status")
            if st not in ("succeeded", "failed", "canceled"): continue
            rec = {"key": key, "provider": "replicate", "id": pid, "status": st, "error": pr.get("error"), "predict_time": (pr.get("metrics") or {}).get("predict_time")}
            if st == "succeeded":
                o = pr["output"]; url = o[0] if isinstance(o, list) else o; fn = f"{OUT}/{key}" + (os.path.splitext(url.split("?")[0])[1] or ".png")
                urllib.request.urlretrieve(url, fn); rec["file"] = fn
            log(rec); del pending[key]; print(st, key, rec["predict_time"], rec["error"] or "", flush=True)
    print("done")

if __name__ == "__main__":
    if "--print-local" in sys.argv:
        for scene, (cast, prompt) in SCENES.items(): print(scene + "\t" + " ".join(f"{CAST}/{c}.png" for c in cast) + "\t" + prompt)
    else: main()
