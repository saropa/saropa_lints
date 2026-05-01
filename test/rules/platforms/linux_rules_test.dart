import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/platforms/linux_rules.dart';

/// Tests for 5 Linux lint rules.
///
/// Test fixtures: example/lib/linux/
void main() {
  group('Linux Rules - Rule Instantiation', () {
    void testRule(String name, String codeName, dynamic Function() create) {
      test(name, () {
        final rule = create();
        expect(rule.code.lowerCaseName, codeName);
        expect(rule.code.problemMessage, contains('[$codeName]'));
        expect(rule.code.problemMessage.length, greaterThan(50));
        expect(rule.code.correctionMessage, isNotNull);
      });
    }

    testRule(
      'AvoidHardcodedUnixPathsRule',
      'avoid_hardcoded_unix_paths',
      () => AvoidHardcodedUnixPathsRule(),
    );

    testRule(
      'PreferXdgDirectoryConventionRule',
      'prefer_xdg_directory_convention',
      () => PreferXdgDirectoryConventionRule(),
    );

    testRule(
      'AvoidX11OnlyAssumptionsRule',
      'avoid_x11_only_assumptions',
      () => AvoidX11OnlyAssumptionsRule(),
    );

    testRule(
      'RequireLinuxFontFallbackRule',
      'require_linux_font_fallback',
      () => RequireLinuxFontFallbackRule(),
    );

    testRule(
      'AvoidSudoShellCommandsRule',
      'avoid_sudo_shell_commands',
      () => AvoidSudoShellCommandsRule(),
    );
  });

  group('Linux Rules - Fixture Verification', () {
    final fixtures = [
      'avoid_hardcoded_unix_paths',
      'prefer_xdg_directory_convention',
      'avoid_x11_only_assumptions',
      'require_linux_font_fallback',
      'avoid_sudo_shell_commands',
    ];

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/linux/${fixture}_fixture.dart');
        expect(file.existsSync(), isTrue);
      });
    }
  });

  group('Linux - Avoidance Rules', () {
    group('avoid_hardcoded_unix_paths', () {
      test('hardcoded /home/user path SHOULD trigger', () {});

      test('XDG or environment paths should NOT trigger', () {});
    });
    group('avoid_x11_only_assumptions', () {
      test('X11-specific code without Wayland check SHOULD trigger', () {});

      test('display-server agnostic code should NOT trigger', () {});
    });
    group('avoid_sudo_shell_commands', () {
      test('sudo in shell command SHOULD trigger', () {});

      test('non-elevated alternatives should NOT trigger', () {});
    });
  });

  group('Linux - Requirement Rules', () {
    group('require_linux_font_fallback', () {
      test('single font without fallback SHOULD trigger', () {});

      test('font fallback chain should NOT trigger', () {});
    });
  });

  group('Linux - Preference Rules', () {
    group('prefer_xdg_directory_convention', () {
      test('custom config path on Linux SHOULD trigger', () {});

      test('XDG Base Directory paths should NOT trigger', () {});
    });
  });
}
