# BUG: `require_scroll_controller_dispose` — Fires when controller is disposed via a local-variable alias

**Status: Fixed (2026-04-25)** — archived from `bugs/`; implementation in `state_lifecycle_dispose_scan.dart`.

Created: 2026-04-25
Rule: `require_scroll_controller_dispose`
File: `lib/src/rules/widget/widget_lifecycle_rules.dart` (line ~3520; helper at line 22)
Severity: False positive
Rule version: v5

---

## Summary

The rule reports a `ScrollController` field as undisposed even when `dispose()` clearly disposes it through a local-variable alias (`final ScrollController? c = field; if (c != null) { c.dispose(); }`). The detection regex hard-matches the literal field name on the left of `.dispose(`, so any disposal that goes through an aliasing local is invisible to the rule.

This pattern is intentional in the consumer code: it captures the nullable field into a non-nullable local once, runs `removeListener` and `dispose` on the local, and avoids the dual nullable-field deref that the rule's correction message implies. The rule has no way to recognize it.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
$ grep -rn "'require_scroll_controller_dispose'" D:/src/saropa_lints/lib/src/rules/
D:/src/saropa_lints/lib/src/rules/widget/widget_lifecycle_rules.dart:3524:    'require_scroll_controller_dispose',

# Negative — rule is NOT in sibling repo source (only in compiled snapshots)
$ grep -rn "'require_scroll_controller_dispose'" D:/src/saropa_drift_advisor/
Binary file D:/src/saropa_drift_advisor/.dart_tool/pub/bin/saropa_lints/saropa_lints.dart-3.11.1.snapshot matches
Binary file D:/src/saropa_drift_advisor/.dart_tool/pub/bin/saropa_lints/saropa_lints.dart-3.11.4.snapshot matches
# (Both matches are the published saropa_lints package cached in pub.)
```

**Emitter registration:** `lib/src/rules/widget/widget_lifecycle_rules.dart:3524`
**Rule class:** `RequireScrollControllerDisposeRule`
**Helper:** `_isNameDisposedInBody` at `lib/src/rules/widget/widget_lifecycle_rules.dart:22`
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#1`

---

## Reproducer

Triggered in `d:/src/contacts/lib/components/device_home_screen_widget/quick_launch_bar.dart` at line 332. Minimal form:

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
    // Avoids `_scrollController?.removeListener(...); _scrollController?.dispose();`
    // which derefs the nullable field twice and races against any reassignment.
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

Expected: NO lint (field is disposed).
Actual: `[require_scroll_controller_dispose] ScrollController created but not disposed.` reported on the field declaration.

**Frequency:** Always — any aliased disposal pattern triggers it.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — controller is disposed via the local `c` that aliases `_scrollController`. |
| **Actual** | `[require_scroll_controller_dispose] ScrollController created but not disposed.` reported on the field declaration. |

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

The rule string-matches the dispose body. Because the `MethodInvocation` target is `c` (a `SimpleIdentifier` whose static element is the local variable), the literal text `_scrollController.dispose(` never appears, and the regex misses.

---

## Root Cause

In `lib/src/rules/widget/widget_lifecycle_rules.dart` at line 22:

```dart
bool _isNameDisposedInBody(String disposeBody, String name) {
  final directRe = RegExp(
    '${RegExp.escape(name)}\\s*[?.]+'
    '\\s*dispose(Safe)?\\s*\\(',
  );
  final iterationRe = RegExp('in\\s+${RegExp.escape(name)}(\\.values)?\\)');
  return directRe.hasMatch(disposeBody) ||
      (iterationRe.hasMatch(disposeBody) &&
          _disposeCallPattern.hasMatch(disposeBody));
}
```

`disposeBody` is the raw `member.body.toSource()` of the `dispose` method. The regex requires the literal field name (`_scrollController`) to appear immediately before `.dispose(` or `?.dispose(`. It only handles two shapes:

1. `name.dispose(` / `name?.dispose(`
2. `for (... in name) { ....dispose() }` / `for (... in name.values) { ... }`

Any disposal that flows through an aliasing local — `final c = name; c.dispose();` — is structurally invisible to a string regex over the dispose body. There is no AST-level visit, no use-def lookup, no resolution of `c.staticElement` to the field.

A second issue compounds the false positive: the rule does not look at `didUpdateWidget` for disposal sites. In the consumer file, `_scrollController` is also disposed in `didUpdateWidget` when parallax is toggled off. Even if the user rewrote `dispose()` to use the field directly, a controller created/destroyed across `didUpdateWidget` cycles would still appear "owned" but the disposal in that method would be ignored.

### Hypothesis A: regex is the only mechanism

