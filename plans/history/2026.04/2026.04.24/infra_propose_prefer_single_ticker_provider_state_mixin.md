# BUG: `prefer_single_ticker_provider_state_mixin` — Propose New Rule — Flag `TickerProviderStateMixin` When Only One `AnimationController` Exists

**Status: Closed (implemented 2026-04-24)**

Created: 2026-04-24
Rule: `prefer_single_ticker_provider_state_mixin` (proposed — does not yet exist)
File: `lib/src/rules/ui/animation_rules.dart` (new rule class; add to `all_rules.dart` + `tiers.dart`)
Severity: False negative — idiomatic/efficiency gap, no existing rule
Rule version: proposed v1

---

## Summary

`TickerProviderStateMixin` supports multiple simultaneous tickers and carries per-mixin bookkeeping for a list of tickers. `SingleTickerProviderStateMixin` is the single-ticker variant — cheaper, intent-revealing, and the Flutter framework's documented default for states with exactly one `AnimationController`.

Propose flagging `State` subclasses that mix in `TickerProviderStateMixin` but declare only **one** `AnimationController` field, recommending the `SingleTickerProviderStateMixin` swap.

---

## Attribution Evidence

```bash
# Positive — confirms no existing rule covers this
grep -rn "'prefer_single_ticker_provider_state_mixin'" lib/src/rules/
grep -rn "'prefer_single_ticker'" lib/src/rules/
grep -rn "'SingleTickerProviderStateMixin'" lib/src/rules/
# Expected: 0 matches (verified 2026-04-24)
```

