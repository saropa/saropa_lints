"""Hand-written repairs that follow the 2026-11-27 translation audit.

Three classes, all in followup_repairs.json ({locale: {English source: value}}):
product names ("Code Health", "Package Vibrancy") that had been translated,
Arabic letter forms in ur values, and translated codicon tokens such as
"$(warning)". Written by an agent without any MT engine; no native-speaker
review. manual_translations_gaps.py folds them into _REPAIRS, so they win over
the MT cache (curated dictionaries.TRANSLATIONS still wins, as for every repair).
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Dict

REPAIRS_PATH = Path(__file__).resolve().parent / "followup_repairs.json"


def load() -> Dict[str, Dict[str, str]]:
    """Return locale -> {English source: hand translation}.

    A missing or malformed file raises: silently dropping these repairs would let
    the next regeneration restore the defective machine translations.
    """
    return json.loads(REPAIRS_PATH.read_text(encoding="utf-8"))