The rule never resolves identifiers to elements. Confirmed by reading the helper: pure `String.indexOf` / `RegExp.hasMatch` over `member.body.toSource()`. There is no `AstVisitor` walking method invocations to ask whether the receiver's static element is the field.

### Hypothesis B: only `dispose()` body is searched

`_isNameDisposedInBody` is called once with the `dispose` method body. There is no fallback for `didUpdateWidget` (which legitimately disposes the controller when a config flag flips), nor for any private helper called from `dispose`.

---

## Suggested Fix

Two layers:

1. **Replace the regex with an AST visit.** Walk the dispose method body with an `AstVisitor`; for every `MethodInvocation` whose method name is `dispose` (or matches `[Dd]ispose`), resolve the receiver's `staticElement`:
   - If the receiver is a `SimpleIdentifier` whose static element is the field → mark disposed.
   - If the receiver is a `SimpleIdentifier` whose static element is a `LocalVariableElement` whose initializer (also resolved) is the field → mark disposed.

   This handles the alias case (`final c = field; c.dispose()`) without text matching, and continues to handle the direct case.

2. **Also walk `didUpdateWidget` and any private method called from `dispose`.** A controller may be disposed in `didUpdateWidget` when an option toggles, and any private helper invoked from `dispose` should be transitively searched.

If the AST rewrite is too large, a narrower interim fix: in `_isNameDisposedInBody`, additionally scan the body for `final\s+\w+\??\s+(\w+)\s*=\s*name\b` and, if matched, run the existing `directRe` against the captured local name. This handles the common alias pattern without a full visitor rewrite. Mark this clearly as a heuristic — it will miss reassignments and field-on-field aliases — but it closes the most common false positive.

---

## Fixture Gap

The fixture at `example*/lib/widget/require_scroll_controller_dispose_fixture.dart` (or equivalent) should include:

1. **Direct disposal** — `_controller.dispose()` in `dispose()` — expect NO lint (regression guard for current behavior).
2. **Null-aware direct disposal** — `_controller?.dispose()` in `dispose()` — expect NO lint.
3. **Local-alias disposal (this bug)** — `final c = _controller; if (c != null) c.dispose();` — expect NO lint.
4. **Local-alias disposal with bang** — `final c = _controller!; c.dispose();` — expect NO lint.
5. **Disposal in `didUpdateWidget` only** — ScrollController torn down when a config flag flips, but not in `dispose()` because the field is null at that point — expect NO lint.
6. **Disposal in private helper called from dispose** — `dispose()` calls `_tearDown();` which calls `_controller.dispose();` — expect NO lint.
7. **Genuinely undisposed** — field initialized in `initState`, no `.dispose()` anywhere — expect LINT (negative case).
8. **Aliased but not disposed** — `final c = _controller; c.removeListener(...);` (no `.dispose()` on `c`) — expect LINT (do not over-correct: alias presence alone is not disposal).

---

## Changes Made

- Added `lib/src/rules/widget/state_lifecycle_dispose_scan.dart`: regex disposal detection (moved from `widget_lifecycle_rules.dart`) plus AST scanning over `dispose`, `didUpdateWidget`, and transitively invoked private instance methods. Locals whose initializer is a tracked field (`final c = _field` / `this._field` / `!` unwrap) map `c.dispose()` to that field. Class members are read via `BlockClassBody` / `EmptyClassBody` for analyzer 11.
- `RequireScrollControllerDisposeRule` and `RequireFocusNodeDisposeRule` now use `isTrackedFieldDisposedInStateLifecycle` (combined `dispose` + `didUpdateWidget` source for regex; AST for aliases and helpers). Diagnostic tags bumped to `{v6}` / `{v7}`.

---

## Tests Added

- `test/state_lifecycle_dispose_scan_test.dart` — local alias + `if (c != null)`, bang alias, `didUpdateWidget`-only dispose, private helper from `dispose`, negative cases (alias without dispose, no dispose).

---

## Commits

- `fix: require_scroll/focus_node dispose via lifecycle AST scan` — adds `lib/src/rules/widget/state_lifecycle_dispose_scan.dart`, wires `RequireScrollControllerDisposeRule` / `RequireFocusNodeDisposeRule`, adds `test/state_lifecycle_dispose_scan_test.dart`.

---

## Environment

- saropa_lints version: (whichever is published in `d:/src/contacts/pubspec.yaml` lockfile — check `pubspec.lock` for `saropa_lints`)
- Dart SDK version: 3.x (project SDK)
- custom_lint version: N/A — saropa_lints runs as a native analyzer plugin (per `MEMORY.md`: "saropa_lints is native analyzer plugin, not custom_lint")
- Triggering project/file: `d:/src/contacts/lib/components/device_home_screen_widget/quick_launch_bar.dart:332`
