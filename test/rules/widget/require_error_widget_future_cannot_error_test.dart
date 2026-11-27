// Bug: plans/history/2026.11/2026.11.27/require_error_widget_false_positive_future_that_cannot_error.md
//
// Runs the real RequireErrorWidgetRule. A FutureBuilder over a same-file
// future that catches every failure must be silent; every shape that can still
// fail, or cannot be traced, must keep reporting.
library;

import 'package:saropa_lints/src/rules/widget/widget_patterns_require_rules.dart';
import 'package:test/test.dart';

import '../../support/syntactic_rule_harness.dart';

/// A self-handling producer used by most cases.
const String _safeLoad = '''
  Future<String?> _load() async {
    try {
      return await fetchName();
    } on Object catch (error, stack) {
      log(error, stack);
      return null;
    }
  }
''';

/// A producer with no handling at all.
const String _rawLoad = '''
  Future<String?> _raw() async => await fetchName();
''';

/// Wraps [members] in a State whose build passes [future] to a FutureBuilder.
/// `new` is required: the syntactic parser cannot otherwise tell a generic
/// constructor call from a method call.
String _state(String members, {String future = '_future', String extra = ''}) =>
    '''
$extra
class _S extends State<W> {
$members
  Widget build(BuildContext context) {
    return new FutureBuilder<String?>(
      future: $future,
      builder: (context, snapshot) => Text(snapshot.data ?? 'none'),
    );
  }
}
''';

/// A field plus `_load` with the given try block, catch clause and finally.
String _loader({
  String tryBody = 'return await fetchName();',
  String handler = 'catch (e) { return null; }',
  String tail = '',
}) =>
    '''
  late final Future<String?> _future = _load();
  Future<String?> _load() async {
    try { $tryBody } $handler $tail
  }
''';

/// Number of diagnostics the real rule reports for [code].
int _count(String code) =>
    runRuleSyntactic(RequireErrorWidgetRule(), code).length;

/// Registers a test expecting the rule to stay silent.
void _ok(String name, String code) =>
    test('OK: $name', () => expect(_count(code), 0));

/// Registers a test expecting exactly one diagnostic.
void _lint(String name, String code) =>
    test('LINT: $name', () => expect(_count(code), 1));

