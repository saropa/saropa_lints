// Reproduction + regression tests for false-positive fixes in
// lib/src/rules/packages/riverpod_rules.dart.
//
// All fixtures define LOCAL STUB classes (WidgetRef, ConsumerState, State,
// AsyncValue, etc.) so the resolved-analyzer oracle resolves types WITHOUT a
// Flutter/Riverpod dependency (the example fixture package has none). The
// harness ENFORCES `applicableFileTypes`: these rules gate on
// FileType.provider, which the FileTypeDetector grants when the file text
// contains one of `@riverpod`, `ConsumerWidget`, `ConsumerStatefulWidget`,
// `ProviderScope`, `ref.watch(`, `ref.read(`, etc. Every fixture below contains
// at least one such marker so the provider gate opens and the visitor runs.
//
// Why local stubs with the SAME NAMES as the real Riverpod types: the fixes
// resolve `ref` to a type named `WidgetRef`/`Ref` and a `.value` target to a
// type named `AsyncValue` by element/type name (not by the identifier's own
// name). A stub class with the matching name lets the oracle exercise the
// resolved path without pulling in the real package.
library;

import 'package:saropa_lints/src/rules/packages/riverpod_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

// Stubs shared by the dispose-related fixtures. `WidgetRef`/`Ref` carry the
// `read`/`watch`/`listen` methods the true positives use; `ConsumerState` is
// the Riverpod state base, `State` the Flutter base, and `OtherRef` an
// unrelated type that happens to expose a `dispose()` method so a field named
// `ref` of THAT type can be exercised as a false-positive case.
const String _disposeStubs = '''
class WidgetRef {
  T read<T>(Object provider) => throw 0;
  T watch<T>(Object provider) => throw 0;
  void listen(Object provider, void Function(Object?, Object?) cb) {}
}

class Ref {
  T read<T>(Object provider) => throw 0;
}

class ConsumerState<T> {
  final WidgetRef ref = WidgetRef();
  void dispose() {}
}

class State<T> {
  void dispose() {}
}

class OtherRef {
  void read(Object x) {}
  void dispose() {}
}

class MyWidget {}
''';

const String _asyncStubs = '''
class AsyncValue<T> {
  T? get value => null;
}

class PlainAsyncThing {
  int? get value => 1;
}
''';

void main() {
  // --------------------------------------------------------------------------
  // Item: avoid_ref_inside_state_dispose
  // The OLD visitor flagged any SimpleIdentifier named `ref` inside dispose(),
  // with no type/element check. A field/local named `ref` of an UNRELATED type
  // must not be flagged. The Riverpod WidgetRef.read in dispose must still flag.
  // --------------------------------------------------------------------------
  group('avoid_ref_inside_state_dispose', () {
    test('flags Riverpod WidgetRef use in dispose (true positive)', () async {
      // `ref` resolves to the stub WidgetRef; calling read() in dispose is the
      // unsafe pattern the rule targets. `ref.read(` also opens the provider gate.
      final code =
          '''
$_disposeStubs
class MyState extends ConsumerState<MyWidget> {
  @override
  void dispose() {
    ref.read(0);
    super.dispose();
  }
}
''';
      final codes = await reportedRuleCodes(
        AvoidRefInsideStateDisposeRule(),
        code,
      );
      expect(codes, contains('avoid_ref_inside_state_dispose'));
    });

    test('does NOT flag unrelated field named ref in dispose (FP)', () async {
      // `ref` here is an OtherRef (not Riverpod). The file still contains a
      // `ref.read(` marker via a separate provider-gated method so the rule runs.
      final code =
          '''
$_disposeStubs
class MyState extends State<MyWidget> {
  final OtherRef ref = OtherRef();
  final WidgetRef _wr = WidgetRef();

  void open() {
    _wr.read<int>(0);
  }

  @override
  void dispose() {
    ref.read(0);
    super.dispose();
  }
}
''';
      final codes = await reportedRuleCodes(
        AvoidRefInsideStateDisposeRule(),
        code,
      );
      expect(codes, isNot(contains('avoid_ref_inside_state_dispose')));
    });
  });

  // --------------------------------------------------------------------------
  // Item: avoid_ref_in_dispose
  // The OLD visitor reported any MethodInvocation whose target is a
  // SimpleIdentifier named `ref`, gated only on the superclass name containing
  // `ConsumerState` OR being exactly `State`. A field named `ref` of an
  // unrelated type in a plain Flutter `State` must not be flagged.
  // --------------------------------------------------------------------------
  group('avoid_ref_in_dispose', () {
    test(
      'flags Riverpod WidgetRef invocation in dispose (true positive)',
      () async {
        final code =
            '''
$_disposeStubs
class MyState extends ConsumerState<MyWidget> {
  @override
  void dispose() {
    ref.read(0);
    super.dispose();
  }
}
''';
        final codes = await reportedRuleCodes(AvoidRefInDisposeRule(), code);
        expect(codes, contains('avoid_ref_in_dispose'));
      },
    );

    test(
      'does NOT flag unrelated ref field in plain State.dispose (FP)',
      () async {
        final code =
            '''
$_disposeStubs
class MyState extends State<MyWidget> {
  final OtherRef ref = OtherRef();
  final WidgetRef _wr = WidgetRef();

  void open() {
    _wr.read<int>(0);
  }

  @override
  void dispose() {
    ref.read(0);
    super.dispose();
  }
}
''';
        final codes = await reportedRuleCodes(AvoidRefInDisposeRule(), code);
        expect(codes, isNot(contains('avoid_ref_in_dispose')));
      },
    );
  });

  // --------------------------------------------------------------------------
  // Item: avoid_nullable_async_value_pattern
  // The OLD logic flagged `<x>.value` when the target source matched
  // /\bAsyncValue\b/ or ended with `async`/`Async`, or the prefix lowercased
  // contained `async`. A variable merely NAMED with `async` accessing `.value`
  // on an unrelated type must not be flagged; a real AsyncValue must be.
  // --------------------------------------------------------------------------
  group('avoid_nullable_async_value_pattern', () {
    test('flags .value on a real AsyncValue (true positive)', () async {
      // `data` resolves to AsyncValue<int>; the `ref.watch(` line opens the
      // provider gate.
      final code =
          '''
$_asyncStubs
int? read(WidgetRef ref) {
  ref.watch(0);
  final AsyncValue<int> data = AsyncValue<int>();
  return data.value;
}

class WidgetRef {
  T watch<T>(Object provider) => throw 0;
}
''';
      final codes = await reportedRuleCodes(
        AvoidNullableAsyncValuePatternRule(),
        code,
      );
      expect(codes, contains('avoid_nullable_async_value_pattern'));
    });

    test(
      'does NOT flag .value on a non-AsyncValue named with async (FP)',
      () async {
        // `asyncThing` is a PlainAsyncThing (NOT AsyncValue). Its name contains
        // "async" and the old prefix heuristic flagged it. The `ref.watch(` marker
        // opens the provider gate.
        final code =
            '''
$_asyncStubs
int? read(WidgetRef ref) {
  ref.watch(0);
  final PlainAsyncThing asyncThing = PlainAsyncThing();
  return asyncThing.value;
}

class WidgetRef {
  T watch<T>(Object provider) => throw 0;
}
''';
        final codes = await reportedRuleCodes(
          AvoidNullableAsyncValuePatternRule(),
          code,
        );
        expect(codes, isNot(contains('avoid_nullable_async_value_pattern')));
      },
    );
  });
}
