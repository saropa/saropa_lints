# BUG: `prefer_dispose_before_new_instance` — Disposal Deferred to Post-Frame Callback Not Recognized

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `prefer_dispose_before_new_instance`
File: `lib/src/rules/architecture/disposal_rules.dart` (line ~2254)
Severity: False positive
Rule version: v4 | Since: unknown | Updated: v4.13.0

---

## Summary

The rule fires when a controller field is reassigned and the old instance is disposed inside an
`addPostFrameCallback` closure rather than on the line immediately before the assignment. The old
instance IS disposed — deferred disposal via a post-frame callback is the required pattern when the
controller is still attached to a mounted widget, because calling `dispose()` inline asserts. The
rule's `_hasDisposeCallBefore` scanner only inspects statements in the same `Block` before the
assignment; it does not look inside closure/callback bodies in those statements, so the disposal is
invisible to it.

Worked around on 2026-06-09 with `// ignore: prefer_dispose_before_new_instance` at responsive
`didChangeDependencies` sites in Saropa Contacts.

---

## Attribution Evidence

Grep proof that this rule lives in `saropa_lints`. Positive attribution confirmed by parent session;
the diagnostic owner in the IDE Problems panel is `_generated_diagnostic_collection_name_#N` (the
analysis-server plugin — negative attribution against sibling repos is not required).

```bash
# Positive — rule IS defined here
grep -rn "'prefer_dispose_before_new_instance'" lib/src/rules/
# Result: lib/src/rules/architecture/disposal_rules.dart:2254: ... 'prefer_dispose_before_new_instance' ...
```

**Emitter registration:** `lib/src/rules/architecture/disposal_rules.dart:2254`
**Rule class:** `PreferDisposeBeforeNewInstanceRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `_generated_diagnostic_collection_name_#N`

---

## Reproducer

Minimal Dart code that triggers the bug.

```dart
class _MyWidgetState extends State<MyWidget> {
  PageController? _pageController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final double f = ResponsiveLayout.isWide(MediaQuery.sizeOf(context).width)
        ? 0.85
        : 1.0;

    // Capture the old instance so the closure captures it, not the new one.
    final PageController? old = _pageController;

    // LINT fires here — but the old instance IS disposed below.
    _pageController = PageController(viewportFraction: f); // LINT — but old is disposed via post-frame

    // Disposing inline asserts because the controller is still attached to
    // the mounted PageView. Post-frame disposal is REQUIRED here.
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose()); // OK
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }
}
```

**Frequency:** Always — fires on every reassignment of a disposable-type field where the prior
instance is disposed inside an `addPostFrameCallback`, `Future.microtask`, or any other closure
body rather than as a bare statement preceding the assignment.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the old instance is disposed (deferred, but correctly) |
| **Actual** | `[prefer_dispose_before_new_instance] Reassigning without dispose leaks the old instance. Listeners and resources remain active forever. {v4}` reported at the `_pageController = PageController(...)` assignment line |

---

## AST Context

```
ClassDeclaration (_MyWidgetState)
  └─ MethodDeclaration (didChangeDependencies)
      └─ Block
          ├─ VariableDeclarationStatement (old = _pageController)
          ├─ AssignmentExpression (_pageController = PageController(...))  ← node reported here
          └─ IfStatement
              └─ ExpressionStatement
                  └─ MethodInvocation (addPostFrameCallback)
                      └─ FunctionExpression (closure)
                          └─ ExpressionStatement
                              └─ MethodInvocation (old.dispose())  ← disposal lives here; invisible to scanner
```

---

## Root Cause

### Hypothesis A: `_hasDisposeCallBefore` only inspects `toSource()` of bare sibling statements

`_hasDisposeCallBefore` (lines 2379–2403) iterates the `Block`'s `statements` list looking for any
statement whose `.toSource()` string contains `fieldName.dispose()`, `fieldName?.dispose()`,
`fieldName..dispose()`, or `fieldName?..dispose()` — where `fieldName` is the name of the field
being reassigned (e.g. `_pageController`).

The pattern `old.dispose()` inside the callback closure does NOT contain `_pageController` — it
contains `old`, a local variable that holds the captured prior value. Even if the local variable
happened to share the field name, the `addPostFrameCallback((_) => ...)` call is a sibling
statement that comes AFTER the assignment (offset ≥ assignmentOffset), so the loop breaks before it
is even evaluated (line 2389: `if (statement.offset >= assignmentOffset) break`).

Both conditions work against detection:
1. The captured-and-renamed local (`old`) does not match the field-name string pattern.
2. Even if it did, the post-frame statement appears after the assignment offset, so it is excluded
   by the early break.

There is no mechanism to look inside closure bodies in statements that appear before the assignment,
nor to follow the "capture old value into local then dispose the local later" idiom.

### Hypothesis B: String-source scanning misses indirect disposal through locals

