// Regression: a cache whose private map is only ever replaced whole by a freshly
// built map cannot accumulate entries, and the replacement is its
// invalidation. avoid_unbounded_cache_growth and require_cache_expiration must
// not report it, and must keep reporting every shape that can still grow.
library;

import 'dart:io';

import 'package:saropa_lints/src/rules/resources/memory_management_rules.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

/// Builds a fixture around [body], the members of a cache-named class.
String _cache(String body) =>
    '''
class Row {
  Row(this.id);
  final String id;
}

class LinkCache {
$body
}
''';

const String _field = '  static Map<String, Row> _byId = <String, Row>{};';

/// Shapes that are pure snapshots: neither rule may report them.
final Map<String, String> _snapshots = <String, String>{
  'populated local then assigned': _cache('''
$_field
  static void replace(List<Row> rows) {
    final Map<String, Row> next = <String, Row>{};
    for (final Row r in rows) {
      next[r.id] = r;
    }
    _byId = next;
  }
  static Row? forId(String id) => _byId[id];'''),
  'collection-for literal': _cache('''
$_field
  static void replace(List<Row> rows) {
    _byId = <String, Row>{for (final Row r in rows) r.id: r};
  }
  static Row? forId(String id) => _byId[id];
  static bool has(String id) => _byId.containsKey(id);
  static int get size => _byId.length;'''),
  'rebuild through helpers that only use their input': _cache('''
$_field
  static String _keyOf(Row r) => r.id;
  static void _put(Map<String, Row> into, Row r) {
    into[_keyOf(r)] = r;
  }
  static void replace(List<Row> rows) {
    final Map<String, Row> next = <String, Row>{};
    for (final Row r in rows) {
      _put(next, r);
    }
    _byId = next;
  }'''),
  'Map constructor on a nullable field': _cache('''
  Map<String, Row>? _byId;
  void replace(List<Row> rows) {
    this._byId = Map<String, Row>.fromEntries(
      rows.map((Row r) => MapEntry<String, Row>(r.id, r)),
    );
  }
  Row? forId(String id) => _byId?[id];'''),
};

