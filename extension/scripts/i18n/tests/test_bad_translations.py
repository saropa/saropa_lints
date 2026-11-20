"""Tests for bad_translations.detect(): every defect class fires, clean text does not."""

from __future__ import annotations

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import bad_translations as bt  # noqa: E402

BLOCK = [{"locale": "de", "en_regex": "file watching", "bad_regex": "Dateibewertung"}]


def hard(en: str, loc: str, locale: str = "de") -> list[str]:
    """Reasons of HARD flags only (soft heuristics are not asserted here)."""
    return [r for s, r in bt.detect(en, loc, locale, BLOCK) if s == "hard"]


class TestDetectPositive(unittest.TestCase):
    """Each known failure class from the Qwen/NLLB measurement must be caught."""

    def test_bare_zz_leak(self) -> None:
        self.assertTrue(any(r.startswith("leak") for r in hard("Disable Drift Advisor", "Deaktiviere Drift AdvisorZZ")))

    def test_question_mark_glyph_leak(self) -> None:
        self.assertTrue(any(r.startswith("leak") for r in hard("Sorts members — fast", "Ordnet Mitglieder ⁇ schnell")))

    def test_placeholder_shield_variant_leak(self) -> None:
        self.assertTrue(any(r.startswith("leak") for r in hard("Run Analysis", "Analyse _PH0_ ausführen")))

    def test_dropped_placeholder(self) -> None:
        self.assertTrue(any(r.startswith("placeholder") for r in hard("Kill All {name}", "Alle beenden")))

    def test_wrong_script(self) -> None:
        # Russian text in an Arabic file.
        self.assertIn("wrong-script", hard("Show more", "покажи больше", "ar"))

    def test_hallucinated_continuation(self) -> None:
        loc = "Aktualisieren: Das ist die Antwort auf eine Frage, die niemand gestellt hat und lang ist."
        self.assertTrue(any(r.startswith("blowup") for r in hard("Refresh", "Refresh " + loc)))

    def test_blocklist(self) -> None:
        self.assertTrue(any(r.startswith("blocklist") for r in hard("Enable file watching", "Dateibewertung aktivieren")))

    def test_empty(self) -> None:
        self.assertEqual(hard("Cancel", "  "), ["empty"])


class TestDetectNegative(unittest.TestCase):
    """Correct translations must not be flagged (a false positive deletes good work)."""

    def test_clean_translation(self) -> None:
        self.assertEqual(hard("Show more", "Mehr anzeigen"), [])

    def test_placeholder_heavy_source_not_blowup(self) -> None:
        en = "{pkg} {to} needs {dep} {range}; Flutter pins {dep}"
        loc = "{pkg} {to} benötigt {dep} {range}; Flutter fixiert {dep}"
        self.assertEqual(hard(en, loc), [])

    def test_token_present_in_english_is_excused(self) -> None:
        self.assertEqual(hard("Use PH2 mode", "PH2-Modus verwenden"), [])

    def test_underscore_wrapped_token_excused_when_english_has_it(self) -> None:
        # Regex matches "_PH2_"; English only has "PH2" - must still be excused.
        self.assertEqual(hard("Use PH2 mode", "_PH2_ Modus verwenden"), [])

    def test_lone_acronym_kept_latin_not_wrong_script(self) -> None:
        # A correct ja/ar translation may keep a single acronym in Latin.
        self.assertEqual(hard("JSON", "JSON", "ja"), [])
        self.assertEqual(hard("URL", "URL", "ar"), [])

    def test_arabic_in_arabic_ok(self) -> None:
        self.assertEqual(hard("Show more", "عرض المزيد", "ar"), [])


class TestPruneBadCacheEntries(unittest.TestCase):
    """prune_bad_cache_entries drives real cache keys: only hard-flagged, non-manual,
    non-dictionary entries may be removed."""

    def setUp(self) -> None:
        import mt_fallback as mt
        self.mt = mt
        self._saved = dict(mt._provenance)
        mt._provenance.clear()

    def tearDown(self) -> None:
        self.mt._provenance.clear()
        self.mt._provenance.update(self._saved)

    def test_prunes_only_defective_entries(self) -> None:
        k = self.mt._cache_key
        cache = {
            k("de", "Show more", "qwen"): "Mehr anzeigen",           # clean -> kept
            k("de", "Disable X", "nllb"): "Deaktiviere XZZ",          # leak -> pruned
            k("de", "Cancel", "qwen"): "Abbrechen",                   # manual-protected below
            k("de", "Retry", "qwen"): "Wiederholen ZZ",               # leak but dictionary -> kept
        }
        self.mt._provenance[k("de", "Cancel", "qwen")] = "manual"
        texts = ["Show more", "Disable X", "Cancel", "Retry"]
        removed = bt.prune_bad_cache_entries(cache, "de", texts, {"Retry": "Wiederholen"})
        self.assertEqual(removed, 1)
        self.assertNotIn(k("de", "Disable X", "nllb"), cache)
        self.assertEqual(len(cache), 3)

    def test_manual_override_never_pruned_even_if_flagged(self) -> None:
        k = self.mt._cache_key("de", "Disable X", "qwen")
        cache = {k: "Deaktiviere XZZ"}
        self.mt._provenance[k] = "manual"
        self.assertEqual(bt.prune_bad_cache_entries(cache, "de", ["Disable X"], {}), 0)
        self.assertIn(k, cache)


if __name__ == "__main__":
    unittest.main()
