"""Provenance, mode-pruning, key-management, and cooperative-stop tests.

No model or network: the Qwen/Google fetch boundaries are stubbed, and
_qwen_active_for is forced True so 'de'/'fr' resolve to Qwen-primary.

    python extension/scripts/i18n/tests/test_mt_provenance_modes.py
"""

from __future__ import annotations

import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import mt_fallback as mt  # noqa: E402


class _Base(unittest.TestCase):
    def setUp(self) -> None:
        mt._provenance.clear()
        mt.reset_engine_stats()
        mt.clear_stop()
        self._env = mock.patch.object(mt, "_mt_env_enabled", return_value=True)
        self._env.start()
        self._primary = mock.patch.object(mt, "_qwen_active_for", return_value=True)
        self._primary.start()

    def tearDown(self) -> None:
        self._env.stop()
        self._primary.stop()
        mt._provenance.clear()
        mt.clear_stop()


class TestProvenanceRecording(_Base):
    def test_records_actual_engine_per_string(self) -> None:
        cache: dict[str, str] = {}
        with mock.patch.object(mt, "_qwen_fetch", return_value="N"), \
                mock.patch.object(mt, "_google_fetch"):
            mt._translate_one("de", "Alpha", cache=cache, primary="qwen")
        self.assertEqual(mt.provenance_of("de", "Alpha"), "qwen")
        with mock.patch.object(mt, "_qwen_fetch", return_value=None), \
                mock.patch.object(mt, "_google_fetch", return_value="G"):
            mt._translate_one("de", "Beta", cache=cache, primary="qwen")
        self.assertEqual(mt.provenance_of("de", "Beta"), "google")

    def test_cache_hit_preserves_original_provenance(self) -> None:
        cache: dict[str, str] = {}
        with mock.patch.object(mt, "_qwen_fetch", return_value="N"), \
                mock.patch.object(mt, "_google_fetch"):
            mt._translate_one("de", "Alpha", cache=cache, primary="qwen")
        with mock.patch.object(mt, "_qwen_fetch") as nf, mock.patch.object(mt, "_google_fetch"):
            mt._translate_one("de", "Alpha", cache=cache, primary="qwen")
            nf.assert_not_called()
        self.assertEqual(mt.provenance_of("de", "Alpha"), "qwen")


class TestPruneModes(_Base):
    def _seed(self) -> dict[str, str]:
        cache: dict[str, str] = {}
        with mock.patch.object(mt, "_qwen_fetch", return_value="N"), \
                mock.patch.object(mt, "_google_fetch"):
            mt._translate_one("de", "Alpha", cache=cache, primary="qwen")
        with mock.patch.object(mt, "_qwen_fetch", return_value=None), \
                mock.patch.object(mt, "_google_fetch", return_value="G"):
            mt._translate_one("de", "Beta", cache=cache, primary="qwen")
        with mock.patch.object(mt, "_qwen_fetch", return_value=None), \
                mock.patch.object(mt, "_google_fetch", return_value="Gamma"):
            mt._translate_one("de", "Gamma", cache=cache, primary="qwen")
        mt.cache_set(cache, "de", "Delta", "manual-val")
        return cache

    TEXTS = ["Alpha", "Beta", "Gamma", "Delta"]

    def test_upgrade_drops_low_quality_keeps_qwen_and_manual(self) -> None:
        cache = self._seed()
        removed = mt.prune_low_quality(cache, "de", self.TEXTS, {})
        self.assertEqual(removed, 2)  # Beta (google) + Gamma (english)
        self.assertIsNotNone(mt.cache_lookup(cache, "de", "Alpha")[0])
        self.assertEqual(mt.cache_lookup(cache, "de", "Beta"), (None, None))
        self.assertEqual(mt.cache_lookup(cache, "de", "Gamma"), (None, None))
        self.assertEqual(mt.cache_lookup(cache, "de", "Delta")[1], "manual")

    def test_all_drops_everything_except_manual(self) -> None:
        cache = self._seed()
        removed = mt.prune_all(cache, "de", self.TEXTS, {})
        self.assertEqual(removed, 3)
        self.assertEqual(mt.cache_lookup(cache, "de", "Delta")[1], "manual")

    def test_upgrade_is_noop_when_google_primary(self) -> None:
        cache = {mt._cache_key("de", "Beta", "qwen"): "G"}
        mt._provenance[mt._cache_key("de", "Beta", "qwen")] = "google"
        with mock.patch.object(mt, "_qwen_active_for", return_value=False):
            removed = mt.prune_low_quality(cache, "de", ["Beta"], {})
        self.assertEqual(removed, 0)

    def test_low_quality_entries_lists_without_removing(self) -> None:
        cache = self._seed()
        found = mt.low_quality_entries(cache, "de", self.TEXTS, {})
        self.assertEqual(sorted(found), ["Beta", "Gamma"])
        for text in self.TEXTS:
            self.assertIsNotNone(mt.cache_lookup(cache, "de", text)[0])

    def test_low_quality_entries_empty_when_google_primary(self) -> None:
        cache = {mt._cache_key("de", "Beta", "qwen"): "G"}
        mt._provenance[mt._cache_key("de", "Beta", "qwen")] = "google"
        with mock.patch.object(mt, "_qwen_active_for", return_value=False):
            found = mt.low_quality_entries(cache, "de", ["Beta"], {})
        self.assertEqual(found, [])


