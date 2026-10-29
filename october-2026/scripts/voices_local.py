#!/usr/bin/env python3
"""Local half of voices.py: the same three memos through mlx-audio 0.6.1 on the M1 Max
(venv ~/Dev/ext/genmedia/mlx-audio-venv). Qwen3-TTS 1.7B VoiceDesign gets the SPEAKERS descriptions; Chatterbox
multilingual then clones each speaker FROM that Qwen output (design once, reuse: the way a voice stays the same
across 20 memos); Voxtral 4B and Kokoro use presets (Voxtral has one German male voice, Kokoro has no German)."""
import json, os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from voices import SPEAKERS, MEMOS, memo_text, OUT, LOG, log, seen
CLI = os.path.expanduser("~/Dev/ext/genmedia/mlx-audio-venv/bin/mlx_audio.tts.generate")
LANG = {"en": "English", "de": "German"}
def gen(key, args):
    if seen().get(key, {}).get("status") == "succeeded": return
    t0 = time.time()
    r = subprocess.run([CLI, *args, "--output_path", OUT, "--file_prefix", key, "--audio_format", "wav", "--join_audio"], capture_output=True, text=True)
    files = sorted(f for f in os.listdir(OUT) if f.startswith(key) and f.endswith(".wav"))
    if r.returncode == 0 and files:
        fn = f"{OUT}/{key}.wav"
        if files[0] != f"{key}.wav": os.replace(f"{OUT}/{files[0]}", fn)
        log({"key": key, "model": args[1], "provider": "local", "status": "succeeded", "file": fn, "secs": round(time.time() - t0, 1)}); print("ok", key, round(time.time() - t0), "s", flush=True)
    else:
        err = "\n".join(l for l in (r.stderr + r.stdout).replace("\r", "\n").splitlines() if "Fetching" not in l and "%|" not in l)  # progress bars hid the error
        log({"key": key, "model": args[1], "provider": "local", "status": "failed", "error": err[-400:]}); print("FAIL", key, err[-300:], flush=True)
os.makedirs(OUT, exist_ok=True)
for m, sp in MEMOS.items():
    lang, desc = SPEAKERS[sp]
    gen(f"local-qwen3-tts-voicedesign-{m}", ["--model", "mlx-community/Qwen3-TTS-12Hz-1.7B-VoiceDesign-bf16", "--text", memo_text(m), "--instruct", desc, "--lang_code", LANG[lang]])
for m, sp in MEMOS.items():
    lang = SPEAKERS[sp][0]; ref = f"{OUT}/local-qwen3-tts-voicedesign-{m}.wav"
    if os.path.exists(ref):
        gen(f"local-chatterbox-ml-{m}", ["--model", "mlx-community/chatterbox-multilingual-v3", "--text", memo_text(m), "--ref_audio", ref, "--ref_text", memo_text(m), "--lang_code", lang])
for m, sp in MEMOS.items():
    lang = SPEAKERS[sp][0]
    gen(f"local-voxtral-4b-{m}", ["--model", "mlx-community/Voxtral-4B-TTS-2603-mlx-bf16", "--text", memo_text(m), "--voice", "neutral_male" if lang == "en" else "de_male"])
gen("local-kokoro-en-climbing-trip", ["--model", "mlx-community/Kokoro-82M-bf16", "--text", memo_text("en-climbing-trip"), "--voice", "bm_lewis", "--lang_code", "b"])
# Ming-3.0 (top open-weight speech model on Artificial Analysis, 26 Oct): voice design from the same descriptions.
for m, sp in MEMOS.items():
    lang, desc = SPEAKERS[sp]
    gen(f"local-ming-3.0-tts-{m}", ["--model", "mlx-community/Ming-3.0-tts-0.5B-8bit", "--text", memo_text(m), "--instruct", desc, "--use_zero_spk_emb", "--lang_code", lang])
# Fish Audio Drama 3 takes no description, only a reference voice: cloned from the Qwen design like Chatterbox.
for m, sp in MEMOS.items():
    ref = f"{OUT}/local-qwen3-tts-voicedesign-{m}.wav"
    if os.path.exists(ref):
        gen(f"local-fish-drama-3-{m}", ["--model", "mlx-community/fish-audio-drama-3-4bit", "--text", memo_text(m), "--ref_audio", ref, "--ref_text", memo_text(m)])
print("done")
