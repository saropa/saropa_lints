// Regression/behavior tests for avoid_futureor_return_type.
//
// This test exercises the rule class directly via the resolved-rule
// harness, which runs a single rule against inline source without
// depending on lib/saropa_lints.dart or lib/src/tiers.dart. (The rule IS
// fully registered there — see lib/saropa_lints.dart, lib/src/tiers.dart,
// and lib/src/rules/all_rules.dart — this harness is just the project's
// standard fast unit-test path, independent of global wiring.)
library;

import 'package:saropa_lints/src/rules/core/avoid_futureor_return_type_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';
import '../../support/rule_instantiation_assertions.dart';

void main() {
  group('avoid_futureor_return_type', () {
    test('fires on a top-level function returning FutureOr<T>', () async {
      final codes = await reportedRuleCodes(AvoidFutureorReturnTypeRule(), '''
import 'dart:async';

FutureOr<int> getValue() => 42;
''');
      expect(codes, contains('avoid_futureor_return_type'));
    });

    test('fires on a method returning FutureOr<T>', () async {
      final codes = await reportedRuleCodes(AvoidFutureorReturnTypeRule(), '''
import 'dart:async';

class Repository {
  FutureOr<String> fetchName() => 'saropa';
}
''');
      expect(codes, contains('avoid_futureor_return_type'));
    });

    test('fires on a getter returning FutureOr<T>', () async {
      final codes = await reportedRuleCodes(AvoidFutureorReturnTypeRule(), '''
import 'dart:async';

class Repository {
  FutureOr<int> get cachedCount => 3;
}
''');
      expect(codes, contains('avoid_futureor_return_type'));
    });

    test('does NOT fire on a plain Future<T> return type', () async {
      final codes = await reportedRuleCodes(AvoidFutureorReturnTypeRule(), '''
Future<int> getValue() async => 42;
''');
      expect(codes, isEmpty);
    });

    test('does NOT fire on a plain sync return type (control)', () async {
      final codes = await reportedRuleCodes(AvoidFutureorReturnTypeRule(), '''
int getValueSync() => 42;
''');
      expect(codes, isEmpty);
    });

    test(
      'does NOT fire on an overriding method — the FutureOr signature is '
      'inherited from the base declaration, which is flagged instead',
      () async {
        final codes = await reportedRuleCodes(AvoidFutureorReturnTypeRule(), '''
import 'dart:async';

abstract class Base {
  FutureOr<int> compute();
}

class Impl extends Base {
  @override
  FutureOr<int> compute() => 1;
}
''');
        final diags = await runRuleResolved(AvoidFutureorReturnTypeRule(), '''
import 'dart:async';

abstract class Base {
  FutureOr<int> compute();
}

class Impl extends Base {
  @override
  FutureOr<int> compute() => 1;
}
''');
        // The base declaration (line 4) is flagged; the override (line 9) is not.
        expect(codes, contains('avoid_futureor_return_type'));
        expect(diags.map((d) => d.line), contains(4));
        expect(diags.map((d) => d.line), isNot(contains(9)));
      },
    );

    test('does NOT fire on a setter (no meaningful return type)', () async {
      final codes = await reportedRuleCodes(AvoidFutureorReturnTypeRule(), '''
class Holder {
  set value(int v) {}
}
''');
      expect(codes, isEmpty);
    });

    test('fires on a nullable FutureOr<T>? return type', () async {
      // Nullability is a separate AST field from the NamedType's lexeme, so
      // the exact-name check must still match `FutureOr<int>?`.
      final codes = await reportedRuleCodes(AvoidFutureorReturnTypeRule(), '''
import 'dart:async';

FutureOr<int>? getValue() => null;
''');
      expect(codes, contains('avoid_futureor_return_type'));
    });

    test('does NOT fire on a getter override — same exemption as method '
        'overrides', () async {
      final diags = await runRuleResolved(AvoidFutureorReturnTypeRule(), '''
import 'dart:async';

abstract class Base {
  FutureOr<int> get cachedTotal;
}

class Impl extends Base {
  @override
  FutureOr<int> get cachedTotal => 1;
}
''');
      // The base declaration (line 4) is flagged; the override (line 9) is not.
      expect(diags.map((d) => d.line), contains(4));
      expect(diags.map((d) => d.line), isNot(contains(9)));
    });

    test('does NOT fire on an override that omits @override — the exemption '
        'is resolution-based (checks the supertype chain), not '
        'annotation-based, since Dart never requires @override to correctly '
        'implement an interface member', () async {
      final diags = await runRuleResolved(AvoidFutureorReturnTypeRule(), '''
import 'dart:async';

abstract class Base {
  FutureOr<int> compute();
}

class Impl implements Base {
  FutureOr<int> compute() => 1;
}
''');
      // The base declaration (line 4) is flagged; the unannotated
      // override (line 8) must NOT be — this is the FP the resolution-
      // based _isOverride check exists to prevent.
      expect(diags.map((d) => d.line), contains(4));
      expect(diags.map((d) => d.line), isNot(contains(8)));
    });

    test('fires on a mixin method returning FutureOr<T>', () async {
      final codes = await reportedRuleCodes(AvoidFutureorReturnTypeRule(), '''
import 'dart:async';

mixin Mixin {
  FutureOr<int> mixinMethod() => 1;
}
''');
      expect(codes, contains('avoid_futureor_return_type'));
    });

    test('does NOT fire on a user-defined class NAMED FutureOr — the check is '
        'resolution-based, so a local type that merely shares the name is not '
        'dart:async.FutureOr and carries no sync/async ambiguity', () async {
      // Regression: the old lexeme comparison flagged this, and the
      // correction message ("make it async / return Future<T>") is
      // nonsense for a plain value wrapper. Note there is no
      // `import 'dart:async'` here — the only FutureOr in scope is local.
      final codes = await reportedRuleCodes(AvoidFutureorReturnTypeRule(), '''
class FutureOr<T> {
  const FutureOr(this.value);
  final T value;
}

FutureOr<int> wrap(int v) => FutureOr<int>(v);
''');
      expect(codes, isEmpty);
    });

    test(
      'fires through a typedef alias to dart:async FutureOr — the alias '
      'hides the lexeme but resolves to the very type this rule targets',
      () async {
        // Regression: the old lexeme comparison saw 'MyFutureOr' and bailed,
        // so the caller-side sync/async ambiguity shipped unflagged.
        final codes = await reportedRuleCodes(AvoidFutureorReturnTypeRule(), '''
import 'dart:async';

typedef MyFutureOr<T> = FutureOr<T>;

MyFutureOr<int> getValue() => 42;
''');
        expect(codes, contains('avoid_futureor_return_type'));
      },
    );

    test('fires on an extension method returning FutureOr<T>', () async {
      final codes = await reportedRuleCodes(AvoidFutureorReturnTypeRule(), '''
import 'dart:async';

extension StringExt on String {
  FutureOr<int> extensionMethod() => 1;
}
''');
      expect(codes, contains('avoid_futureor_return_type'));
    });
  });

  // Rule Instantiation: metadata smoke test.
  group('avoid_futureor_return_type - Rule Instantiation', () {
    test('AvoidFutureorReturnTypeRule', () {
      assertRuleMetadata(
        AvoidFutureorReturnTypeRule(),
        'avoid_futureor_return_type',
      );
    });
  });
}
