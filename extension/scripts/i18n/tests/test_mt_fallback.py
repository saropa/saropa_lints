"""Regression tests for the locale-generation placeholder/brand shield.

Run from this directory (imports resolve against the i18n scripts)::

    python -m unittest test_mt_fallback -v

or from the repository root::

    python extension/scripts/i18n/tests/test_mt_fallback.py

These pin the contract that prevented two shipped i18n bugs (2026-05-20):
  * "Saropa" transliterated into local scripts in 124 locale strings, and
  * shield-sentinel residue ("q0q") leaking into 67 translated strings while
    the loose placeholder check counted them as "translated".
All cases here are pure-function — no network / no machine translation.
"""

from __future__ import annotations

import os
import sys
import unittest

# The i18n scripts import each other by bare module name (``from dictionaries
# import ...``), so they expect their own directory on sys.path. Add it here so
# the test runs regardless of the caller's cwd.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import mt_fallback as mt  # noqa: E402 — path injected above


class TestShieldRoundTrip(unittest.TestCase):
    def test_placeholder_round_trip(self) -> None:
        masked, holders = mt.shield_placeholders("of {total} total")
        self.assertNotIn("{total}", masked)  # shielded, not raw
        self.assertEqual(mt.unshield_placeholders(masked, holders), "of {total} total")

    def test_brand_is_shielded_and_restored(self) -> None:
        # "Saropa" must be masked so MT never sees the literal brand, then
        # restored verbatim — never transliterated.
        masked, holders = mt.shield_placeholders("Saropa Findings Dashboard")
        self.assertNotIn("Saropa", masked)
        self.assertEqual(
            mt.unshield_placeholders(masked, holders), "Saropa Findings Dashboard"
        )

    def test_brand_and_placeholder_together(self) -> None:
        src = "Saropa Package Dashboard v{version}"
        masked, holders = mt.shield_placeholders(src)
        self.assertNotIn("Saropa", masked)
        self.assertNotIn("{version}", masked)
        self.assertEqual(mt.unshield_placeholders(masked, holders), src)

    def test_brand_only_shield_leaves_braces_raw(self) -> None:
        # The raw-brace fallback path shields the brand but leaves {tokens} raw.
        masked, holders = mt._shield_brand_only("Saropa needs {target}")
        self.assertNotIn("Saropa", masked)
        self.assertIn("{target}", masked)
        self.assertEqual(mt.unshield_placeholders(masked, holders), "Saropa needs {target}")

    def test_multiword_product_name_shielded_as_unit(self) -> None:
        # "Saropa Lints" must be masked whole — neither half visible to MT — so the
        # engine cannot translate the "Lints" word (the 300+ "Saropa Fusseln /
        # Pelusas / 糸くず" regressions came from only "Saropa" being shielded).
        # The longest-first ordering also has to win: bare "Saropa" must NOT mask
        # the "Saropa" inside the phrase and strand a raw "Lints".
        masked, holders = mt.shield_placeholders("About Saropa Lints today")
        self.assertNotIn("Saropa", masked)
        self.assertNotIn("Lints", masked)
        self.assertEqual(
            mt.unshield_placeholders(masked, holders), "About Saropa Lints today"
        )

    def test_tool_brand_names_shielded(self) -> None:
        # Tool/proper-noun brands that MT had been transliterating ("VS Kodu",
        # "पब.डेव", "オワスプ") must round-trip verbatim.
        for src in ("Open on pub.dev", "follow VS Code display", "OWASP signal"):
            masked, holders = mt.shield_placeholders(src)
            self.assertEqual(mt.unshield_placeholders(masked, holders), src)


class TestSentinelIntegrity(unittest.TestCase):
    def test_intact_when_all_present(self) -> None:
        masked, holders = mt.shield_placeholders("a {x} b {y}")
        self.assertTrue(mt._sentinels_intact(masked, len(holders)))

    def test_not_intact_when_sentinel_dropped(self) -> None:
        # Simulate MT stripping one sentinel: integrity must fail so the result
        # is rejected rather than restored into garbage.
        masked, holders = mt.shield_placeholders("a {x} b {y}")
        damaged = masked.replace(mt._sentinel(0), "", 1)
        self.assertFalse(mt._sentinels_intact(damaged, len(holders)))


class TestResidueDetection(unittest.TestCase):
    def test_detects_legacy_and_current_residue(self) -> None:
        for poisoned in ("Cannot reach q0q {target}", "v{version} ZZ3ZZ", "x ﷐ y"):
            self.assertTrue(mt._SHIELD_RESIDUE_RE.search(poisoned), poisoned)

    def test_clean_strings_not_flagged(self) -> None:
        for clean in ("normal {count} text", "Iraq is here", "pizzazz"):
            self.assertIsNone(mt._SHIELD_RESIDUE_RE.search(clean), clean)


class TestCacheValueIsClean(unittest.TestCase):
    def test_accepts_clean_translation(self) -> None:
        self.assertTrue(mt._cache_value_is_clean("Cannot reach {target}", "Erreur {target}"))

    def test_rejects_placeholder_loss(self) -> None:
        self.assertFalse(mt._cache_value_is_clean("Cannot reach {target}", "Erreur"))

    def test_rejects_sentinel_residue(self) -> None:
        self.assertFalse(mt._cache_value_is_clean("Cannot reach {target}", "Erreur q0q {target}"))

    def test_rejects_transliterated_brand(self) -> None:
        # Source has the brand; a cached value missing it means MT transliterated
        # it (e.g. "ساروبا") and must be re-fetched.
        self.assertFalse(mt._cache_value_is_clean("Run Saropa Lints", "تشغيل ساروبا لينتس"))

    def test_accepts_brand_preserved(self) -> None:
        self.assertTrue(mt._cache_value_is_clean("Run Saropa Lints", "تشغيل Saropa Lints"))


class TestShouldSkip(unittest.TestCase):
    def test_skips_pure_brand(self) -> None:
        self.assertTrue(mt.should_skip_machine_translate("Saropa"))
        self.assertTrue(mt.should_skip_machine_translate("Saropa "))

    def test_skips_single_letter_label(self) -> None:
        # "L{line}" — MT only renames {line}->{Linie}; keep the English label.
        self.assertTrue(mt.should_skip_machine_translate("L{line}"))

    def test_does_not_skip_real_phrases(self) -> None:
        for s in ("of {total} total", "Saropa Package Dashboard", "Cannot reach {target}"):
            self.assertFalse(mt.should_skip_machine_translate(s), s)


if __name__ == "__main__":
    unittest.main()
