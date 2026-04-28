import 'dart:convert' show jsonDecode;

import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

void main() {
  group('RuleTimingTracker JSON contract', () {
    setUp(() {
      RuleTimingTracker.reset();
    });

    test('sortedTimingsJson uses stable keys and ordering', () {
      RuleTimingTracker.record(
        'slow_rule',
        const Duration(milliseconds: 9, microseconds: 500),
      );
      RuleTimingTracker.record('fast_rule', const Duration(milliseconds: 1));
      RuleTimingTracker.record('slow_rule', const Duration(milliseconds: 2));

      final json = RuleTimingTracker.sortedTimingsJson;

      expect(json, hasLength(2));
      expect(json.first['ruleName'], 'slow_rule');
      expect(
        json.first.keys,
        containsAll(['ruleName', 'totalMs', 'callCount', 'avgMs']),
      );
      expect(json.first['callCount'], 2);
      expect(json.first['totalMs'], 11.5);
      expect(json.first['avgMs'], 5.75);
    });

    test('summaryJson mirrors sortedTimingsJson payload', () {
      RuleTimingTracker.record('one_rule', const Duration(milliseconds: 3));

      final decoded =
          jsonDecode(RuleTimingTracker.summaryJson) as List<dynamic>;
      expect(decoded, hasLength(1));

      final first = decoded.first as Map<String, dynamic>;
      expect(first['ruleName'], 'one_rule');
      expect(first['totalMs'], 3.0);
      expect(first['callCount'], 1);
      expect(first['avgMs'], 3.0);
    });
  });
}
