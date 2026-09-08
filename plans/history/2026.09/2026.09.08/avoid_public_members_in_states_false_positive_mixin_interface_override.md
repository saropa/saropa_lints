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

Scope of this fix is narrow by design: it recognizes named framework mixins
(`WidgetsBindingObserver`, `RouteAware`, `AutomaticKeepAliveClientMixin`), not
an arbitrary resolved-element "does this override a non-`State` supertype
member" check — the more general fix the bug report's Root Cause section
flagged as the more robust option. Any other Flutter framework mixin with
public-by-contract callback methods will reproduce this same false positive
until it is added to `_mixinRequiredMethodsByType`.

### Hardening pass (2026-09-08, same day)

The initial `WidgetsBindingObserver` list was written from memory and was
incomplete: cross-checked against
`api.flutter.dev/flutter/widgets/WidgetsBindingObserver-class.html`, it was
missing `didChangeViewFocus`, `didPopRoute`, `didPushRoute`,
`didPushRouteInformation`, and the four predictive-back-gesture handlers
(`handleCancelBackGesture`, `handleCommitBackGesture`,
`handleStartBackGesture`, `handleStatusBarTap`,
`handleUpdateBackGestureProgress`). All were added. `RouteAware`'s four
methods were confirmed correct against
`api.flutter.dev/flutter/widgets/RouteAware-class.html`.

A second common mixin with the same false-positive class was identified and
added: `AutomaticKeepAliveClientMixin.wantKeepAlive` is a getter (still a
`MethodDeclaration` in the AST, so `_checkMethod`'s existing string-name
check covers it with no code change beyond the table entry) whose public
spelling the framework reads directly.

### Resolved-element fallback (2026-09-08, same day)

The general fix flagged above as a follow-up was built in this same pass
instead of deferred: `_isFlutterSdkContractOverride` walks
`classElement.allSupertypes` (via `node.declaredFragment?.element`) and, for
an `@override` method or getter, checks whether the same name is declared
(not merely inherited) on a non-`State`, non-`Object` supertype whose owning
library is `package:flutter/...` or `dart:ui`. When it is, the override is
exempted the same way a `_mixinRequiredMethodsByType` hit is — the SDK, not
the class's author, mandates that public spelling.

This is deliberately narrower than "any `@override` resolving to a
non-`State` supertype member": restricting it to Flutter-SDK-owned
supertypes avoids exempting a same-named override of an app-authored mixin,
which is exactly the encapsulation leak this rule exists to catch (an author
could otherwise define `mixin PublicAccessor { void exposedMethod(); }`,
mix it into `State`, and dodge the lint). `_mixinRequiredMethodsByType`
remains the primary/fast path (works without a Flutter SDK in the analysis
context, matching this rule's existing non-type-resolved design); the
resolved check is an additional fallback for Flutter SDK mixins not yet
added to that table, so future SDK additions to `WidgetsBindingObserver` (or
an as-yet-unlisted mixin like `TickerProvider`) no longer require a code
change to stay correct — only mixins from packages other than
`package:flutter`/`dart:ui` still need a manual table entry.

Not covered by the fixture suite: `example/lib/flutter_mocks.dart` is a
local mock package, not `package:flutter` itself, so the fixture's
`WidgetsBindingObserver`/`RouteAware`/`AutomaticKeepAliveClientMixin` cases
are verified only via the syntactic table path, not this resolved fallback.
The resolved path was validated indirectly (compiles, `dart run
saropa_lints scan` runs clean on the fixture, `dart test` on the rule file's
76 cases passes) but has no fixture exercising an actual `package:flutter`
resolution context.

**Efficiency follow-up (same day):** a multi-agent review pass flagged that
the first version of this fallback re-walked `classElement.allSupertypes`
once per uncovered public `@override` member instead of once per class.
Restructured into `_flutterSdkContractMembers`, computed once per
`ClassDeclaration` into a `_FlutterSdkContractMembers` holder (separate
method-name and getter-name sets, so a getter can't be mistaken for a
method of the same name from an unrelated SDK interface); `_checkMethod`
now does an O(1) set-membership check per candidate member instead of
re-walking supertypes. Re-verified with the same scan/test commands above
after the refactor — identical results.

The same review pass also noted the hand-maintained
`_mixinRequiredMethodsByType` table now substantially overlaps what the
resolved fallback would already catch for its three current entries
(`WidgetsBindingObserver`, `RouteAware`, `AutomaticKeepAliveClientMixin` are
themselves declared in `package:flutter`). This overlap is intentional, not
dead weight: the table is the only path that works when the analysis
context has no Flutter SDK resolved (this rule file's existing
non-type-resolved design), so it stays as the fast/no-SDK-required primary
path, with the resolved check as an SDK-aware fallback for names not yet
added to the table.

**Reviewed and not changed — two correctness questions raised by the same
pass:**

1. *"The check exempts by name-anywhere-in-the-Flutter-supertype-chain, not
   by confirming this specific `@override` satisfies that specific
   supertype's contract."* True as described, but not a false negative in
   practice: Dart has one method table slot per name per class — a class
   cannot have two differently-typed members named `update`, so if
   `classElement.allSupertypes` genuinely contains a Flutter interface
   requiring public `update()` (which it only does if the class actually
   extends/implements/mixes that interface, per `allSupertypes`'
   definition), then *any* method literally named `update` on that class is,
   by construction, the same override satisfying that interface's contract
   — an app-authored contract requiring the same name would have to share
   the same public spelling regardless. No fixture demonstrates this
   corner case; flagged here for whoever revisits this code next rather
   than building a full override-resolution check for a scenario Dart's own
   type system already forecloses.
2. *"`getMethod`/`getGetter` might resolve inherited members, not just
   declared-on-this-type ones, defeating the `State`/`Object` exclusion."*
   Not applicable to the shipped code: `_flutterSdkContractMembers` uses
   `InterfaceType.methods` / `.getters`, both documented as "declared in
   this type" (not inherited) — confirmed by reading
   `analyzer-12.1.0/lib/dart/element/type.dart` directly. The earlier
   per-method draft did call `getMethod`/`getGetter` (also declared-only
   per the same source), but that draft was already replaced by the
   per-class cache before this review landed.

---

## Environment

- saropa_lints version: v15.3.0 (rule `Since`)
- Triggering project/file: `d:/src/contacts` —
  `lib/components/connection/user_account_auth_dot.dart:66,185` (two
  `State` classes, `_ConnectionDotStackState` and
  `_UserConnectionDotStreamState`, both `with WidgetsBindingObserver`
  overriding `didChangeAppLifecycleState`)
