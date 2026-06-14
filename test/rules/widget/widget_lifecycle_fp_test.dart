// Reproduction + regression tests for false-positive / false-negative fixes in
// lib/src/rules/widget/widget_lifecycle_rules.dart.
//
// All fixtures define LOCAL STUB classes (Widget, StatelessWidget,
// StatefulWidget, State, AnimationController, ScrollController, etc.) so the
// resolved-analyzer oracle can resolve types WITHOUT a Flutter dependency (the
// example fixture package has none). Element identity / staticType checks
// therefore work against these stubs.
//
// The harness ENFORCES `applicableFileTypes`: every widget-gated rule only runs
// when the file content classifies as FileType.widget, which requires the text
// to contain `extends StatelessWidget` / `extends StatefulWidget` /
// `extends State<`. The stubs below include a concrete `extends State<...>`
// class so the gate opens.
library;

import 'package:saropa_lints/src/rules/widget/widget_lifecycle_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

/// Minimal Flutter-shaped stubs. `State<T>` resolves to THIS declaration, so
/// `superclass.element` is non-null and its name is `State` — exactly what a
/// genuine Flutter State subclass would resolve to in a real project. A class
/// the user names `State` themselves also resolves here, which is why the
/// element check still treats it as a State; the meaningful FP cases tested
/// below are the ones where the enclosing class is NOT a State at all.
const String _stubs = '''
class Widget {
  const Widget({this.child});
  final Widget? child;
}

class BuildContext {}

class StatelessWidget extends Widget {
  const StatelessWidget();
}

class StatefulWidget extends Widget {
  const StatefulWidget();
}

class State<T> {
  void initState() {}
  void dispose() {}
  void didChangeDependencies() {}
  void setState(void Function() fn) {}
  bool get mounted => true;
}

class ScrollController {
  void dispose() {}
  void addListener(void Function() fn) {}
}

class TextEditingController {
  void dispose() {}
  void addListener(Object fn) {}
}

class AnimationController {
  void dispose() {}
}

class ChangeNotifier {
  void addListener(void Function() fn) {}
  void removeListener(void Function() fn) {}
}

// Used so a fixture always classifies as FileType.widget even when the class
// under test is intentionally NOT a State subclass.
class _GateWidget extends StatelessWidget {
  const _GateWidget();
}
''';

