"""Build a single-page HTML viewer pairing each photo with all candidate captions."""
import base64
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).parent
PHOTO_CACHE = ROOT / ".photo-cache"
RESULTS = ROOT / "results"
OUT = RESULTS / "comparison.html"


def parse_md(path: pathlib.Path) -> dict:
    """Return {photo_id: (gen_seconds, caption_text)}."""
    if not path.exists():
        return {}
    text = path.read_text()
    out = {}
    for block in re.split(r"\n## ", text)[1:]:
        m = re.match(r"(\S+)\s+\(([^)]+)\)\s*\n", block)
        if not m:
            continue
        pid = m.group(1)
        cand = re.search(
            r"\*\*Candidate \([^)]+, ([\d.]+)s\):\*\*\s*\n\s*>\s*(.+?)(?=\n---|\Z)",
            block,
            re.DOTALL,
        )
        if cand:
            out[pid] = (float(cand.group(1)), cand.group(2).strip())
    return out


def main():
    photoset = json.loads((ROOT / "photo_set_phase2.json").read_text())
    candidates = [
        ("MiniCPM-V 4.5 (baseline)", None),  # baseline read from photoset
        (
            "FastVLM-0.5B-bf16 (SwiftLM)",
            RESULTS / "2026-05-08-swiftlm-mlx-community-fastvlm-0-5b-bf16.md",
        ),
        (
            "SmolVLM2-2.2B-Instruct (SwiftLM)",
            RESULTS / "2026-05-08-swiftlm-mlx-community-smolvlm2-2-2b-instruct-mlx.md",
        ),
        (
            "Qwen2.5-VL-7B-4bit (SwiftLM)",
            RESULTS / "2026-05-08-swiftlm-mlx-community-qwen2-5-vl-7b-instruct-4bit.md",
        ),
        (
            "Qwen3-VL-8B-4bit (SwiftLM)",
            RESULTS
            / "2026-05-08-swiftlm-lmstudio-community-qwen3-vl-8b-instruct-mlx-4bit.md",
        ),
        (
            "Gemma-4-26B-A4B-it-4bit (SwiftLM) ⭐",
            RESULTS / "2026-05-08-swiftlm-mlx-community-gemma-4-26b-a4b-it-4bit.md",
        ),
        (
            "MiniCPM-O 4.5 think-ON (fork)",
            RESULTS / "2026-05-08-fork-openbmb-minicpm-o4-5-latest-think-on.md",
        ),
        (
            "MiniCPM-O 4.5 /no_think (fork)",
            RESULTS / "2026-05-08-fork-openbmb-minicpm-o4-5-latest-think-off.md",
        ),
    ]
    parsed = {label: parse_md(p) if p else {} for label, p in candidates}

    parts = [
        "<!doctype html>",
        '<html lang="en"><head><meta charset="utf-8">',
        "<title>Captioning A/B — 25 photos</title>",
        "<style>",
        "body { font: 14px -apple-system, system-ui, sans-serif; margin: 0; padding: 24px; max-width: 1400px; background: #f7f7f8; }",
        "h1 { margin-top: 0; }",
        "header.summary { background: #fff; padding: 16px 20px; border-radius: 8px; margin-bottom: 24px; box-shadow: 0 1px 3px rgba(0,0,0,.05); }",
        ".photo { background: #fff; border-radius: 8px; padding: 20px; margin-bottom: 28px; box-shadow: 0 1px 3px rgba(0,0,0,.05); display: grid; grid-template-columns: 320px 1fr; gap: 24px; }",
        ".photo h2 { margin-top: 0; font-size: 16px; }",
        ".photo .meta { color: #666; font-size: 12px; margin-bottom: 8px; }",
        "img { max-width: 320px; max-height: 400px; border-radius: 6px; display: block; }",
        ".cand { margin-bottom: 14px; padding: 10px 14px; background: #fafafa; border-left: 3px solid #ddd; border-radius: 4px; }",
        ".cand .label { font-weight: 600; font-size: 12px; color: #444; margin-bottom: 4px; display: flex; justify-content: space-between; }",
        ".cand .time { color: #888; font-weight: 400; font-size: 11px; }",
        ".cand .caption { white-space: pre-wrap; line-height: 1.45; color: #222; }",
        ".cand.baseline { border-left-color: #888; background: #f0f0f0; }",
        ".cand.gemma4 { border-left-color: #7c3aed; background: #f3eeff; }",
        ".cand.qwen3vl { border-left-color: #2563eb; background: #eef4ff; }",
        ".cand.qwen25vl { border-left-color: #0ea5e9; background: #eff8fe; }",
        ".cand.fastvlm { border-left-color: #16a34a; background: #effbf2; }",
        ".cand.smolvlm { border-left-color: #14b8a6; background: #ecfffd; }",
        ".cand.fork-on { border-left-color: #dc2626; background: #fff0f0; }",
        ".cand.fork-off { border-left-color: #f97316; background: #fff5ed; }",
        "details summary { cursor: pointer; user-select: none; font-size: 12px; color: #888; }",
        "</style></head><body>",
        "<h1>Captioning A/B — 25-photo bench (2026-05-08)</h1>",
        '<header class="summary">',
        "<p><strong>Speed</strong>: FastVLM 5.5s · v4.5 ~10s · <strong>Gemma-4-26B-A4B 16s</strong> · Qwen2.5-VL 16s · Qwen3-VL 22s · SmolVLM2 24s · fork o4.5 37–41s</p>",
        "<p><strong>Quality verdict</strong>: <strong>Gemma 4 26B-A4B is the new winner</strong> — best OCR (Swedish + Finnish verbatim WITH English translations), correct setting context, same speed as 7B-class models thanks to MoE. Qwen3-VL strong runner-up. v4.5 still solid baseline. fork o4.5 too slow + unreliable. See <a href=\"SUMMARY.md\">SUMMARY.md</a> for full analysis.</p>",
        "</header>",
    ]

    cls = {
        "MiniCPM-V 4.5 (baseline)": "baseline",
        "FastVLM-0.5B-bf16 (SwiftLM)": "fastvlm",
        "SmolVLM2-2.2B-Instruct (SwiftLM)": "smolvlm",
        "Qwen2.5-VL-7B-4bit (SwiftLM)": "qwen25vl",
        "Qwen3-VL-8B-4bit (SwiftLM)": "qwen3vl",
        "Gemma-4-26B-A4B-it-4bit (SwiftLM) ⭐": "gemma4",
        "MiniCPM-O 4.5 think-ON (fork)": "fork-on",
        "MiniCPM-O 4.5 /no_think (fork)": "fork-off",
    }

    for p in photoset["photos"]:
        uuid = p["photo_uuid"]
        img_path = PHOTO_CACHE / f"{uuid}.jpg"
        b64 = base64.b64encode(img_path.read_bytes()).decode() if img_path.exists() else ""
        img_tag = (
            f'<img src="data:image/jpeg;base64,{b64}" alt="{p["id"]}">'
            if b64
            else "<i>(image not cached)</i>"
        )
        parts.append('<div class="photo">')
        parts.append(f'<div>{img_tag}<div class="meta">{p["id"]} · {p["expected_focus"]}<br>{uuid}</div></div>')
        parts.append("<div>")
        # baseline first
        parts.append(f'<div class="cand baseline">'
                     f'<div class="label"><span>MiniCPM-V 4.5 (baseline, in registry)</span></div>'
                     f'<div class="caption">{p["v45_caption"]}</div></div>')
        for label, _ in candidates[1:]:
            row = parsed.get(label, {}).get(p["id"])
            if not row:
                continue
            t, txt = row
            parts.append(
                f'<div class="cand {cls[label]}">'
                f'<div class="label"><span>{label}</span><span class="time">{t:.1f}s</span></div>'
                f'<div class="caption">{txt}</div></div>'
            )
        parts.append("</div></div>")  # /photo

    parts.append("</body></html>")
    OUT.write_text("\n".join(parts))
    print(f"wrote {OUT}  ({OUT.stat().st_size//1024} KB)")


if __name__ == "__main__":
    main()
