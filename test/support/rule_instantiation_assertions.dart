// Shared assertion for the "Rule Instantiation" metadata smoke test that
// every rule-category test file carries (see
// scripts/modules/_rule_metrics.py `_compute_rule_instantiation_stats`,
// which flags a category by literal string match for "Rule Instantiation"
// in its test file — replacing a hand-rolled 4-assertion block per rule
// with this call keeps that convention centralized instead of copy-pasted).
library;

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

/// Asserts [rule]'s `LintCode` satisfies the project's message contract:
/// the code name matches [expectedCode], the problem message is prefixed
/// with `[expectedCode]` and exceeds 50 characters, and a correction
/// message is present.
///
/// Call this inside a `group('<category> - Rule Instantiation', ...)`
/// block so the literal marker string that `_rule_metrics.py` scans for
/// is present in the test file.
void assertRuleMetadata(SaropaLintRule rule, String expectedCode) {
  expect(rule.code.lowerCaseName, expectedCode);
  expect(rule.code.problemMessage, contains('[$expectedCode]'));
  expect(rule.code.problemMessage.length, greaterThan(50));
  expect(rule.code.correctionMessage, isNotNull);
}
