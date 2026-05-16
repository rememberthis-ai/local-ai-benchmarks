"""
Build a long-context Dreamer-style prompt from real registry data.
Concatenates recent voice-memo transcripts and photo captions, ends with a
synthesis question. Writes prompt.txt and reports approximate token count
(rough char/3.5 estimate for English; multi-language drives this up so the
real count tends to be a bit higher).

Usage:
  python3 build_dreamer_prompt.py --target-tokens 80000
"""
import argparse
import datetime
import json
import pathlib
import re
import sqlite3

ROOT = pathlib.Path(__file__).parent
DB = pathlib.Path.home() / "Library/Caches/ai.rememberthis/registry_index.sqlite"
OUT = ROOT / "dreamer_prompt.txt"


def tokens_estimate(s: str) -> int:
    return max(1, len(s) // 4)  # rough — Swedish/Finnish bias raises char-per-token


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--target-tokens", type=int, default=80_000)
    ap.add_argument("--min-voice-tlen", type=int, default=2000, help="min transcription length in chars")
    args = ap.parse_args()

    conn = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    conn.row_factory = sqlite3.Row

    # Pull voice memos with rich transcripts, oldest-first within last year so
    # we get genuine variety (not just last week)
    voice = conn.execute(
        """
        SELECT file_path, captured_at, transcription, voice_source, length(transcription) AS tlen
        FROM registry_items
        WHERE item_type = 'voice_memo'
          AND status = 'done'
          AND length(coalesce(transcription, '')) >= ?
          AND captured_at >= strftime('%s','now','-365 days')
        ORDER BY captured_at DESC
        """,
        (args.min_voice_tlen,),
    ).fetchall()

    # Pull recent photo captions (sample broadly)
    photos = conn.execute(
        """
        SELECT file_path, captured_at, caption, locality, country, people, latitude, longitude
        FROM registry_items
        WHERE item_type = 'photo'
          AND status = 'done'
          AND length(coalesce(caption, '')) >= 80
          AND captured_at >= strftime('%s','now','-180 days')
        ORDER BY captured_at DESC
        LIMIT 200
        """
    ).fetchall()

    # Build narrative: photos first (smaller), voice second (filler to target)
    parts = []
    parts.append(
        "You are an assistant helping the user reflect on their own life data. "
        "Below is a chronological sample of their recent voice memos and photo "
        "captions across the last several months. Read all of it, then answer "
        "the question at the end. Be specific — cite particular days, places, "
        "and observations from the source material; do not generalize.\n\n"
    )
    parts.append("=" * 72 + "\n")
    parts.append("PHOTOS\n")
    parts.append("=" * 72 + "\n\n")
    photo_count = 0
    for p in photos:
        when = datetime.datetime.utcfromtimestamp(p["captured_at"]).isoformat(sep=" ", timespec="minutes")
        loc = p["locality"] or p["country"] or ""
        people = p["people"] or ""
        head = f"[{when}] " + (f"{loc} · " if loc else "") + (f"with {people} · " if people else "")
        cap = re.sub(r"\s+", " ", p["caption"]).strip()
        parts.append(head + cap + "\n\n")
        photo_count += 1

    parts.append("\n" + "=" * 72 + "\n")
    parts.append("VOICE MEMOS\n")
    parts.append("=" * 72 + "\n\n")
    voice_count = 0
    current_tokens = sum(tokens_estimate(p) for p in parts)
    for v in voice:
        if current_tokens >= args.target_tokens - 1500:
            break
        when = datetime.datetime.utcfromtimestamp(v["captured_at"]).isoformat(sep=" ", timespec="minutes")
        head = f"[{when}] {v['voice_source']}\n"
        body = v["transcription"].strip()
        chunk = head + body + "\n\n"
        chunk_tok = tokens_estimate(chunk)
        if current_tokens + chunk_tok > args.target_tokens - 500:
            # truncate this entry to fit
            remaining_chars = (args.target_tokens - 500 - current_tokens) * 4
            chunk = head + body[:remaining_chars] + "\n…[truncated]…\n\n"
            chunk_tok = tokens_estimate(chunk)
        parts.append(chunk)
        current_tokens += chunk_tok
        voice_count += 1

    # Synthesis question
    parts.append("\n" + "=" * 72 + "\n")
    parts.append("QUESTION\n")
    parts.append("=" * 72 + "\n\n")
    parts.append(
        "Based on everything above:\n\n"
        "1. Identify three recurring themes that show up across the voice "
        "memos and photos. Quote at least one specific moment that "
        "illustrates each theme.\n"
        "2. Name a person mentioned in the voice memos who also appears in "
        "the photo captions, and describe the relationship visible across "
        "both data sources.\n"
        "3. Pick one place (city or location) that appears in both sources "
        "and summarize what activities the user did there.\n"
        "4. Identify one tension or unresolved question that recurs across "
        "the recordings — something the user is wrestling with.\n"
        "5. Conclude with one observation about how the user's days are "
        "structured, drawing on patterns visible in the timestamps.\n"
    )

    prompt = "".join(parts)
    OUT.write_text(prompt)

    print(f"prompt: {OUT}")
    print(f"  bytes: {len(prompt):,}")
    print(f"  rough tokens (chars/4): {tokens_estimate(prompt):,}")
    print(f"  photos included: {photo_count}")
    print(f"  voice memos included: {voice_count}")


if __name__ == "__main__":
    main()
