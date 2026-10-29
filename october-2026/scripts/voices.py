#!/usr/bin/env python3
"""Voice comparison (26 Oct 2026): the same three memos (open-synthetic-identities/generate/voice-scripts) read by
the leading hosted TTS models, one invented voice per speaker. Where a model can design a voice from a description
(ElevenLabs, Qwen3-TTS) it gets the SPEAKERS description; otherwise the closest preset plus a style hint.
Outputs ~/Dev/ext/genmedia/out/voices-<date>/<model>-<memo>.<ext>, log results/voices-<date>/runs.jsonl.
Keys from the keychain (augmentedmind-genai): REPLICATE_API_TOKEN, ELEVENLABS_API_KEY, GEMINI_API_KEY."""
import base64, json, os, re, subprocess, sys, time, urllib.request, urllib.error, wave
HERE = os.path.dirname(os.path.abspath(__file__))
VS = os.path.normpath(f"{HERE}/../../open-synthetic-identities/generate/voice-scripts")
DATE = os.environ.get("RUN_DATE", time.strftime("%Y%m%d"))
OUT = os.path.expanduser(f"~/Dev/ext/genmedia/out/voices-{DATE}"); LOG = f"{HERE}/results/voices-{DATE}/runs.jsonl"
def key(n): return subprocess.run(["security", "find-generic-password", "-s", "augmentedmind-genai", "-a", n, "-w"], capture_output=True, text=True).stdout.strip()

SPEAKERS = {
  "alex": ("en", "A calm British adult in their late thirties with a gender-neutral, mid-pitched voice and a light northern English accent, relaxed and friendly, quietly dictating a note to self into a phone."),
  "sam": ("de", "A warm, kind man in his late thirties, a secondary-school teacher in Berlin, speaking fluent natural German with a soft, friendly, mid-low voice, recording a quick reminder on his phone."),
  "fischer": ("de", "A German tax advisor in his late fifties, a measured, slightly dry baritone with standard German pronunciation, speaking politely and efficiently in a meeting."),
}
MEMOS = {"en-climbing-trip": "alex", "de-mira-schulausflug": "sam", "de-steuerberater-termin": "fischer"}
PRESETS = {  # closest built-in voice per model and speaker
  "gemini-3.8-flash-tts": {"alex": "Iapetus", "sam": "Achird", "fischer": "Algenib"},
  "inworld-realtime-tts-2": {"alex": "Alex", "sam": "Dennis", "fischer": "Ronald"},
  "minimax-speech-2.8-hd": {"alex": "English_Deep-VoicedGentleman", "sam": "German_FriendlyMan", "fischer": "German_PlayfulMan"},
}
def memo_text(m):
    t = open(f"{VS}/{m}.md").read().split("\n", 1)[1]
    return re.sub(r"\s+", " ", t).strip()

def http(url, body=None, headers=None, raw=False, timeout=300):
    r = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, headers=headers or {})
    try:
        with urllib.request.urlopen(r, timeout=timeout) as f: return f.read() if raw else json.load(f)
    except urllib.error.HTTPError as e: return {"error": f"HTTP {e.code}: {e.read().decode()[:400]}"}
def log(rec):
    with open(LOG, "a") as f: f.write(json.dumps(rec) + "\n")
def seen():
    s = {}
    if os.path.exists(LOG):
        for l in open(LOG): j = json.loads(l); s.setdefault(j["key"], {}).update(j)
    return s

def eleven_voices(K):
    """Design one voice per speaker (eleven_ttv_v3), save it, return {speaker: voice_id}. Cached in the log."""
    H = {"xi-api-key": K, "Content-Type": "application/json"}; s = seen(); ids = {}
    for sp, (lang, desc) in SPEAKERS.items():
        k = f"eleven-voice-{sp}"
        if s.get(k, {}).get("voice_id"): ids[sp] = s[k]["voice_id"]; continue
        d = http("https://api.elevenlabs.io/v1/text-to-voice/design", {"voice_description": desc, "model_id": "eleven_ttv_v3", "auto_generate_text": True}, H)
        prev = (d.get("previews") or [{}])[0]
        if not prev.get("generated_voice_id"): log({"key": k, "status": "failed", "error": str(d)[:400]}); print("FAIL", k, str(d)[:300]); continue
        v = http("https://api.elevenlabs.io/v1/text-to-voice", {"voice_name": f"genmedia-{sp}", "voice_description": desc, "generated_voice_id": prev["generated_voice_id"]}, H)
        if not v.get("voice_id"): log({"key": k, "status": "failed", "error": str(v)[:400]}); print("FAIL", k, str(v)[:300]); continue
        ids[sp] = v["voice_id"]; log({"key": k, "status": "succeeded", "voice_id": v["voice_id"]}); print("designed", k)
    return ids

# The free plan cannot design voices through the API (403 "only available on a paid plan"), so the fallback is the
# closest premade voice: River (neutral, calm), Chris (warm, down-to-earth, male), Daniel (formal, steady).
ELEVEN_PREMADE = {"alex": "SAz9YHcvj6GT2YYXdXww", "sam": "iP95p4xoKVk53GoZ742B", "fischer": "onwK4e9ZLuTAKqWW03F9"}

