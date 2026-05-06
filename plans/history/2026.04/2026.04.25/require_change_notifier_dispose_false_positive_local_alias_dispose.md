# BUG: `require_change_notifier_dispose` — Fires when ChangeNotifier-derived field is disposed via a local-variable alias

**Status: Fixed**

Created: 2026-04-25
Rule: `require_change_notifier_dispose`
File: `lib/src/rules/architecture/disposal_rules.dart` (line ~1280; helper `_isFieldDisposed` at line 446)
Severity: False positive
Rule version: v5

---

## Summary

The rule reports a `ScrollController` field (one of the types in `_changeNotifierTypes`) as undisposed even when `dispose()` clearly disposes it through a local-variable alias (`final ScrollController? c = field; if (c != null) { c.dispose(); }`). The detection regex `_isFieldDisposed` requires the literal field name to appear immediately before `.dispose(`, so any disposal routed through an aliasing local is invisible.

Same shape as the parallel bug in `require_scroll_controller_dispose`, but in a different file with a different (parallel) helper, so the fix is local to this rule. Both rules currently fire on the same field declaration in consumer code, doubling the noise.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
$ grep -rn "'require_change_notifier_dispose'" D:/src/saropa_lints/lib/src/rules/
D:/src/saropa_lints/lib/src/rules/architecture/disposal_rules.dart:1299:    'require_change_notifier_dispose',

# Negative — rule is NOT in sibling repo source (only in compiled snapshots)
$ grep -rn "'require_change_notifier_dispose'" D:/src/saropa_drift_advisor/
Binary file D:/src/saropa_drift_advisor/.dart_tool/pub/bin/saropa_lints/saropa_lints.dart-3.11.1.snapshot matches
Binary file D:/src/saropa_drift_advisor/.dart_tool/pub/bin/saropa_lints/saropa_lints.dart-3.11.4.snapshot matches
# (Both matches are the published saropa_lints package cached in pub.)
```

**Emitter registration:** `lib/src/rules/architecture/disposal_rules.dart:1299`
**Rule class:** `RequireChangeNotifierDisposeRule`
**Helpers:**
- `_isFieldDisposed` at `lib/src/rules/architecture/disposal_rules.dart:446`
- `_findOwnedFieldsOfType` at `lib/src/rules/architecture/disposal_rules.dart:313`
- `_reportUndisposedFields` at `lib/src/rules/architecture/disposal_rules.dart:459`

**Type set that includes the affected type:** `_changeNotifierTypes` at line 1309 includes `ScrollController`.

**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#1`

---

## Reproducer

Triggered in `d:/src/contacts/lib/components/device_home_screen_widget/quick_launch_bar.dart` at line 332. Minimal form (identical to the `require_scroll_controller_dispose` reproducer because both rules fire on the same field):

```dart
import 'package:flutter/widgets.dart';

class MyWidget extends StatefulWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  // LINT — but should NOT lint. Field IS disposed below via local alias `c`.
  ScrollController? _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    // Capture nullable field once, then operate on non-nullable local.
    final ScrollController? c = _scrollController;
    if (c != null) {
      c.removeListener(_onScroll);
      c.dispose();
    }
    super.dispose();
  }

  void _onScroll() {}
}
```

Expected: NO lint.
Actual: `[require_change_notifier_dispose] Failing to dispose a ChangeNotifier ...` reported on the field declaration.

The same field also triggers `require_scroll_controller_dispose` simultaneously (separate bug file). Two errors, one undisposed field that is in fact disposed.

**Frequency:** Always — any ChangeNotifier-derived field disposed via an aliasing local triggers it. Affects all five types in `_changeNotifierTypes`: `ChangeNotifier`, `ValueNotifier`, `ScrollController`, `AnimationController`, `FocusNode`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — controller is disposed via local alias `c`. |
| **Actual** | `[require_change_notifier_dispose] Failing to dispose a ChangeNotifier (or ValueNotifier, etc.) in the dispose() method ...` reported on the field declaration. |

---

## AST Context

```
ClassDeclaration (_MyWidgetState extends State<MyWidget>)
  ├─ FieldDeclaration
  │   └─ VariableDeclaration (_scrollController)   ← reported here
  └─ MethodDeclaration (dispose)
      └─ BlockFunctionBody
          └─ Block
              ├─ VariableDeclarationStatement
              │   └─ VariableDeclaration (c) = SimpleIdentifier(_scrollController)
              ├─ IfStatement (c != null)
              │   └─ Block
              │       ├─ ExpressionStatement
              │       │   └─ MethodInvocation (c.removeListener(_onScroll))
              │       └─ ExpressionStatement
              │           └─ MethodInvocation (c.dispose())   ← actual disposal
              └─ ExpressionStatement
                  └─ MethodInvocation (super.dispose())
```

`_findOwnedFieldsOfType` correctly classifies `_scrollController` as owned (declared `ScrollController?`, assigned in `initState` with `ScrollController(...)` constructor). `_getDisposeMethodBody` returns the dispose body source. `_isFieldDisposed` then runs a regex on that source that misses the alias.

---

## Root Cause

In `lib/src/rules/architecture/disposal_rules.dart` at line 446:

```dart
bool _isFieldDisposed(String fieldName, String? disposeBody) {
  if (disposeBody == null) return false;

  final RegExp disposePattern = RegExp(
    '${RegExp.escape(fieldName)}\\??\\.' // fieldName. or fieldName?.
    r'\w*[Dd]ispose\w*\(', // any method containing "dispose"
  );
  return disposePattern.hasMatch(disposeBody);
}
```

