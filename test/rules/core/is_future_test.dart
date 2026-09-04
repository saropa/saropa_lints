// Behavioral tests for is_future: fires on `x is Future` / `x is! Future` /
// `x is Future<T>?` (nullable form), stays silent on FutureOr<T> (a distinct
// DartType, not a Future subtype), on unrelated `is` checks, and on a custom
// class that extends Future (rule matches only the literal `Future`
// annotation, not supertypes — see is_future_rules.dart's "Scope note"), and
// stays silent on the v2 exemption: narrowing an already-FutureOr<T> value
// with `is Future<T>` / `is! Future<T>`, which is the only way to unwrap a
// FutureOr in a synchronous context.
// Runs the real rule against resolved source via the oracle so detection
// logic — not just metadata — is verified.
library;

import 'package:saropa_lints/src/rules/core/is_future_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('is_future', () {
    test('fires on "result is Future"', () async {
      final codes = await reportedRuleCodes(IsFutureRule(), '''
void handle(dynamic result) {
  if (result is Future) {
    result.then((value) => print(value));
  } else {
    print(result);
  }
}
''');
      expect(codes, contains('is_future'));
    });

    test('fires on negated "result is! Future"', () async {
      final codes = await reportedRuleCodes(IsFutureRule(), '''
void handle(dynamic result) {
  if (result is! Future) {
    print(result);
  }
}
''');
      expect(codes, contains('is_future'));
    });

    test('fires on "result is Future<int>"', () async {
      final codes = await reportedRuleCodes(IsFutureRule(), '''
void handle(dynamic result) {
  if (result is Future<int>) {
    result.then((value) => print(value));
  }
}
''');
      expect(codes, contains('is_future'));
    });

    test('fires on nullable "result is Future<int>?"', () async {
      // isDartAsyncFuture is true for both Future<T> and Future<T>? (see
      // return_rules.dart's nullable-return guard for the same fact used
      // the other way), so the nullable form is just as fragile and must
      // still be flagged by this rule.
      final codes = await reportedRuleCodes(IsFutureRule(), '''
void handle(dynamic result) {
  if (result is Future<int>?) {
    result?.then((value) => print(value));
  }
}
''');
      expect(codes, contains('is_future'));
    });

    test(
      'does NOT fire on a custom class extending Future (scope boundary)',
      () async {
        // Documents that this rule intentionally checks only the literal
        // `Future` annotation, not supertypes — unlike async_rules.dart's
        // _staticTypeIsFuture, which walks allSupertypes for a value's
        // resolved static type. See the class DartDoc "Scope note".
        final codes = await reportedRuleCodes(IsFutureRule(), '''
class CustomFuture<T> extends Future<T> {
  @override
  Stream<T> asStream() => throw UnimplementedError();
  @override
  Future<T> catchError(Function onError, {bool Function(Object)? test}) =>
      throw UnimplementedError();
  @override
  Future<R> then<R>(FutureOr<R> Function(T) onValue, {Function? onError}) =>
      throw UnimplementedError();
  @override
  Future<T> timeout(Duration timeLimit, {FutureOr<T> Function()? onTimeout}) =>
      throw UnimplementedError();
  @override
  Future<T> whenComplete(FutureOr<void> Function() action) =>
      throw UnimplementedError();
}

void handle(dynamic result) {
  if (result is CustomFuture) {
    print(result);
  }
}
''');
        expect(codes, isEmpty);
      },
    );

    test('does NOT fire on FutureOr<T> (near-miss, not a Future)', () async {
      final codes = await reportedRuleCodes(IsFutureRule(), '''
import 'dart:async';

Future<void> handle(FutureOr<Object?> result) async {
  final value = await result;
  print(value);
}
''');
      expect(codes, isEmpty);
    });

    test(
      'does NOT fire when narrowing a FutureOr<T> in a SYNCHRONOUS context',
      () async {
        // Regression guard for the v2 false positive: this is the canonical,
        // analyzer-recommended way to narrow a FutureOr<T>, and it is the
        // ONLY way here because the override cannot be made async without
        // breaking the synchronous SyncReader contract — so the rule's own
        // correction ("type the parameter as FutureOr<T> and await it") is
        // both already satisfied and impossible to apply.
        final codes = await reportedRuleCodes(IsFutureRule(), '''
import 'dart:async';

abstract class SyncReader {
  int? tryReadSync(FutureOr<int> value);
}

class EagerReader implements SyncReader {
  @override
  int? tryReadSync(FutureOr<int> value) {
    if (value is Future<int>) {
      return null;
    }
    return value;
  }
}
''');
        expect(codes, isEmpty);
      },
    );

    test('does NOT fire on negated FutureOr<T> narrowing', () async {
      // The `is!` form of the same idiom must be exempt too — negation
      // changes only which branch runs first, not the legitimacy.
      final codes = await reportedRuleCodes(IsFutureRule(), '''
import 'dart:async';

FutureOr<String> label(FutureOr<String> value) {
  if (value is! Future<String>) {
    return value.toUpperCase();
  }
  return value;
}
''');
      expect(codes, isEmpty);
    });

    test('still fires when the FutureOr type argument does NOT match', () async {
      // The exemption requires STATIC evidence of a real narrowing. A
      // FutureOr<int> tested against Future<String> narrows nothing, so the
      // guard must not swallow it.
      final codes = await reportedRuleCodes(IsFutureRule(), '''
import 'dart:async';

void handle(FutureOr<int> value) {
  if (value is Future<String>) {
    print(value);
  }
}
''');
      expect(codes, contains('is_future'));
    });

    test('does NOT fire on an unrelated "is" check', () async {
      final codes = await reportedRuleCodes(IsFutureRule(), '''
void handle(dynamic result) {
  if (result is String) {
    print(result);
  }
}
''');
      expect(codes, isEmpty);
    });
  });

  // Rule Instantiation: metadata smoke test.
  group('is_future - Rule Instantiation', () {
    test('IsFutureRule', () {
      final rule = IsFutureRule();
      expect(rule.code.lowerCaseName, 'is_future');
      expect(rule.code.problemMessage, contains('[is_future]'));
      expect(rule.code.problemMessage.length, greaterThan(50));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });
}
