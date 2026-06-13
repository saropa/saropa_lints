/// Module overview (comment coverage pass).
/// comment-coverage: module overview (batch).
///
/// Analyzer-backed tests for `rule_packs_pubspec_markers_test` (rule packs pubspec markers).
///
/// Uses `// LINT` markers and `example/` fixtures per CONTRIBUTING.md.
import 'package:saropa_lints/src/config/rule_packs.dart';
import 'package:test/test.dart';

// rule_packs: pubspec marker keys align with pack ids for detection.

void main() {
  test('every pack id has a pubspec markers map entry', () {
    expect(
      kRulePackPubspecMarkers.keys.toSet(),
      equals(kRulePackRuleCodes.keys.toSet()),
    );
  });

  // Every pack now gates on at least one pubspec marker. The former
  // `package_specific` ("Mixed packages") pack was the sole exception (empty
  // marker set, opt-in only); it was split into per-package gated packs, so the
  // exemption no longer exists and the invariant is now universal.
  test('every pack declares at least one pubspec marker', () {
    for (final entry in kRulePackPubspecMarkers.entries) {
      expect(
        entry.value,
        isNotEmpty,
        reason: '${entry.key} should list pubspec dependency name(s)',
      );
    }
  });

  test('isRulePackSuggestedByPubspec detects riverpod', () {
    const pubspec = '''
name: demo
dependencies:
  flutter_riverpod: ^2.0.0
''';
    expect(isRulePackSuggestedByPubspec('riverpod', pubspec), isTrue);
    expect(isRulePackSuggestedByPubspec('drift', pubspec), isFalse);
  });

  test('isRulePackSuggestedByPubspec ignores commented dependency lines', () {
    const pubspec = '''
name: demo
dependencies:
  # flutter_riverpod: ^2.0.0
  path: any
''';
    expect(isRulePackSuggestedByPubspec('riverpod', pubspec), isFalse);
  });

  test('isRulePackSuggestedByPubspec does not match longer package names', () {
    const pubspec = '''
name: demo
dependencies:
  my_flutter_riverpod_fork: any
''';
    expect(isRulePackSuggestedByPubspec('riverpod', pubspec), isFalse);
  });
}
