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

    def test_coverage_dialogue_is_flagged(self) -> None:
        # `dialogue` was missing while `catalogue`/`analogue` were present —
        # the -ogue group was incomplete. Pin the gap closed.
        hits = self._scan_text("// open the dialogue box\n")
        self.assertEqual(hits, [("dialogue", "dialog")])

    def test_coverage_realise_is_flagged(self) -> None:
        # `realise` was missing from the -ise group. The auto-derivation
        # also covers realised/realising from this one base entry.
        hits = self._scan_text("// you will realise this soon\n")
        self.assertEqual(hits, [("realise", "realize")])

    def test_coverage_realised_derived_form_is_flagged(self) -> None:
        # Pins that adding the base "realise" yields the -ed form for free.
        hits = self._scan_text("// we realised the problem\n")
        self.assertEqual(hits, [("realised", "realized")])

    def test_coverage_labelled_is_flagged(self) -> None:
        # Doubled-consonant tense forms are NOT auto-derived, so `labelled`
        # had to be listed explicitly. Pin it.
        hits = self._scan_text("// the labelled node\n")
        self.assertEqual(hits, [("labelled", "labeled")])

    def test_analyses_noun_plural_is_not_flagged(self) -> None:
        # `analyses` is the correct American plural of `analysis`, so it must
        # NOT fire even though the British verb `analyse` is flagged. This is
        # the ambiguity the post-derivation pop() guards against.
        hits = self._scan_text("// two analyses were run\n")
        self.assertEqual(hits, [])

    def test_analysed_verb_form_is_flagged(self) -> None:
        # The unambiguous British verb form still fires (no US homograph).
        hits = self._scan_text("// the tool analysed the file\n")
        self.assertEqual(hits, [("analysed", "analyzed")])

    def test_storeys_maps_to_stories_not_storys(self) -> None:
        # The blunt +s derivation would suggest "storys"; the override fixes
        # the plural to the correct "stories".
        hits = self._scan_text("// a three storeys building\n")
        self.assertEqual(hits, [("storeys", "stories")])

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


class TestScanPaths(unittest.TestCase):
    """Pin ``scan_paths`` — the file-scoped entry the git/editor hooks use.

    The hooks pass raw staged / just-edited paths, so ``scan_paths`` must
    apply the same extension / skip-file / plans-history exemptions as the
    whole-tree ``scan_directory`` and must tolerate paths that aren't real
    files (a staged deletion, a directory) without crashing.
    """

    def setUp(self) -> None:
        from scripts.modules._us_spelling import scan_paths

        self._scan_paths = scan_paths
        self._root = Path(
            tempfile.mkdtemp(prefix="scan_paths_test_")
        )

    def _write(self, rel: str, body: str) -> Path:
        """Write ``body`` to ``rel`` under the temp project root."""
        path = self._root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body, encoding="utf-8")
        return path

    def _uk_words(self, paths: list[Path]) -> list[str]:
        hits = self._scan_paths(paths, self._root)
        return sorted(h.uk_word for h in hits)

    def test_dirty_dart_file_is_flagged(self) -> None:
        # The core positive case: a British spelling in a passed file is
        # reported. This is what both hooks rely on to block.
        path = self._write("lib/a.dart", "// uses colour here\n")
        self.assertEqual(self._uk_words([path]), ["colour"])

    def test_clean_dart_file_is_silent(self) -> None:
        path = self._write("lib/b.dart", "// uses color here\n")
        self.assertEqual(self._uk_words([path]), [])

    def test_non_scannable_extension_is_skipped(self) -> None:
        # A ``.txt`` is outside _SCAN_EXTENSIONS — forwarding it from a
        # hook must not crash or flag.
        path = self._write("notes.txt", "favour and colour\n")
        self.assertEqual(self._uk_words([path]), [])

    def test_skip_file_name_is_exempt(self) -> None:
        # The scanner's own dictionary file references British forms
        # verbatim; passing it explicitly must stay silent.
        path = self._write(
            "_us_spelling.py", "x = 'colour'  # dictionary key\n"
        )
        self.assertEqual(self._uk_words([path]), [])

    def test_plans_history_is_exempt(self) -> None:
        # Archived plan docs are frozen prose; the hook must not block a
        # commit that merely touches one.
        path = self._write(
            "plans/history/2026.06/note.md", "we cancelled it\n"
        )
        self.assertEqual(self._uk_words([path]), [])

    def test_missing_path_is_skipped(self) -> None:
        # A staged deletion / renamed-away path no longer exists on disk.
        # scan_paths must skip it rather than raise.
        missing = self._root / "lib" / "gone.dart"
        self.assertEqual(self._uk_words([missing]), [])


class TestGeneratedDartMapParity(unittest.TestCase):
    """Guard that the generated Dart spelling map stays in sync with UK_TO_US.

    The prefer_us_english_spelling lint rule consumes a Dart copy of the
    canonical dictionary. If `UK_TO_US` changes and the generator is not
    re-run, this test fails so the stale file cannot ship.
    """

    def test_committed_dart_file_matches_generator_output(self) -> None:
        from pathlib import Path

        from scripts.generate_us_english_rule_data import (
            render_dart,
            _OUTPUT_REL,
            _REPO_ROOT,
        )

        committed = (_REPO_ROOT / _OUTPUT_REL).read_text(encoding="utf-8")
        expected = render_dart()
        self.assertEqual(
            committed,
            expected,
            "lib/src/rules/data/uk_to_us_spellings.dart is stale. "
            "Run: py -3 scripts/generate_us_english_rule_data.py",
        )


if __name__ == "__main__":
    unittest.main()
