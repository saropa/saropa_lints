/// Behavior tests for the short-callee proof of
/// `require_notification_for_long_tasks`.
library;

import 'dart:io';

import 'package:saropa_lints/src/rules/platforms/ios_platform_lifecycle_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

/// Number of diagnostics the rule reports for [code].
Future<int> _count(String code) async {
  final diags = await runRuleResolved(
    RequireNotificationForLongTasksRule(),
    code,
  );
  return diags.length;
}

/// A caller of `syncAll` declared by [declarations].
String _calling(String declarations) =>
    '$declarations\nFuture<void> caller() async { await syncAll(); }\n';

void main() {
  group('provably short generic callee is not reported', () {
    test('sequential same-file writes', () async {
      expect(
        await _count('''
Future<void> syncWidgetA() async {}
Future<void> syncWidgetB() async { print('b'); }
Future<void> syncAllWidgets() async {
  await syncWidgetA();
  await Future.wait([syncWidgetB()]);
}
Future<void> onLocaleChanged() async { await syncAllWidgets(); }
'''),
        0,
      );
    });

    // Guards the accessor/operator checks against over-reach: plain variable
    // reads and writes, SDK operators and a short private getter stay short.
    test('variable access, SDK operators and a short private getter', () async {
      expect(
        await _count('''
int _count = 0;
final List<int> _ids = [];
int get _total => _count;
Future<void> syncAll() async {
  _count += 1;
  _ids.add(_count);
  _ids[0] = _total;
  final String label = 'n\$_count';
  print(label.length);
}
Future<void> caller() async { await syncAll(); }
'''),
        0,
      );
    });

    test('private instance method', () async {
      expect(
        await _count('''
class A {
  Future<void> _syncAll() async {}
  Future<void> run() async { await _syncAll(); }
}
'''),
        0,
      );
    });
  });

  group('still reported', () {
    const Map<String, String> cases = {
      'loop': 'Future<void> syncAll() async { for (var i = 0; i < 9; i++) {} }',
      'closure iteration':
          'Future<void> syncAll() async { [1].forEach((e) {}); }',
      'tear-off iteration':
          'Future<void> syncAll() async { [1].forEach(print); }',
      'loop in a nested callee':
          'Future<void> a() async { while (true) {} }\n'
          'Future<void> syncAll() async { await a(); }',
      'dart:io call':
          "import 'dart:io';\n"
          'Future<void> syncAll() async { await HttpClient().getUrl(Uri()); }',
      'abstract callee':
          'abstract class Api { Future<void> push(); }\n'
          'Api api() => throw 0;\n'
          'Future<void> syncAll() async { await api().push(); }',
      'awaited stored future':
          'Future<void>? pending;\n'
          'Future<void> syncAll() async { await pending; }',
      'stored future behind a combinator':
          'Future<void> pending = Future.value();\n'
          'Future<void> syncAll() async '
          '{ await pending.timeout(Duration.zero); }',
      'unlisted Future.wait':
          'List<Future<void>> jobs = [];\n'
          'Future<void> syncAll() async { await Future.wait(jobs); }',
      'recursion': 'Future<void> syncAll() async { await syncAll(); }',
      'no body to inspect': 'external Future<void> syncAll();',
      // Getters, setters, operators and constructors run bodies on a
      // plain-looking read, write or `Type()` and must be proven like calls.
      'long getter':
          'int get total { for (var i = 0; i < 9; i++) {} return 0; }\n'
          'Future<void> syncAll() async { print(total); }',
      'long setter':
          'set total(int v) { for (var i = 0; i < v; i++) {} }\n'
          'Future<void> syncAll() async { total = 9; }',
      'user-defined operator':
          'class V { V operator +(V o) => this; }\n'
          'late final V v;\n'
          'Future<void> syncAll() async { v + v; }',
      'user-defined index write':
          'class Store { void operator []=(int i, int v) {} }\n'
          'late final Store store;\n'
          'Future<void> syncAll() async { store[0] = 1; }',
      'non-SDK constructor':
          'class _Job { _Job() { for (var i = 0; i < 9; i++) {} } }\n'
          'Future<void> syncAll() async { _Job(); }',
      'public field that a getter could override':
          'class P { int n = 0; }\n'
          'late final P p;\n'
          'Future<void> syncAll() async { print(p.n); }',
      'dynamic receiver':
          'Future<void> syncAll() async { dynamic d; print(d.items); }',
      'function-typed field called':
          'Future<void> Function() _cb = () async {};\n'
          'Future<void> syncAll() async { await _cb(); }',
      'returned stored future':
          'Future<void> _pending = Future.value();\n'
          'Future<void> _get() => _pending;\n'
          'Future<void> syncAll() async { await _get(); }',
      'stored future wrapped by an SDK constructor':
          'Future<void> _pending = Future.value();\n'
          'Future<void> syncAll() async { await Future.value(_pending); }',
    };

    for (final MapEntry<String, String> entry in cases.entries) {
      test(entry.key, () async {
        // The recursion case reports the inner call as well as the caller.
        expect(await _count(_calling(entry.value)), greaterThan(0));
      });
    }

    test('overridable public instance method', () async {
      expect(
        await _count('''
class A { Future<void> syncAll() async {} }
Future<void> caller(A a) async { await a.syncAll(); }
'''),
        1,
      );
    });

    // A private member is only safe when nothing else in the library can
    // take over the call: a same-file subclass override must be seen.
    test('private method overridden by a same-file subclass', () async {
      expect(
        await _count('''
class _A { Future<void> _syncAll() async {} }
class _B extends _A {
  @override
  Future<void> _syncAll() async { for (var i = 0; i < 9; i++) {} }
}
Future<void> caller(_A a) async { await a._syncAll(); }
'''),
        greaterThan(0),
      );
    });

    test('private method answerable by a same-file noSuchMethod', () async {
      expect(
        await _count('''
class _A { Future<void> _syncAll() async {} }
class _C implements _A {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}
Future<void> caller(_A a) async { await a._syncAll(); }
'''),
        1,
      );
    });

    // The BAD fixture must actually fire: a skip signal anywhere in its text
    // (comments included) would silence the rule for the whole file.
    test('BAD fixture reports each expect_lint call', () async {
      final String source = File(
        'example/lib/ios/require_notification_for_long_tasks_fixture.dart',
      ).readAsStringSync();
      expect(await _count(source), 3);
    });

    test('callee that is not declared in this file', () async {
      expect(
        await _count('Future<void> caller(d) async { await d.syncAll(); }'),
        1,
      );
    });

    test('transfer names are not disproved by an empty body', () async {
      expect(
        await _count('''
Future<void> uploadLargeFile() async {}
Future<void> syncAllAndUploadFile() async {}
Future<void> caller() async {
  await uploadLargeFile();
  await syncAllAndUploadFile();
}
'''),
        2,
      );
    });
  });
}
