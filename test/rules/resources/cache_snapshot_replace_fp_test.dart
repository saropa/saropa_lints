// Regression: a Map cache invalidated by `field = null` and rebuilt wholesale
// is bounded by the source it mirrors; avoid_unbounded_cache_growth and
// require_cache_expiration must not report it.
library;

import 'package:saropa_lints/src/rules/resources/memory_management_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

const String _snapshot = '''
class Row {
  Row(this.uuid);
  final String uuid;
}

abstract final class ConnectionCache {
  static Map<String, Row>? _byUuid;
  static Map<String, Row>? _byEmail;

  static void preWarm(List<Row> rows) {
    final Map<String, Row> byUuid = <String, Row>{};
    for (final Row row in rows) {
      byUuid[row.uuid] = row;
    }
    _byUuid = byUuid;
  }

  static void invalidate(List<Row> rows) {
    _byUuid = null;
    _byEmail = null;
    preWarm(rows);
  }

  static Row? lookup(String uuid) => _byUuid?[uuid];
}
''';

const String _growing = '''
class Row {
  Row(this.uuid);
  final String uuid;
}

class ConnectionCache {
  static final Map<String, Row> _byUuid = <String, Row>{};
  static final Map<String, Row> _byEmail = <String, Row>{};

  static void add(Row row) {
    _byUuid[row.uuid] = row;
  }

  static Row? lookup(String uuid) => _byUuid[uuid];
}
''';

void main() {
  test('avoid_unbounded_cache_growth: snapshot cache not flagged', () async {
    final codes = await reportedRuleCodes(
      AvoidUnboundedCacheGrowthRule(),
      _snapshot,
    );
    expect(codes, isNot(contains('avoid_unbounded_cache_growth')));
  });

  test('require_cache_expiration: snapshot cache not flagged', () async {
    final codes = await reportedRuleCodes(
      RequireCacheExpirationRule(),
      _snapshot,
    );
    expect(codes, isNot(contains('require_cache_expiration')));
  });

  test('avoid_unbounded_cache_growth: still flags append-only cache', () async {
    final codes = await reportedRuleCodes(
      AvoidUnboundedCacheGrowthRule(),
      _growing,
    );
    expect(codes, contains('avoid_unbounded_cache_growth'));
  });

  test('require_cache_expiration: still flags append-only cache', () async {
    final codes = await reportedRuleCodes(
      RequireCacheExpirationRule(),
      _growing,
    );
    expect(codes, contains('require_cache_expiration'));
  });
}
