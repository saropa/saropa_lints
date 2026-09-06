#!/usr/bin/env python3
"""
Unit tests for scripts/triage_scan.py.

Run:  python -m pytest scripts/test_triage_scan.py -v
      python scripts/test_triage_scan.py          (unittest runner)

Version:   1.0
Author:    Saropa
Copyright: (c) 2026 Saropa
"""

from __future__ import annotations

import json
import unittest

from triage_scan import (
    _normalize_path,
    _path_matches_dir_set,
    _validate_diagnostics,
    classify_location,
    format_json,
    format_report,
    triage,
)


# --- Helpers -----------------------------------------------------------------

def _diag(
    file_path: str = 'lib/src/foo.dart',
    severity: str = 'WARNING',
    rule_name: str = 'some_rule',
    impact: str | None = None,
    line: int = 1,
    correction: str | None = None,
) -> dict:
    """Build a minimal diagnostic dict matching the scan JSON schema."""
    return {
        'filePath': file_path,
        'line': line,
        'column': 1,
        'endLine': line,
        'endColumn': 20,
        'ruleName': rule_name,
        'severity': severity,
        'impact': impact,
        'problemMessage': f'{rule_name} problem',
        'correctionMessage': correction,
    }


# --- Path classification tests -----------------------------------------------

class TestNormalizePath(unittest.TestCase):
    """Verify backslash-to-forward-slash normalization."""

    def test_backslashes_become_forward(self) -> None:
        self.assertEqual(_normalize_path(r'lib\src\foo.dart'), 'lib/src/foo.dart')

    def test_forward_slashes_unchanged(self) -> None:
        self.assertEqual(_normalize_path('lib/src/foo.dart'), 'lib/src/foo.dart')

    def test_mixed_slashes(self) -> None:
        self.assertEqual(
            _normalize_path(r'lib/src\debug\foo.dart'), 'lib/src/debug/foo.dart',
        )

    def test_windows_drive_letter(self) -> None:
        # Drive letter should not interfere with segment matching.
        result = _normalize_path(r'D:\src\debug\foo.dart')
        self.assertEqual(result, 'D:/src/debug/foo.dart')


class TestPathMatchesDirSet(unittest.TestCase):
    """Verify directory-segment matching."""

    def test_matches_segment(self) -> None:
        self.assertTrue(
            _path_matches_dir_set('lib/debug/foo.dart', {'debug'}),
        )

    def test_no_match_substring(self) -> None:
        # 'debug' in a filename should NOT match — only directory segments.
        self.assertFalse(
            _path_matches_dir_set('lib/debugger_helper.dart', {'debug'}),
        )

    def test_no_match_empty(self) -> None:
        self.assertFalse(
            _path_matches_dir_set('lib/src/foo.dart', {'debug'}),
        )

    def test_windows_absolute_path(self) -> None:
        # Windows absolute path with drive letter.
        self.assertTrue(
            _path_matches_dir_set(
                r'D:\src\dependency_overrides\pkg\lib\foo.dart',
                {'dependency_overrides'},
            ),
        )


class TestClassifyLocation(unittest.TestCase):
    """Verify location classification into forked/dev/app."""

    def test_forked_dir(self) -> None:
        self.assertEqual(
            classify_location(
                'dependency_overrides/pkg/lib/foo.dart',
                {'dependency_overrides'}, {'_dev'},
            ),
            'forked',
        )

    def test_dev_dir(self) -> None:
        self.assertEqual(
            classify_location('_dev/sql_sentinel.dart', set(), {'_dev'}),
            'dev',
        )

    def test_app_code(self) -> None:
        self.assertEqual(
            classify_location(
                'lib/src/foo.dart', {'dependency_overrides'}, {'_dev'},
            ),
            'app',
        )

    def test_forked_takes_priority_over_dev(self) -> None:
        # If a path matches both, forked wins (checked first).
        self.assertEqual(
            classify_location(
                'dependency_overrides/_dev/foo.dart',
                {'dependency_overrides'}, {'_dev'},
            ),
            'forked',
        )


# --- Triage logic tests -----------------------------------------------------

