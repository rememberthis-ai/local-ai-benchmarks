#!/usr/bin/env python3
"""Checks every voice memo in out/voices-<date>/ by ear's stand-in: transcribe it with My Transcriber's whisper
(large-v3-turbo, --text-only so nothing is imported into the library) and compute the word error rate against the
script it was read from. A dropped sentence, an invented word or the wrong language shows up here, not by listening.
Writes results/voices-<date>/check.jsonl (one line per file, rerun-safe: files already checked are skipped)."""
import json, os, re, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from voices import MEMOS, memo_text, OUT, HERE, DATE
CLI = "/Applications/My Transcriber.app/Contents/MacOS/mytranscriber-daemon"
CHECK = f"{HERE}/results/voices-{DATE}/check.jsonl"

# Whisper writes numbers as digits and the scripts spell them out; that is not a reading error.
NUMBERS = {"sixty": "60", "zwölf": "12"}
def words(t):
    t = re.sub(r"^\s*transcription:\s*", "", t.lower()).replace("ß", "ss")  # the CLI's own label
    return [NUMBERS.get(w, w) for w in re.findall(r"[a-z0-9äöüéèàç']+", t)]
def wer(ref, hyp):
    r, h = words(ref), words(hyp)
    d = list(range(len(h) + 1))
    for i in range(1, len(r) + 1):
        p, d[0] = d[0], i
        for j in range(1, len(h) + 1):
            p, d[j] = d[j], min(d[j] + 1, d[j - 1] + 1, p + (r[i - 1] != h[j - 1]))
    return d[len(h)] / max(1, len(r))
def duration(f):
    out = subprocess.run(["afinfo", f], capture_output=True, text=True).stdout
    m = re.search(r"estimated duration: ([\d.]+)", out)
    return round(float(m.group(1)), 1) if m else None

done = set()
if os.path.exists(CHECK):
    done = {json.loads(l)["file"] for l in open(CHECK)}
for f in sorted(os.listdir(OUT)):
    memo = next((m for m in MEMOS if f.rsplit(".", 1)[0].endswith(m)), None)
    if not memo or f in done or not f.endswith((".wav", ".mp3")): continue
    lang = memo.split("-")[0]
    r = subprocess.run([CLI, "transcribe", "--text-only", "-l", lang, f"{OUT}/{f}"], capture_output=True, text=True)
    hyp = r.stdout.strip()
    rec = {"file": f, "model": f[: -len(memo) - 1 - len(f.rsplit(".", 1)[1]) - 1].rstrip("-"), "memo": memo,
           "secs": duration(f"{OUT}/{f}"), "wer": round(wer(memo_text(memo), hyp), 3) if hyp else None,
           "transcript": hyp or (r.stderr or "")[-300:]}
    with open(CHECK, "a") as fh: fh.write(json.dumps(rec, ensure_ascii=False) + "\n")
    print(f"{rec['wer']}\t{rec['secs']}s\t{f}", flush=True)
# Rescore every line from its stored transcript, so a change to the normalisation needs no new transcription.
recs = [json.loads(l) for l in open(CHECK)]
for r in recs:
    if r["transcript"] and not r["transcript"].startswith(("Error", "error")): r["wer"] = round(wer(memo_text(r["memo"]), r["transcript"]), 3)
t = CHECK + ".tmp"
with open(t, "w") as fh: fh.writelines(json.dumps(r, ensure_ascii=False) + "\n" for r in recs)
os.replace(t, CHECK)
