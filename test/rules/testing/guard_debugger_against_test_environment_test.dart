import 'dart:io';

import 'package:saropa_lints/src/rules/testing/debug_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

/// Tests for the `guard_debugger_against_test_environment` lint rule.
///
/// Test fixture:
/// example/lib/debug/guard_debugger_against_test_environment_fixture.dart
///
/// The detection groups below run the rule for real through
/// `resolved_rule_harness.dart`, resolving `dart:developer`'s `debugger()`
/// against the SDK so the library-URI check in `_isDebuggerElement` is
/// actually exercised, not just asserted.
const String _ruleCode = 'guard_debugger_against_test_environment';

void main() {
  group('GuardDebuggerAgainstTestEnvironmentRule - Rule Instantiation', () {
    test('GuardDebuggerAgainstTestEnvironmentRule', () {
      final rule = GuardDebuggerAgainstTestEnvironmentRule();
      expect(rule.code.lowerCaseName, _ruleCode);
      expect(rule.code.problemMessage, contains('[$_ruleCode]'));
      expect(rule.code.problemMessage.length, greaterThan(100));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('GuardDebuggerAgainstTestEnvironmentRule - Fixture Verification', () {
    test('fixture file exists', () {
      final file = File(
        'example/lib/debug/'
        'guard_debugger_against_test_environment_fixture.dart',
      );

      expect(file.existsSync(), isTrue);
    });
  });

  group('GuardDebuggerAgainstTestEnvironmentRule - BAD cases fire', () {
    test('flags a bare, unguarded debugger() call', () async {
      const code = '''
import 'dart:developer';

void someMethod() {
  debugger();
}
''';
      final codes = await reportedRuleCodes(
        GuardDebuggerAgainstTestEnvironmentRule(),
        code,
      );
      expect(codes.contains(_ruleCode), isTrue);
    });

    test('flags debugger() guarded only by kDebugMode', () async {
      // The trap this rule exists to catch: flutter test runs in debug
      // mode, so kDebugMode is not a test-environment guard at all.
      const code = '''
import 'dart:developer';

const bool kDebugMode = true;

void someMethod() {
  if (kDebugMode) {
    debugger();
  }
}
''';
      final codes = await reportedRuleCodes(
        GuardDebuggerAgainstTestEnvironmentRule(),
        code,
      );
      expect(codes.contains(_ruleCode), isTrue);
    });

    test('flags debugger() in the else branch of a negated guard '
        '(runs exactly when isTestEnvironment is true)', () async {
      const code = '''
import 'dart:developer';

class PlatformUtils {
  static bool isTestEnvironment = false;
}

void someMethod() {
  if (!PlatformUtils.isTestEnvironment) {
    // safe path
  } else {
    debugger();
  }
}
''';
      final codes = await reportedRuleCodes(
        GuardDebuggerAgainstTestEnvironmentRule(),
        code,
      );
      expect(codes.contains(_ruleCode), isTrue);
    });
  });

  group('GuardDebuggerAgainstTestEnvironmentRule - library-URI check', () {
    test(
      'does not flag an unrelated user-defined debugger() function',
      () async {
        // Proves _isDebuggerElement's dart:developer library-URI check is
        // actually load-bearing: a locally declared `debugger()` resolves
        // to a different element than the SDK one and must stay silent.
        const code = '''
void debugger() {}

void someMethod() {
  debugger();
}
''';
        final codes = await reportedRuleCodes(
          GuardDebuggerAgainstTestEnvironmentRule(),
          code,
        );
        expect(codes.contains(_ruleCode), isFalse);
      },
    );
  });

  group('GuardDebuggerAgainstTestEnvironmentRule - GOOD cases stay silent', () {
    test('does not flag a direct negated isTestEnvironment guard', () async {
      const code = '''
import 'dart:developer';

class PlatformUtils {
  static bool isTestEnvironment = false;
}

void someMethod() {
  if (!PlatformUtils.isTestEnvironment) {
    debugger();
  }
}
''';
      final codes = await reportedRuleCodes(
        GuardDebuggerAgainstTestEnvironmentRule(),
        code,
      );
      expect(codes.contains(_ruleCode), isFalse);
    });

    test(
      'does not flag a compound condition (isBreak && !isTestEnvironment)',
      () async {
        const code = '''
import 'dart:developer';

class PlatformUtils {
  static bool isTestEnvironment = false;
}

void someMethod(bool isBreak) {
  if (isBreak && !PlatformUtils.isTestEnvironment) {
    debugger();
  }
}
''';
        final codes = await reportedRuleCodes(
          GuardDebuggerAgainstTestEnvironmentRule(),
          code,
        );
        expect(codes.contains(_ruleCode), isFalse);
      },
    );

    test('does not flag an inline FLUTTER_TEST environment guard', () async {
      const code = '''
import 'dart:developer';
import 'dart:io';

void someMethod() {
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    debugger();
  }
}
''';
      final codes = await reportedRuleCodes(
        GuardDebuggerAgainstTestEnvironmentRule(),
        code,
      );
      expect(codes.contains(_ruleCode), isFalse);
    });

    test('does not flag a guard higher up the lexical chain', () async {
      const code = '''
import 'dart:developer';

class PlatformUtils {
  static bool isTestEnvironment = false;
}

void someMethod(bool isBreak) {
  if (!PlatformUtils.isTestEnvironment) {
    if (isBreak) {
      debugger();
    }
  }
}
''';
      final codes = await reportedRuleCodes(
        GuardDebuggerAgainstTestEnvironmentRule(),
        code,
      );
      expect(codes.contains(_ruleCode), isFalse);
    });
  });
}