class TestKeyManagement(_Base):
    def test_set_lookup_unset(self) -> None:
        cache: dict[str, str] = {}
        mt.cache_set(cache, "fr", "Hello", "Bonjour")
        self.assertEqual(mt.cache_lookup(cache, "fr", "Hello"), ("Bonjour", "manual"))
        self.assertTrue(mt.cache_unset(cache, "fr", "Hello"))
        self.assertEqual(mt.cache_lookup(cache, "fr", "Hello"), (None, None))
        self.assertFalse(mt.cache_unset(cache, "fr", "Hello"))


class TestStopFlag(_Base):
    def test_request_and_clear(self) -> None:
        self.assertFalse(mt.stop_requested())
        mt.request_stop()
        self.assertTrue(mt.stop_requested())
        mt.clear_stop()
        self.assertFalse(mt.stop_requested())

    def test_prefetch_translates_nothing_once_stopped(self) -> None:
        cache: dict[str, str] = {}
        mt.request_stop()
        with mock.patch.object(mt, "_qwen_fetch", return_value="N") as nf, \
                mock.patch.object(mt, "_google_fetch"):
            mt.prefetch_machine_translations("de", ["A", "B", "C"], cache=cache, dict_table={})
        nf.assert_not_called()

    def test_translate_one_skips_live_call_for_uncached_when_stopped(self) -> None:
        cache: dict[str, str] = {}
        mt.request_stop()
        with mock.patch.object(mt, "_qwen_fetch", return_value="N") as nf, \
                mock.patch.object(mt, "_google_fetch") as gf:
            out = mt._translate_one("de", "Untranslated", cache=cache, primary="qwen")
        self.assertEqual(out, "Untranslated")
        nf.assert_not_called()
        gf.assert_not_called()
        self.assertNotIn(mt._cache_key("de", "Untranslated", "qwen"), cache)

    def test_translate_one_still_serves_clean_cache_when_stopped(self) -> None:
        cache: dict[str, str] = {}
        with mock.patch.object(mt, "_qwen_fetch", return_value="N"), \
                mock.patch.object(mt, "_google_fetch"):
            mt._translate_one("de", "Warm", cache=cache, primary="qwen")
        mt.request_stop()
        with mock.patch.object(mt, "_qwen_fetch") as nf, mock.patch.object(mt, "_google_fetch") as gf:
            out = mt._translate_one("de", "Warm", cache=cache, primary="qwen")
            nf.assert_not_called()
            gf.assert_not_called()
        self.assertEqual(out, "N")


if __name__ == "__main__":
    unittest.main()
