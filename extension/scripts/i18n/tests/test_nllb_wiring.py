"""Wiring tests for Qwen-primary / Google-fallback selection in mt_fallback.

Run from the repo root::

    python extension/scripts/i18n/tests/test_nllb_wiring.py

No real engine ever runs: the fetch boundaries (``_qwen_fetch`` / ``_google_fetch``)
are stubbed, so neither the local Ollama model nor the network is touched. These pin
the contract that Qwen is preferred when available, Google is the per-string
fallback, and the cache is keyed by the primary engine so a Google-only cache is
upgraded once Qwen is installed.

Historical note: this file was originally ``test_nllb_wiring.py``; after the
NLLB→Qwen migration the references were updated in place.
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
        with mock.patch.dict(os.environ, {"SAROPA_SKIP_QWEN": "1"}):
            self.assertEqual(mt._primary_engine("de"), "google")

    def test_unsupported_locale_has_no_engine(self) -> None:
        with mock.patch.dict(os.environ, {"SAROPA_SKIP_QWEN": "1"}):
            self.assertIsNone(mt._primary_engine("xx"))

    def test_qwen_wins_when_active(self) -> None:
        with mock.patch.object(mt, "_qwen_active_for", return_value=True):
            self.assertEqual(mt._primary_engine("de"), "qwen")


class TestCacheKeyNamespacing(unittest.TestCase):
    def test_google_key_is_legacy_format(self) -> None:
        key = mt._cache_key("de", "Cancel")
        self.assertTrue(key.startswith("de:"))
        self.assertFalse(key.startswith("google:"))

    def test_qwen_key_is_namespaced_and_distinct(self) -> None:
        g = mt._cache_key("de", "Cancel")
        q = mt._cache_key("de", "Cancel", "qwen")
        self.assertTrue(q.startswith("qwen:de:"))
        self.assertNotEqual(g, q)


class TestTranslateOneFallback(unittest.TestCase):
    def setUp(self) -> None:
        self._env = mock.patch.object(mt, "_mt_env_enabled", return_value=True)
        self._env.start()

    def tearDown(self) -> None:
        self._env.stop()

    def test_qwen_result_used_and_cached_under_qwen_key(self) -> None:
        cache: dict[str, str] = {}
        with mock.patch.object(mt, "_qwen_fetch", return_value="Qwen-out") as qf, \
                mock.patch.object(mt, "_google_fetch") as gf:
            out = mt._translate_one("de", "Cancel", cache=cache, primary="qwen")
        self.assertEqual(out, "Qwen-out")
        qf.assert_called_once()
        gf.assert_not_called()
        self.assertEqual(cache[mt._cache_key("de", "Cancel", "qwen")], "Qwen-out")

    def test_google_fallback_when_qwen_returns_none(self) -> None:
        cache: dict[str, str] = {}
        with mock.patch.object(mt, "_qwen_fetch", return_value=None), \
                mock.patch.object(mt, "_google_fetch", return_value="Google-out") as gf:
            out = mt._translate_one("de", "Cancel", cache=cache, primary="qwen")
        self.assertEqual(out, "Google-out")
        gf.assert_called_once()
        self.assertEqual(cache[mt._cache_key("de", "Cancel", "qwen")], "Google-out")

    def test_clean_cache_hit_skips_engines(self) -> None:
        cache = {mt._cache_key("de", "Cancel", "qwen"): "Cached"}
        with mock.patch.object(mt, "_qwen_fetch") as qf, \
                mock.patch.object(mt, "_google_fetch") as gf:
            out = mt._translate_one("de", "Cancel", cache=cache, primary="qwen")
        self.assertEqual(out, "Cached")
        qf.assert_not_called()
        gf.assert_not_called()

    def test_total_failure_returns_english(self) -> None:
        cache: dict[str, str] = {}
        with mock.patch.object(mt, "_qwen_fetch", return_value=None), \
                mock.patch.object(mt, "_google_fetch", return_value=None):
            out = mt._translate_one("de", "Cancel", cache=cache, primary="qwen")
        self.assertEqual(out, "Cancel")
        self.assertNotIn(mt._cache_key("de", "Cancel", "qwen"), cache)


class TestPrefetchWarmsPrimaryKey(unittest.TestCase):
    def test_prefetch_then_machine_translate_hits_cache(self) -> None:
        cache: dict[str, str] = {}
        with mock.patch.object(mt, "_mt_env_enabled", return_value=True), \
                mock.patch.object(mt, "_qwen_active_for", return_value=True), \
                mock.patch.object(mt, "_qwen_fetch", return_value="Qwen-out") as qf, \
                mock.patch.object(mt, "_google_fetch"):
            mt.prefetch_machine_translations("de", ["Cancel"], cache=cache, dict_table={})
            self.assertEqual(qf.call_count, 1)
            out = mt.machine_translate("Cancel", "de", cache=cache)
        self.assertEqual(out, "Qwen-out")
        self.assertEqual(qf.call_count, 1)


class TestLazyEngineDetectionOnFullyCachedLocale(unittest.TestCase):
    """Pins the fix: a fully-cached locale must never resolve the primary
    engine — resolving it self-provisions Qwen/Ollama (daemon start, model
    pull), which a "nothing left to translate" run must not pay for."""

    def test_all_cached_never_calls_primary_engine(self) -> None:
        texts = ["Cancel", "Save", "Delete"]
        cache = {mt._cache_key("de", t, "qwen"): f"{t}-de" for t in texts}
        with mock.patch.object(mt, "_primary_engine") as pe:
            pending = list(
                mt._iter_pending_texts("de", texts, cache=cache, dict_table={})
            )
        self.assertEqual(pending, [])
        pe.assert_not_called()

    def test_count_pending_zero_never_calls_primary_engine(self) -> None:
        texts = ["Cancel"]
        cache = {mt._cache_key("de", "Cancel", "qwen"): "Cancel-de"}
        with mock.patch.object(mt, "_mt_env_enabled", return_value=True), \
                mock.patch.object(mt, "_primary_engine") as pe:
            count = mt.count_pending_translations(
                "de", texts, cache=cache, dict_table={}
            )
        self.assertEqual(count, 0)
        pe.assert_not_called()

    def test_prefetch_all_cached_never_calls_primary_engine(self) -> None:
        texts = ["Cancel"]
        cache = {mt._cache_key("de", "Cancel", "qwen"): "Cancel-de"}
        with mock.patch.object(mt, "_mt_env_enabled", return_value=True), \
                mock.patch.object(mt, "_primary_engine") as pe:
            mt.prefetch_machine_translations("de", texts, cache=cache, dict_table={})
        pe.assert_not_called()

    def test_one_uncached_string_resolves_engine_exactly_once(self) -> None:
        cache = {mt._cache_key("de", "Cancel", "qwen"): "Cancel-de"}
        texts = ["Cancel", "NewString"]
        with mock.patch.object(mt, "_primary_engine", return_value="qwen") as pe:
            pending = list(
                mt._iter_pending_texts("de", texts, cache=cache, dict_table={})
            )
        self.assertEqual(pending, ["NewString"])
        pe.assert_called_once_with("de")


class TestEngineStats(unittest.TestCase):
    def setUp(self) -> None:
        mt.reset_engine_stats()
        self._env = mock.patch.object(mt, "_mt_env_enabled", return_value=True)
        self._env.start()

    def tearDown(self) -> None:
        self._env.stop()
        mt.reset_engine_stats()

    def test_records_each_engine(self) -> None:
        cache: dict[str, str] = {}
        with mock.patch.object(mt, "_qwen_fetch", return_value="Q"), \
                mock.patch.object(mt, "_google_fetch"):
            mt._translate_one("de", "A", cache=cache, primary="qwen")
        with mock.patch.object(mt, "_qwen_fetch", return_value=None), \
                mock.patch.object(mt, "_google_fetch", return_value="G"):
            mt._translate_one("de", "B", cache=cache, primary="qwen")
        with mock.patch.object(mt, "_qwen_fetch", return_value=None), \
                mock.patch.object(mt, "_google_fetch", return_value=None):
            mt._translate_one("de", "C", cache=cache, primary="qwen")
        with mock.patch.object(mt, "_qwen_fetch", return_value="Q"), \
                mock.patch.object(mt, "_google_fetch"):
            mt._translate_one("de", "A", cache=cache, primary="qwen")
        stats = mt.engine_stats_for("de")
        self.assertEqual((stats.get("qwen"), stats.get("google"), stats.get("english"), stats.get("cached")),
                         (1, 1, 1, 1))

    def test_echo_attributed_to_english_not_engine(self) -> None:
        cache: dict[str, str] = {}
        with mock.patch.object(mt, "_qwen_fetch", return_value=None), \
                mock.patch.object(mt, "_google_fetch", return_value="Echo"):
            mt._translate_one("de", "Echo", cache=cache, primary="qwen")
        stats = mt.engine_stats_for("de")
        self.assertEqual(stats.get("english"), 1)
        self.assertIsNone(stats.get("google"))


if __name__ == "__main__":
    unittest.main()
