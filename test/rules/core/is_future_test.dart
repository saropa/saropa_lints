// Behavioral tests for is_future: fires on `x is Future` / `x is! Future`,
// stays silent on FutureOr<T> (a distinct DartType, not a Future subtype)
// and on unrelated `is` checks. Runs the real rule against resolved source
// via the oracle so detection logic — not just metadata — is verified.
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
