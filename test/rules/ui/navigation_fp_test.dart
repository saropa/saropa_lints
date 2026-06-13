/// Resolved-AST false-positive / false-negative regression tests for
/// navigation_rules.dart. Each group first reproduces the audit-flagged defect
/// (the FP case), then pins the genuine BAD-fires and GOOD-silent behavior so a
/// future edit cannot silently regress either direction.
///
/// The harness writes fixtures under example/lib (no Flutter dep), so Flutter
/// types resolve to InvalidType. Rules that key off Flutter element types are
/// stubbed locally where the rule's detection actually needs resolution; rules
/// that key off method names / string-literal paths work directly.
import 'package:saropa_lints/src/rules/ui/navigation_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  // ===========================================================================
  // avoid_context_after_navigation — guard-state must be lexical, not scalar.
  // ===========================================================================
  group('avoid_context_after_navigation', () {
    final rule = AvoidContextAfterNavigationRule();
    const ruleName = 'avoid_context_after_navigation';

    // FP repro: a `mounted` check in an UNRELATED later branch (after the
    // unguarded context use) must NOT retroactively suppress the diagnostic.
    test('FP: mounted in unrelated later branch does not suppress', () async {
      const code = '''
class State {}
class W extends State {
  bool mounted = true;
  Object? navigator;
  Future<void> go() async {
    await navigator!.push();
    navigator!.of(context);
    if (mounted) {
      doSomethingElse();
    }
  }
  void doSomethingElse() {}
  Object? get context => null;
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });

    // FP repro 2: a `mounted` check that appears BEFORE the await (so it does
    // NOT guard the post-await context use) must not suppress the diagnostic.
    test('FP: mounted check before the await does not suppress', () async {
      const code = '''
class State {}
class W extends State {
  bool mounted = true;
  Object? navigator;
  Future<void> go() async {
    if (mounted) {
      doSomething();
    }
    await navigator!.push();
    navigator!.of(context);
  }
  void doSomething() {}
  Object? get context => null;
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });

    // GOOD: a mounted guard placed BEFORE the context use suppresses correctly.
    test('GOOD: mounted guard before context use stays silent', () async {
      const code = '''
class State {}
class W extends State {
  bool mounted = true;
  Object? navigator;
  Future<void> go() async {
    await navigator!.push();
    if (!mounted) return;
    navigator!.of(context);
  }
  Object? get context => null;
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    // BAD: unguarded context use after awaited navigation fires.
    test('BAD: unguarded context after await fires', () async {
      const code = '''
class State {}
class W extends State {
  bool mounted = true;
  Object? navigator;
  Future<void> go() async {
    await navigator!.push();
    navigator!.of(context);
  }
  Object? get context => null;
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });
  });

  // ===========================================================================
  // require_route_guards — match path SEGMENTS, not substrings.
  // ===========================================================================
  group('require_route_guards', () {
    final rule = RequireRouteGuardsRule();
    const ruleName = 'require_route_guards';

    // FP repro: '/reorder' contains 'order', '/accounting' contains 'account'.
    test('FP: /reorder does not match protected segment "order"', () async {
      const code = '''
class GoRoute {
  GoRoute({this.path, this.builder});
  final String? path;
  final Object? builder;
}
final r = GoRoute(path: '/reorder', builder: null);
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    test('FP: /accounting does not match protected segment "account"',
        () async {
      const code = '''
class GoRoute {
  GoRoute({this.path, this.builder});
  final String? path;
  final Object? builder;
}
final r = GoRoute(path: '/accounting', builder: null);
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    // BAD: a real protected segment with no redirect fires.
    test('BAD: /account with no redirect fires', () async {
      const code = '''
class GoRoute {
  GoRoute({this.path, this.builder});
  final String? path;
  final Object? builder;
}
final r = GoRoute(path: '/account', builder: null);
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });

    // GOOD: protected segment WITH a redirect stays silent.
    test('GOOD: /admin with redirect stays silent', () async {
      const code = '''
class GoRoute {
  GoRoute({this.path, this.builder, this.redirect});
  final String? path;
  final Object? builder;
  final Object? redirect;
}
final r = GoRoute(path: '/admin', builder: null, redirect: null);
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });
  });

  // ===========================================================================
  // avoid_pop_without_result — exact identifier matching, robust parent walk.
  // ===========================================================================
  group('avoid_pop_without_result', () {
    final rule = AvoidPopWithoutResultRule();
    const ruleName = 'avoid_pop_without_result';

    // FP repro: variable `result` whose only later use is the DIFFERENT
    // identifier `resultValue` must not be treated as "used without null check".
    test('FP: distinct variable resultValue not seen as use of result',
        () async {
      const code = '''
class Navigator {
  static Future<Object?> push(Object? route) async => null;
}
Future<void> go() async {
  final result = await Navigator.push(null);
  final resultValue = 42;
  print(resultValue);
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    // BAD: result used directly with no null check fires.
    test('BAD: result used without null check fires', () async {
      const code = '''
class Navigator {
  static Future<Object?> push(Object? route) async => null;
}
Future<void> go() async {
  final result = await Navigator.push(null);
  print(result.toString());
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });

    // GOOD: result guarded with == null stays silent.
    test('GOOD: result guarded with null check stays silent', () async {
      const code = '''
class Navigator {
  static Future<Object?> push(Object? route) async => null;
}
Future<void> go() async {
  final result = await Navigator.push(null);
  if (result == null) return;
  print(result);
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });
  });

  // ===========================================================================
  // avoid_go_router_push_replacement_confusion — compare path SEGMENTS.
  // ===========================================================================
  group('avoid_go_router_push_replacement_confusion', () {
    final rule = AvoidGoRouterPushReplacementConfusionRule();
    const ruleName = 'avoid_go_router_push_replacement_confusion';

    // FP repro: '/viewport/$x' — '/view' must not match the '/viewport' segment.
    test('FP: /viewport does not match detail segment /view', () async {
      const code = r'''
class C {
  void go(String p) {}
}
void run(C context, String x) {
  context.go('/viewport/$x');
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    // BAD: real /view detail route with dynamic param fires.
    test('BAD: /view/:id fires', () async {
      const code = r'''
class C {
  void go(String p) {}
}
void run(C context, String x) {
  context.go('/view/$x');
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });
  });

  // ===========================================================================
  // avoid_push_replacement_misuse — inspect the route NAME, not whole source.
  // ===========================================================================
  group('avoid_push_replacement_misuse', () {
    final rule = AvoidPushReplacementMisuseRule();
    const ruleName = 'avoid_push_replacement_misuse';

    // FP repro: a builder that constructs `ListView` must not match 'view'.
    test('FP: ListView in builder does not match indicator "view"', () async {
      const code = '''
class Navigator {
  static void pushReplacement(Object? c, Object? route) {}
}
class ListView {}
class MaterialPageRoute {
  MaterialPageRoute({this.builder});
  final Object? builder;
}
void run(Object? context) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: () => ListView()),
  );
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    // BAD: pushReplacementNamed to a '/detail' named route fires.
    test('BAD: pushReplacementNamed to /detail fires', () async {
      const code = '''
class Navigator {
  static void pushReplacementNamed(Object? c, String name) {}
}
void run(Object? context) {
  Navigator.pushReplacementNamed(context, '/detail');
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });
  });

  // ===========================================================================
  // require_deep_link_testing — inspect named-arg labels via AST.
  // ===========================================================================
  group('require_deep_link_testing', () {
    final rule = RequireDeepLinkTestingRule();
    const ruleName = 'require_deep_link_testing';

    // FP repro: object whose construction has a `uuid:` arg (contains 'id:')
    // must not be treated as carrying an `id`.
    test('FP: uuid: named arg does not count as id', () async {
      const code = '''
class Foo {
  Foo({this.uuid});
  final String? uuid;
}
class Navigator {
  static void pushNamed(Object? c, String name, {Object? arguments}) {}
}
void run(Object? context) {
  Navigator.pushNamed(context, '/x', arguments: Foo(uuid: 'abc'));
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });

    // GOOD: object whose construction has a real `id:` arg stays silent.
    test('GOOD: id: named arg counts as id', () async {
      const code = '''
class Foo {
  Foo({this.id});
  final String? id;
}
class Navigator {
  static void pushNamed(Object? c, String name, {Object? arguments}) {}
}
void run(Object? context) {
  Navigator.pushNamed(context, '/x', arguments: Foo(id: 'abc'));
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });
  });

  // ===========================================================================
  // prefer_go_router_extra_typed — inspect declared element type, not display.
  // ===========================================================================
  group('prefer_go_router_extra_typed', () {
    final rule = PreferGoRouterExtraTypedRule();
    const ruleName = 'prefer_go_router_extra_typed';

    // FP repro: a strongly-typed custom class passed as extra must not fire.
    test('FP: typed custom class extra stays silent', () async {
      const code = '''
class UserData {
  const UserData(this.name);
  final String name;
}
class C {
  void push(String p, {Object? extra}) {}
}
void run(C context) {
  const data = UserData('a');
  context.push('/x', extra: data);
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    // BAD: a Map literal extra fires.
    test('BAD: map literal extra fires', () async {
      const code = '''
class C {
  void push(String p, {Object? extra}) {}
}
void run(C context) {
  context.push('/x', extra: {'k': 'v'});
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });
  });
}
