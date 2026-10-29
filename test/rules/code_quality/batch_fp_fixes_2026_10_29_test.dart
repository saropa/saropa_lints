// Resolved regression tests for six false-positive reports (2026-10-29):
// avoid_parameter_mutation (documented in-place mutators),
// move_variable_closer_to_its_usage (pre-mutation state snapshot),
// prefer_asmap_over_indexed_iteration (pairwise loops),
// prefer_static_method (singleton facade),
// prefer_try_parse_for_dynamic_data (Uri.parse of constants/encoded parts).
library;

import 'package:saropa_lints/src/rules/architecture/structure_rules.dart';
import 'package:saropa_lints/src/rules/code_quality/code_quality_variables_rules.dart';
import 'package:saropa_lints/src/rules/data/collection_rules.dart';
import 'package:saropa_lints/src/rules/data/json_datetime_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  group('avoid_parameter_mutation in-place mutators', () {
    const String model = 'class M { int x = 0; }\n';
    Future<Set<String>> run(String body) =>
        reportedRuleCodes(AvoidParameterMutationRule(), model + body);

    test('NO lint: doc says "in place"', () async {
      expect(
        await run('/// Updates [m] in place.\nvoid change(M m) { m.x = 1; }'),
        isNot(contains('avoid_parameter_mutation')),
      );
    });
    test('NO lint: mutator verb name, bool return', () async {
      expect(
        await run('bool restoreX(M m, int s) { m.x = s; return true; }'),
        isNot(contains('avoid_parameter_mutation')),
      );
    });
    test('NO lint: stamp verb, void', () async {
      expect(
        await run('void stampRuling(M m) { m.x = 1; }'),
        isNot(contains('avoid_parameter_mutation')),
      );
    });
    test('LINT: neutral name, no doc', () async {
      expect(
        await run('void process(M m) { m.x = 1; }'),
        contains('avoid_parameter_mutation'),
      );
    });
    test('LINT: non-void returning the object', () async {
      expect(
        await run('M withX(M m) { m.x = 1; return m; }'),
        contains('avoid_parameter_mutation'),
      );
    });
    test('LINT: verb prefix must be a whole word (marketing)', () async {
      expect(
        await run('void marketing(M m) { m.x = 1; }'),
        contains('avoid_parameter_mutation'),
      );
    });
  });

  group('move_variable_closer_to_its_usage state snapshot', () {
    const String prelude = '''
final Set<String> store = <String>{};
Set<String> load() => Set<String>.of(store);
Future<void> mutate(String k) async => store.add(k);
void step() {}
''';
    test('NO lint: call snapshot before awaited loop', () async {
      final codes = await reportedRuleCodes(MoveVariableCloserToUsageRule(), '''
$prelude
Future<Set<String>> merge(List<String> items) async {
  final Set<String> before = load();
  for (final String i in items) {
    await mutate(i);
  }
  step();
  step();
  return load().difference(before);
}
''');
      expect(codes, isNot(contains('move_variable_closer_to_its_usage')));
    });
    test('LINT: snapshot call but no await in between', () async {
      final codes = await reportedRuleCodes(MoveVariableCloserToUsageRule(), '''
$prelude
Set<String> merge() {
  final Set<String> before = load();
  step();
  step();
  step();
  return load().difference(before);
}
''');
      expect(codes, contains('move_variable_closer_to_its_usage'));
    });
    test('LINT: literal initializer with awaits in between', () async {
      final codes = await reportedRuleCodes(MoveVariableCloserToUsageRule(), '''
$prelude
Future<int> merge() async {
  final int base = 5;
  await mutate('a');
  await mutate('b');
  await mutate('c');
  return base;
}
''');
      expect(codes, contains('move_variable_closer_to_its_usage'));
    });
  });

  group('prefer_asmap_over_indexed_iteration pairwise', () {
    test('NO lint on either loop of a pairwise scan', () async {
      final codes = await reportedRuleCodes(
        PreferAsmapOverIndexedIterationRule(),
        '''
void b(List<int> l) {
  for (int i = 0; i < l.length; i++) {
    for (int j = i + 1; j < l.length; j++) {
      print(l[i] + l[j]);
    }
  }
}
''',
      );
      expect(codes, isNot(contains('prefer_asmap_over_indexed_iteration')));
    });
    test('LINT: plain index walk from 0', () async {
      final codes = await reportedRuleCodes(
        PreferAsmapOverIndexedIterationRule(),
        'void a(List<int> l) { for (int i = 0; i < l.length; i++) { print(l[i]); } }',
      );
      expect(codes, contains('prefer_asmap_over_indexed_iteration'));
    });
  });

  group('prefer_static_method singleton', () {
    test('NO lint: private ctor + static self-typed field', () async {
      final codes = await reportedRuleCodes(PreferStaticMethodRule(), '''
class Svc {
  Svc._();
  static final Svc instance = Svc._();
  String ping() => 'pong';
}
''');
      expect(codes, isNot(contains('prefer_static_method')));
    });
    test('NO lint: factory singleton', () async {
      final codes = await reportedRuleCodes(PreferStaticMethodRule(), '''
class Svc2 {
  Svc2._();
  static final Svc2 _i = Svc2._();
  factory Svc2() => _i;
  String ping() => 'pong';
}
''');
      expect(codes, isNot(contains('prefer_static_method')));
    });
    test('LINT: plain utility class', () async {
      final codes = await reportedRuleCodes(
        PreferStaticMethodRule(),
        'class Util { int add(int a, int b) => a + b; }',
      );
      expect(codes, contains('prefer_static_method'));
    });
    test('LINT: private ctor but no static self instance', () async {
      final codes = await reportedRuleCodes(PreferStaticMethodRule(), '''
class U {
  U._();
  int add(int a, int b) => a + b;
}
''');
      expect(codes, contains('prefer_static_method'));
    });
  });

  group('prefer_try_parse_for_dynamic_data Uri.parse', () {
    Future<Set<String>> run(String code) =>
        reportedRuleCodes(PreferTryParseForDynamicDataRule(), code);
    const String id = 'prefer_try_parse_for_dynamic_data';

    test('NO lint: const base and encoded component', () async {
      final codes = await run('''
const String base = 'https://example.com/api';
Uri c() => Uri.parse('\$base/items');
Uri d(String v) => Uri.parse('app:///co?q=\${Uri.encodeComponent(v)}');
''');
      expect(codes, isNot(contains(id)));
    });
    test('LINT: raw input', () async {
      expect(await run('Uri a(String u) => Uri.parse(u);'), contains(id));
    });
    test('LINT: host-interpolated input', () async {
      final codes = await run(
        "Uri b(String host) => Uri.parse('https://\$host/x');",
      );
      expect(codes, contains(id));
    });
  });
}
