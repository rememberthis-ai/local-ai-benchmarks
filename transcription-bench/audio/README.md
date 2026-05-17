# Reference audio for the transcription bench

These clips are committed via git-lfs so the same exact bytes can be used on any machine running the bench — making the cross-arch numbers (Intel vs Apple Silicon) directly comparable instead of "well, his recording was probably different from mine."

## `holmes_clip60.wav` — canonical 60 s clean-speech reference

- **Source**: LibriVox recording of *The Adventures of Sherlock Holmes* by Arthur Conan Doyle, chapter 1 ("A Scandal in Bohemia"), narrator Ralph Snelson. Public domain.
- **Archive.org item**: <https://archive.org/details/adventures_holmes>
- **Original file**: `adventureholmes_01_doyle_64kb.mp3` (64 kbps mono mp3, 65 min total).
- **Clip**: first 60 s, resampled to 16 kHz mono PCM WAV (whisper's native input format).
- **Speech profile**: single narrator, audiobook-typical pace, clean studio recording, mid-Atlantic English.

This is the clip the May 2026 blog post's Audio Transcription numbers use. If you run `sona_bench.sh` without overriding `CLIP`, this is what it picks up.

## Reproducing the clip from scratch

If you don't want to pull it through LFS (or want to verify it):

```bash
curl -sLo /tmp/holmes_ch1.mp3 \
  https://archive.org/download/adventures_holmes/adventureholmes_01_doyle_64kb.mp3
ffmpeg -y -i /tmp/holmes_ch1.mp3 -ss 0 -t 60 -ar 16000 -ac 1 holmes_clip60.wav
```

Output should be exactly 1,920,186 bytes — the WAV header carries no timestamp, so the file is byte-identical across machines as long as you use the same ffmpeg pipeline. Sanity-check with `shasum holmes_clip60.wav`.

## License

LibriVox recordings are released into the public domain ([catalog statement](https://librivox.org/pages/public-domain/)). No attribution required, but: credit narrator Ralph Snelson if you publish derived results, because it's nice.
