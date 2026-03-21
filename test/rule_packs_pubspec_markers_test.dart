import 'package:saropa_lints/src/config/rule_packs.dart';
import 'package:test/test.dart';

void main() {
  test('every pack id has a pubspec markers map entry', () {
    expect(
      kRulePackPubspecMarkers.keys.toSet(),
      equals(kRulePackRuleCodes.keys.toSet()),
    );
  });

  test('packs other than package_specific declare at least one marker', () {
    for (final entry in kRulePackPubspecMarkers.entries) {
      if (entry.key == 'package_specific') continue;
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
