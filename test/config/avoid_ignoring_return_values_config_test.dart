import 'package:saropa_lints/src/config/avoid_ignoring_return_values_config.dart';
import 'package:test/test.dart';

/// Tests for [loadAvoidIgnoringReturnValuesConfig] — parsing
/// `avoid_ignoring_return_values: safe_to_ignore:` from
/// analysis_options_custom.yaml content.
void main() {
  // Reset before each test so state doesn't leak between cases.
  setUp(() {
    userSafeToIgnoreMethods = <String>{};
  });

  test('null content yields empty set', () {
    loadAvoidIgnoringReturnValuesConfig(null);
    expect(userSafeToIgnoreMethods, isEmpty);
  });

  test('empty content yields empty set', () {
    loadAvoidIgnoringReturnValuesConfig('');
    expect(userSafeToIgnoreMethods, isEmpty);
  });

  test('missing section key yields empty set', () {
    loadAvoidIgnoringReturnValuesConfig('max_issues: 500\noutput: both');
    expect(userSafeToIgnoreMethods, isEmpty);
  });

  test('missing safe_to_ignore sub-key yields empty set', () {
    loadAvoidIgnoringReturnValuesConfig(
      'avoid_ignoring_return_values:\n'
      '  enabled: true\n',
    );
    expect(userSafeToIgnoreMethods, isEmpty);
  });

  test('single method name is parsed', () {
    loadAvoidIgnoringReturnValuesConfig(
      'avoid_ignoring_return_values:\n'
      '  safe_to_ignore:\n'
      '    - computeHash\n',
    );
    expect(userSafeToIgnoreMethods, {'computeHash'});
  });

  test('multiple method names are parsed', () {
    loadAvoidIgnoringReturnValuesConfig(
      'avoid_ignoring_return_values:\n'
      '  safe_to_ignore:\n'
      '    - computeHash\n'
      '    - fireEvent\n'
      '    - _privateHelper\n',
    );
    expect(userSafeToIgnoreMethods, {
      'computeHash',
      'fireEvent',
      '_privateHelper',
    });
  });

  test('quoted method names are accepted', () {
    loadAvoidIgnoringReturnValuesConfig(
      'avoid_ignoring_return_values:\n'
      '  safe_to_ignore:\n'
      "    - 'computeHash'\n"
      '    - "fireEvent"\n',
    );
    expect(userSafeToIgnoreMethods, {'computeHash', 'fireEvent'});
  });

  test('parsing stops at non-list line', () {
    // The `other_key:` line ends the list — only items before it are parsed.
    loadAvoidIgnoringReturnValuesConfig(
      'avoid_ignoring_return_values:\n'
      '  safe_to_ignore:\n'
      '    - computeHash\n'
      'other_key:\n'
      '    - shouldNotAppear\n',
    );
    expect(userSafeToIgnoreMethods, {'computeHash'});
  });

  test('blank lines within the list are skipped', () {
    loadAvoidIgnoringReturnValuesConfig(
      'avoid_ignoring_return_values:\n'
      '  safe_to_ignore:\n'
      '    - computeHash\n'
      '\n'
      '    - fireEvent\n',
    );
    expect(userSafeToIgnoreMethods, {'computeHash', 'fireEvent'});
  });

  test('section among other config lines', () {
    loadAvoidIgnoringReturnValuesConfig(
      'max_issues: 500\n'
      'avoid_ignoring_return_values:\n'
      '  safe_to_ignore:\n'
      '    - computeHash\n'
      'output: both\n',
    );
    expect(userSafeToIgnoreMethods, {'computeHash'});
  });

  test('YAML comments between list items are skipped', () {
    loadAvoidIgnoringReturnValuesConfig(
      'avoid_ignoring_return_values:\n'
      '  safe_to_ignore:\n'
      '    - computeHash\n'
      '    # This is a comment explaining the next entry.\n'
      '    - fireEvent\n',
    );
    expect(userSafeToIgnoreMethods, {'computeHash', 'fireEvent'});
  });

  test('previous state is replaced on reload', () {
    // Simulate first load.
    loadAvoidIgnoringReturnValuesConfig(
      'avoid_ignoring_return_values:\n'
      '  safe_to_ignore:\n'
      '    - oldMethod\n',
    );
    expect(userSafeToIgnoreMethods, {'oldMethod'});

    // Second load replaces — oldMethod should not persist.
    loadAvoidIgnoringReturnValuesConfig(
      'avoid_ignoring_return_values:\n'
      '  safe_to_ignore:\n'
      '    - newMethod\n',
    );
    expect(userSafeToIgnoreMethods, {'newMethod'});
    expect(userSafeToIgnoreMethods, isNot(contains('oldMethod')));
  });
}