void main() {
  group('require_error_widget: future that cannot error', () {
    _ok(
      'late final field initializer',
      _state('late final Future<String?> _future = _load();\n$_safeLoad'),
    );
    _ok('direct call', _state(_safeLoad, future: '_load()'));
    _ok('this-qualified call', _state(_safeLoad, future: 'this._load()'));
    _ok(
      'initState assignment',
      _state('''
  late Future<String?> _future;
  void initState() { _future = _load(); }
$_safeLoad'''),
    );
    _ok(
      'every reassignment qualifies',
      _state('''
  late Future<String?> _future;
  void initState() { _future = _load(); }
  void refresh() { this._future = _load(); }
$_safeLoad'''),
    );
    _ok(
      'top-level function',
      _state(
        '',
        future: 'load()',
        extra: '''
Future<String?> load() async {
  try { return await fetch(); } catch (e) { return ''; }
}''',
      ),
    );
    _ok('catch (e) with literal fallback', _state(_loader()));
    _ok(
      'same field name in an unrelated class',
      _state(
        _loader(),
        extra: '''
class _Other {
  Future<int>? _future;
  void go() { _future = fetch(); }
}''',
      ),
    );
  });

  // `return items;` is only safe when the local's written type rules out a
  // future; anything else could hand back an un-awaited one.
  group('require_error_widget: returning a local from the try', () {
    _ok(
      'typed core local, with a statement call in the handler',
      _state(
        _loader(
          tryBody:
              'final List<String> items = await fetch() ?? <String>[]; '
              'if (items.isEmpty) notify(); return items;',
          handler:
              'on Object catch (e, s) { log(e, s); close(); return <String>[]; }',
        ),
      ),
    );
    _lint(
      'inferred local may hold a future',
      _state(_loader(tryBody: 'final x = fetchName(); return x;')),
    );
    _lint(
      'Future-typed local',
      _state(
        _loader(tryBody: 'final Future<String?> x = fetchName(); return x;'),
      ),
    );
    _lint(
      'Object-typed local',
      _state(_loader(tryBody: 'final Object x = fetchName(); return x;')),
    );
    _lint(
      'loop variable shadows the typed local',
      _state(
        _loader(
          tryBody:
              "final String x = ''; for (final x in pending) { return x; } "
              'return x;',
        ),
      ),
    );
    _lint(
      'unassigned late local throws in the handler',
      _state(_loader(handler: 'catch (e) { late String x; return x; }')),
    );
  });

  group('require_error_widget: future that can still error', () {
    _lint('rethrow', _state(_loader(handler: 'catch (e) { rethrow; }')));
    _lint(
      'throw in catch',
      _state(_loader(handler: 'catch (e) { throw StateError("x"); }')),
    );
    _lint(
      'unawaited return in try',
      _state(_loader(tryBody: 'return fetchName();')),
    );
    _lint(
      'unawaited return in catch',
      _state(_loader(handler: 'catch (e) { return fallback(); }')),
    );
    _lint(
      'await in catch',
      _state(_loader(handler: 'catch (e) { await report(e); return null; }')),
    );
    _lint(
      'throw in finally',
      _state(_loader(tail: 'finally { throw StateError("x"); }')),
    );
    _lint(
      'on FormatException catch is not a catch-all',
      _state(_loader(handler: 'on FormatException catch (e) { return null; }')),
    );
    _lint(
      'statement outside the try',
      _state('''
  Future<String?> _load() async {
    prepare();
    try { return await fetchName(); } catch (e) { return null; }
  }''', future: '_load()'),
    );
  });

  group('require_error_widget: untraceable future', () {
    _lint(
      'one reassignment from a raw future',
      _state('''
  late Future<String?> _future;
  void initState() { _future = _load(); }
  void refresh() { _future = _raw(); }
$_safeLoad$_rawLoad'''),
    );
    _lint(
      'public mutable field',
      _state('''
  Future<String?>? future;
  void initState() { future = _load(); }
$_safeLoad''', future: 'future'),
    );
    _lint(
      'field set from a constructor parameter',
      _state('_S(this._future);\n  final Future<String?> _future;'),
    );
    _lint('local variable shadows the field', '''
class _S {
  late final Future<String?> _future = _load();
$_safeLoad
  Widget build(BuildContext context) {
    final _future = fetchName();
    return new FutureBuilder(future: _future, builder: (c, s) => Text('x'));
  }
}''');
    _lint('member of another object', _state('', future: 'widget.future'));
    _lint('unresolved call', _state('', future: 'fetchName()'));
  });

  // The traced body only proves something when it is the code that runs: an
  // override replaces it at runtime.
  group('require_error_widget: overridable producer', () {
    _lint(
      'same-file subclass overrides the method',
      _state(
        _loader(),
        extra: '''
class _T extends _S {
  Future<String?> _load() async => throw StateError('x');
}''',
      ),
    );
    _lint(
      'same-file subclass replaces the field with a getter',
      _state(
        _loader(),
        extra: '''
class _T extends _S {
  Future<String?> get _future => fetchName();
}''',
      ),
    );
    _lint(
      'grandchild override through a class alias',
      _state(
        _loader(),
        extra: '''
class _A = _S with _M;
class _T extends _A {
  Future<String?> _load() async => throw StateError('x');
}''',
      ),
    );
    _lint('public method on an extendable public class', '''
class S extends State<W> {
  Future<String?> load() async {
    try { return await fetchName(); } catch (e) { return null; }
  }
  Widget build(BuildContext context) {
    return new FutureBuilder<String?>(
      future: load(),
      builder: (context, snapshot) => Text(snapshot.data ?? 'none'),
    );
  }
}''');
    _ok('public method on a final class', '''
final class S extends State<W> {
  Future<String?> load() async {
    try { return await fetchName(); } catch (e) { return null; }
  }
  Widget build(BuildContext context) {
    return new FutureBuilder<String?>(
      future: load(),
      builder: (context, snapshot) => Text(snapshot.data ?? 'none'),
    );
  }
}''');
    _lint(
      'library with a part file',
      _state(_loader(), extra: "part 'other.dart';"),
    );
    _ok(
      'unrelated sibling class with the same method name',
      _state(
        _loader(),
        extra: '''
class _Other extends State<W> {
  Future<String?> _load() async => throw StateError('x');
}''',
      ),
    );
    _lint('call inside an extension resolves to its own member', '''
Future<String?> _load() async {
  try { return await fetchName(); } catch (e) { return null; }
}
extension on Foo {
  Future<String?> _load() => fetchName();
  Widget view() => new FutureBuilder<String?>(
    future: _load(),
    builder: (context, snapshot) => Text(snapshot.data ?? 'none'),
  );
}''');
  });

  // An error thrown synchronously inside a handler also fails the future.
  group('require_error_widget: handler that can throw', () {
    _ok(
      'guarded debug log',
      _state(
        _loader(
          handler:
              "catch (e) { if (kDebugMode) debugPrint('\$e'); return null; }",
        ),
      ),
    );
    _lint(
      'cast in catch',
      _state(
        _loader(
          handler:
              'catch (e) { _err = (e as FormatException).message; return null; }',
        ),
      ),
    );
    _lint(
      'null assertion in catch',
      _state(_loader(handler: 'catch (e) { _last = _cache!; return null; }')),
    );
    _lint(
      'index in catch',
      _state(_loader(handler: 'catch (e) { _last = codes[0]; return null; }')),
    );
    _lint(
      'call whose result is kept',
      _state(
        _loader(handler: 'catch (e) { final m = describe(e); return null; }'),
      ),
    );
    _lint(
      'constructor call in catch',
      _state(
        _loader(handler: 'catch (e) { _err = AppError(e); return null; }'),
      ),
    );
    _lint(
      'loop in catch',
      _state(
        _loader(
          handler: 'catch (e) { for (final x in xs) { log(x); } return null; }',
        ),
      ),
    );
    _lint(
      'call in finally result is kept',
      _state(_loader(tail: 'finally { _done = mark(); }')),
    );
  });
}
