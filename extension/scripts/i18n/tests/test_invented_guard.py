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


class TestSindhiInUrdu(unittest.TestCase):
    """Sindhi letters are a defect in ur only."""

    SINDHI = "هٽايو"  # old ur value for "Remove"
    URDU = "ٹڈڑںھہے"  # Urdu's own letters

    def sindhi_flags(self, loc: str, locale: str) -> list[str]:
        return [r for _, r in bt.detect("Remove", loc, locale, []) if r.startswith("sindhi:")]

    def test_flagged_in_ur(self) -> None:
        self.assertEqual(self.sindhi_flags(self.SINDHI, "ur"), ["sindhi:U+067D"])

    def test_urdu_letters_and_other_locales_pass(self) -> None:
        self.assertEqual(self.sindhi_flags(self.URDU, "ur"), [])
        self.assertEqual(self.sindhi_flags(self.SINDHI, "ar"), [])

    def test_curated_and_shipped_ur_are_clean(self) -> None:
        # Curated entries win over every repair file, so they are checked directly.
        from dictionaries import TRANSLATIONS

        curated = [s for s, v in TRANSLATIONS["ur"].items() if bt._SINDHI_ONLY_RE.search(v)]
        self.assertEqual(curated, [])
        shipped = bt.scan_shipped(Path(__file__).resolve().parents[3])["ur"]
        self.assertEqual([i["key"] for i in shipped if i["reason"].startswith("sindhi:")], [])


class TestArabicLettersInUrdu(unittest.TestCase):
    """Arabic-only letters are a defect in ur; letters English carries are excused."""

    def flags_for(self, en: str, loc: str, locale: str = "ur") -> list[str]:
        return [r.split(":")[0] for _, r in bt.detect(en, loc, locale, []) if r.startswith(("arabic-letter:", "sindhi:"))]

    def test_flagged_in_ur_only(self) -> None:
        self.assertEqual(self.flags_for("Warning", "تحذير"), ["arabic-letter"])
        self.assertEqual(self.flags_for("Warning", "تحذير", "ar"), [])

    def test_excused_letter_does_not_hide_another(self) -> None:
        self.assertEqual(self.flags_for("Type \u067b", "\u067b"), [])
        self.assertEqual(self.flags_for("Type \u067b", "\u067b \u067d"), ["sindhi"])


class TestProductNames(unittest.TestCase):
    """"Code Health" and "Package Vibrancy" stay English; lowercase prose does not."""

    def names(self, en: str, loc: str) -> list[str]:
        return [r for _, r in bt.detect(en, loc, "de", []) if r.startswith("product-name:")]

    def test_translated_name_is_flagged(self) -> None:
        self.assertEqual(self.names("Open Code Health", "Codezustand öffnen"), ["product-name:Code Health"])
        self.assertTrue(self.names("Code Health: open Code Health", "Code Health: öffnen"))

    def test_lowercase_prose_is_free(self) -> None:
        self.assertEqual(self.names("Code health summary", "Zusammenfassung"), [])

    def test_codicon_must_survive(self) -> None:
        reasons = [r for _, r in bt.detect("$(warning) {count}", "$(aviso) {count}", "es", [])]
        self.assertTrue(any(r.startswith("placeholder:codicons") for r in reasons), reasons)

    def test_curated_and_repairs_keep_names(self) -> None:
        # Regeneration writes these values, so a translated name here would ship again.
        # Only sources in the current English catalogs are checked.
        from dictionaries import TRANSLATIONS
        from verify_locales import discover, load

        fams, _ = discover(Path(__file__).resolve().parents[3])
        sources = {v for src, _p in fams.values() for v in load(src).values() if isinstance(v, str)}
        bad = [
            (loc, s[:40]) for loc, entries in TRANSLATIONS.items() for s, v in entries.items()
            if s in sources and any(v.count(n) < s.count(n) for n in bt.PRODUCT_NAMES)
        ]
        self.assertEqual(bad, [])

    def test_shipped_names_and_ur_letters_are_clean(self) -> None:
        prefixes = ("product-name:", "arabic-letter:", "placeholder:codicons")
        bad = [
            f"{loc} {it['key']} {it['reason']}"
            for loc, items in bt.scan_shipped(Path(__file__).resolve().parents[3]).items()
            for it in items if it["reason"].startswith(prefixes)
        ]
        self.assertEqual(bad, [], f"{len(bad)} value(s), first: {bad[:5]}")


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
