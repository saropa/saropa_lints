"""Tests for the cache-only mapping pass (no live engine call after prefetch)."""
from __future__ import annotations

import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
import mt_fallback as m  # noqa: E402


class TestCacheOnly(unittest.TestCase):
    def test_uncached_string_makes_no_engine_call(self) -> None:
        # A string the prefetch pass failed on is absent from the cache; the
        # mapping pass must return English without touching Qwen or Google.
        with mock.patch.object(m, "_qwen_fetch") as q, mock.patch.object(
            m, "_google_fetch"
        ) as g:
            out = m._translate_one("bn", "Mobile", cache={}, primary="qwen", cache_only=True)
        self.assertEqual(out, "Mobile")
        q.assert_not_called()
        g.assert_not_called()

    def test_cached_string_still_served(self) -> None:
        # Positive case: a real cached translation must still come back.
        cache = {m._cache_key("bn", "Mobile", "qwen"): "মোবাইল"}
        out = m._translate_one("bn", "Mobile", cache=cache, primary="qwen", cache_only=True)
        self.assertEqual(out, "মোবাইল")


if __name__ == "__main__":
    unittest.main()