class TestTriage(unittest.TestCase):
    """Verify bucket assignment logic."""

    def test_errors_go_to_p1(self) -> None:
        diags = [_diag(severity='ERROR')]
        result = triage(diags, set(), set())
        self.assertEqual(len(result['p1_errors']), 1)
        self.assertEqual(len(result['p3_individual']), 0)

    def test_forked_goes_to_p5(self) -> None:
        diags = [_diag(file_path='dependency_overrides/pkg/foo.dart')]
        result = triage(diags, {'dependency_overrides'}, set())
        self.assertEqual(len(result['p5_forked']), 1)

    def test_dev_goes_to_p4(self) -> None:
        diags = [_diag(file_path='_dev/tool.dart')]
        result = triage(diags, set(), {'_dev'})
        self.assertEqual(len(result['p4_dev']), 1)

    def test_bulk_threshold_groups_to_p2(self) -> None:
        # 5 diagnostics with the same rule → bulk.
        diags = [_diag(rule_name='same_rule', file_path=f'lib/f{i}.dart')
                 for i in range(5)]
        result = triage(diags, set(), set(), bulk_threshold=5)
        self.assertEqual(len(result['p2_bulk']), 5)
        self.assertEqual(len(result['p3_individual']), 0)

    def test_below_bulk_threshold_stays_p3(self) -> None:
        # 4 diagnostics from the same rule — below default threshold.
        diags = [_diag(rule_name='same_rule', file_path=f'lib/f{i}.dart')
                 for i in range(4)]
        result = triage(diags, set(), set(), bulk_threshold=5)
        self.assertEqual(len(result['p2_bulk']), 0)
        self.assertEqual(len(result['p3_individual']), 4)

    def test_error_in_forked_dir_goes_to_p5_not_p1(self) -> None:
        # Location classification happens before severity — forked wins.
        diags = [_diag(
            file_path='dependency_overrides/pkg/foo.dart', severity='ERROR',
        )]
        result = triage(diags, {'dependency_overrides'}, set())
        self.assertEqual(len(result['p5_forked']), 1)
        self.assertEqual(len(result['p1_errors']), 0)

    def test_empty_diagnostics(self) -> None:
        result = triage([], set(), set())
        for bucket in result.values():
            self.assertEqual(len(bucket), 0)

    def test_mixed_rules_split_bulk_and_individual(self) -> None:
        # 5 from rule_a (bulk) + 2 from rule_b (individual).
        diags = (
            [_diag(rule_name='rule_a', file_path=f'lib/a{i}.dart')
             for i in range(5)]
            + [_diag(rule_name='rule_b', file_path=f'lib/b{i}.dart')
               for i in range(2)]
        )
        result = triage(diags, set(), set(), bulk_threshold=5)
        self.assertEqual(len(result['p2_bulk']), 5)
        self.assertEqual(len(result['p3_individual']), 2)


# --- Formatting tests --------------------------------------------------------

class TestFormatReport(unittest.TestCase):
    """Verify human-readable report output."""

    def test_empty_buckets_show_none(self) -> None:
        buckets = {
            'p1_errors': [], 'p2_bulk': [], 'p3_individual': [],
            'p4_dev': [], 'p5_forked': [],
        }
        report = format_report(buckets, 0)
        self.assertIn('(none)', report)
        self.assertIn('0 total', report)

    def test_p1_entries_show_file_and_rule(self) -> None:
        buckets = {
            'p1_errors': [_diag(
                file_path='lib/foo.dart', severity='ERROR',
                rule_name='bad_rule', line=42,
            )],
            'p2_bulk': [], 'p3_individual': [],
            'p4_dev': [], 'p5_forked': [],
        }
        report = format_report(buckets, 1)
        self.assertIn('foo.dart:42', report)
        self.assertIn('bad_rule', report)
        self.assertIn('ERROR', report)

    def test_p2_shows_site_count(self) -> None:
        diags = [_diag(rule_name='yield_rule', file_path=f'lib/f{i}.dart')
                 for i in range(6)]
        buckets = {
            'p1_errors': [],
            'p2_bulk': diags,
            'p3_individual': [],
            'p4_dev': [], 'p5_forked': [],
        }
        report = format_report(buckets, 6)
        self.assertIn('[6 sites]', report)
        self.assertIn('yield_rule', report)


class TestFormatJson(unittest.TestCase):
    """Verify JSON output structure."""

    def test_valid_json(self) -> None:
        buckets = {
            'p1_errors': [_diag(severity='ERROR')],
            'p2_bulk': [], 'p3_individual': [],
            'p4_dev': [], 'p5_forked': [],
        }
        raw = format_json(buckets, 1)
        data = json.loads(raw)
        self.assertEqual(data['version'], 1)
        self.assertEqual(data['total'], 1)
        self.assertEqual(data['buckets']['p1_errors']['count'], 1)

    def test_bulk_includes_by_rule(self) -> None:
        diags = [_diag(rule_name='r1') for _ in range(3)]
        buckets = {
            'p1_errors': [],
            'p2_bulk': diags,
            'p3_individual': [],
            'p4_dev': [], 'p5_forked': [],
        }
        data = json.loads(format_json(buckets, 3))
        self.assertIn('byRule', data['buckets']['p2_bulk'])
        self.assertEqual(data['buckets']['p2_bulk']['byRule']['r1'], 3)

    def test_forked_includes_by_file(self) -> None:
        diags = [
            _diag(file_path='vendor/a.dart'),
            _diag(file_path='vendor/a.dart'),
            _diag(file_path='vendor/b.dart'),
        ]
        buckets = {
            'p1_errors': [], 'p2_bulk': [], 'p3_individual': [],
            'p4_dev': [],
            'p5_forked': diags,
        }
        data = json.loads(format_json(buckets, 3))
        by_file = data['buckets']['p5_forked']['byFile']
        self.assertEqual(by_file['vendor/a.dart'], 2)
        self.assertEqual(by_file['vendor/b.dart'], 1)


# --- Validation tests --------------------------------------------------------

class TestValidateDiagnostics(unittest.TestCase):
    """Verify missing-key warnings."""

    def test_no_warning_for_complete_diag(self) -> None:
        # Should not raise or print.
        _validate_diagnostics([_diag()])

    def test_warning_for_missing_keys(self) -> None:
        # Diagnostic without required keys — should warn to stderr.
        import io
        import contextlib
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr):
            _validate_diagnostics([{'line': 1}])
        output = stderr.getvalue()
        self.assertIn('missing required keys', output)
        self.assertIn('filePath', output)

    def test_empty_list_no_crash(self) -> None:
        _validate_diagnostics([])


if __name__ == '__main__':
    unittest.main()
