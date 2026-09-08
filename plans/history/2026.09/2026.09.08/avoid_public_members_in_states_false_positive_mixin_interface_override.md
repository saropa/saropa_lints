# BUG: `avoid_public_members_in_states` — flags `WidgetsBindingObserver` interface overrides (e.g. `didChangeAppLifecycleState`)

**Status: Fixed**

Created: 2026-09-08
Rule: `avoid_public_members_in_states`
File: `lib/src/rules/widget/widget_lifecycle_rules.dart` (line ~5098-5114)
Severity: False positive
Rule version: v1 | Since: v15.3.0 | Updated: v15.3.0

---

## Summary

The rule exempts a hardcoded list of `State<T>`-mandated lifecycle methods
(`_frameworkRequiredMethods`: `build`, `initState`, `dispose`,
`didUpdateWidget`, `didChangeDependencies`, `deactivate`, `activate`,
`reassemble`, `debugFillProperties`, `setState`) from the "public member on
State" check. It does **not** exempt public methods required by a *mixin
interface* the State class implements — e.g. `WidgetsBindingObserver`'s
`didChangeAppLifecycleState`. Renaming such a method to a private name (the
rule's own suggested fix) silently breaks the override: the framework calls
the interface method by its exact public name, so the mixin stops receiving
lifecycle callbacks with no compile error.

---

## Attribution Evidence

```bash
grep -rn "'avoid_public_members_in_states'" lib/src/rules/
# lib/src/rules/widget/widget_lifecycle_rules.dart:5086:    'avoid_public_members_in_states',
```

**Emitter registration:** `lib/src/rules/widget/widget_lifecycle_rules.dart:5086`
**Rule class:** `AvoidPublicMembersInStatesRule` — defined at
`lib/src/rules/widget/widget_lifecycle_rules.dart:5064`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

```dart
import 'package:flutter/material.dart';

class _MyWidgetState extends State<MyWidget> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // LINT (false positive) — this is a WidgetsBindingObserver interface
  // override, not an author's design choice. The rule's own suggested fix
  // ("prefix with an underscore") would break the override: the framework
  // looks up this exact public name on the observer, so a private rename
  // silently stops the callback from firing — no compile error, no warning.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  @override
  Widget build(BuildContext context) => const SizedBox.shrink(); // OK — build is exempt
}

class MyWidget extends StatefulWidget {
  const MyWidget({super.key});
  @override
  State<MyWidget> createState() => _MyWidgetState();
}
```

**Frequency:** Always, for any `State` class mixing in `WidgetsBindingObserver`
(or any other framework mixin/interface with a public callback method not in
`_frameworkRequiredMethods`).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `didChangeAppLifecycleState` is a mandated override of the `WidgetsBindingObserver` interface, exactly like `build`/`initState`/etc. are mandated by `State` |
| **Actual** | `[avoid_public_members_in_states]` reported at the method name, suggesting a private rename that would break the mixin's dispatch |

---

## AST Context

```
ClassDeclaration (_MyWidgetState extends State<MyWidget> with WidgetsBindingObserver)
  └─ MethodDeclaration (didChangeAppLifecycleState)
      ├─ metadata: [@override]
      └─ name token  ← node reported here (_checkMethod, widget_lifecycle_rules.dart:5172)
```

---

## Root Cause

`_checkMethod` (`lib/src/rules/widget/widget_lifecycle_rules.dart:5154-5173`)
only exempts names present in the static `_frameworkRequiredMethods` set
(line 5103) or annotated `@visibleForTesting`/`@protected`. It has no general
notion of "this overrides a required method from an implemented
interface/mixin" — it is a closed name list, not an override-contract check.
Any `with`-mixed-in observer interface (`WidgetsBindingObserver`,
`RouteAware`, `TickerProviderStateMixin` callback methods if any are public
by contract, etc.) whose callback method isn't in that literal list gets
flagged identically to an author-chosen public API.

### Hypothesis A (confirmed): closed literal list doesn't cover mixin-mandated overrides

The list should either be extended with known Flutter framework-mixin
callback names (`didChangeAppLifecycleState`, `didChangePlatformBrightness`,
`didChangeMetrics`, `didChangeLocales`, `didChangeTextScaleFactor`,
`didHaveMemoryPressure`, `didRequestAppExit`, from `WidgetsBindingObserver`;
similarly for `RouteAware`'s `didPush`/`didPop`/`didPushNext`/`didPopNext`),
or — more robustly — the check should recognize `@override` methods whose
name matches a member of any mixin/interface the class implements, not just
a fixed `State` list. A name-list approach will always be incomplete as new
framework mixins get used; a resolved-element check (does this override
resolve to a member declared on a non-`State` supertype that isn't itself
private?) would generalize correctly.

---

## Suggested Fix

Minimal fix: extend `_frameworkRequiredMethods` (or add a second exemption
path) with the common `WidgetsBindingObserver` callback names. More general
fix: in `_checkMethod`, before flagging, check whether `node.declaredElement`
(or the resolved override) comes from an interface/mixin other than `State`
itself — if so, treat it the same as a `_frameworkRequiredMethods` hit,
since its public spelling is equally non-optional for the author.

---

## Fixture Gap

The fixture at
`example/lib/widget_lifecycle/avoid_public_members_in_states_fixture.dart`
should include:

1. **A `State` class `with WidgetsBindingObserver` overriding
   `didChangeAppLifecycleState`** — expect NO lint.
2. Keep existing cases where a genuinely author-chosen public method/field
   on `State` (not tied to any mixin contract) is flagged — must still LINT.

---

## Changes Made

Implemented the "minimal fix" path from the Suggested Fix section: added
`_mixinRequiredMethodsByType`, a map from a framework mixin's source name
(`WidgetsBindingObserver`, `RouteAware`) to its mandated callback method
names. `runWithReporter` now inspects the class's `with` clause
syntactically (consistent with this file's other non-type-resolved checks)
and passes the resulting exempt-method set into `_checkMethod`, which skips
reporting when a public method name is in it. The exemption is scoped to
classes that actually mix in the matching type, so an unrelated public
method on an observer-mixed-in class is still flagged.
(`lib/src/rules/widget/widget_lifecycle_rules.dart`)

---

## Tests Added

`example/lib/widget_lifecycle/avoid_public_members_in_states_fixture.dart`:

- `_GoodObserverState` — a `State` `with WidgetsBindingObserver` overriding
  `didChangeAppLifecycleState` and `didChangeLocales` — expects NO lint.
- `_BadObserverExtraMethodState` — a `State` `with WidgetsBindingObserver`
  that also declares an unrelated public method (`refreshFromObserver`) not
  part of the mixin's contract — expects the lint to still fire, proving the
  exemption is scoped to the mixin's actual callback names and not a
  blanket exemption for the whole class.

Verified with `dart run saropa_lints scan example/lib/widget_lifecycle
--files avoid_public_members_in_states_fixture.dart --format json`: exactly
the 3 expected violations fire (lines 113, 116, and the new negative
control), and the observer callbacks are silent.

---

## Commits

`e51044e2` — fix: avoid_public_members_in_states no longer flags WidgetsBindingObserver/RouteAware overrides

---

## Finish Report (2026-09-08)

`avoid_public_members_in_states` reported a false positive on public methods that
override a Flutter framework mixin's callback contract (e.g.
`WidgetsBindingObserver.didChangeAppLifecycleState`) on a `State` subclass. The
rule only recognized a closed list of `State`-mandated lifecycle method names,
so it treated a mixin-mandated public override the same as an author-chosen
public API and suggested a private rename that would have silently broken the
mixin's dispatch.

The fix added a second, narrower exemption path in
`lib/src/rules/widget/widget_lifecycle_rules.dart`:
`_mixinRequiredMethodsByType` maps a framework mixin's source name
(`WidgetsBindingObserver`, `RouteAware`) to its known callback method names.
`runWithReporter` inspects the class's `with` clause syntactically — consistent
with the file's other non-type-resolved checks — and only exempts a method
name when the class actually mixes in the matching interface, so an unrelated
public method on the same class is still flagged.

Verified two ways: `dart run saropa_lints scan example/lib/widget_lifecycle
--files avoid_public_members_in_states_fixture.dart --format json` reports
exactly the 3 expected violations (the two pre-existing BAD cases plus the new
negative-control case), with the observer-callback overrides silent; and `dart
test test/rules/widget/widget_lifecycle_rules_test.dart` passes all 76 cases
(instantiation-pin test only — no assertion needed updating). A `/code-review
low` pass against commit `e51044e2` found no correctness issues.

Scope of this fix is narrow by design: it recognizes two named framework
mixins (`WidgetsBindingObserver`, `RouteAware`), not an arbitrary
resolved-element "does this override a non-`State` supertype member" check —
the more general fix the bug report's Root Cause section flagged as the more
robust option. Any other Flutter framework mixin with public-by-contract
callback methods (e.g. a future SDK addition) will reproduce this same false
positive until it is added to `_mixinRequiredMethodsByType`.

---

## Environment

- saropa_lints version: v15.3.0 (rule `Since`)
- Triggering project/file: `d:/src/contacts` —
  `lib/components/connection/user_account_auth_dot.dart:66,185` (two
  `State` classes, `_ConnectionDotStackState` and
  `_UserConnectionDotStreamState`, both `with WidgetsBindingObserver`
  overriding `didChangeAppLifecycleState`)
