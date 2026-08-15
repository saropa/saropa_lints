import 'package:saropa_lints/src/rules/packages/firebase_rules.dart';
import 'package:test/test.dart';
import '../../support/resolved_rule_harness.dart';

/// Regression coverage for App Check activation deferred to a sibling
/// top-level function (bugs/require_firebase_app_check_production_false_positive_activation_in_separate_function.md).
void main() {
  group('RequireFirebaseAppCheckProductionRule', () {
    test(
      'does not fire when activate() is in a separate top-level function',
      () async {
        final diags = await runRuleResolved(
          RequireFirebaseAppCheckProductionRule(),
          '''
// uses firebase
class Firebase { static Future<void> initializeApp() async {} }
class FirebaseAppCheck {
  static FirebaseAppCheck get instance => FirebaseAppCheck();
  Future<void> activate() async {}
}

Future<void> main() async {
  await Firebase.initializeApp();
  scheduleStartupTask(initAppCheckLater);
}

Future<void> initAppCheckLater() async {
  await FirebaseAppCheck.instance.activate();
}

void scheduleStartupTask(Future<void> Function() task) {}
''',
        );
        expect(diags, isEmpty);
      },
    );

    test('fires when no activation exists anywhere in the file', () async {
      final diags = await runRuleResolved(
        RequireFirebaseAppCheckProductionRule(),
        '''
// uses firebase
class Firebase { static Future<void> initializeApp() async {} }

Future<void> main() async {
  await Firebase.initializeApp();
}
''',
      );
      expect(
        diags.map((d) => d.ruleName),
        contains('require_firebase_app_check_production'),
      );
    });

    test(
      'still fires when the activating function is never called (dead code)',
      () async {
        final diags = await runRuleResolved(
          RequireFirebaseAppCheckProductionRule(),
          '''
// uses firebase
class Firebase { static Future<void> initializeApp() async {} }
class FirebaseAppCheck {
  static FirebaseAppCheck get instance => FirebaseAppCheck();
  Future<void> activate() async {}
}

Future<void> main() async {
  await Firebase.initializeApp();
}

// Never referenced from anywhere — dead code, not a real activation path.
Future<void> _unusedInitAppCheck() async {
  await FirebaseAppCheck.instance.activate();
}
''',
        );
        expect(
          diags.map((d) => d.ruleName),
          contains('require_firebase_app_check_production'),
        );
      },
    );

    test('still fires when AppCheck is only mentioned in a comment', () async {
      final diags = await runRuleResolved(
        RequireFirebaseAppCheckProductionRule(),
        '''
// uses firebase
// TODO: consider FirebaseAppCheck activation later
class Firebase { static Future<void> initializeApp() async {} }

Future<void> main() async {
  await Firebase.initializeApp();
}
''',
      );
      expect(
        diags.map((d) => d.ruleName),
        contains('require_firebase_app_check_production'),
      );
    });
  });

  group('RequireFirebaseAppCheckRule', () {
    test(
      'does not fire when activate() is in a separate top-level function',
      () async {
        final diags = await runRuleResolved(RequireFirebaseAppCheckRule(), '''
class Firebase { static Future<void> initializeApp() async {} }
class FirebaseAppCheck {
  static FirebaseAppCheck get instance => FirebaseAppCheck();
  Future<void> activate() async {}
}

Future<void> main() async {
  await Firebase.initializeApp();
  scheduleStartupTask(initAppCheckLater);
}

Future<void> initAppCheckLater() async {
  await FirebaseAppCheck.instance.activate();
}

void scheduleStartupTask(Future<void> Function() task) {}
''');
        expect(diags, isEmpty);
      },
    );

    test('fires when no activation exists anywhere in the file', () async {
      final diags = await runRuleResolved(RequireFirebaseAppCheckRule(), '''
// uses firebase
class Firebase { static Future<void> initializeApp() async {} }

Future<void> main() async {
  await Firebase.initializeApp();
}
''');
      expect(
        diags.map((d) => d.ruleName),
        contains('require_firebase_app_check'),
      );
    });
  });
}
