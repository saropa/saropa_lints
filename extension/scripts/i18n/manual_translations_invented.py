"""Hand-written replacements for machine translations that invented text or
garbled short labels.

Found by the 2026-11-27 audit: NLLB inserted sentences that are not in the English
("Saropa Lints: là người có thể ...", "Es el nombre de la persona ...",
"{features} É um termo usado para descrever a") and turned short labels into
nonsense ("El mensaje es el mensaje." for "Message", "Línea Linea La línea" for
"Line"). Each entry was written by hand from the English source, keeping
{placeholders}, code spans, link targets, markdown and the brand "Saropa" exactly.
No MT engine or LLM translation tool produced any value. Unverified by native
speakers.

The data is too large for a Python literal, so it lives in one JSON file per
locale under invented_repairs/ ({English source: translation}). load() returns
locale -> entries; manual_translations_gaps.py folds them into _REPAIRS, so they
win over GAPS and the MT cache (curated dictionaries.TRANSLATIONS still wins, as
for every _REPAIRS entry).
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Dict

# One file per locale keeps each diff reviewable and lets a locale be repaired
# (and committed) on its own.
REPAIRS_DIR = Path(__file__).resolve().parent / "invented_repairs"


def load() -> Dict[str, Dict[str, str]]:
    """Return locale -> {English source: hand translation} from invented_repairs/.

    A missing directory yields {} so the generator still runs on a partial
    checkout; a malformed file raises, because silently dropping repairs would
    let the MT cache's invented text ship again.
    """
    out: Dict[str, Dict[str, str]] = {}
    if not REPAIRS_DIR.is_dir():
        return out
    for path in sorted(REPAIRS_DIR.glob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        # Every value must be a string: a nested object here is a format error.
        if not all(isinstance(v, str) for v in data.values()):
            raise ValueError(f"{path.name}: every repair value must be a string")
        out[path.stem] = data
    return out
