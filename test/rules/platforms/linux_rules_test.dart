import 'dart:io';

import 'package:test/test.dart';

import 'package:saropa_lints/src/rules/platforms/linux_rules.dart';
import '../../helpers/fixture_discovery.dart';

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
    final fixtureDir = Directory('example/lib/linux');
    final fixtures = discoverFixtures(fixtureDir);
    test('fixture directory exists and is not empty', () {
      expect(fixtureDir.existsSync(), isTrue);

      expect(fixtures, isNotEmpty);
    });

    for (final fixture in fixtures) {
      test('$fixture fixture exists', () {
        final file = File('example/lib/linux/${fixture}_fixture.dart');

        expect(file.existsSync(), isTrue);
      });
    }
  });
}
