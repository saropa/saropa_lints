// Reproduction + regression tests for false-positive fixes in
// lib/src/rules/packages/bloc_rules.dart.
//
// All fixtures define LOCAL STUB classes (Bloc, Cubit, event/state bases) so the
// resolved-analyzer oracle resolves types WITHOUT a Flutter dependency (the
// example fixture package has none). The harness ENFORCES `applicableFileTypes`:
// these rules gate on FileType.bloc, which requires the file text to contain
// `extends Bloc<` or `extends Cubit<`. Every fixture below includes a concrete
// `extends Bloc<...>` / `extends Cubit<...>` class so the gate opens.
library;

import 'package:saropa_lints/src/rules/packages/bloc_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

/// Minimal Bloc/Cubit-shaped stubs. `add` is a real method on `Bloc` so an
/// unqualified `add(event)` inside a Bloc constructor resolves to it; unrelated
/// collections (`List.add`) and stream controllers (`StreamController.add`)
/// resolve to their own `add`, which the fixed rule must NOT flag.
const String _blocStubs = '''
abstract class Bloc<E, S> {
  Bloc(this._state);
  S _state;
  void add(E event) {}
  void on<T extends E>(void Function(T, dynamic) handler) {}
}

abstract class Cubit<S> {
  Cubit(this._state);
  S _state;
}

class StreamController<T> {
  void add(T event) {}
}

class CounterEvent {}
class Increment extends CounterEvent {}
class Decrement extends CounterEvent {}
''';

void main() {
  // --------------------------------------------------------------------------
  // Item 1: avoid_bloc_event_in_constructor — must only flag the bloc's own
  // unqualified `add(event)`, not `someList.add(x)` / `controller.add(x)`.
  // --------------------------------------------------------------------------
  group('avoid_bloc_event_in_constructor', () {
    test('flags unqualified add() in bloc constructor (true positive)', () async {
      final code =
          '''
$_blocStubs
class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    add(Increment());
  }
}
''';
      final codes = await reportedRuleCodes(
        AvoidBlocEventInConstructorRule(),
        code,
      );
      expect(codes, contains('avoid_bloc_event_in_constructor'));
    });

    test('does NOT flag List.add() in bloc constructor (FP)', () async {
      final code =
          '''
$_blocStubs
class CounterBloc extends Bloc<CounterEvent, int> {
  final List<int> _items = <int>[];
  CounterBloc() : super(0) {
    _items.add(1);
  }
}
''';
      final codes = await reportedRuleCodes(
        AvoidBlocEventInConstructorRule(),
        code,
      );
      expect(codes, isNot(contains('avoid_bloc_event_in_constructor')));
    });

    test('does NOT flag controller.add() in bloc constructor (FP)', () async {
      final code =
          '''
$_blocStubs
class CounterBloc extends Bloc<CounterEvent, int> {
  final StreamController<int> _controller = StreamController<int>();
  CounterBloc() : super(0) {
    _controller.add(5);
  }
}
''';
      final codes = await reportedRuleCodes(
        AvoidBlocEventInConstructorRule(),
        code,
      );
      expect(codes, isNot(contains('avoid_bloc_event_in_constructor')));
    });
  });

  // --------------------------------------------------------------------------
  // Item 2: require_immutable_bloc_state — must only flag classes that
  // participate in a Bloc/Cubit state hierarchy (used as a `Bloc<_, ThisState>`
  // or `Cubit<ThisState>` type argument), not any `...State`-named domain class.
  // --------------------------------------------------------------------------
  group('require_immutable_bloc_state', () {
    test('flags mutable state used as Bloc state type arg (true positive)', () async {
      final code =
          '''
$_blocStubs
class CounterState {
  int count;
  CounterState(this.count);
}

class CounterBloc extends Bloc<CounterEvent, CounterState> {
  CounterBloc() : super(CounterState(0));
}
''';
      final codes = await reportedRuleCodes(
        RequireImmutableBlocStateRule(),
        code,
      );
      expect(codes, contains('require_immutable_bloc_state'));
    });

    test('does NOT flag a ...State domain class not wired to any bloc (FP)', () async {
      // `ButtonState` ends with "State" and is mutable, but is never used as a
      // Bloc/Cubit type argument — it is a plain domain object, not a BLoC
      // state, so the rule must stay silent.
      final code =
          '''
$_blocStubs
class ButtonState {
  bool pressed;
  ButtonState(this.pressed);
}

class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0);
}
''';
      final codes = await reportedRuleCodes(
        RequireImmutableBlocStateRule(),
        code,
      );
      expect(codes, isNot(contains('require_immutable_bloc_state')));
    });

    test('does NOT flag RequestState not wired to any bloc (FP)', () async {
      final code =
          '''
$_blocStubs
class RequestState {
  bool loading;
  RequestState(this.loading);
}

class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0);
}
''';
      final codes = await reportedRuleCodes(
        RequireImmutableBlocStateRule(),
        code,
      );
      expect(codes, isNot(contains('require_immutable_bloc_state')));
    });
  });

  // --------------------------------------------------------------------------
  // Item 3: prefer_cubit_for_simple — must count real `on<...>` AST invocations,
  // not regex matches in comments/strings, and must catch `on<Foo<Bar>>`.
  // --------------------------------------------------------------------------
  group('prefer_cubit_for_simple', () {
    test('flags bloc with <=2 event handlers (true positive)', () async {
      final code =
          '''
$_blocStubs
class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<Increment>((e, emit) {});
  }
}
''';
      final codes = await reportedRuleCodes(PreferCubitForSimpleRule(), code);
      expect(codes, contains('prefer_cubit_for_simple'));
    });

    test('still flags simple bloc despite fake on<X> tokens in comment/string', () async {
      // Exactly ONE real handler, so this SHOULD suggest Cubit. The comment and
      // string literal contain extra `on<Foo>` tokens that the old
      // `RegExp(r'on<\\w+>')` over node.toSource() would have counted, pushing
      // the total past 2 and silencing the rule (a false negative). The AST
      // counter ignores comments/strings and still flags.
      final code =
          '''
$_blocStubs
class CounterBloc extends Bloc<CounterEvent, int> {
  // handlers: on<Increment> on<Decrement> on<Reset> on<Pause>
  final String doc = 'register on<Increment> on<Decrement> on<Reset>';
  CounterBloc() : super(0) {
    on<Increment>((e, emit) {});
  }
}
''';
      final codes = await reportedRuleCodes(PreferCubitForSimpleRule(), code);
      expect(codes, contains('prefer_cubit_for_simple'));
    });

    test('counts on<Foo<Bar>> nested-generic handlers (true positive)', () async {
      // Three handlers, one with a nested generic type argument the old
      // `on<\\w+>` regex would have missed entirely (undercounting to 2).
      final code =
          '''
$_blocStubs
class Wrapper<T> extends CounterEvent {}

class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<Increment>((e, emit) {});
    on<Decrement>((e, emit) {});
    on<Wrapper<int>>((e, emit) {});
  }
}
''';
      final codes = await reportedRuleCodes(PreferCubitForSimpleRule(), code);
      // 3 real handlers => should NOT suggest Cubit. The old regex missed the
      // nested-generic one and counted 2, wrongly flagging.
      expect(codes, isNot(contains('prefer_cubit_for_simple')));
    });
  });
}
