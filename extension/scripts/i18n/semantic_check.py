#!/usr/bin/env python3
"""Rank shipped translations by cross-lingual meaning similarity (report only).

Complements bad_translations.py, which only sees mechanical defects. NLLB's measured
failure mode is subtle word-sense errors that look fine on the surface; a multilingual
embedding model places a faithful translation close to its English source and a
wrong-sense one farther away, so the lowest-similarity pairs are the review queue.

No translation is performed: this embeds both strings with a local Ollama embedding
model (default ``bge-m3``, multilingual) and compares cosine similarity. It is NOT an
MT pipeline and writes nothing to the translation cache. Output is advisory (soft):
precision is UNMEASURED, so nothing here auto-deletes or gates CI.

  python semantic_check.py --locales de,ja --limit 200 --out D:\\tmp\\semantic_check.json
"""
from __future__ import annotations

import argparse
import json
import math
import sys
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))  # sibling imports work as script or module

from verify_locales import discover, flatten  # noqa: E402  (path tweak first)

OLLAMA_URL = "http://localhost:11434/api/embed"
DEFAULT_MODEL = "bge-m3"
BATCH = 32  # strings per request; keeps each HTTP body small on an 8 GB GPU


def cosine(a: list[float], b: list[float]) -> float:
    """Cosine similarity; 0.0 for a zero vector so a degenerate embedding sorts
    as maximally suspicious instead of raising ZeroDivisionError."""
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    if na == 0.0 or nb == 0.0:
        return 0.0
    return sum(x * y for x, y in zip(a, b)) / (na * nb)


def embed(texts: list[str], model: str) -> list[list[float]]:
    """Embed *texts* via the local Ollama server, batched. Raises on any failure
    (server down, model missing) -- a silent empty result would read as 'no
    suspicious translations' (the parser-silent-empty trap)."""
    vectors: list[list[float]] = []
    for i in range(0, len(texts), BATCH):
        body = json.dumps({"model": model, "input": texts[i:i + BATCH]}).encode()
        req = urllib.request.Request(OLLAMA_URL, body, {"Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        got = data.get("embeddings")
        if not got or len(got) != len(texts[i:i + BATCH]):
            raise RuntimeError(f"embed: unexpected response shape for batch at {i}")
        vectors.extend(got)
    return vectors


def collect_pairs(ext: Path, locales: set[str] | None) -> dict[str, list[tuple[str, str, str]]]:
    """{locale: [(key, english, translated)]} for prose strings that differ from
    English. Identical strings (brand, acronym) carry no signal and are skipped."""
    fams, all_locales = discover(ext)
    out: dict[str, list[tuple[str, str, str]]] = {}
    for fam, (src, pathfn) in fams.items():
        en = flatten(json.loads(src.read_text(encoding="utf-8")))
        for locale in all_locales:
            if locales and locale not in locales:
                continue
            p = pathfn(locale)
            if not p.is_file():
                continue
            loc = flatten(json.loads(p.read_text(encoding="utf-8")))
            for key, ev in en.items():
                lv = loc.get(key)
                if isinstance(ev, str) and isinstance(lv, str) and lv != ev and ev.strip():
                    out.setdefault(locale, []).append((f"{fam}:{key}", ev, lv))
    return out


def rank(pairs: list[tuple[str, str, str]], model: str, limit: int) -> list[dict]:
    """Lowest-similarity pairs first (most likely meaning drift)."""
    if not pairs:
        return []
    ev = embed([p[1] for p in pairs], model)
    lv = embed([p[2] for p in pairs], model)
    scored = [
        {"key": k, "en": e, "value": v, "similarity": round(cosine(a, b), 4)}
        for (k, e, v), a, b in zip(pairs, ev, lv)
    ]
    scored.sort(key=lambda r: r["similarity"])
    return scored[:limit]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--locales", default="", help="comma list; default all")
    ap.add_argument("--limit", type=int, default=100, help="lowest-similarity rows per locale")
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--out", default=r"D:\tmp\semantic_check.json")
    ap.add_argument("--ext", default=str(HERE.parent.parent))
    args = ap.parse_args(argv)

    wanted = {x.strip() for x in args.locales.split(",") if x.strip()} or None
    result: dict[str, list[dict]] = {}
    for locale, pairs in sorted(collect_pairs(Path(args.ext), wanted).items()):
        result[locale] = rank(pairs, args.model, args.limit)
        worst = result[locale][0]["similarity"] if result[locale] else None
        print(f"{locale}: {len(pairs)} pairs, lowest similarity {worst}")
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"review queue -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