The regex requires the literal field name (`_scrollController`) to appear immediately before a method whose name contains `dispose`. Any indirection — assignment to a local, call through `this`, call from a private helper — is invisible to this string match.

The disposal in the consumer code looks like:

```
final ScrollController? c = _scrollController;
if (c != null) {
  c.removeListener(_onScroll);
  c.dispose();   // <-- receiver is local `c`, regex sees no "_scrollController.dispose("
}
```

The string `_scrollController.dispose(` never appears, so `disposePattern.hasMatch` returns `false`, and `_reportUndisposedFields` flags the field.

This is the same architectural issue as the parallel rule `require_scroll_controller_dispose` (separate bug file). Both rules use string matching over the dispose body source; both miss the same aliasing pattern. Sharing a fix would be ideal but the helpers live in separate files and have differently-shaped regexes, so the fixes can be coordinated but should be filed and tracked separately.

### Hypothesis A: regex is the only mechanism

Confirmed by reading the helper. No `AstVisitor`, no element resolution, no use-def chasing. Pure `RegExp.hasMatch` against `disposeBody`.

### Hypothesis B: only `dispose()` body is searched

`_getDisposeMethodBody` returns only the body of the method literally named `dispose`. `didUpdateWidget` disposal sites (legitimate when a config option flips and the controller is recreated) are not considered. Private helpers called from `dispose` are not transitively searched.

### Hypothesis C: ownership detection is correct

Verified by tracing `_findOwnedFieldsOfType` against the reproducer:
- Declared type `ScrollController?` matches `'$typeName?'` branch → field is recorded with `fieldOwnership[name] = false` (no inline initializer).
- `_initStateAssignsFieldOfType` walks the `initState` body and finds `_scrollController = ScrollController(` → `fieldOwnership[name] = true`.
- Field is returned as owned. This is the right answer; ownership is not the bug.

---

## Suggested Fix

Replace `_isFieldDisposed` with an AST-based check:

1. Walk the dispose method body with an `AstVisitor`.
2. For every `MethodInvocation` whose method name matches `\w*[Dd]ispose\w*`, resolve `MethodInvocation.target.staticElement` (when target is a `SimpleIdentifier`):
   - If the resolved element is the `FieldElement` for `fieldName` → disposed.
   - If the resolved element is a `LocalVariableElement` and its declared initializer (also resolved) refers to the field → disposed.
3. Apply the same walk to `didUpdateWidget` and to any private method invoked from `dispose` (transitively, with cycle protection).

If a full AST rewrite is too large for one PR, a narrower interim heuristic: extend `_isFieldDisposed` to scan for `final\s+\w+\??\s+(\w+)\s*=\s*fieldName\b` (or `final\s+\w+!\s*=\s*fieldName\b`), then re-run the existing `disposePattern` against the captured local name. This closes the common alias false positive without an AST visitor; it will not handle reassignments or field-to-field aliasing, and that limitation should be documented in the helper's doc comment.

Both layers should land together with the parallel fix in `require_scroll_controller_dispose` so the consumer file stops emitting two errors for one correctly-disposed field.

---

## Fixture Gap

The fixture for this rule should cover all five `_changeNotifierTypes` (`ChangeNotifier`, `ValueNotifier`, `ScrollController`, `AnimationController`, `FocusNode`) for each of these patterns:

1. **Direct disposal** — `_field.dispose()` — expect NO lint (regression guard).
2. **Null-aware direct disposal** — `_field?.dispose()` — expect NO lint.
3. **Local-alias disposal (this bug)** — `final x = _field; if (x != null) x.dispose();` — expect NO lint.
4. **Local-alias disposal with bang** — `final x = _field!; x.dispose();` — expect NO lint.
5. **Disposal in `didUpdateWidget` only** — field torn down across config-flag flips — expect NO lint.
6. **Disposal in private helper called from `dispose`** — `dispose()` calls `_tearDown()` which disposes — expect NO lint.
7. **Genuinely undisposed** — field initialized in `initState`, no disposal anywhere — expect LINT.
8. **Aliased but not disposed** — `final x = _field; x.removeListener(...);` only — expect LINT (alias presence alone is not disposal).
9. **Aliased through reassignment** — `var x = _other; x = _field; x.dispose();` — expect NO lint when fix can resolve, otherwise documented as a known limitation.

---

## Changes Made

- Extended `_isFieldDisposed` in `disposal_rules.dart` with `_disposeCallOnReceiver` and `_localVariableAliasesOfField` so disposal via `final c = _field; c.dispose()` is recognized (typed `final`, inferred `final`, and `var` rhs with optional `this.` on the field).
- Rule message version bumped to `{v5}`; fixture BAD/GOOD now use real `_changeNotifierTypes` (`ChangeNotifier`, `ScrollController`) plus alias/bang GOOD cases.

---

## Tests Added

- Fixture cases `_good329alias__MyWidgetState` and `_good329bang__MyWidgetState` in `example/lib/disposal/require_change_notifier_dispose_fixture.dart`.

---

## Commits

<!-- Fill in at merge time. -->

---

## Environment

- saropa_lints version: (check `d:/src/contacts/pubspec.lock` for `saropa_lints` resolved version)
- Dart SDK version: 3.x (project SDK)
- custom_lint version: N/A — saropa_lints runs as a native analyzer plugin (per `MEMORY.md`: "saropa_lints is native analyzer plugin, not custom_lint")
- Triggering project/file: `d:/src/contacts/lib/components/device_home_screen_widget/quick_launch_bar.dart:332`

---

## Related

- `bugs/require_scroll_controller_dispose_false_positive_local_alias_dispose.md` — same field, same root pattern, parallel rule in `widget/widget_lifecycle_rules.dart`. Coordinate fixes.
