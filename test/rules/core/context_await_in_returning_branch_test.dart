// Regression: an `await` inside an early-returning `if` branch must not put
// later statements in the "after await" danger zone. Shared by
// avoid_context_across_async and avoid_context_after_await_in_static.
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:saropa_lints/src/async_context_utils.dart';
import 'package:saropa_lints/src/rules/core/context_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

/// Parses [stmt] as the first statement of a function body.
Statement _first(String stmt) {
  final unit = parseString(
    content: 'Future<void> f() async { $stmt }',
    throwIfDiagnostics: false,
  ).unit;
  final fn = unit.declarations.first as FunctionDeclaration;
  return ((fn.functionExpression.body as BlockFunctionBody).block)
      .statements
      .first;
}

void main() {
  group('awaitConfinedToExitingBranches', () {
    test('true: await only in a returning branch', () {
      expect(
        awaitConfinedToExitingBranches(_first('if (a) { return await g(); }')),
        isTrue,
      );
    });

    test('true: await then throw in branch', () {
      expect(
        awaitConfinedToExitingBranches(
          _first('if (a) { await g(); throw 1; }'),
        ),
        isTrue,
      );
    });

    test('false: awaiting branch falls through', () {
      expect(
        awaitConfinedToExitingBranches(_first('if (a) { await g(); }')),
        isFalse,
      );
    });

    test('false: await in the condition', () {
      expect(
        awaitConfinedToExitingBranches(_first('if (await g()) { return; }')),
        isFalse,
      );
    });

    test('false: awaiting else branch falls through', () {
      expect(
        awaitConfinedToExitingBranches(
          _first('if (a) { return; } else { await g(); }'),
        ),
        isFalse,
      );
    });
  });

  group('avoid_context_after_await_in_static', () {
    String src(String body) =>
        '''
Future<bool> work() async => true;
void toast(BuildContext context) {}
class C {
  static Future<bool> run(BuildContext context, String? code) async {
$body
  }
}
''';

    test('silent when the await is only in a returning branch', () async {
      final codes = await reportedRuleCodes(
        AvoidContextAfterAwaitInStaticRule(),
        src('''
    try {
      if (code == 'off') {
        return await work();
      }
      toast(context);
      return false;
    } on Object {
      return false;
    }
'''),
      );
      expect(codes, isNot(contains('avoid_context_after_await_in_static')));
    });

    test('still fires when the awaiting branch falls through', () async {
      final codes = await reportedRuleCodes(
        AvoidContextAfterAwaitInStaticRule(),
        src('''
    if (code == 'off') {
      await work();
    }
    toast(context);
    return false;
'''),
      );
      expect(codes, contains('avoid_context_after_await_in_static'));
    });
  });
}
