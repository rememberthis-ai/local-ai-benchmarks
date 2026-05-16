#!/usr/bin/env python3
"""Map ollama model tags (e.g. 'llama3.2:1b') to their on-disk GGUF blob path.

Reads ~/.ollama/models/manifests/registry.ollama.ai/library/<name>/<ver> and
prints: "<tag>\\t<blob-path>\\t<size>\\t<unit>" per requested tag.

Usage:
    python3 ollama-blob-resolver.py llama3.2:1b moondream:1.8b
"""
import json
import pathlib
import sys

MANIFESTS = pathlib.Path.home() / ".ollama/models/manifests/registry.ollama.ai/library"
BLOBS = pathlib.Path.home() / ".ollama/models/blobs"


def resolve(tag: str) -> tuple[pathlib.Path, float] | None:
    name, ver = tag.split(":", 1)
    manifest_path = MANIFESTS / name / ver
    if not manifest_path.exists():
        return None
    m = json.loads(manifest_path.read_text())
    for layer in m.get("layers", []):
        if layer.get("mediaType") == "application/vnd.ollama.image.model":
            digest = layer["digest"].replace("sha256:", "sha256-")
            return BLOBS / digest, layer["size"] / 1024**3
    return None


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: ollama-blob-resolver.py <tag>...", file=sys.stderr)
        return 2
    rc = 0
    for tag in sys.argv[1:]:
        try:
            r = resolve(tag)
        except ValueError:
            print(f"{tag}\tERR\tinvalid tag", file=sys.stderr)
            rc = 1
            continue
        if r is None:
            print(f"{tag}\tERR\tnot installed", file=sys.stderr)
            rc = 1
            continue
        blob, size_gb = r
        print(f"{tag}\t{blob}\t{size_gb:.2f}\tGB")
    return rc


if __name__ == "__main__":
    sys.exit(main())
