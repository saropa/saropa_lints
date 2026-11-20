"""Tests for parallel Qwen prefetch: result mapping, stats, stop, serial fallback."""
from __future__ import annotations

import os
import sys
import threading
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import mt_fallback as m  # noqa: E402
import qwen_engine as q  # noqa: E402


def _fake_qwen(locale: str, text: str) -> str:
    # Deterministic per-source output so a mismatched mapping is detectable.
    return f"T[{text}]"


class TestParallelPrefetch(unittest.TestCase):
    def setUp(self) -> None:
        m.reset_engine_stats()

    def _run(self, texts, workers):
        cache: dict[str, str] = {}
        with mock.patch.object(m, "_mt_env_enabled", return_value=True), \
             mock.patch.object(m, "_primary_engine", return_value="qwen"), \
             mock.patch.object(m, "_qwen_fetch", side_effect=_fake_qwen), \
             mock.patch.object(m, "_cache_value_is_clean", return_value=True), \
             mock.patch.object(m, "cache_lookup_any", return_value=(None, None)), \
             mock.patch.object(m, "save_mt_cache"), mock.patch.object(m, "save_provenance"), \
             mock.patch.object(m, "_prefetch_workers", return_value=workers):
            calls: list[int] = []
            m.prefetch_machine_translations(
                "bn", texts, cache=cache, dict_table={},
                progress=lambda d, t, s: calls.append(d),
            )
        return cache, calls

    def test_each_result_keyed_to_its_own_source(self) -> None:
        texts = [f"word{i}" for i in range(40)]
        cache, calls = self._run(texts, 4)
        for t in texts:
            self.assertEqual(cache[m._cache_key("bn", t, "qwen")], f"T[{t}]")
        self.assertEqual(sorted(calls), list(range(1, 41)))

    def test_engine_tally_exact_under_concurrency(self) -> None:
        self._run([f"w{i}" for i in range(200)], 4)
        self.assertEqual(m.engine_stats_for("bn"), {"qwen": 200})

    def test_stop_skips_unstarted_strings(self) -> None:
        with mock.patch.object(m, "stop_requested", return_value=True):
            cache, _ = self._run([f"w{i}" for i in range(10)], 2)
        self.assertEqual(cache, {})

    def test_serial_path_when_one_worker(self) -> None:
        cache, calls = self._run(["a", "b"], 1)
        self.assertEqual(len(cache), 2)
        self.assertEqual(calls, [1, 2])


class TestCheckpointDuringWrites(unittest.TestCase):
    def test_checkpoint_uses_snapshot_not_live_dict(self) -> None:
        # Regression: save_mt_cache iterated the live cache while workers added
        # keys, raising RuntimeError. The saver must receive a copy.
        seen: list[object] = []
        cache: dict[str, str] = {}
        with mock.patch.object(m, "_mt_env_enabled", return_value=True),              mock.patch.object(m, "_primary_engine", return_value="qwen"),              mock.patch.object(m, "_qwen_fetch", side_effect=_fake_qwen),              mock.patch.object(m, "_cache_value_is_clean", return_value=True),              mock.patch.object(m, "cache_lookup_any", return_value=(None, None)),              mock.patch.object(m, "_CHECKPOINT_EVERY", 5),              mock.patch.object(m, "save_mt_cache", side_effect=seen.append),              mock.patch.object(m, "_stream_dict_to_json"),              mock.patch.object(m, "_prefetch_workers", return_value=4):
            m.prefetch_machine_translations(
                "bn", [f"w{i}" for i in range(30)], cache=cache, dict_table={}
            )
        self.assertTrue(seen)
        self.assertTrue(all(c is not cache for c in seen))


class TestParallelRequests(unittest.TestCase):
    def test_default_and_clamp(self) -> None:
        for raw, want in [("", 2), ("1", 1), ("9", 4), ("0", 1), ("x", 2)]:
            with mock.patch.dict(os.environ, {"SAROPA_QWEN_PARALLEL": raw}):
                self.assertEqual(q.parallel_requests(), want)


if __name__ == "__main__":
    unittest.main()
