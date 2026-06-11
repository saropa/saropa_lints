"""Tests for the locale-generation progress reporter and its prefetch wiring.

Run from the repo root::

    python extension/scripts/i18n/tests/test_progress.py

No model loads and no network is touched: the duration formatter and the bar
geometry are pure, and the prefetch callback is exercised with ``_translate_one``
stubbed so the per-string completion signal is verified without any real
translation. These pin the WPM/ETA progress contract added to the MT phase.
"""

from __future__ import annotations

import os
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import generate_locales as gl  # noqa: E402 — path injected above
import mt_fallback as mt  # noqa: E402


class TestFmtDuration(unittest.TestCase):
    def test_unknown_renders_placeholder_not_zero(self) -> None:
        # A not-yet-established rate (0/negative) or NaN must read as unknown, not
        # "00:00" — the latter falsely signals "done".
        self.assertEqual(gl._fmt_duration(0), "--:--")
        self.assertEqual(gl._fmt_duration(-5), "--:--")
        self.assertEqual(gl._fmt_duration(float("nan")), "--:--")

    def test_minutes_seconds_and_hours(self) -> None:
        self.assertEqual(gl._fmt_duration(65), "01:05")
        self.assertEqual(gl._fmt_duration(3725), "1:02:05")


class TestProgressBar(unittest.TestCase):
    def test_bar_geometry(self) -> None:
        p = gl._TranslationProgress("th")
        width = gl._TranslationProgress._BAR_WIDTH
        self.assertEqual(p._bar(0, width * 4), "[" + "-" * width + "]")
        self.assertEqual(p._bar(width * 4, width * 4), "[" + "#" * width + "]")
        half = p._bar(width * 2, width * 4)
        self.assertEqual(half.count("#"), width // 2)

    def test_zero_total_does_not_divide(self) -> None:
        # An empty locale must not raise; the guard renders an empty bar.
        p = gl._TranslationProgress("th")
        self.assertEqual(p._bar(0, 0), "[" + " " * gl._TranslationProgress._BAR_WIDTH + "]")


class TestPrefetchProgressCallback(unittest.TestCase):
    def test_callback_fires_once_per_pending_string(self) -> None:
        texts = ["one two", "three", "four five six"]
        calls: list[tuple[int, int, str]] = []

        # Stub the actual translation so nothing loads/network-calls; force NLLB
        # primary and MT enabled so every text counts as pending.
        with mock.patch.object(mt, "_primary_engine", return_value="nllb"), \
             mock.patch.object(mt, "_mt_env_enabled", return_value=True), \
             mock.patch.object(mt, "_translate_one", return_value="x"):
            mt.prefetch_machine_translations(
                "ar", texts, cache={}, dict_table={},
                progress=lambda done, total, src: calls.append((done, total, src)),
            )

        # One call per string, monotonically increasing done, constant total.
        self.assertEqual([d for d, _, _ in calls], [1, 2, 3])
        self.assertTrue(all(t == 3 for _, t, _ in calls))
        self.assertEqual([s for _, _, s in calls], texts)

    def test_no_callback_when_progress_is_none(self) -> None:
        # Backward-compatible: the parameter is optional and defaults to no-op.
        with mock.patch.object(mt, "_primary_engine", return_value="nllb"), \
             mock.patch.object(mt, "_mt_env_enabled", return_value=True), \
             mock.patch.object(mt, "_translate_one", return_value="x"):
            mt.prefetch_machine_translations("ar", ["a b"], cache={}, dict_table={})
        # Reaching here without a TypeError proves the default path still works.


if __name__ == "__main__":
    unittest.main(verbosity=2)
