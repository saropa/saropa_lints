import 'package:saropa_lints/src/rules/packages/firebase_rules.dart';
import 'package:test/test.dart';
import '../../support/resolved_rule_harness.dart';
import '../../support/syntactic_rule_harness.dart';

/// Regression coverage for a private Firebase wrapper whose callers own the
/// try-catch
/// (plans/history/2026.11/2026.11.26/require_firebase_error_handling_false_positive_private_helper_callers_catch.md).
///
/// Each case runs on BOTH passes: the IDE plugin is resolved, the default
/// `scan` is syntactic, and the caller trace is name-based so it must agree
/// on both.
void main() {
  // Local stand-in: the rule matches the call target's source text, so the
  // Firebase package does not need to resolve.
  const String firebaseStub = '''
class FirebaseMessaging {
  static final FirebaseMessaging instance = FirebaseMessaging();
  Future<void> setAutoInitEnabled(bool enabled) async {}
}
''';

  /// Rule codes reported for [body] on the resolved and syntactic passes.
  Future<List<Set<String>>> codesBothPasses(String body) async {
    final String code = '$firebaseStub\n$body';
    final resolved = await runRuleResolved(
      RequireFirebaseErrorHandlingRule(),
      code,
    );
    final syntactic = runRuleSyntactic(
      RequireFirebaseErrorHandlingRule(),
      code,
    );
    return <Set<String>>[
      resolved.map((d) => d.ruleName).toSet(),
      syntactic.map((d) => d.ruleName).toSet(),
    ];
  }

  void expectSilent(List<Set<String>> codes) {
    expect(codes[0], isEmpty, reason: 'resolved pass');
    expect(codes[1], isEmpty, reason: 'syntactic pass');
  }

  void expectReported(List<Set<String>> codes) {
    expect(
      codes[0],
      contains('require_firebase_error_handling'),
      reason: 'resolved pass',
    );
    expect(
      codes[1],
      contains('require_firebase_error_handling'),
      reason: 'syntactic pass',
    );
  }

  group('RequireFirebaseErrorHandlingRule - guarded private helpers', () {
    test(
      'private method, every direct caller awaits inside try-catch',
      () async {
        expectSilent(
          await codesBothPasses('''
class Policy {
  static Future<void> onDisconnect() async {
    try {
      await _setAutoInit(isEnabled: false);
    } on Object catch (e) {
      print(e);
    }
  }

  /// Wraps [_setAutoInit] for documentation only.
  static Future<void> _setAutoInit({required bool isEnabled}) async {
    await FirebaseMessaging.instance.setAutoInitEnabled(isEnabled);
  }
}
'''),
        );
      },
    );

    test('@visibleForTesting function field seam, callers guarded', () async {
      expectSilent(
        await codesBothPasses('''
import 'package:meta/meta.dart';

class Policy {
  @visibleForTesting
  static Future<void> Function({required bool isEnabled}) setAutoInit =
      _setAutoInit;

  static Future<void> onDisconnect() async {
    try {
      await setAutoInit(isEnabled: false);
    } on Object catch (e) {
      print(e);
    }
  }

  static Future<void> _setAutoInit({required bool isEnabled}) async {
    await FirebaseMessaging.instance.setAutoInitEnabled(isEnabled);
  }
}
'''),
      );
    });

    test('private function field seam, callers guarded', () async {
      expectSilent(
        await codesBothPasses('''
class Policy {
  static Future<void> Function() _seam = _disable;

  static Future<void> onDisconnect() async {
    try {
      await Policy._seam();
    } catch (e) {
      print(e);
    }
  }

  static Future<void> _disable() async {
    await FirebaseMessaging.instance.setAutoInitEnabled(false);
  }
}
'''),
      );
    });

    test('still reports: one caller is not inside a try', () async {
      expectReported(
        await codesBothPasses('''
class Policy {
  static Future<void> onDisconnect() async {
    try {
      await _setAutoInit(false);
    } catch (e) {
      print(e);
    }
  }

  static Future<void> onLogout() async {
    await _setAutoInit(false);
  }

  static Future<void> _setAutoInit(bool v) async {
    await FirebaseMessaging.instance.setAutoInitEnabled(v);
  }
}
'''),
      );
    });

    test(
      'still reports: caller does not await (error escapes the try)',
      () async {
        expectReported(
          await codesBothPasses('''
class Policy {
  static void onDisconnect() {
    try {
      _setAutoInit(false);
    } catch (e) {
      print(e);
    }
  }

  static Future<void> _setAutoInit(bool v) async {
    await FirebaseMessaging.instance.setAutoInitEnabled(v);
  }
}
'''),
        );
      },
    );

    test('still reports: try has only finally, no catch', () async {
      expectReported(
        await codesBothPasses('''
class Policy {
  static Future<void> onDisconnect() async {
    try {
      await _setAutoInit(false);
    } finally {
      print('done');
    }
  }

  static Future<void> _setAutoInit(bool v) async {
    await FirebaseMessaging.instance.setAutoInitEnabled(v);
  }
}
'''),
      );
    });

    test(
      'still reports: public seam field without @visibleForTesting',
      () async {
        // The bug's reproducer as written: a public field can be invoked from
        // any other library, so its callers cannot be traced here.
        expectReported(
          await codesBothPasses('''
class Policy {
  static Future<void> Function({required bool isEnabled}) setAutoInit =
      _setAutoInit;

  static Future<void> onDisconnect() async {
    try {
      await setAutoInit(isEnabled: false);
    } on Object catch (e) {
      print(e);
    }
  }

  static Future<void> _setAutoInit({required bool isEnabled}) async {
    await FirebaseMessaging.instance.setAutoInitEnabled(isEnabled);
  }
}
'''),
        );
      },
    );

    test('still reports: tear-off passed as an argument', () async {
      expectReported(
        await codesBothPasses('''
class Policy {
  static Future<void> onDisconnect() async {
    try {
      await _setAutoInit(false);
    } catch (e) {
      print(e);
    }
    schedule(_setAutoInit);
  }

  static void schedule(Future<void> Function(bool) task) {}

  static Future<void> _setAutoInit(bool v) async {
    await FirebaseMessaging.instance.setAutoInitEnabled(v);
  }
}
'''),
      );
    });

    test('still reports: public helper (callers in other libraries)', () async {
      expectReported(
        await codesBothPasses('''
class Policy {
  static Future<void> onDisconnect() async {
    try {
      await setAutoInit(false);
    } catch (e) {
      print(e);
    }
  }

  static Future<void> setAutoInit(bool v) async {
    await FirebaseMessaging.instance.setAutoInitEnabled(v);
  }
}
'''),
      );
    });

    test('still reports: private helper with no callers', () async {
      expectReported(
        await codesBothPasses('''
class Policy {
  static Future<void> _setAutoInit(bool v) async {
    await FirebaseMessaging.instance.setAutoInitEnabled(v);
  }
}
'''),
      );
    });

    test('still reports: part file (callers may be in the library)', () {
      final diags = runRuleSyntactic(RequireFirebaseErrorHandlingRule(), '''
part of 'policy.dart';

class Policy {
  static Future<void> onDisconnect() async {
    try {
      await _setAutoInit(false);
    } catch (e) {
      print(e);
    }
  }

  static Future<void> _setAutoInit(bool v) async {
    await FirebaseMessaging.instance.setAutoInitEnabled(v);
  }
}
''');
      expect(
        diags.map((d) => d.ruleName),
        contains('require_firebase_error_handling'),
      );
    });

    // Name-matching soundness: the reference scan matches by name, a
    // superset of the real calls. An unguarded call to ANY same-named member
    // (another class, a subclass override, a mixin, an extension or an
    // interface implementation) must keep the report.
    const Map<String, String> sameNameCases = <String, String>{
      'unguarded call to a same-named member of another class': '''
class Other {
  Future<void> _setAutoInit(bool v) async {}
  Future<void> run() async { await _setAutoInit(true); }
}
''',
      'unguarded super call from a same-file subclass override': '''
class Child extends Policy {
  @override
  Future<void> _setAutoInit(bool v) async { await super._setAutoInit(v); }
}
''',
      'unguarded call from a class mixing in a same-named member': '''
mixin M { Future<void> _setAutoInit(bool v) async {} }
class UsesMixin with M {
  Future<void> run() async { await _setAutoInit(true); }
}
''',
      'unguarded call through a same-named extension member': '''
extension on Object { Future<void> _setAutoInit(bool v) async {} }
Future<void> run(Object o) async { await o._setAutoInit(true); }
''',
      'unguarded call on an interface implementation': '''
class Impl implements Policy {
  @override
  Future<void> _setAutoInit(bool v) async {}
}
Future<void> run(Impl i) async { await i._setAutoInit(true); }
''',
    };
    for (final MapEntry<String, String> entry in sameNameCases.entries) {
      test('still reports: ${entry.key}', () async {
        expectReported(
          await codesBothPasses('''
class Policy {
  Future<void> onDisconnect() async {
    try {
      await _setAutoInit(false);
    } catch (e) {
      print(e);
    }
  }

  Future<void> _setAutoInit(bool v) async {
    await FirebaseMessaging.instance.setAutoInitEnabled(v);
  }
}
${entry.value}'''),
        );
      });
    }

    test(
      'control: the same Policy with no other references is silent',
      () async {
        expectSilent(
          await codesBothPasses('''
class Policy {
  Future<void> onDisconnect() async {
    try {
      await _setAutoInit(false);
    } catch (e) {
      print(e);
    }
  }

  Future<void> _setAutoInit(bool v) async {
    await FirebaseMessaging.instance.setAutoInitEnabled(v);
  }
}
'''),
        );
      },
    );

    test('still reports: unguarded direct Firebase call', () async {
      expectReported(
        await codesBothPasses('''
Future<void> disable() async {
  await FirebaseMessaging.instance.setAutoInitEnabled(false);
}
'''),
      );
    });
  });
}
