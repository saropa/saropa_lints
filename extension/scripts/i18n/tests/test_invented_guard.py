"""Guard for NLLB-invented sentences and spaceless CJK label loops (2026-11-27 audit).

Covers: the invented-phrase list (invented_phrases.json) flags each measured shape
and honors its English excuse; the CJK loop check flags "メニューメニューメヌー"
but not ordinary katakana or Thai doubling; the shipped catalogs carry neither;
and the hand repairs in invented_repairs/ reach the generator and are clean.
"""

from __future__ import annotations

import os
import sys
import unittest
from pathlib import Path

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import bad_translations as bt  # noqa: E402

PREFIXES = ("invented:", "loop:")


def flags(en: str, loc: str, locale: str) -> list[str]:
    """Only this guard's reasons, so unrelated heuristics cannot mask a miss."""
    return [r for s, r in bt.detect(en, loc, locale, []) if s == "hard" and r.startswith(PREFIXES)]


class TestInventedPositive(unittest.TestCase):
    """Measured inventions must be flagged."""

    def test_vi_after_brand_prefix(self) -> None:
        loc = "Saropa Lints: là người có thể sao chép JSON."
        self.assertTrue(flags("Saropa Lints: copied related rule telemetry JSON.", loc, "vi"))

    def test_es_invented_sentence(self) -> None:
        loc = "Saropa Lints: Es el nombre de la persona que tiene más probabilidades de exportar."
        self.assertTrue(flags("Saropa Lints: Export OWASP Compliance Report", loc, "es"))

    def test_pt_tail_after_placeholder(self) -> None:
        loc = "Características não utilizadas: {features} É um termo usado para descrever a"
        self.assertTrue(flags("Unused features: {features}", loc, "pt"))

    def test_cjk_katakana_loop(self) -> None:
        self.assertTrue(flags("Internal", "メニューメニューメヌー", "ja"))

    def test_cjk_han_loop(self) -> None:
        self.assertTrue(flags("Version", "版本版本版本的版本", "zh"))


class TestInventedNegative(unittest.TestCase):
    """Legitimate text must pass."""

    def test_excused_when_english_says_it(self) -> None:
        # The phrase is only an invention when the English is not about a person.
        loc = "Es el nombre de la persona que tiene el paquete."
        self.assertEqual(flags("This is the name of the person who owns the package.", loc, "es"), [])

    def test_phrase_list_is_per_locale(self) -> None:
        self.assertEqual(flags("Cells", "tế bào", "fr"), [])

    def test_katakana_word_boundary_is_not_a_loop(self) -> None:
        self.assertEqual(flags("Sign-in providers", "サインインプロバイダー", "ja"), [])

    def test_thai_doubling_is_not_checked(self) -> None:
        self.assertEqual(flags("Flags it anywhere it appears", "ทุกที่ที่ปรากฏ", "th"), [])

    def test_every_excuse_compiles(self) -> None:
        # A bad regex would raise inside detect() during a generation run.
        table = bt.load_invented_phrases(bt.INVENTED_PHRASES_PATH)
        self.assertGreater(sum(len(v) for v in table.values()), 0)


class TestShippedAndRepairs(unittest.TestCase):
    """No shipped value may carry these flags; the repairs must win and be clean."""

    def test_no_invented_or_cjk_loop_ships(self) -> None:
        ext = Path(__file__).resolve().parents[3]
        bad = [
            f"{loc} {it['key']} {it['reason']}"
            for loc, items in bt.scan_shipped(ext).items()
            for it in items
            if it["reason"].startswith(PREFIXES)
        ]
        self.assertEqual(bad, [], f"{len(bad)} value(s), first: {bad[:5]}")

    def test_repairs_reach_the_dictionary_and_are_clean(self) -> None:
        from dictionaries import TRANSLATIONS
        from manual_translations_invented import load

        repairs = load()
        self.assertEqual(len(repairs), 24)
        # TRANSLATIONS merges _REPAIRS with setdefault; a mismatch means a curated
        # entry would silently replace the repair on the next generation run.
        lost = [(l, s[:40]) for l, e in repairs.items() for s, v in e.items() if TRANSLATIONS.get(l, {}).get(s) != v]
        self.assertEqual(lost, [])
        flagged = [
            (l, s[:40]) for l, e in repairs.items() for s, v in e.items()
            if any(sev == "hard" for sev, _ in bt.detect(s, v, l, []))
        ]
        self.assertEqual(flagged, [])


if __name__ == "__main__":
    unittest.main()
