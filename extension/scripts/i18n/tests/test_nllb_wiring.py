"""Wiring tests for NLLB-primary / Google-fallback selection in mt_fallback.

Run from the repo root::

    python extension/scripts/i18n/tests/test_nllb_wiring.py

No real engine ever runs: the fetch boundaries (``_nllb_fetch`` / ``_google_fetch``)
are stubbed, so neither the 3.3B model nor the network is touched. These pin the
contract that NLLB is preferred when available, Google is the per-string
fallback, and the cache is keyed by the primary engine so a Google-only cache is
upgraded once NLLB is installed.
"""

from __future__ import annotations

import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import mt_fallback as mt  # noqa: E402 — path injected above


class TestPrimaryEngineSelection(unittest.TestCase):
    def test_english_has_no_engine(self) -> None:
        self.assertIsNone(mt._primary_engine("en"))

    def test_skip_env_forces_google(self) -> None:
        # With NLLB skipped, a Google-supported locale falls to Google even if a
        # model were present.
        with mock.patch.dict(os.environ, {"SAROPA_SKIP_NLLB": "1"}):
            self.assertEqual(mt._primary_engine("de"), "google")

    def test_unsupported_locale_has_no_engine(self) -> None:
        with mock.patch.dict(os.environ, {"SAROPA_SKIP_NLLB": "1"}):
            self.assertIsNone(mt._primary_engine("xx"))

    def test_nllb_wins_when_active(self) -> None:
        with mock.patch.object(mt, "_nllb_active_for", return_value=True):
            self.assertEqual(mt._primary_engine("de"), "nllb")


class TestCacheKeyNamespacing(unittest.TestCase):
    def test_google_key_is_legacy_format(self) -> None:
        # Backward compat: existing Google cache entries must keep resolving.
        key = mt._cache_key("de", "Cancel")
        self.assertTrue(key.startswith("de:"))
        self.assertFalse(key.startswith("google:"))

    def test_nllb_key_is_namespaced_and_distinct(self) -> None:
        g = mt._cache_key("de", "Cancel")
        n = mt._cache_key("de", "Cancel", "nllb")
        self.assertTrue(n.startswith("nllb:de:"))
        self.assertNotEqual(g, n)


class TestTranslateOneFallback(unittest.TestCase):
    def setUp(self) -> None:
        # Force MT "on" without touching env-var parsing in each test.
        self._env = mock.patch.object(mt, "_mt_env_enabled", return_value=True)
        self._env.start()

    def tearDown(self) -> None:
        self._env.stop()

    def test_nllb_result_used_and_cached_under_nllb_key(self) -> None:
        cache: dict[str, str] = {}
        with mock.patch.object(mt, "_nllb_fetch", return_value="NLLB-out") as nf, \
                mock.patch.object(mt, "_google_fetch") as gf:
            out = mt._translate_one("de", "Cancel", cache=cache, primary="nllb")
        self.assertEqual(out, "NLLB-out")
        nf.assert_called_once()
        gf.assert_not_called()  # NLLB succeeded — Google must NOT be hit
        self.assertEqual(cache[mt._cache_key("de", "Cancel", "nllb")], "NLLB-out")

    def test_google_fallback_when_nllb_returns_none(self) -> None:
        cache: dict[str, str] = {}
        with mock.patch.object(mt, "_nllb_fetch", return_value=None), \
                mock.patch.object(mt, "_google_fetch", return_value="Google-out") as gf:
            out = mt._translate_one("de", "Cancel", cache=cache, primary="nllb")
        self.assertEqual(out, "Google-out")
        gf.assert_called_once()
        # Cached under the PRIMARY (nllb) key so the slow NLLB call isn't retried.
        self.assertEqual(cache[mt._cache_key("de", "Cancel", "nllb")], "Google-out")

    def test_clean_cache_hit_skips_engines(self) -> None:
        cache = {mt._cache_key("de", "Cancel", "nllb"): "Cached"}
        with mock.patch.object(mt, "_nllb_fetch") as nf, \
                mock.patch.object(mt, "_google_fetch") as gf:
            out = mt._translate_one("de", "Cancel", cache=cache, primary="nllb")
        self.assertEqual(out, "Cached")
        nf.assert_not_called()
        gf.assert_not_called()

    def test_total_failure_returns_english(self) -> None:
        cache: dict[str, str] = {}
        with mock.patch.object(mt, "_nllb_fetch", return_value=None), \
                mock.patch.object(mt, "_google_fetch", return_value=None):
            out = mt._translate_one("de", "Cancel", cache=cache, primary="nllb")
        self.assertEqual(out, "Cancel")  # English, coverage gate flags it
        self.assertNotIn(mt._cache_key("de", "Cancel", "nllb"), cache)


class TestPrefetchWarmsPrimaryKey(unittest.TestCase):
    def test_prefetch_then_machine_translate_hits_cache(self) -> None:
        cache: dict[str, str] = {}
        with mock.patch.object(mt, "_mt_env_enabled", return_value=True), \
                mock.patch.object(mt, "_nllb_active_for", return_value=True), \
                mock.patch.object(mt, "_nllb_fetch", return_value="NLLB-out") as nf, \
                mock.patch.object(mt, "_google_fetch"):
            mt.prefetch_machine_translations("de", ["Cancel"], cache=cache, dict_table={})
            self.assertEqual(nf.call_count, 1)
            # Second pass reads the warmed nllb-key cache — no further fetch.
            out = mt.machine_translate("Cancel", "de", cache=cache)
        self.assertEqual(out, "NLLB-out")
        self.assertEqual(nf.call_count, 1)


if __name__ == "__main__":
    unittest.main()
