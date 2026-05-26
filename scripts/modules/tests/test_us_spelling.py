"""Regression tests for the US-English spelling audit.

Run from repository root::

    python -m unittest discover -s scripts/modules/tests -t . -v

These tests pin two behaviors of ``scripts/modules/_us_spelling.py``:

1. The original word-boundary pattern still catches standalone British
   spellings (``cancelled`` in prose, ``Colour`` at sentence start).

2. The CamelCase pattern catches British words embedded in identifiers
   that the ``\\b`` boundary misses (``_ScanCancelled``,
   ``OnColourPicked``, ``isCancelled``). This is the case that motivated
   the second pattern — a private class named ``_ScanCancelled`` shipped
   to ``bin/project_vibrancy.dart`` and the original audit could not see
   it because ``\\bCancelled\\b`` has no boundary between ``n`` and
   ``C`` in ``ScanCancelled``.

The tests also pin the negative cases (leading-underscore identifiers,
words outside the dictionary, lines tagged with ``cspell``) so future
edits don't accidentally narrow or widen detection.
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path


class TestUsSpellingScanner(unittest.TestCase):
    """Pin the contract of ``scan_file`` against representative inputs."""

    def setUp(self) -> None:
        from scripts.modules._us_spelling import scan_file

        self._scan = scan_file

    def _scan_text(self, body: str) -> list[tuple[str, str]]:
        """Write ``body`` to a temp file, scan it, return (uk, us) pairs."""
        fh = tempfile.NamedTemporaryFile(
            "w", suffix=".dart", delete=False, encoding="utf-8",
        )
        fh.write(body)
        fh.close()
        hits = self._scan(Path(fh.name))
        return [(h.uk_word, h.us_word) for h in hits]

    def test_standalone_lowercase_word_is_flagged(self) -> None:
        # Original behavior: the existing word-boundary pattern catches
        # prose mentions of British forms. This test pins that it still
        # fires after the CamelCase pattern was added.
        hits = self._scan_text("// User cancelled the dialog\n")
        self.assertEqual(hits, [("cancelled", "canceled")])

    def test_standalone_capitalized_word_is_flagged(self) -> None:
        # `Cancelled.` at sentence start is a word-boundary match (the
        # leading non-letter is a boundary), not a CamelCase match.
        hits = self._scan_text("Cancelled.\n")
        self.assertEqual(hits, [("Cancelled", "Canceled")])

    def test_camelcase_embedded_word_is_flagged(self) -> None:
        # The case the second pattern was added for: ``_ScanCancelled``
        # has no ``\b`` boundary between ``n`` and ``C``, so the original
        # pattern misses it. The CamelCase pattern catches it because the
        # transition lowercase->Uppercase counts as a word start.
        hits = self._scan_text(
            "class _ScanCancelled implements Exception {}\n"
        )
        self.assertEqual(hits, [("Cancelled", "Canceled")])

    def test_camelcase_with_multiple_uk_words(self) -> None:
        # CamelCase pattern should flag every embedded UK word on a line,
        # not just the first. Pins the multi-match behavior.
        hits = self._scan_text("onColourPickedHandleBehaviour();\n")
        uk_words = sorted(h[0] for h in hits)
        self.assertEqual(uk_words, ["Behaviour", "Colour"])

    def test_leading_underscore_lowercase_is_not_flagged(self) -> None:
        # ``_cancelled`` has ``_`` (word char) before lowercase ``c``, so
        # there is no CamelCase boundary AND no ``\b`` boundary inside
        # the identifier. Intentionally not flagged — this is how the
        # ``_cancelTokenCancellationPatterns`` regex in
        # ``api_network_rules.dart`` matches user code without itself
        # being flagged.
        hits = self._scan_text("RegExp(r'\\b_cancelled\\b'),\n")
        self.assertEqual(hits, [])

    def test_non_dictionary_word_is_not_flagged(self) -> None:
        # ``cancellation`` is the same in British and American English,
        # so it is NOT in the dictionary. Pin that the CamelCase pattern
        # only matches dictionary entries — adding ``Cancelled`` to the
        # dict must not implicitly add ``Cancellation``.
        hits = self._scan_text(
            "static const String cancellationReason = '';\n"
            "class CancellationToken {}\n"
        )
        self.assertEqual(hits, [])

    def test_cspell_tag_suppresses_line(self) -> None:
        # The scanner skips any line containing the literal ``cspell``
        # (case-insensitive). Used as the escape hatch for intentional
        # API-name references (Dio ``isCancelled``).
        hits = self._scan_text(
            "bool get isCancelled => false; // cspell:ignore isCancelled\n"
        )
        self.assertEqual(hits, [])

    def test_dedup_prevents_same_span_being_reported_twice(self) -> None:
        # ``Cancelled`` at sentence start is a word-boundary match. It is
        # ALSO matchable by the CamelCase pattern when preceded by a
        # lowercase letter elsewhere on the line. The scanner must dedupe
        # so the same character range isn't reported twice.
        hits = self._scan_text(
            "Cancelled by the user; the cancelled flag is set.\n"
        )
        uk_words = sorted(h[0] for h in hits)
        # Exactly two hits: one for ``Cancelled`` (capitalized standalone)
        # and one for ``cancelled`` (lowercase standalone). No duplicates.
        self.assertEqual(uk_words, ["Cancelled", "cancelled"])


if __name__ == "__main__":
    unittest.main()