**Nearest existing rules (orthogonal):**
- `require_vsync_mixin` ([animation_rules.dart:49](lib/src/rules/ui/animation_rules.dart#L49)) — flags `AnimationController(...)` without `vsync:`. This proposal is downstream: given that you have vsync, pick the right mixin for the ticker count.
- `avoid_multiple_animation_controllers` ([animation_rules.dart:2053](lib/src/rules/ui/animation_rules.dart#L2053)) — flags **≥ 3** controllers on one State. Lower-bound partner to this proposal's upper-bound (1 vs ≥2).

Together the three form a staircase:
- 0 controllers + `TickerProviderStateMixin` → unused mixin (separate issue, not proposed here)
- **1 controller + `TickerProviderStateMixin` → THIS rule (prefer Single variant)**
- 2 controllers + `TickerProviderStateMixin` → correct, no lint
- ≥3 controllers → `avoid_multiple_animation_controllers`

**Emitter registration (when implemented):** `lib/src/rules/ui/animation_rules.dart:NN`
**Rule class:** `PreferSingleTickerProviderStateMixinRule` — to be registered in `lib/src/rules/all_rules.dart`

---

## Reproducer

Real-world trigger from `saropa-contacts` — [lib/components/primitive/animation/common_inkwell.dart](lib/components/primitive/animation/common_inkwell.dart) (pre-fix state):

```dart
class _CommonInkWellState extends State<CommonInkWell>
    with TickerProviderStateMixin {  // LINT — only one controller; use Single variant
  late final AnimationController _animationController;   // ← the only controller
  late final Animation<double> _scaleAnimation;          // derived Animation, not a controller
  late final Animation<double> _opacityAnimation;        // derived Animation, not a controller

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation   = Tween<double>(begin: 1, end: 0.9).animate(_animationController);
    _opacityAnimation = Tween<double>(begin: 1, end: 0.7).animate(_animationController);
  }
  // ...
}
```

### Correct patterns (must NOT lint)

```dart
// OK — two controllers, plural mixin is correct
class _MultiState extends State<MultiWidget>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;
}

// OK — already using the Single variant
class _FineState extends State<FineWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
}

// OK — controller inside a List / Map requires dynamic ticker management
class _DynamicState extends State<DynamicWidget>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
}
```

**Frequency:** Always, for the exact shape `State + TickerProviderStateMixin + exactly one AnimationController field`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | Diagnostic `[prefer_single_ticker_provider_state_mixin] State declares only one AnimationController but uses TickerProviderStateMixin. Switch to SingleTickerProviderStateMixin — cheaper, intent-revealing, and the framework's documented default for single-controller state.` |
| **Actual** | No diagnostic — pattern ships as-is. |

---

## AST Context

```
ClassDeclaration (_CommonInkWellState)
  ├─ ExtendsClause
  │   └─ NamedType (State<CommonInkWell>)
  ├─ WithClause
  │   └─ NamedType (TickerProviderStateMixin)   ← node reported here
  └─ ClassBody
      ├─ FieldDeclaration (_animationController, AnimationController)     ← count == 1
      ├─ FieldDeclaration (_scaleAnimation, Animation<double>)            ← not counted (Animation, not Controller)
      ├─ FieldDeclaration (_opacityAnimation, Animation<double>)          ← not counted
      └─ MethodDeclaration (initState, build, dispose, etc.)
```

Detection report site: the `TickerProviderStateMixin` NamedType token inside the `WithClause`. The correction rewrites just that token.

---

## Detection Plan

### Registry

`context.addClassDeclaration` — same shape `avoid_multiple_animation_controllers` already uses at [animation_rules.dart:2094](lib/src/rules/ui/animation_rules.dart#L2094).

### Trigger conditions (all must hold)

1. **Is a `State<T>` subclass** — `extendsClause.superclass.name.lexeme == 'State'` AND `typeArguments != null`. (Reuses the check at [animation_rules.dart:2099](lib/src/rules/ui/animation_rules.dart#L2099).)
2. **Mixes in `TickerProviderStateMixin`** — iterate `withClause?.mixinTypes`; match `NamedType.name.lexeme == 'TickerProviderStateMixin'`. Capture the matching `NamedType` for the report site.
3. **Has exactly one `AnimationController` field** — scan class members:
   - Explicit type `AnimationController` / `AnimationController?` → count each variable in the declarator.
   - Inferred type (initializer is `InstanceCreationExpression` of `AnimationController`) → count one.
   - **Exclude** collections — `List<AnimationController>`, `Set<AnimationController>`, `Map<..., AnimationController>`, `Iterable<AnimationController>` — same exclusion pattern already documented for `require_animation_controller_dispose` at [animation_rules.dart:208](lib/src/rules/ui/animation_rules.dart#L208).
4. **Report site** — `reporter.atNode(mixinNamedType)` on the `TickerProviderStateMixin` token, so the squiggle lands exactly on what the user needs to change.

### Early-exit gate

```dart
@override
Set<String>? get requiredPatterns => {'TickerProviderStateMixin'};
```

Files without that token cannot match — most project files in a large codebase skip AST registration entirely.

### Why not handle the "zero controllers" case

`TickerProviderStateMixin` with zero controllers is dead-mixin territory — different class of issue, more likely to be a partial refactor or a generic utility that accepts vsync. Out of scope for this rule; worth a separate `avoid_unused_ticker_provider_mixin` proposal later.

---

## Known False-Positive Avoidance

| Pattern | Behavior | Rationale |
|---|---|---|
| One controller + `TickerProviderStateMixin` | LINT | Rule target. |
| One controller + `SingleTickerProviderStateMixin` | NO lint | Already correct. |
| Two+ controllers + `TickerProviderStateMixin` | NO lint | Plural mixin is correct. |
| One `List<AnimationController>` + `TickerProviderStateMixin` | NO lint | Collections imply dynamic ticker count. |
| One `AnimationController?` field | LINT | Still one controller; nullability doesn't change ticker count. |
| Mixin composed via a parent state class (e.g. `extends _MyBaseState`) | NO lint for derived class | Don't try to resolve mixins up the class chain — rule scope is the declaring class only. Avoids false reports on subclasses that inherit the mixin. |
| `State<T>` where `T` isn't provided or is unresolved | NO lint | Existing pattern in `avoid_multiple_animation_controllers` requires `typeArguments != null`. |
| Non-`State` class that happens to mix in `TickerProviderStateMixin` | NO lint | Extends-`State` gate filters these out. |

---

## Suggested Fix Generator

High-confidence quick fix — swap the mixin name token:

```
- with TickerProviderStateMixin {
+ with SingleTickerProviderStateMixin {
```

Implementation: `SaropaFixGenerator` that replaces the `NamedType` source range with `SingleTickerProviderStateMixin`. No import change needed — both mixins live in `package:flutter/widgets.dart`. No argument changes needed — both mixins expose the same `vsync: this` protocol.

Edge case: if the user ever adds a second controller later, the fix becomes wrong — they would need to swap back. Not the rule's problem; the build would compile-fail on the second `Ticker createTicker(...)` call and the user would switch back. Acceptable round-trip.

---

## Fixture Gap

New fixture: `example*/lib/ui/prefer_single_ticker_provider_state_mixin_fixture.dart`

Must include:

1. **One controller + `TickerProviderStateMixin`** → expect LINT
2. **One controller + `SingleTickerProviderStateMixin`** → expect NO lint
3. **Two controllers + `TickerProviderStateMixin`** → expect NO lint
4. **Zero controllers + `TickerProviderStateMixin`** → expect NO lint (out of scope)
5. **`List<AnimationController>` + `TickerProviderStateMixin`** → expect NO lint (collection excluded)
6. **Nullable `AnimationController?` (one field) + `TickerProviderStateMixin`** → expect LINT
7. **Inferred-type field via `late final _c = AnimationController(...)`** → counted, expect LINT when it's the only one
8. **Subclass inheriting the mixin from a parent State class** → expect NO lint on the subclass
9. **Non-`State` class that mixes in `TickerProviderStateMixin`** → expect NO lint
10. **Quick fix application** — verify the replacement text is exactly `SingleTickerProviderStateMixin` and surrounding whitespace / `with`/`,` context is preserved

---

## Metadata

```dart
class PreferSingleTickerProviderStateMixinRule extends SaropaLintRule {
  PreferSingleTickerProviderStateMixinRule() : super(code: _code);

  /// Idiomatic improvement — no correctness bug. TickerProviderStateMixin
  /// allocates a list-of-tickers per instance; Single variant stores a
  /// single nullable ticker. Cheap perf win + intent-revealing.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui', 'animation'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  @override
  Set<String>? get requiredPatterns => {'TickerProviderStateMixin'};

  static const LintCode _code = LintCode(
    'prefer_single_ticker_provider_state_mixin',
    '[prefer_single_ticker_provider_state_mixin] This State class '
        'declares only one AnimationController but mixes in '
        'TickerProviderStateMixin, which exists for multi-ticker '
        'states and allocates a list for the additional tickers it '
        'will never receive here. SingleTickerProviderStateMixin is '
        'the framework default for single-controller state — cheaper '
        'and intent-revealing to a reader. {v1}',
    correctionMessage:
        'Replace TickerProviderStateMixin with '
        'SingleTickerProviderStateMixin. Both live in '
        'package:flutter/widgets.dart and expose the same "vsync: this" '
        'protocol, so no other changes are needed.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        PreferSingleTickerProviderStateMixinFix(context: context),
  ];
}
```

### Severity Guide mapping

Low — cosmetic/idiomatic. `DiagnosticSeverity.INFO` in `LintCode` is correct; this is a style nudge, not a bug.

---

## Priority

**Low but broadly applicable.** The pattern is extremely common in Flutter codebases — any `StatefulWidget` with a single press/hover/ripple animation tends to ship with the plural mixin by copy-paste. Easy win with a one-token auto-fix. Real-world hit in `saropa-contacts/lib/components/primitive/animation/common_inkwell.dart:204` (pre-fix).

---

## Open Design Questions

1. **Flag via Material default imports?** Both mixins live in `flutter/widgets.dart` — no import resolution needed; rule can match purely by lexeme.
2. **Across-file inheritance** — if a project base class (e.g. `CommonAnimatedState`) declares the mixin and subclasses only add the controller, should the subclass get flagged? v1: no — report only the class that declares the mixin. v2 (future): resolve mixin supertypes. Keep scope tight for initial release.

---

## Environment

- saropa_lints version: target for next release
- Dart SDK version: any
- custom_lint version: n/a — native analyzer plugin
- Triggering project/file: `d:\src\contacts\lib\components\primitive\animation\common_inkwell.dart` (one controller + `TickerProviderStateMixin`, fixed 2026-04-24 — this rule would have caught it pre-review).
