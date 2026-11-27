"""Guard for MT prompt leaks, looped words and overlong values (2026-11-27 audit).

Covers three things: the detector in bad_translations catches each failure class
and leaves correct text alone; the shipped catalogs carry none of them; and the
hand repairs in manual_translations_mt_leaks.py win over the MT cache.
"""

from __future__ import annotations

import os
import sys
import unittest
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import bad_translations as bt  # noqa: E402

ECHO_PREFIXES = ("prompt-leak", "loop:", "overlong:")


def echo_flags(en: str, loc: str, locale: str = "de") -> list[str]:
    """Only the reasons this guard adds, so unrelated heuristics cannot mask a miss."""
    return [r for s, r in bt.detect(en, loc, locale, []) if s == "hard" and r.startswith(ECHO_PREFIXES)]


class TestEchoDetectPositive(unittest.TestCase):
    """Each measured failure shape must be flagged."""

    def test_numbered_prompt_lines(self) -> None:
        loc = "Strenge Regeln:\n1. Geben Sie nur den übersetzten Text aus.\n2. Keine Erklärungen."
        self.assertIn("prompt-leak", echo_flags("Configure which rules run.", loc))

    def test_prompt_only_without_translation(self) -> None:
        # Several values kept only the first prompt line and no translation at all.
        self.assertIn("prompt-leak", echo_flags("Only ~200 error/warning rules run in-editor", "Règles strictes :\n1. Retournez UNIQUEMENT la sortie traduite.", "fr"))

    def test_inline_prompt_with_newlines_collapsed(self) -> None:
        loc = "Строгое правило: 1. Возвращайте ТОЛЬКО строку. 2. НЕ включайте объяснения. 3. Копируйте токены."
        self.assertIn("prompt-leak", echo_flags("Regex patterns that mean the document still reads as open work.", loc, "ru"))

    def test_looped_short_label(self) -> None:
        self.assertTrue(any(r.startswith("loop:") for r in echo_flags("Line", "Linea Linea Linea Linea", "it")))

    def test_looped_devanagari_label(self) -> None:
        # Vowel signs are not \w; without mark stripping this loop went unseen.
        self.assertTrue(any(r.startswith("loop:") for r in echo_flags("Message", "संदेश संदेश संदेश।", "hi")))

    def test_looped_clause(self) -> None:
        loc = "kwa hiyo ina kuzalishwa kwa kuzalishwa kwa kuzalishwa kwa kuzalishwa kwa"
        self.assertTrue(any(r.startswith("loop:") for r in echo_flags("so it can grow until the machine slows down", loc, "sw")))

    def test_overlong_long_source(self) -> None:
        en = "Routing and deep-link handling — auto_route, go_router."
        self.assertTrue(any(r.startswith("overlong:") for r in echo_flags(en, en + " " + "x" * 120)))


class TestEchoDetectNegative(unittest.TestCase):
    """Correct text must not be flagged; a false positive prunes good cache entries."""

    def test_numbered_list_in_english_is_excused(self) -> None:
        en = "Steps:\n1. Open the file.\n2. Save it."
        self.assertEqual(echo_flags(en, "Schritte:\n1. Datei öffnen.\n2. Speichern."), [])

    def test_version_numbers_are_not_a_list(self) -> None:
        self.assertEqual(echo_flags("Requires Dio 5.x and Bloc 8.x", "Erfordert Dio 5.x und Bloc 8.x"), [])

    def test_two_repeats_are_not_a_loop(self) -> None:
        self.assertEqual(echo_flags("No", "Nein, nein"), [])

    def test_hyphen_reduplication_is_not_a_loop(self) -> None:
        # Indonesian plural by reduplication is grammatical, not an MT loop.
        self.assertEqual(echo_flags("Functions", "Fungsi-fungsi", "id"), [])

    def test_long_but_legitimate_translation(self) -> None:
        en = "Saropa Lints: could not create baseline. {details}"
        loc = "Saropa Lints: Es konnte keine Baseline erstellt werden, weil ein Fehler auftrat. {details}"
        self.assertEqual(echo_flags(en, loc), [])


class TestShippedCatalogs(unittest.TestCase):
    """Audit gate: no shipped locale value may carry a leak, loop or overlong flag."""

    def test_no_echo_flags_ship(self) -> None:
        ext = Path(__file__).resolve().parents[3]
        found = bt.scan_shipped(ext)
        bad = [
            f"{loc} {it['key']} {it['reason']}"
            for loc, items in found.items()
            for it in items
            if it["reason"].startswith(ECHO_PREFIXES)
        ]
        self.assertEqual(bad, [], f"{len(bad)} value(s), first: {bad[:5]}")


class TestLeakRepairsWin(unittest.TestCase):
    """The repairs must reach the generator ahead of the MT cache, and be clean."""

    def test_repairs_are_in_the_dictionary(self) -> None:
        from dictionaries import TRANSLATIONS
        from manual_translations_mt_leaks import LEAK_REPAIRS

        # The base table wins over _REPAIRS via setdefault; a mismatch here means the
        # repair would be silently dropped by the next generation run.
        lost = [
            (loc, src[:40])
            for loc, entries in LEAK_REPAIRS.items()
            for src, value in entries.items()
            if TRANSLATIONS.get(loc, {}).get(src) != value
        ]
        self.assertEqual(lost, [])

    def test_dictionary_beats_a_bad_cache_entry(self) -> None:
        import mt_fallback as mt
        from manual_translations_mt_leaks import LEAK_REPAIRS
        from translator import HybridTranslator

        bad = "Linea Linea Linea Linea"
        cache = {mt._cache_key("it", "Line", engine): bad for engine in ("qwen", "nllb", "google")}
        out = HybridTranslator("it", cache, cache_only=True).translate_text("Line")
        self.assertEqual(out, LEAK_REPAIRS["it"]["Line"])

    def test_repairs_trip_no_hard_flag(self) -> None:
        from manual_translations_mt_leaks import LEAK_REPAIRS

        # Also proves each repair kept its placeholders, code spans and links.
        flagged = [
            (loc, src[:40], [r for s, r in bt.detect(src, value, loc, []) if s == "hard"])
            for loc, entries in LEAK_REPAIRS.items()
            for src, value in entries.items()
            if any(s == "hard" for s, _ in bt.detect(src, value, loc, []))
        ]
        self.assertEqual(flagged, [])


if __name__ == "__main__":
    unittest.main()
