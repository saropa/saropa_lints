// Regression tests for `no_equal_nested_conditions`: a condition re-checked
// after a suspension is a required guard unless nothing can change it.
library;

import 'package:saropa_lints/src/rules/code_quality/code_quality_control_flow_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';
import '../../support/syntactic_rule_harness.dart';

const String _id = 'no_equal_nested_conditions';

const String _prelude = '''
bool get ready => DateTime.now().second.isEven;
bool flag = false;
const bool constFlag = true;
bool check() => flag;
Future<void> read() async {}
Future<bool> ask() async => flag;
void run() {}
void later(void Function() f) {}
class Box {
  final bool fixed = true;
  bool open = true;
}
''';

/// Wraps [condition] in the outer-check / [between] / inner-check shape.
String _nested(String condition, {String between = 'await read();'}) =>
    '''
$_prelude
Future<void> f(bool p, String s, List<int> list, Box box) async {
  final bool local = ready;
  if ($condition) {
    $between
    if ($condition) run();
  }
}
''';

/// A function body placed after the shared declarations.
String _body(String body) =>
    '$_prelude\nFuture<void> f(List<int> l) async {\n'
    '$body\n}\n';

void main() {
  Future<Set<String>> codes(String code) =>
      reportedRuleCodes(NoEqualNestedConditionsRule(), code);

  group('NO lint: value can change during the suspension', () {
    for (final String condition in <String>[
      'ready',
      'flag',
      'check()',
      'box.open',
      'list.isEmpty',
      'local && ready',
    ]) {
      test(condition, () async {
        expect(await codes(_nested(condition)), isNot(contains(_id)));
      });
    }

    test('local written by a closure', () async {
      final String code = _body('''
  bool canceled = false;
  later(() => canceled = true);
  if (!canceled) {
    await read();
    if (!canceled) run();
  }''');
      expect(await codes(code), isNot(contains(_id)));
    });

    test('await later in the same loop body', () async {
      final String code = _body('''
  if (ready) {
    for (final int i in l) {
      if (ready) run();
      await read();
    }
  }''');
      expect(await codes(code), isNot(contains(_id)));
    });

    // A closure can run after the outer check stopped holding, with no await
    // in this function at all.
    test('re-check inside a deferred closure', () async {
      final String code = _body('''
  if (ready) {
    later(() { if (ready) run(); });
  }''');
      expect(await codes(code), isNot(contains(_id)));
    });

    test('local written by a stored callback, then a call', () async {
      final String code = _body('''
  bool canceled = false;
  later(() => canceled = true);
  if (!canceled) {
    run();
    if (!canceled) run();
  }''');
      expect(await codes(code), isNot(contains(_id)));
    });

    test(
      'field written by a listener in another method, then a call',
      () async {
        final String code =
            '''
$_prelude
class Job {
  bool done = false;
  void listen() { later(() { this.done = true; }); }
  void step() {
    if (!done) {
      run();
      if (!done) run();
    }
  }
}
''';
        expect(await codes(code), isNot(contains(_id)));
      },
    );

    test('condition that itself awaits', () async {
      final String code = _body('''
  if (await ask()) {
    if (await ask()) run();
  }''');
      expect(await codes(code), isNot(contains(_id)));
    });
  });

  group('LINT: still redundant', () {
    for (final String condition in <String>[
      'local',
      'p',
      '!p',
      'constFlag',
      'box.fixed',
      's.isEmpty',
      "s.startsWith('a')",
      's.length > 1',
    ]) {
      test('$condition after await', () async {
        expect(await codes(_nested(condition)), contains(_id));
      });
    }

    test('getter with no await', () async {
      expect(await codes(_nested('ready', between: 'run();')), contains(_id));
    });

    test('await only inside a closure', () async {
      final String code = _nested(
        'ready',
        between: 'later(() async { await read(); });',
      );
      expect(await codes(code), contains(_id));
    });

    // Guards the closure handling against over-reach.
    test('stable parameter re-checked inside a closure', () async {
      final String code = _body('''
  final bool p = l.isEmpty;
  if (p) {
    later(() { if (p) run(); });
  }''');
      expect(await codes(code), contains(_id));
    });

    test('call between, but no closure writes the local', () async {
      final String code = _body('''
  bool canceled = l.isEmpty;
  if (!canceled) {
    run();
    if (!canceled) run();
  }''');
      expect(await codes(code), contains(_id));
    });

    test('closure write, but no call between the checks', () async {
      final String code = _body('''
  bool canceled = false;
  later(() => canceled = true);
  if (!canceled) {
    if (!canceled) run();
  }''');
      expect(await codes(code), contains(_id));
    });

    test('await after the inner check', () async {
      final String code = _body('''
  if (ready) {
    if (ready) run();
    await read();
  }''');
      expect(await codes(code), contains(_id));
    });
  });

  group('unresolved scan', () {
    Set<String> syntactic(String code) =>
        reportedRuleCodesSyntactic(NoEqualNestedConditionsRule(), code);

    test('NO lint: getter after await', () {
      expect(syntactic(_nested('ready')), isNot(contains(_id)));
    });
    test('LINT: final local after await', () {
      expect(syntactic(_nested('local')), contains(_id));
    });
  });
}
