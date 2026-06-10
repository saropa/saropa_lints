"""Tests for the NLLB phrase-level splitter and the fallback report.

Run from the repo root::

    python extension/scripts/i18n/tests/test_phrase_split.py

No model ever loads: ``_split_into_phrases`` is pure, and ``_translate_via_phrases``
is exercised with ``nllb_translate`` stubbed. These pin the contract that a single
over-gate sentence is broken on clause/line boundaries (so NLLB keeps the work
instead of dropping to Google) WITHOUT splitting mid-URL, and that the split
rejoins byte-identically.
"""

from __future__ import annotations

import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import nllb_engine as ne  # noqa: E402 — path injected above
import mt_fallback as mt  # noqa: E402


class TestPhraseSplit(unittest.TestCase):
    def _rejoins(self, text: str) -> None:
        # The split must be lossless: separators are captured, so "".join is the
        # source byte-for-byte. A lossy split would silently corrupt translations.
        self.assertEqual("".join(ne._split_into_phrases(text)), text)

    def test_comma_list_splits_and_rejoins(self) -> None:
        text = "unused files, circular dependencies, import stats, dead imports"
        parts = [p for p in ne._split_into_phrases(text) if p.strip()]
        self.assertGreater(len(parts), 1)
        self._rejoins(text)

    def test_url_is_never_split_midtoken(self) -> None:
        # The ':' and '.' inside a URL have no trailing space, so the clause
        # patterns must not break it (a split URL would 404).
        text = "https://pub.dev/packages/saropa_lints"
        self.assertEqual(ne._split_into_phrases(text), [text])

    def test_markdown_link_block_splits_on_newlines(self) -> None:
        text = "[Learn more](https://pub.dev/x)\n[About](command:saropaLints.showAbout)"
        parts = [p for p in ne._split_into_phrases(text) if p.strip()]
        self.assertEqual(len(parts), 2)
        self._rejoins(text)

    def test_no_delimiter_returns_single(self) -> None:
        # Nothing to split -> caller stops recursing and reports the input.
        self.assertEqual(ne._split_into_phrases("just plain words here"), ["just plain words here"])

    def test_newline_preferred_over_comma(self) -> None:
        # Strongest boundary wins: a paragraph break splits before commas do.
        text = "a, b\nc, d"
        parts = [p for p in ne._split_into_phrases(text) if p.strip()]
        self.assertEqual(len(parts), 2)


class TestTranslateViaPhrases(unittest.TestCase):
    def test_translates_each_clause_and_rejoins(self) -> None:
        # Stub prefixes each clause (a genuine change, not a case-only echo the
        # guard would reject). Separators/newlines must survive the rejoin.
        text = "alpha\nbeta\ngamma"
        with mock.patch.object(ne, "nllb_translate", side_effect=lambda s, t: "x" + s):
            out = ne._translate_via_phrases(text, "ar")
        self.assertEqual(out, "xalpha\nxbeta\nxgamma")

    def test_returns_none_when_unsplittable(self) -> None:
        with mock.patch.object(ne, "nllb_translate", side_effect=lambda s, t: "x" + s):
            self.assertIsNone(ne._translate_via_phrases("oneword", "ar"))

    def test_partial_failure_keeps_english_clause(self) -> None:
        # A clause NLLB can't do stays English while the rest translate — never a
        # silent drop of the whole string.
        def stub(s: str, t: str):
            return None if "beta" in s else "x" + s

        with mock.patch.object(ne, "nllb_translate", side_effect=stub):
            out = ne._translate_via_phrases("alpha\nbeta\ngamma", "ar")
        self.assertEqual(out, "xalpha\nbeta\nxgamma")


class TestFallbackLog(unittest.TestCase):
    def setUp(self) -> None:
        mt.reset_engine_stats()  # also clears the fallback log

    def test_english_left_is_recorded(self) -> None:
        # NLLB and Google both fail -> string left English -> must be reported.
        with mock.patch.object(mt, "_primary_engine", return_value="nllb"), \
             mock.patch.object(mt, "_mt_env_enabled", return_value=True), \
             mock.patch.object(mt, "_nllb_fetch", return_value=None), \
             mock.patch.object(mt, "_google_fetch", return_value=None):
            mt.machine_translate("Untranslatable thing", "ar", cache={})
        self.assertIn(("ar", "english", "Untranslatable thing"), mt.fallback_log())

    def test_google_fallback_under_nllb_is_recorded(self) -> None:
        # NLLB declined, Google produced it -> reported as a google fallback.
        with mock.patch.object(mt, "_primary_engine", return_value="nllb"), \
             mock.patch.object(mt, "_mt_env_enabled", return_value=True), \
             mock.patch.object(mt, "_nllb_fetch", return_value=None), \
             mock.patch.object(mt, "_google_fetch", return_value="ترجمة"):
            mt.machine_translate("Hello there", "ar", cache={})
        self.assertIn(("ar", "google", "Hello there"), mt.fallback_log())

    def test_nllb_success_not_recorded(self) -> None:
        with mock.patch.object(mt, "_primary_engine", return_value="nllb"), \
             mock.patch.object(mt, "_mt_env_enabled", return_value=True), \
             mock.patch.object(mt, "_nllb_fetch", return_value="ترجمة جيدة"):
            mt.machine_translate("Hello there", "ar", cache={})
        self.assertEqual(mt.fallback_log(), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
