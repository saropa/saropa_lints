# BUG: `prefer_single_ticker_provider_state_mixin` — false positive when State serves as TickerProvider for externally-constructed AnimationControllers

**Status: Fixed (workspace head)**

Created: 2026-04-28
Rule: `prefer_single_ticker_provider_state_mixin`
File: `lib/src/rules/ui/animation_rules.dart` (line 2266; AST counter at lines 2326–2351)
Severity: False positive
Rule version: v1 | Since: v12.5.0 (introduced) | Updated: —

---

## Summary

The rule counts only `AnimationController` fields declared **directly** on the State class. It misses the common pattern where the State holds *helper objects* (e.g. `IconAnimationController`, custom controller wrappers, particle/sprite controllers) that take `vsync: this` in their constructor and create their **own** internal `AnimationController` keyed off this State's ticker.

The State is therefore a `TickerProvider` for **N** controllers (1 directly-declared + N held inside helper objects), but the rule sees only the 1 direct field, fires "single controller — switch to `SingleTickerProviderStateMixin`", and silently recommends a change that would **crash at runtime** when the second helper controller calls `createTicker(...)` against `SingleTickerProviderStateMixin`.

Quoting Flutter's own doc on `SingleTickerProviderStateMixin`:

> If a [TickerProvider] is used by exactly one [Ticker], the [SingleTickerProviderStateMixin] may be more efficient. […] Calling `createTicker` more than once will throw an exception.

---

## Attribution Evidence

```bash
$ grep -rn "'prefer_single_ticker_provider_state_mixin'" lib/src/rules/
lib/src/rules/ui/animation_rules.dart:2266:    'prefer_single_ticker_provider_state_mixin',
```

**Emitter registration:** `lib/src/rules/ui/animation_rules.dart:2266`
**Rule class:** `PreferSingleTickerProviderStateMixinRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` (saropa_lints native plugin)

---

## Reproducer

Real downstream codebase: `D:\src\contacts`. Five files share the exact same shape — five FP hits, one per file:

- `lib/views/static_data/curious_fact_view_screen.dart:72`
- `lib/views/static_data/horoscope_view_screen.dart:156`
- `lib/views/static_data/inspirational_quote_view_screen.dart:78`
- `lib/views/static_data/interesting_vocabulary_view_screen.dart:72`
- `lib/views/static_data/mental_model_view_screen.dart:92`

Minimal reproducer (compiled-down version of the contacts pattern):

```dart
import 'package:flutter/widgets.dart';

/// External controller that owns its own AnimationController.
/// The State below is its TickerProvider, NOT the State's only ticker.
class IconAnimationController {
  IconAnimationController({required this.vsync});
  final TickerProvider vsync;
  late final AnimationController _ctrl;
  void start() {
    // Internal AnimationController — vsync arrives from the State above.
    _ctrl = AnimationController(vsync: vsync, duration: Duration.zero)..forward();
  }
  void dispose() => _ctrl.dispose();
}

class MyScreen extends StatefulWidget {
  const MyScreen({super.key});
  @override
  State<MyScreen> createState() => _MyScreenState();
}

// LINT — but should NOT lint. There are 4 tickers attached to this State:
// 1× _mainController (declared) + 3× IconAnimationController (held in list,
// each with its own internal AnimationController(vsync: this)).
class _MyScreenState extends State<MyScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  final List<IconAnimationController> _iconControllers = <IconAnimationController>[];

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(vsync: this, duration: Duration.zero);
    for (int i = 0; i < 3; i++) {
      _iconControllers.add(IconAnimationController(vsync: this)..start());
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    for (final c in _iconControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

**If the rule's quick fix is applied** (`TickerProviderStateMixin` → `SingleTickerProviderStateMixin`), the second `IconAnimationController(vsync: this)` will throw at runtime — `SingleTickerProviderStateMixin` permits exactly one `createTicker` call and the second call raises `FlutterError`.

**Frequency:** Always. Any State that hands `vsync: this` to a helper class is a candidate.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when the State passes `this` (or a field that resolves to `this`) as a `TickerProvider` to an external object stored on the State (field, list, map, set, late init). The rule should treat each such handoff as ≥1 additional ticker consumer. |
| **Actual** | Diagnostic fires because the rule only counts directly-declared `AnimationController` fields. Quick fix would convert the mixin and silently ship runtime-broken code. |

---

## AST Context

```
ClassDeclaration (_MyScreenState)
  ├─ ExtendsClause (State<MyScreen>)
  ├─ WithClause
  │   └─ NamedType (TickerProviderStateMixin)              ← reported here
  └─ ClassBody
      ├─ FieldDeclaration  AnimationController _mainController     ← counted (1)
      ├─ FieldDeclaration  List<IconAnimationController> _iconControllers
      │                    └─ NamedType lexeme = "List"            ← NOT counted
      └─ ConstructorBody / initState
          └─ InstanceCreationExpression  IconAnimationController(vsync: this)
              └─ NamedExpression  vsync: ThisExpression            ← MISSED ticker handoff
