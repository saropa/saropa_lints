// Regression: `Map<K, Future<V>>.remove(key)` has static type `Future<V>?` but
// creates no Future, so the fire-and-forget Future rules must stay silent.
library;

import 'package:saropa_lints/src/rules/code_quality/code_quality_avoid_rules.dart';
import 'package:saropa_lints/src/rules/core/async_rules.dart';
import 'package:saropa_lints/src/rules/flow/error_handling_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

const String _mapRemove = '''
final Map<String, Future<int?>> _inFlight = <String, Future<int?>>{};

Future<int?> save(String key, Future<int?> Function() run) {
  final Future<int?> queued = run();
  _inFlight[key] = queued;
  return queued.whenComplete(() {
    _inFlight.remove(key);
  });
}
''';

const String _realFireAndForget = '''
Future<int> work() async => 1;

void caller() {
  work();
}
''';

void main() {
  final rules = <String, dynamic Function()>{
    'avoid_async_call_in_sync_function': AvoidAsyncCallInSyncFunctionRule.new,
    'avoid_unawaited_future': AvoidUnawaitedFutureRule.new,
    'avoid_uncaught_future_errors': AvoidUncaughtFutureErrorsRule.new,
  };

  for (final entry in rules.entries) {
    group(entry.key, () {
      test('does NOT fire on Map<K, Future>.remove(key)', () async {
        final codes = await reportedRuleCodes(entry.value(), _mapRemove);
        expect(codes, isNot(contains(entry.key)));
      });

      test('still fires on a real dropped Future', () async {
        final codes = await reportedRuleCodes(
          entry.value(),
          _realFireAndForget,
        );
        expect(codes, contains(entry.key));
      });
    });
  }
}
