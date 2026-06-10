"""Pure-logic tests for the NLLB engine (no model load, no inference).

Run from the repo root::

    python extension/scripts/i18n/tests/test_nllb_engine.py

Every case here returns BEFORE ``_ensure_model`` is reached (unmapped locale,
empty input, or ``SAROPA_SKIP_NLLB=1``), so the 3.3B model is never loaded and
no translation ever runs. The engine's actual inference quality is verified by
running the real pipeline, not by this suite.
"""

from __future__ import annotations

import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import nllb_engine as ne  # noqa: E402 — path injected above


class TestLangCode(unittest.TestCase):
    def test_exact_shipped_locales(self) -> None:
        self.assertEqual(ne.nllb_lang_code("ar"), "arb_Arab")
        self.assertEqual(ne.nllb_lang_code("fil"), "tgl_Latn")
        self.assertEqual(ne.nllb_lang_code("zh"), "zho_Hans")

    def test_region_variant_resolves_exact_then_base(self) -> None:
        # zh-CN has its own entry; an unknown region falls back to the base lang.
        self.assertEqual(ne.nllb_lang_code("zh-CN"), "zho_Hans")
        self.assertEqual(ne.nllb_lang_code("zh-TW"), "zho_Hant")
        self.assertEqual(ne.nllb_lang_code("de-AT"), "deu_Latn")  # base fallback

    def test_unmapped_and_english_return_none(self) -> None:
        self.assertIsNone(ne.nllb_lang_code("xx"))
        self.assertIsNone(ne.nllb_lang_code("en"))  # English is the source, never a target


class TestSentenceSplit(unittest.TestCase):
    def test_abbreviation_not_a_boundary(self) -> None:
        # "Dr." must not end a sentence; the real break is after "home.".
        parts = ne._split_into_sentences("Dr. Smith went home. Then he slept.")
        self.assertEqual(len(parts), 2)

    def test_name_initial_not_a_boundary(self) -> None:
        parts = ne._split_into_sentences("James T. Kirk took command. Later he retired.")
        self.assertEqual(len(parts), 2)

    def test_single_sentence_returns_one(self) -> None:
        self.assertEqual(len(ne._split_into_sentences("Hello world!")), 1)

    def test_join_round_trips_byte_for_byte(self) -> None:
        for src in (
            "Dr. Smith went home. Then he slept.",
            "One sentence only.",
            "Hi.\nWorld.",
        ):
            self.assertEqual("".join(ne._split_into_sentences(src)), src, src)


class TestNoInferenceGuards(unittest.TestCase):
    """These must short-circuit before any model load — they are also the proof
    that the suite cannot accidentally start a 3.3B inference run."""

    def test_unmapped_locale_returns_none_without_load(self) -> None:
        self.assertIsNone(ne.nllb_translate("Cancel", "xx"))

    def test_empty_input_returns_none(self) -> None:
        self.assertIsNone(ne.nllb_translate("   ", "de"))

    def test_skip_env_disables_engine(self) -> None:
        prev = os.environ.get("SAROPA_SKIP_NLLB")
        os.environ["SAROPA_SKIP_NLLB"] = "1"
        try:
            # Even a mapped locale must return None (no load) when skipped.
            self.assertIsNone(ne.nllb_translate("Cancel", "de"))
            self.assertFalse(ne.nllb_model_available())
        finally:
            if prev is None:
                os.environ.pop("SAROPA_SKIP_NLLB", None)
            else:
                os.environ["SAROPA_SKIP_NLLB"] = prev
            ne._available = None  # reset session probe cache mutated above


if __name__ == "__main__":
    unittest.main()
