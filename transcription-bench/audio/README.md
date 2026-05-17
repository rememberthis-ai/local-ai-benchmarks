# Reference audio for the transcription bench

These clips are committed via git-lfs so the same exact bytes can be used on any machine running the bench — making the cross-arch numbers (Intel vs Apple Silicon) directly comparable instead of "well, his recording was probably different from mine."

## `holmes_clip60.wav` — clean studio narration

- **Source**: LibriVox recording of *The Adventures of Sherlock Holmes* by Arthur Conan Doyle, chapter 1 ("A Scandal in Bohemia"), narrator Ralph Snelson. Public domain.
- **Archive.org item**: <https://archive.org/details/adventures_holmes>
- **Original file**: `adventureholmes_01_doyle_64kb.mp3` (64 kbps mono mp3, 65 min total).
- **Clip**: first 60 s, resampled to 16 kHz mono PCM WAV (whisper's native input format).
- **Speech profile**: single narrator, audiobook-typical pace, clean studio recording, mid-Atlantic English.
- **SHA-1**: `b481bd16bdba47d09eaf147f76cc3d1253d7bf8c`

This is the clip `sona_bench.sh` and `sona_bench_extended.sh` use by default. Use it for the cross-arch (Intel vs Apple Silicon) comparison.

### Reproducing from scratch

```bash
curl -sLo /tmp/holmes_ch1.mp3 \
  https://archive.org/download/adventures_holmes/adventureholmes_01_doyle_64kb.mp3
ffmpeg -y -i /tmp/holmes_ch1.mp3 -ss 0 -t 60 -ar 16000 -ac 1 holmes_clip60.wav
```

Output should be exactly 1,920,186 bytes — the WAV header carries no timestamp, so the file is byte-identical across machines as long as you use the same ffmpeg pipeline. Sanity-check with `shasum holmes_clip60.wav`.

## `fdr_clip60.wav` — voice-memo-like regime (slow, conversational, pauses)

- **Source**: Franklin Delano Roosevelt's *Fireside Chat #14, "On the European War"*, September 3, 1939. Public domain (US federal government work, pre-1972 fixation).
- **Archive.org item**: <https://archive.org/details/1September31939FiresideChat14OnTheEuropeanWarFDR>
- **Original file**: 11-min mp3 at 134 kbps mono, sourced from the National Archives.
- **Clip**: 60 s starting at offset 60 s (skipping the announcer intro), resampled to 16 kHz mono PCM WAV.
- **Speech profile**: single speaker, slow conversational radio pace with natural pauses, 1939 broadcast recording quality (warmer, less crisp than studio audiobook). Closer to a personal voice memo's rhythm than `holmes_clip60.wav`.
- **SHA-1**: `1f4da908c54e46cc1f6aebf51a482d274ceffbb2`

This is the regime-control clip — same machine, same clean conditions, different audio shape. Used to test whether the CPU-vs-Metal result is genuinely audio-dependent or simply contamination-of-old-runs.

### Reproducing from scratch

```bash
curl -sLo /tmp/fdr.mp3 \
  "https://archive.org/download/1September31939FiresideChat14OnTheEuropeanWarFDR/%5B1%5DSeptember%203%2C%201939%20Fireside%20Chat%2014%20On%20the%20European%20War-%20FDR.mp3"
ffmpeg -y -i /tmp/fdr.mp3 -ss 60 -t 60 -ar 16000 -ac 1 fdr_clip60.wav
```

Output should be exactly 1,920,078 bytes (note: 108 bytes smaller than the Holmes clip due to header alignment, harmless).

## License

- LibriVox recordings are public domain ([catalog statement](https://librivox.org/pages/public-domain/)). No attribution required, but credit narrator Ralph Snelson if you publish derived results.
- US federal government works (FDR addresses) are public domain by statute (17 U.S.C. § 105). The Archive.org host carries the file from the National Archives.
