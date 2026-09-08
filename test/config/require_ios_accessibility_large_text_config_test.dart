import 'package:saropa_lints/src/config/require_ios_accessibility_large_text_config.dart';
import 'package:test/test.dart';

/// Tests for [loadRequireIosAccessibilityLargeTextConfig] — parsing
/// `require_ios_accessibility_large_text: scaling_aware:` from
/// analysis_options_custom.yaml content.
void main() {
  // Reset before each test so state doesn't leak between cases.
  setUp(() {
    userScalingAwareMethods = <String>{};
  });

  test('null content yields empty set', () {
    loadRequireIosAccessibilityLargeTextConfig(null);
    expect(userScalingAwareMethods, isEmpty);
  });

  test('empty content yields empty set', () {
    loadRequireIosAccessibilityLargeTextConfig('');
    expect(userScalingAwareMethods, isEmpty);
  });

  test('missing section key yields empty set', () {
    loadRequireIosAccessibilityLargeTextConfig('max_issues: 500\noutput: both');
    expect(userScalingAwareMethods, isEmpty);
  });

  test('missing scaling_aware sub-key yields empty set', () {
    loadRequireIosAccessibilityLargeTextConfig(
      'require_ios_accessibility_large_text:\n'
      '  enabled: true\n',
    );
    expect(userScalingAwareMethods, isEmpty);
  });

  test('single getter name is parsed', () {
    loadRequireIosAccessibilityLargeTextConfig(
      'require_ios_accessibility_large_text:\n'
      '  scaling_aware:\n'
      '    - size\n',
    );
    expect(userScalingAwareMethods, {'size'});
  });

  test('multiple getter names are parsed', () {
    loadRequireIosAccessibilityLargeTextConfig(
      'require_ios_accessibility_large_text:\n'
      '  scaling_aware:\n'
      '    - size\n'
      '    - scaledFontSize\n'
      '    - _dynamicSize\n',
    );
    expect(
      userScalingAwareMethods,
      {'size', 'scaledFontSize', '_dynamicSize'},
    );
  });

  test('quoted names are accepted', () {
    loadRequireIosAccessibilityLargeTextConfig(
      'require_ios_accessibility_large_text:\n'
      '  scaling_aware:\n'
      "    - 'size'\n"
      '    - "scaledFontSize"\n',
    );
    expect(userScalingAwareMethods, {'size', 'scaledFontSize'});
  });

  test('parsing stops at non-list line', () {
    // The `other_key:` line ends the list — only items before it are parsed.
    loadRequireIosAccessibilityLargeTextConfig(
      'require_ios_accessibility_large_text:\n'
      '  scaling_aware:\n'
      '    - size\n'
      'other_key:\n'
      '    - shouldNotAppear\n',
    );
    expect(userScalingAwareMethods, {'size'});
  });

  test('blank lines within the list are skipped', () {
    loadRequireIosAccessibilityLargeTextConfig(
      'require_ios_accessibility_large_text:\n'
      '  scaling_aware:\n'
      '    - size\n'
      '\n'
      '    - scaledFontSize\n',
    );
    expect(userScalingAwareMethods, {'size', 'scaledFontSize'});
  });

  test('section among other config lines', () {
    loadRequireIosAccessibilityLargeTextConfig(
      'max_issues: 500\n'
      'require_ios_accessibility_large_text:\n'
      '  scaling_aware:\n'
      '    - size\n'
      'output: both\n',
    );
    expect(userScalingAwareMethods, {'size'});
  });

  test('previous state is replaced on reload', () {
    // Simulate first load.
    loadRequireIosAccessibilityLargeTextConfig(
      'require_ios_accessibility_large_text:\n'
      '  scaling_aware:\n'
      '    - oldGetter\n',
    );
    expect(userScalingAwareMethods, {'oldGetter'});

    // Second load replaces — oldGetter should not persist.
    loadRequireIosAccessibilityLargeTextConfig(
      'require_ios_accessibility_large_text:\n'
      '  scaling_aware:\n'
      '    - newGetter\n',
    );
    expect(userScalingAwareMethods, {'newGetter'});
    expect(userScalingAwareMethods, isNot(contains('oldGetter')));
  });
}