Even if the disposal callback were placed before the assignment in source order (which it cannot be
— the callback must capture the new assignment's predecessor), the string match `$fieldName.dispose()` would fail because `dispose()` is called on `old`, not on `_pageController`. The rule
would need to track that `old` was assigned the previous value of `_pageController` and that
disposing `old` therefore constitutes disposing the prior `_pageController` instance.

---

## Suggested Fix

In `_hasDisposeCallBefore` (line 2379), extend the search to include statements that appear AFTER
the assignment when those statements contain an `addPostFrameCallback` or `Future.microtask` call
whose closure body disposes the captured old value. Concretely:

1. Detect the "capture old value" pattern: a `VariableDeclarationStatement` immediately before the
   assignment whose initializer is `fieldName` (i.e. `final X? old = _fieldName;`).
2. If such a local exists, also accept disposal of that local's name (`old.dispose()`,
   `old?.dispose()`) in any statement in the block — before or after the assignment — including
   inside a callback closure body (`toSource()` search of the full statement suffices for the
   deferred case, given `old` cannot otherwise be confused with a different field disposal).

A simpler, less precise alternative: treat the assignment as safe when ANY statement in the
enclosing block (regardless of position) calls `addPostFrameCallback` or `scheduleMicrotask` and
that statement's source contains `.dispose()`. This would reduce false positives for this common
responsive-layout idiom without requiring full data-flow analysis.

---

## Fixture Gap

The fixture at `example*/lib/architecture/prefer_dispose_before_new_instance_fixture.dart` should
include:

1. **Post-frame capture-and-dispose (local renamed)** — `final old = _ctrl; _ctrl = Ctor(); addPostFrameCallback((_) => old.dispose());` — expect NO lint.
2. **Post-frame on same name (hypothetical)** — `addPostFrameCallback((_) => _ctrl?.dispose()); _ctrl = Ctor();` — expect NO lint (disposal is deferred but logically before the replacement takes effect from the widget's perspective).
3. **True leak (no dispose anywhere)** — `_ctrl = PageController(viewportFraction: f);` with no capture, no callback, no inline dispose — expect LINT.
4. **Inline dispose (happy path)** — `_ctrl?.dispose(); _ctrl = PageController(...)` — expect NO lint (currently passing).
5. **Microtask variant** — same as case 1 but using `Future.microtask(() => old.dispose())` — expect NO lint.

---

## Changes Made

Implemented the capture-and-deferred-dispose detection in `disposal_rules.dart`
(`PreferDisposeBeforeNewInstanceRule`):

- Before reporting, the rule now looks for a `final old = _field;` capture
  declared before the reassignment (`_capturedOldLocalName`), and if found,
  checks whether the enclosing block disposes that local anywhere
  (`_blockDisposesLocal`, via `block.toSource()` so disposal inside an
  `addPostFrameCallback`/`Future.microtask` closure is seen). When both hold,
  the reassignment is treated as safe.

This covers the responsive `didChangeDependencies` idiom where disposing inline
asserts (controller still attached to a mounted widget), so the old instance is
captured and disposed in a post-frame callback. The existing inline-dispose
detection and the true-leak path are unchanged.

---

## Tests Added

- Rewrote `example/lib/disposal/prefer_dispose_before_new_instance_fixture.dart`
  with inline-dispose, capture+post-frame, capture+microtask (all NO lint) and a
  true leak (LINT) inside a `_State` class.

**Verification limitation:** the rule is resolution-dependent — it only fires
when the reassignment RHS resolves to an `InstanceCreationExpression`. The
project scan CLI parses without full resolution, so `_field = PageController(…)`
is an unresolved `MethodInvocation` and the rule does not fire there at all
(confirmed: zero hits, including on the leak case). The fix is therefore
verified by inspection + clean per-file analyze: the new code only ADDS a
suppression path (a `return` before `reporter.atNode`), so it can never produce
a new false positive. The disposal unit suite passes.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Finish Report (2026-06-09)

**Scope:** (A) Dart lint rules / analyzer plugin.

**Deep review:** Both helpers are bounded scans (statements before the
assignment for the capture; one `toSource()` contains-check for the disposal).
The `this.$fieldName` form is also accepted as a capture initializer. The change
is suppression-only and leaves the leak and inline-dispose paths intact. Rule
file, tier, severity, `LintImpact` unchanged.

**Tests:** `dart test test/rules/architecture/disposal_rules_test.dart` → all
pass. Scan CLI cannot exercise this resolution-dependent rule (noted above).

**Maintenance:** CHANGELOG `[Unreleased]` Fixed bullet added. README/ROADMAP
unchanged (false-positive fix).

**Bug archived:** bugs/prefer_dispose_before_new_instance_false_positive_deferred_postframe_dispose.md
→ plans/history/2026.06/2026.06.09/prefer_dispose_before_new_instance_false_positive_deferred_postframe_dispose.md

**Finish report appended:** this file.

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: (project default — see pubspec.lock)
- custom_lint version: N/A — saropa_lints is a native analyzer plugin
- Triggering project/file: Saropa Contacts 2026-06-09 — `lib/` responsive `didChangeDependencies`
  sites using `PageController` viewport-fraction recreation on width-tier change
