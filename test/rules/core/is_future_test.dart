// Behavioral tests for is_future: fires on `x is Future` / `x is! Future` /
// `x is Future<T>?` (nullable form), stays silent on FutureOr<T> (a distinct
// DartType, not a Future subtype), on unrelated `is` checks, and on a custom
// class that extends Future (rule matches only the literal `Future`
// annotation, not supertypes — see is_future_rules.dart's "Scope note").
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
}
