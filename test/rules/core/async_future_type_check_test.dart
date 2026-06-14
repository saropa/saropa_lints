// Regression tests for the Future-type detection fix in async_rules.dart.
//
// Several rules used `type.getDisplayString().startsWith('Future')` to decide
// whether an expression was a Future. That prefix test wrongly matches
// `FutureOr<T>` (display "FutureOr<T>") — a false positive — and misses Future
// subtypes. The fix routes all of them through `_staticTypeIsFuture`
// (Future + implementers, NOT FutureOr). These tests run the real rules against
// resolved source via the oracle.
library;

import 'package:saropa_lints/src/rules/core/async_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('avoid_future_tostring', () {
    test('fires on toString() of a real Future', () async {
      final codes = await reportedRuleCodes(AvoidFutureToStringRule(), '''
String f(Future<int> value) => value.toString();
''');
      expect(codes, contains('avoid_future_tostring'));
    });

    test(
      'does NOT fire on toString() of a FutureOr (was a false positive)',
      () async {
        // FutureOr<int> is NOT a Future; its display string merely starts with
        // "Future", which the old prefix check wrongly flagged.
        final codes = await reportedRuleCodes(AvoidFutureToStringRule(), '''
import 'dart:async';

String f(FutureOr<int> value) => value.toString();
''');
        expect(codes, isNot(contains('avoid_future_tostring')));
      },
    );

    test('does NOT fire on toString() of a plain int (control)', () async {
      final codes = await reportedRuleCodes(AvoidFutureToStringRule(), '''
String f(int value) => value.toString();
''');
      expect(codes, isEmpty);
    });
  });

  group('prefer_return_await', () {
    test(
      'fires when an async function returns a Future without await',
      () async {
        final codes = await reportedRuleCodes(PreferReturnAwaitRule(), '''
Future<int> inner() async => 1;
Future<int> outer() async {
  return inner();
}
''');
        expect(codes, contains('prefer_return_await'));
      },
    );

    test('does NOT fire when returning a non-Future value', () async {
      final codes = await reportedRuleCodes(PreferReturnAwaitRule(), '''
Future<int> outer() async {
  return 1;
}
''');
      expect(codes, isEmpty);
    });
  });

  group('avoid_unawaited_future', () {
    test('fires on an unawaited Future-returning call', () async {
      final codes = await reportedRuleCodes(AvoidUnawaitedFutureRule(), '''
Future<void> work() async {}
void caller() {
  work();
}
''');
      expect(codes, contains('avoid_unawaited_future'));
    });
  });
}