/// Shapes that can still grow or go stale: both rules must keep reporting.
final Map<String, String> _growing = <String, String>{
  'per-key lazy fill': _cache('''
$_field
  static void store(Row r) {
    _byId[r.id] = r;
  }'''),
  'per-key write beside a replace': _cache('''
$_field
  static void replace(List<Row> rows) {
    _byId = <String, Row>{for (final Row r in rows) r.id: r};
  }
  static void store(Row r) {
    _byId[r.id] = r;
  }'''),
  'rebuild spreads the old map': _cache('''
$_field
  static void store(Row r) {
    _byId = <String, Row>{..._byId, r.id: r};
  }'''),
  'rebuild copies old entries into a local': _cache('''
$_field
  static void store(Row r) {
    final Map<String, Row> next = Map<String, Row>.of(_byId);
    next[r.id] = r;
    _byId = next;
  }'''),
  'rebuild draws from an accumulating field': _cache('''
$_field
  static final List<Row> _seen = <Row>[];
  static void store(Row r) {
    _seen.add(r);
    _byId = <String, Row>{for (final Row x in _seen) x.id: x};
  }'''),
  'rebuild draws from accumulated state through a helper': '''
final List<String> _log = <String>[];
List<String> _history() => _log;

class LinkCache {
  static Map<String, String> _byId = <String, String>{};
  static void store(String id) {
    _log.add(id);
    _byId = <String, String>{for (final String x in _history()) x: x};
  }
}
''',
  'helper fills the local from accumulated state': '''
class History {
  static final List<String> _ids = <String>[];
  static void carry(Map<String, String> into) {
    for (final String x in _ids) {
      into[x] = x;
    }
  }
  static void add(String id) => _ids.add(id);
}

class LinkCache {
  static Map<String, String> _byId = <String, String>{};
  static void store(String id) {
    History.add(id);
    final Map<String, String> next = <String, String>{};
    History.carry(next);
    _byId = next;
  }
}
''',
  'accumulated state two helpers deep': '''
class History {
  final List<String> _ids = <String>[];
  List<String> get all => _ids;
  void add(String id) => _ids.add(id);
}

final History _history = History();
List<String> _outer() => _inner();
List<String> _inner() => _history.all;

class LinkCache {
  static Map<String, String> _byId = <String, String>{};
  static void store(String id) {
    _history.add(id);
    _byId = <String, String>{for (final String x in _outer()) x: x};
  }
}
''',
  'addAll on the field': _cache('''
$_field
  static void replace(Map<String, Row> more) {
    _byId = <String, Row>{};
    _byId.addAll(more);
  }'''),
  'field passed to another function': _cache('''
$_field
  static void replace(Row r) {
    _byId = <String, Row>{};
    fill(_byId, r);
  }
  static void fill(Map<String, Row> into, Row r) {
    into[r.id] = r;
  }'''),
  'assigned a caller-owned map': _cache('''
$_field
  static void replace(Map<String, Row> theirs) {
    _byId = theirs;
  }
  static void unused() {
    final Map<String, Row> next = <String, Row>{};
    next['a'] = Row('a');
  }'''),
  'assigned a view over a caller-owned map':
      """
import 'dart:collection';

${_cache('''
$_field
  static void replace(Map<String, Row> theirs) {
    _byId = UnmodifiableMapView<String, Row>(theirs);
  }
  static void unused() {
    final Map<String, Row> next = <String, Row>{};
    next['a'] = Row('a');
  }''')}""",
  'public field': _cache('''
  static Map<String, Row> byId = <String, Row>{};
  static void replace(List<Row> rows) {
    final Map<String, Row> next = <String, Row>{};
    for (final Row r in rows) {
      next[r.id] = r;
    }
    byId = next;
  }'''),
  'load once with ??=': _cache('''
  static Map<String, Row>? _byId;
  static void load(List<Row> rows) {
    _byId ??= <String, Row>{};
    final Map<String, Row> next = <String, Row>{};
    next['a'] = rows.first;
  }'''),
};

void main() {
  final Map<String, SaropaLintRule Function()> rules =
      <String, SaropaLintRule Function()>{
        'avoid_unbounded_cache_growth': AvoidUnboundedCacheGrowthRule.new,
        'require_cache_expiration': RequireCacheExpirationRule.new,
      };

  for (final MapEntry<String, SaropaLintRule Function()> rule
      in rules.entries) {
    group(rule.key, () {
      for (final MapEntry<String, String> c in _snapshots.entries) {
        test('allows snapshot: ${c.key}', () async {
          final codes = await reportedRuleCodes(rule.value(), c.value);
          expect(codes, isNot(contains(rule.key)));
        });
      }
      for (final MapEntry<String, String> c in _growing.entries) {
        test('still flags: ${c.key}', () async {
          final codes = await reportedRuleCodes(rule.value(), c.value);
          expect(codes, contains(rule.key));
        });
      }
    });
  }

  // Guards the example fixture itself: a file-wide exemption (such as a
  // `.clear()` on a same-named field) would silently mute its BAD cases.
  test(
    'require_cache_expiration fixture reports exactly its markers',
    () async {
      final String code = File(
        'example/lib/memory_management/require_cache_expiration_fixture.dart',
      ).readAsStringSync();
      final List<String> lines = code.split('\n');
      // Each marker sits on the line above the class that must be reported.
      final List<int> expected = <int>[
        for (int i = 0; i < lines.length; i++)
          if (lines[i].trim() == '// expect_lint: require_cache_expiration')
            i + 2,
      ];

      final diagnostics = await runRuleResolved(
        RequireCacheExpirationRule(),
        code,
      );

      expect(expected, isNotEmpty);
      expect(diagnostics.map((d) => d.line).toList(), expected);
    },
  );
}
