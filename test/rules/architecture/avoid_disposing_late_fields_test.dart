import 'dart:io';

import 'package:saropa_lints/src/rules/architecture/avoid_disposing_late_fields_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

/// Tests for the `avoid_disposing_late_fields` lint rule.
///
/// Test fixture: example/lib/architecture/avoid_disposing_late_fields_fixture.dart
///
/// The behavior group below actually RUNS the rule. The previous version of
/// this file only asserted metadata, regex-counted `// expect_lint:` markers
/// and `.contains()`-checked class names in the fixture text — every one of
/// those assertions would have passed with detection completely broken, which
/// is exactly how the nested-branch false positive fixed in v2 shipped
/// unnoticed. Each case below pins one detection decision.
void main() {
  group('AvoidDisposingLateFieldsRule - Rule Instantiation', () {
    test('AvoidDisposingLateFieldsRule', () {
      final rule = AvoidDisposingLateFieldsRule();
      expect(rule.code.lowerCaseName, 'avoid_disposing_late_fields');
      expect(
        rule.code.problemMessage,
        contains('[avoid_disposing_late_fields]'),
      );
      // The project's documented threshold (CLAUDE.md "Problem Message
      // Requirements") is >200 chars, not the weaker >50 inherited from the
      // instantiation-test boilerplate.
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('avoid_disposing_late_fields - Fixture Verification', () {
    test('fixture exists', () {
      expect(
        File(
          'example/lib/architecture/avoid_disposing_late_fields_fixture.dart',
        ).existsSync(),
        isTrue,
        reason: 'Fixture must exist',
      );
    });
  });

  group('avoid_disposing_late_fields - Behavior (BAD cases fire)', () {
    test('conditional init + unconditional dispose() fires', () async {
      final codes = await _run('''
class _BadState extends State<StatefulWidget> {
  late final AnimationController _controller;
  bool autoPlay = false;

  @override
  void initState() {
    super.initState();
    if (autoPlay) {
      _controller = AnimationController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
''');
      expect(codes, contains(_rule));
    });

    // Cascade disposal: the `..dispose()` section has a null target (the
    // real target hangs off the enclosing CascadeExpression), so the
    // target-based matcher used to miss it entirely.
    test('cascade dispose (`_controller..dispose()`) fires', () async {
      final codes = await _run('''
class _CascadeState extends State<StatefulWidget> {
  late final AnimationController _controller;
  bool autoPlay = false;

  @override
  void initState() {
    super.initState();
    if (autoPlay) {
      _controller = AnimationController();
    }
  }

  @override
  void dispose() {
    _controller..dispose();
    super.dispose();
  }
}
''');
      expect(codes, contains(_rule));
    });

    // `??=` READS the late field before deciding to assign it, so on a
    // genuinely uninitialized field the read itself throws — it is not
    // proof of safe initialization.
    test('`??=` is not accepted as safe initialization', () async {
      final codes = await _run('''
class _NullAwareState extends State<StatefulWidget> {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller ??= AnimationController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
''');
      expect(codes, contains(_rule));
    });

    // Arrow-bodied dispose() is a legal single-statement override; the rule
    // must walk `=> expr;` bodies, not only `{ ... }` blocks.
    test('arrow-bodied dispose() fires', () async {
      final codes = await _run('''
class _ArrowDisposeState extends State<StatefulWidget> {
  late final AnimationController _controller;
  bool autoPlay = false;

  @override
  void initState() {
    super.initState();
    if (autoPlay) {
      _controller = AnimationController();
    }
  }

  @override
  void dispose() => _controller.dispose();
}
''');
      expect(codes, contains(_rule));
    });

    // Call-site matching is widened past `.dispose()` to the sibling
    // cleanup verbs the rule's own doc claims to cover.
    test('`.cancel()` on a conditional late subscription fires', () async {
      final codes = await _run('''
class _SubscriptionState extends State<StatefulWidget> {
  late final AnimationController _subscription;
  bool listenEnabled = false;

  @override
  void initState() {
    super.initState();
    if (listenEnabled) {
      _subscription = AnimationController();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
''');
      expect(codes, contains(_rule));
    });
  });

  group('avoid_disposing_late_fields - Behavior (GOOD cases stay silent)', () {
    test('unconditional assignment in initState() does not fire', () async {
      final codes = await _run('''
class _GoodState extends State<StatefulWidget> {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
''');
      expect(codes, isNot(contains(_rule)));
    });

    test('if/else assigning in every branch does not fire', () async {
      final codes = await _run('''
class _FullCoverageState extends State<StatefulWidget> {
  late final AnimationController _controller;
  bool fast = false;

  @override
  void initState() {
    super.initState();
    if (fast) {
      _controller = AnimationController();
    } else {
      _controller = AnimationController();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
''');
      expect(codes, isNot(contains(_rule)));
    });

    // THE v2 FIX. Both branches genuinely initialize the field through a
    // private helper. `_hasUnanalyzableStatement` used to skip past every
    // IfStatement without recursing, and `_branchAssigns` had no bail-out of
    // its own for an unanalyzable shape nested in a branch — it just
    // returned "does not assign", producing this false positive on an
    // always-safe pattern.
    test('if/else delegating to helpers in BOTH branches does '
        'not fire', () async {
      final codes = await _run('''
class _BranchDelegationState extends State<StatefulWidget> {
  late final AnimationController _controller;
  bool useAdvanced = false;

  @override
  void initState() {
    super.initState();
    if (useAdvanced) {
      _setupAdvancedController();
    } else {
      _setupBasicController();
    }
  }

  void _setupAdvancedController() {
    _controller = AnimationController();
  }

  void _setupBasicController() {
    _controller = AnimationController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
''');
      expect(codes, isNot(contains(_rule)));
    });

    // Same bail-to-safe policy, reached through a `try` nested in a branch
    // rather than a helper call — pins that the recursion covers every
    // unanalyzable shape, not just implicit-`this` invocations.
    test('try/catch assignment nested in a branch does not fire', () async {
      final codes = await _run('''
class _BranchTryState extends State<StatefulWidget> {
  late final AnimationController _controller;
  bool useAdvanced = false;

  @override
  void initState() {
    super.initState();
    if (useAdvanced) {
      try {
        _controller = AnimationController();
      } catch (_) {
        rethrow;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
''');
      expect(codes, isNot(contains(_rule)));
    });

    // Existing top-level policy, kept as a regression pin alongside the new
    // nested variant above.
    test('top-level helper delegation does not fire', () async {
      final codes = await _run('''
class _HelperDelegationState extends State<StatefulWidget> {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  void _setupController() {
    _controller = AnimationController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
''');
      expect(codes, isNot(contains(_rule)));
    });

    test('if-guarded dispose() call does not fire', () async {
      final codes = await _run('''
class _GuardedState extends State<StatefulWidget> {
  late final AnimationController _controller;
  bool autoPlay = false;

  @override
  void initState() {
    super.initState();
    if (autoPlay) {
      _controller = AnimationController();
    }
  }

  @override
  void dispose() {
    if (autoPlay) {
      _controller.dispose();
    }
    super.dispose();
  }
}
''');
      expect(codes, isNot(contains(_rule)));
    });

    // THE v2 GUARD FIX. A switch-case arm is just as deliberate a guard as
    // an `if`; `_isGuarded` used to recognize only IfStatement ancestors.
    test('switch-guarded dispose() call does not fire', () async {
      final codes = await _run('''
class _SwitchGuardedState extends State<StatefulWidget> {
  late final AnimationController _controller;
  int mode = 0;

  @override
  void initState() {
    super.initState();
    if (mode == 1) {
      _controller = AnimationController();
    }
  }

  @override
  void dispose() {
    switch (mode) {
      case 1:
        _controller.dispose();
        break;
      default:
        break;
    }
    super.dispose();
  }
}
''');
      expect(codes, isNot(contains(_rule)));
    });

    // A ternary is a conditional too — same guard reasoning as switch.
    test('ternary-guarded dispose() call does not fire', () async {
      final codes = await _run('''
class _TernaryGuardedState extends State<StatefulWidget> {
  late final AnimationController _controller;
  bool autoPlay = false;

  @override
  void initState() {
    super.initState();
    if (autoPlay) {
      _controller = AnimationController();
    }
  }

  @override
  void dispose() {
    autoPlay ? _controller.dispose() : null;
    super.dispose();
  }
}
''');
      expect(codes, isNot(contains(_rule)));
    });

    // A `late final _x = ...;` inline initializer is lazy — it always runs
    // exactly once on first read and cannot throw at dispose().
    test('late field with an inline initializer does not fire', () async {
      final codes = await _run('''
class _LazyState extends State<StatefulWidget> {
  late final AnimationController _controller = AnimationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
''');
      expect(codes, isNot(contains(_rule)));
    });

    // Not a `late` field at all — a nullable field with a null-aware
    // teardown is a different, already-covered pattern.
    test('nullable (non-late) field does not fire', () async {
      final codes = await _run('''
class _NullableState extends State<StatefulWidget> {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
''');
      expect(codes, isNot(contains(_rule)));
    });
  });
}

/// The rule code every behavior assertion checks for.
const String _rule = 'avoid_disposing_late_fields';

/// Local stand-ins for the Flutter types this rule keys off.
///
/// The resolved-rule harness analyzes fixtures inside the `example` package,
/// which does NOT depend on Flutter — so `State`/`StatefulWidget` would
/// otherwise resolve to InvalidType. Declaring them locally keeps the
/// fixtures fully resolved (no unrelated analysis noise) while preserving
/// what the rule actually inspects: an `extends State<...>` clause matched
/// by name, plus a class body containing `late` fields and a `dispose()`
/// override. The word `late` and `dispose` in the preamble also satisfy the
/// rule's `requiredPatterns` pre-filter, and `extends State<` satisfies its
/// `applicableFileTypes: {FileType.widget}` gate.
const String _preamble = '''
class StatefulWidget {}

class State<T> {
  bool mounted = true;
  void initState() {}
  void dispose() {}
}

class AnimationController {
  void dispose() {}
  void cancel() {}
  void close() {}
}
''';

/// Runs the rule over [body] appended to [_preamble] and returns the codes
/// reported. Kept as a helper so each test reads as just the widget class
/// under scrutiny.
Future<Set<String>> _run(String body) {
  return reportedRuleCodes(AvoidDisposingLateFieldsRule(), '$_preamble\n$body');
}
