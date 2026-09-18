// Oracle-backed regression test for `move_variable_closer_to_its_usage`.
//
// Guards the fix for the false positive where the rule suggested relocating a
// throwing `await`-initialized declaration past sibling statements (HTTP
// status/header writes) that a sibling `catch`/`finally` in the same
// `TryStatement` depends on. Moving the declaration later would let those
// side effects run *before* the possible throw instead of after, changing
// what the handler observes — following the rule's own `MoveDeclarationCloserFix`
// would have introduced a real bug.
//
// Scope note: the fix keys specifically on `await` (a syntactically checkable
// proxy for "can suspend and skip the rest of the block"), not on general
// throw-safety. A *synchronous* initializer that can throw (e.g.
// `int.parse(s)`) has the identical reordering hazard but is NOT exempted —
// that remains a known, separate false-positive shape, not fixed here.
// See: bugs/move_variable_closer_to_its_usage_false_positive_throwing_await_before_header_writes.md
library;

import 'package:saropa_lints/src/rules/code_quality/code_quality_variables_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

const String _rule = 'move_variable_closer_to_its_usage';

void main() {
  group('move_variable_closer_to_its_usage throwing-await-in-try guard', () {
    test(
      'NO lint: throwing await before status/header writes a sibling catch depends on',
      () async {
        const String code = '''
class FakeResponse {
  int statusCode = 0;
  String? disposition;
}

Future<List<int>> getBytes() async => <int>[1, 2, 3];

Future<void> sendFile(FakeResponse res) async {
  try {
    final bytes = await getBytes();
    res.statusCode = 200;
    res.disposition = 'attachment';
    print('sending');
    print(bytes.length);
  } catch (e) {
    res.statusCode = 500;
  }
}
''';
        final codes = await reportedRuleCodes(
          MoveVariableCloserToUsageRule(),
          code,
        );
        expect(codes, isNot(contains(_rule)));
      },
    );

    test(
      'NO lint: throwing await guarded by finally-only (no catch)',
      () async {
        const String code = '''
class FakeResponse {
  int statusCode = 0;
  String? disposition;
}

Future<List<int>> getBytes() async => <int>[1, 2, 3];

Future<void> sendFile(FakeResponse res) async {
  try {
    final bytes = await getBytes();
    res.statusCode = 200;
    res.disposition = 'attachment';
    print('sending');
    print(bytes.length);
  } finally {
    print('done');
  }
}
''';
        final codes = await reportedRuleCodes(
          MoveVariableCloserToUsageRule(),
          code,
        );
        expect(codes, isNot(contains(_rule)));
      },
    );

    test(
      'LINT: same shape but a non-await initializer (guard is scoped to '
      '`await`, not general throw-safety — a synchronous throwing call '
      'here, e.g. int.parse, would ALSO have the reordering hazard but is '
      'NOT exempted by this fix; that remains a known, separate FP shape)',
      () async {
        const String code = '''
class FakeResponse {
  int statusCode = 0;
  String? disposition;
}

List<int> getBytesSync() => <int>[1, 2, 3];

void sendFile(FakeResponse res) {
  try {
    final bytes = getBytesSync();
    res.statusCode = 200;
    res.disposition = 'attachment';
    print('sending');
    print(bytes.length);
  } catch (e) {
    res.statusCode = 500;
  }
}
''';
        final codes = await reportedRuleCodes(
          MoveVariableCloserToUsageRule(),
          code,
        );
        expect(codes, contains(_rule));
      },
    );

    test(
      'LINT: throwing await outside any try/catch is still flagged',
      () async {
        const String code = '''
Future<List<int>> getBytes() async => <int>[1, 2, 3];

Future<void> f() async {
  final bytes = await getBytes();
  print('a');
  print('b');
  print('c');
  print(bytes.length);
}
''';
        final codes = await reportedRuleCodes(
          MoveVariableCloserToUsageRule(),
          code,
        );
        expect(codes, contains(_rule));
      },
    );
  });
}