def run_eleven(K):
    ids = {**ELEVEN_PREMADE, **eleven_voices(K)}; s = seen()
    for m, sp in MEMOS.items():
        k = f"eleven-v4-{m}"
        if s.get(k, {}).get("status") == "succeeded" or sp not in ids: continue
        t0 = time.time()
        b = http(f"https://api.elevenlabs.io/v1/text-to-speech/{ids[sp]}?output_format=mp3_44100_128",
                 {"text": memo_text(m), "model_id": "eleven_v4", "language_code": SPEAKERS[sp][0]}, {"xi-api-key": K, "Content-Type": "application/json"}, raw=True)
        done(k, "eleven/eleven_v4", b, "mp3", t0)

def gemini_prompt(desc, text, directed):
    # The first run (plain) put the description before the text in one paragraph, and Gemini read it aloud in 2 of 3
    # memos. "directed" is the layout Google documents for TTS: profile and notes as headings, then the transcript.
    if not directed: return f"Read this as the following speaker. {desc}\n\n{text}"
    return f"# AUDIO PROFILE\n{desc}\n\n### DIRECTOR'S NOTES\nSpeak only the transcript below; never read these notes aloud.\n\n#### TRANSCRIPT\n{text}"
def run_gemini(K, directed=False):
    s = seen()
    for m, sp in MEMOS.items():
        k = f"gemini-3.8-flash-tts{'-directed' if directed else ''}-{m}"
        if s.get(k, {}).get("status") == "succeeded": continue
        t0 = time.time(); desc = SPEAKERS[sp][1]
        r = http("https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash-tts:generateContent",
                 {"contents": [{"parts": [{"text": gemini_prompt(desc, memo_text(m), directed)}]}],
                  "generationConfig": {"responseModalities": ["AUDIO"], "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": PRESETS["gemini-3.8-flash-tts"][sp]}}}}},
                 {"x-goog-api-key": K, "Content-Type": "application/json"})
        try:
            pcm = base64.b64decode(r["candidates"][0]["content"]["parts"][0]["inlineData"]["data"])
            fn = f"{OUT}/{k}.wav"; w = wave.open(fn, "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(24000); w.writeframes(pcm); w.close()
            log({"key": k, "model": "google/gemini-3.8-flash-tts", "status": "succeeded", "file": fn, "secs": round(time.time() - t0, 1), "usage": r.get("usageMetadata")}); print("ok", k)
        except Exception: log({"key": k, "model": "gemini-3.8-flash-tts", "status": "failed", "error": str(r)[:400]}); print("FAIL", k, str(r)[:300])

def done(k, model, b, ext, t0):
    if isinstance(b, bytes) and len(b) > 1000:
        fn = f"{OUT}/{k}.{ext}"; open(fn, "wb").write(b); log({"key": k, "model": model, "status": "succeeded", "file": fn, "secs": round(time.time() - t0, 1)}); print("ok", k)
    else: log({"key": k, "model": model, "status": "failed", "error": str(b)[:400]}); print("FAIL", k, str(b)[:300])

def run_replicate(T):
    H = {"User-Agent": "rt-genmedia-bench", "Authorization": f"Bearer {T}", "Content-Type": "application/json", "Prefer": "wait=60"}
    s = seen()
    for m, sp in MEMOS.items():
        lang, desc = SPEAKERS[sp]; text = memo_text(m)
        jobs = {
          "qwen3-tts": ("qwen/qwen3-tts", {"mode": "voice_design", "text": text, "voice_description": desc, "language": {"en": "English", "de": "German"}[lang]}),
          "inworld-realtime-tts-2": ("inworld/realtime-tts-2", {"text": text, "voice_id": PRESETS["inworld-realtime-tts-2"][sp], "language": lang, "audio_format": "mp3"}),
          "minimax-speech-2.8-hd": ("minimax/speech-2.8-hd", {"text": text, "voice_id": PRESETS["minimax-speech-2.8-hd"][sp], "language_boost": {"en": "English", "de": "German"}[lang], "audio_format": "mp3"}),
        }
        for name, (model, inp) in jobs.items():
            k = f"{name}-{m}"
            if s.get(k, {}).get("status") == "succeeded": continue
            t0 = time.time(); pr = http(f"https://api.replicate.com/v1/models/{model}/predictions", {"input": inp}, H)
            while pr.get("status") in ("starting", "processing"):
                time.sleep(3); pr = http(f"https://api.replicate.com/v1/predictions/{pr['id']}", headers=H)
            o = pr.get("output"); url = (o[0] if isinstance(o, list) else o) if pr.get("status") == "succeeded" else None
            if isinstance(url, dict): url = url.get("audio") or next(iter(url.values()))
            b = urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "x"})).read() if url else pr.get("error") or pr
            done(k, model, b, (os.path.splitext(url.split("?")[0])[1][1:] if url else "mp3"), t0)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True); os.makedirs(os.path.dirname(LOG), exist_ok=True)
    which = sys.argv[1:] or ["eleven", "gemini", "replicate"]
    if "eleven" in which: run_eleven(key("ELEVENLABS_API_KEY"))
    if "gemini" in which: run_gemini(key("GEMINI_API_KEY"))
    if "gemini-directed" in which: run_gemini(key("GEMINI_API_KEY"), directed=True)
    if "replicate" in which: run_replicate(key("REPLICATE_API_TOKEN"))
    print("done")