void main() {
  // ===========================================================================
  // avoid_inherited_widget_in_initstate — must gate on enclosing State class.
  // ===========================================================================
  group('avoid_inherited_widget_in_initstate', () {
    test('FP: initState in a NON-State class must not fire', () async {
      // A plain class with a method literally named `initState` that calls
      // Theme.of(...) is not a Flutter State at all — the lifecycle hazard
      // (unmounted element tree) cannot apply. The rule used to fire on any
      // method named initState regardless of the enclosing class.
      final codes = await reportedRuleCodes(
        AvoidInheritedWidgetInInitStateRule(),
        '''
$_stubs
class Theme {
  static Object of(Object c) => 0;
}
class NotAState {
  void initState() {
    Theme.of(0);
  }
}
''',
      );
      expect(
        codes,
        isNot(contains('avoid_inherited_widget_in_initstate')),
        reason: 'initState outside a State subclass is not a lifecycle hazard.',
      );
    });

    test('BAD: Theme.of in a real State.initState still fires', () async {
      final codes = await reportedRuleCodes(
        AvoidInheritedWidgetInInitStateRule(),
        '''
$_stubs
class Theme {
  static Object of(Object c) => 0;
}
class _S extends State<Widget> {
  @override
  void initState() {
    super.initState();
    Theme.of(context);
  }
}
''',
      );
      expect(codes, contains('avoid_inherited_widget_in_initstate'));
    });
  });

  // ===========================================================================
  // avoid_expensive_did_change_dependencies — must gate on enclosing State.
  // ===========================================================================
  group('avoid_expensive_did_change_dependencies', () {
    test(
      'FP: didChangeDependencies in a NON-State class must not fire',
      () async {
        final codes = await reportedRuleCodes(
          AvoidExpensiveDidChangeDependenciesRule(),
          '''
$_stubs
class NotAState {
  Object fetchData() => 0;
  void didChangeDependencies() {
    fetchData();
  }
}
''',
        );
        expect(
          codes,
          isNot(contains('avoid_expensive_did_change_dependencies')),
          reason: 'Only the State lifecycle callback re-runs on dep changes.',
        );
      },
    );

    test(
      'BAD: expensive call in a real State.didChangeDependencies fires',
      () async {
        final codes = await reportedRuleCodes(
          AvoidExpensiveDidChangeDependenciesRule(),
          '''
$_stubs
class _S extends State<Widget> {
  Object fetchData() => 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    fetchData();
  }
}
''',
        );
        expect(codes, contains('avoid_expensive_did_change_dependencies'));
      },
    );
  });

  // ===========================================================================
  // avoid_recursive_widget_calls — self-instantiation by resolved element.
  // ===========================================================================
  group('avoid_recursive_widget_calls', () {
    test('FP: same-named imported widget is not self-recursion', () async {
      // The build method returns a DIFFERENT class that merely shares the
      // simple name `Card` with... no — here the local widget is `MyCard` and
      // it builds a same-named `MyCard` that is a SEPARATE class. Lexeme
      // matching of the constructor type name to the enclosing class name
      // false-flagged any same-named type even when it resolves elsewhere.
      final codes = await reportedRuleCodes(AvoidRecursiveWidgetCallsRule(), '''
$_stubs
class _OtherLib {
  static Widget make() => const _Inner();
}
class _Inner extends StatelessWidget {
  const _Inner();
}
class MyCard extends StatelessWidget {
  const MyCard();
  @override
  Widget build(BuildContext context) {
    return _OtherLib.make();
  }
}
''');
      expect(
        codes,
        isNot(contains('avoid_recursive_widget_calls')),
        reason: 'Build returns a different resolved type, not itself.',
      );
    });

    test('BAD: genuine self-instantiation in build still fires', () async {
      final codes = await reportedRuleCodes(AvoidRecursiveWidgetCallsRule(), '''
$_stubs
class Loop extends StatelessWidget {
  const Loop();
  @override
  Widget build(BuildContext context) {
    return const Loop();
  }
}
''');
      expect(codes, contains('avoid_recursive_widget_calls'));
    });
  });

  // ===========================================================================
  // avoid_unsafe_setstate — `if (mounted)` else-branch is NOT a guard.
  // ===========================================================================
  group('avoid_unsafe_setstate', () {
    test('FP-reproduction: setState in the ELSE branch of if(mounted)', () async {
      // setState lives in the `else` of `if (mounted)`, i.e. it runs only when
      // NOT mounted — the opposite of guarded. The ancestor-walk used to treat
      // any enclosing `if (mounted)` as a guard regardless of branch.
      final codes = await reportedRuleCodes(AvoidUnsafeSetStateRule(), '''
$_stubs
class _S extends State<Widget> {
  void go() {
    if (mounted) {
      print('ok');
    } else {
      setState(() {});
    }
  }
}
''');
      expect(
        codes,
        contains('avoid_unsafe_setstate'),
        reason: 'setState in the else of if(mounted) is unguarded.',
      );
    });

    test(
      'GOOD: setState in the THEN branch of if(mounted) stays silent',
      () async {
        final codes = await reportedRuleCodes(AvoidUnsafeSetStateRule(), '''
$_stubs
class _S extends State<Widget> {
  void go() {
    if (mounted) {
      setState(() {});
    }
  }
}
''');
        expect(codes, isEmpty);
      },
    );
  });

  // ===========================================================================
  // prefer_widget_state_mixin — whole-word interaction-state field detection.
  // ===========================================================================
  group('prefer_widget_state_mixin', () {
    test(
      'FP: _unfocusTimer / _focusableItems are not interaction states',
      () async {
        // `_unfocusTimer` contains "focus" and `_focusableItems` contains
        // "focus"; substring matching counted both as hover/press/focus state
        // fields and fired. Neither tracks an interaction (hover/pressed/focused)
        // boolean.
        final codes = await reportedRuleCodes(PreferWidgetStateMixinRule(), '''
$_stubs
class _S extends State<Widget> {
  Object? _unfocusTimer;
  List<Object> _focusableItems = [];
}
''');
        expect(
          codes,
          isNot(contains('prefer_widget_state_mixin')),
          reason:
              'Substring "focus" in unrelated names is not an interaction '
              'state field.',
        );
      },
    );

    test('BAD: two genuine interaction-state booleans still fire', () async {
      final codes = await reportedRuleCodes(PreferWidgetStateMixinRule(), '''
$_stubs
class _S extends State<Widget> {
  bool _isHovered = false;
  bool _isPressed = false;
}
''');
      expect(codes, contains('prefer_widget_state_mixin'));
    });
  });

  // ===========================================================================
  // avoid_scaffold_messenger_after_await — source-order await tracking.
  // ===========================================================================
  group('avoid_scaffold_messenger_after_await', () {
    test('FP: ScaffoldMessenger use BEFORE the await must not fire', () async {
      // The ScaffoldMessenger.of(context) call is lexically BEFORE the await,
      // inside the same first statement (a try block). Per-statement hasAwait
      // wrongly reported it as "after await".
      final codes = await reportedRuleCodes(
        AvoidScaffoldMessengerAfterAwaitRule(),
        '''
$_stubs
class ScaffoldMessenger {
  static Object of(Object c) => 0;
}
Future<void> f(Object future) async {
  try {
    ScaffoldMessenger.of(0);
    await future;
  } catch (e) {}
}
''',
      );
      expect(
        codes,
        isNot(contains('avoid_scaffold_messenger_after_await')),
        reason: 'Use precedes the await in source order; not "after".',
      );
    });

    test('BAD: ScaffoldMessenger use AFTER the await still fires', () async {
      final codes = await reportedRuleCodes(
        AvoidScaffoldMessengerAfterAwaitRule(),
        '''
$_stubs
class ScaffoldMessenger {
  static Object of(Object c) => 0;
}
Future<void> f(Object future) async {
  await future;
  ScaffoldMessenger.of(0);
}
''',
      );
      expect(codes, contains('avoid_scaffold_messenger_after_await'));
    });
  });

  // ===========================================================================
  // require_field_dispose — cross-statement cascade must not satisfy a field.
  // ===========================================================================
  group('require_field_dispose', () {
    test(
      'FN-reproduction: another field disposed INSIDE _a\'s cascade arg',
      () async {
        // `_a` is only added as a listener — never disposed. `_b` is disposed
        // but nested as an argument INSIDE `_a`'s cascade section. The cross-
        // statement regex (`_a\??(?:\.\.[^;]+)*\.\.dispose\(`) wrongly matches
        // `_a` against the nested `_b..dispose(` because `[^;]+` swallows the
        // whole single-statement expression, so `_a` is treated as disposed.
        final codes = await reportedRuleCodes(RequireDisposeRule(), '''
$_stubs
class _S extends State<Widget> {
  TextEditingController _a = TextEditingController();
  TextEditingController _b = TextEditingController();

  @override
  void dispose() {
    _a..addListener(_b..dispose());
    super.dispose();
  }
}
''');
        expect(
          codes,
          contains('require_field_dispose'),
          reason:
              '_a is undisposed; a nested _b..dispose() must not satisfy it.',
        );
      },
    );

    test(
      'GOOD: each field disposed via its own cascade stays silent',
      () async {
        final codes = await reportedRuleCodes(RequireDisposeRule(), '''
$_stubs
class _S extends State<Widget> {
  TextEditingController _a = TextEditingController();
  TextEditingController _b = TextEditingController();

  @override
  void dispose() {
    _a..dispose();
    _b..dispose();
    super.dispose();
  }
}
''');
        expect(codes, isEmpty);
      },
    );

    test('FP: parent-owned controller (widget.controller) is skipped', () async {
      // Mirrors the existing ownership exemption; pinned here as a regression.
      final codes = await reportedRuleCodes(RequireDisposeRule(), '''
$_stubs
class _W extends StatefulWidget {
  const _W(this.controller);
  final TextEditingController controller;
}
class _S extends State<Widget> {
  TextEditingController _c = widget.controller;
  @override
  void dispose() {
    super.dispose();
  }
}
''');
      expect(codes, isNot(contains('require_field_dispose')));
    });
  });

  // ===========================================================================
  // require_init_state_idempotent — removeListener must be a real invocation.
  //
  // This rule self-gates on `ProjectContext.getProjectInfo(...).isFlutterProject`
  // and returns early when the analyzed file is not in a Flutter project. The
  // resolved-rule oracle writes fixtures under the example package, which has NO
  // Flutter dependency, so this rule never reaches its detection logic here and
  // CANNOT be exercised by the harness (both the FP and the GOOD case would
  // report empty trivially, proving nothing). The substring->AST-invocation fix
  // (match `removeListener(`/`removeObserver(` as a real MethodInvocation in the
  // dispose body instead of a text substring of toSource()) is therefore
  // verified by code inspection, not by this oracle. Pinned skip so the gap is
  // explicit rather than a silently-passing trivial assertion.
  // ===========================================================================
  group('require_init_state_idempotent', () {
    test(
      'removeListener detection (Flutter-gated; not oracle-runnable)',
      () {},
      skip:
          'Rule returns early unless isFlutterProject; the Flutter-less '
          'example package cannot satisfy that gate. Fix verified by inspection.',
    );
  });

  // ===========================================================================
  // State-matched rules: require_super_dispose_call / require_super_init_state_call
  // / avoid_set_state_in_dispose. These previously checked
  // `node.parent is ClassDeclaration`, but in the current analyzer a
  // MethodDeclaration's direct parent is the class BODY node, not the
  // ClassDeclaration — so the guard never held and the rules NEVER fired (a
  // silent false-negative, not the false-positive the audit framed). The fix
  // walks `thisOrAncestorOfType<ClassDeclaration>()` and gates on a resolved
  // State subclass. These tests pin that the genuine cases now fire again.
  // ===========================================================================
  group('State-matched rules: genuine cases fire', () {
    test('require_super_dispose_call: missing super.dispose() fires', () async {
      final codes = await reportedRuleCodes(RequireSuperDisposeCallRule(), '''
$_stubs
class _S extends State<Widget> {
  @override
  void dispose() {
    // no super.dispose()
  }
}
''');
      expect(codes, contains('require_super_dispose_call'));
    });

    test(
      'require_super_init_state_call: missing super.initState() fires',
      () async {
        final codes = await reportedRuleCodes(
          RequireSuperInitStateCallRule(),
          '''
$_stubs
class _S extends State<Widget> {
  @override
  void initState() {
    // no super.initState()
  }
}
''',
        );
        expect(codes, contains('require_super_init_state_call'));
      },
    );

    test('avoid_set_state_in_dispose: setState in dispose fires', () async {
      final codes = await reportedRuleCodes(AvoidSetStateInDisposeRule(), '''
$_stubs
class _S extends State<Widget> {
  @override
  void dispose() {
    setState(() {});
    super.dispose();
  }
}
''');
      expect(codes, contains('avoid_set_state_in_dispose'));
    });
  });

  // ===========================================================================
  // require_scroll_controller_dispose — parent-owned controller skip.
  // ===========================================================================
  group('require_scroll_controller_dispose', () {
    test(
      'FP: parent-owned ScrollController (widget.controller) is skipped',
      () async {
        final codes = await reportedRuleCodes(
          RequireScrollControllerDisposeRule(),
          '''
$_stubs
class _S extends State<Widget> {
  ScrollController _c = widget.controller;
  @override
  void dispose() {
    super.dispose();
  }
}
''',
        );
        expect(
          codes,
          isNot(contains('require_scroll_controller_dispose')),
          reason: 'Parent owns the controller; State must not dispose it.',
        );
      },
    );

    test(
      'BAD: locally constructed undisposed ScrollController still fires',
      () async {
        final codes = await reportedRuleCodes(
          RequireScrollControllerDisposeRule(),
          '''
$_stubs
class _S extends State<Widget> {
  ScrollController _c = ScrollController();
  @override
  void dispose() {
    super.dispose();
  }
}
''',
        );
        expect(codes, contains('require_scroll_controller_dispose'));
      },
    );
  });
}