```

The rule's loop in `runWithReporter` (lines 2326–2351) walks `node.body.members`, filters to `FieldDeclaration`, and bumps `controllerCount` when:

- `type is NamedType && type.name.lexeme == 'AnimationController'`, OR
- `type == null` and the initializer is a direct `AnimationController(...)` `InstanceCreationExpression`.

**Both conditions miss every external-ticker pattern.** The class-comment on Gate 3 (lines 2320–2325) even acknowledges that `List<AnimationController>` won't match because the `NamedType` lexeme is `"List"`, not `"AnimationController"` — but it stops short of recognizing that *external classes that consume `vsync: this`* also represent additional tickers.

---

## Root Cause

### Flaw A: counter measures the wrong thing

The rule's stated goal (file header at lines 2242–2244) is "single-ticker states use the lighter mixin." The correct **input** to that decision is "how many tickers does this State produce via `createTicker` calls" — not "how many `AnimationController` fields are declared."

`AnimationController` is the *most common* but not the *only* ticker consumer. Any class that takes a `TickerProvider` parameter and calls `vsync.createTicker(...)` (directly, or transitively via `AnimationController(vsync: …)`) is a ticker consumer. The rule cannot see those handoffs because it only inspects field declarations.

### Flaw B: false positive is silent and the quick fix is destructive

Severity is INFO and the rule ships a quick fix (`PreferSingleTickerProviderStateMixinFix`, line 2283–2286). A user who applies the fix in good faith ships code that throws on the second `createTicker` call — a runtime regression introduced by an INFO-level lint with a green "Apply Fix" button.

INFO + auto-fix + runtime crash is the worst combination. INFO suggests "low risk, safe to take." The quick fix lowers friction further. The actual outcome is a crash that only manifests when the State is exercised at runtime (not at analysis time).

### Flaw C: no handshake check that downgrade is safe

The rule never tries to verify that downgrading the mixin preserves correctness. The minimum bar should be: **"do not flag if there is any expression in this State whose target is `this` or a `this`-derived value that is passed as a `TickerProvider`-typed argument."** Even a coarse syntactic heuristic ("any `vsync: this` argument anywhere in this class body") would prevent the destructive case.

---

## Suggested Fix

Three layers of defense, in priority order. Flaw B (destructive quick fix on FP) is the urgent one.

### Fix 1 — Skip when any `vsync: this` argument exists in the class body

Walk `node.body.members` and look for any `NamedExpression` with `name.label.name == 'vsync'` whose `expression` is `ThisExpression`. If found, return without reporting. This is the smallest correct change: every external ticker handoff in idiomatic Flutter is `vsync: this`.

```dart
// Inside runWithReporter, after Gate 3 counts to 1:
bool hasExternalVsyncHandoff = false;
node.body.visitChildren(_VsyncThisDetector(
  onMatch: () => hasExternalVsyncHandoff = true,
));
if (hasExternalVsyncHandoff) return;
```

This catches:
- `IconAnimationController(vsync: this)` — the contacts case
- `MyParticleSystem(vsync: this)` — generic helper class
- `Ticker.create(vsync: this)` — direct ticker construction
- `someBuilder(vsync: this)` — factory pattern

### Fix 2 — Also skip when the State is **passed** as `TickerProvider` to a helper

Some codebases pass `TickerProvider` positionally or through a `vsync` field rather than the canonical `vsync:` named argument. A second pass: walk `Argument` lists for any expression whose `staticType` resolves to `TickerProvider` (or `TickerProviderStateMixin`/`State<…> with TickerProviderStateMixin`) and is `ThisExpression`. This covers the long tail.

### Fix 3 — Counter should count vsync handoffs, not field declarations

Reframe the counter so it counts "ticker consumers," not "AnimationController fields." Concretely: count direct `AnimationController` fields **plus** every distinct `vsync: this` argument site in the class body. If the total is > 1, return.

This is more invasive but semantically correct, and it would future-proof the rule against patterns that don't yet exist (composite controllers, gesture choreographers, custom Ticker subclasses).

---

## Fixture Gap

The fixture at `example/lib/animation/prefer_single_ticker_provider_state_mixin_fixture.dart` should include:

1. **State with 1 direct `AnimationController` and no `vsync: this` handoff** — expect LINT (true positive baseline)
2. **State with 1 direct `AnimationController` + `IconAnimationController(vsync: this)` field** — expect NO lint *(currently false positive)*
3. **State with 1 direct `AnimationController` + `List<IconAnimationController>` populated in `initState` with `vsync: this`** — expect NO lint *(currently false positive — exact contacts pattern)*
4. **State with 1 direct `AnimationController` + `Ticker` created via `createTicker(...)` directly** — expect NO lint
5. **State with 0 direct `AnimationController` + 1 `OtherController(vsync: this)` field** — expect NO lint (rule already gates on `controllerCount == 1`, but worth a pin)
6. **State with 2 direct `AnimationController` fields** — expect NO lint (true negative baseline)

---

## Downstream

Tracked in `D:\src\contacts`. Five FP hits across:

- `lib/views/static_data/curious_fact_view_screen.dart:72`
- `lib/views/static_data/horoscope_view_screen.dart:156`
- `lib/views/static_data/inspirational_quote_view_screen.dart:78`
- `lib/views/static_data/interesting_vocabulary_view_screen.dart:72`
- `lib/views/static_data/mental_model_view_screen.dart:92`

Once this report exists, each State class gets an `// ignore: prefer_single_ticker_provider_state_mixin` line on the `with TickerProviderStateMixin` token with a comment pointing at this filename. The ignore stays until the rule ships a fix, at which point contacts can bump `saropa_lints` and remove the ignores.

---

## Environment

- saropa_lints version (consumer): `^12.5.3`
- saropa_lints version (workspace head): 12.6.2
- Dart SDK: 3.9.x
- Triggering project: `d:/src/contacts`
- Platform: Windows 11
