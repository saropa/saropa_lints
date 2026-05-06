# `use_setstate_synchronously` — false positive: rule flags `setState` that occurs BEFORE the async gap when the call sits inside a try-block whose body contains a later `await`

**Status:** Fixed (rule version v10)

Filed: 2026-04-26
Fixed: 2026-04-26
Rule: `use_setstate_synchronously`
File: `lib/src/rules/widget/widget_lifecycle_rules.dart` (line 2086, code at 2105–2167)
Severity: False positive (statement-traversal granularity)
Rule version: v9 → v10 | Severity in code: WARNING | Impact: medium

**Resolution:** Replaced top-level statement iteration with `_OrderedSetStateScanner`, a `RecursiveAstVisitor` that tracks `seenAwait` and per-Block `if (!mounted) return;` guard state in source order. A `setState` is now reported only when it is lexically AFTER the first `await`, has no active early-exit guard in any enclosing Block (a new await resets all of them), and has no inline `if (mounted)` ancestor. Nested function expressions are skipped — they have their own async scope. Fixture cases for the four false-positive shapes (try/if/post-await-guard-in-catch, plus a mixed positive/negative) added in `example/lib/async/use_setstate_synchronously_fixture.dart`.

---

## Summary

The rule's contract is in its own message: *"setState called **after** async gap without mounted check."* The detection logic, however, walks `body.block.statements` at the top level only — it never recurses into compound statements (`try`, `if`, `for`, `while`, `switch`) to discover the *order* of `setState` and `await` within them.

When a method body is a single top-level `try { ... } on X catch { ... }` (the common shape in this codebase: every method wrapped in error handling per the project's mandatory error-handling rule), the rule sees one statement. As soon as `containsAwait(stmt)` returns true for that one statement, the rule sets `seenAwait = true` and walks **every** `setState` invocation inside the try block via `_reportUnprotectedSetState` — including `setState` calls that appear **lexically before** any `await` and therefore could not be after an async gap.

The user-facing effect: a method that opens with `if (!mounted) return; setState(() => _isLoading = true);` and only later awaits, gets the warning anyway. Adding the `if (!mounted) return;` guard does nothing because the rule never checked for mounted at that position — it only checks at top-level statement granularity.

---

## Attribution Evidence

```bash
$ grep -rn "'use_setstate_synchronously'" lib/src/rules/
lib/src/rules/widget/widget_lifecycle_rules.dart:2106:    'use_setstate_synchronously',
```

Rule lives here. Confirmed.

**Emitter registration:** `lib/src/rules/widget/widget_lifecycle_rules.dart:2086` (`UseSetStateSynchronouslyRule`)
**Rule class:** `UseSetStateSynchronouslyRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner`:** `dart` (saropa_lints native plugin)

---

## Reproducer

Consumer project: `D:\src\contacts`. Site: `lib/components/contact/avatar/native_photo_write_back_dialog.dart:282`.

```dart
/// Pushes the photo to the native contact and closes the dialog.
Future<void> _onConfirmPush() async {
  try {
    if (_isPushing) return;
    if (!mounted) return;                           // ← guard BEFORE setState
    setState(() => _isPushing = true);              // ← LINT — but should NOT lint (no await yet)

    final NativeContactWriteResult result = await NativeContactWriteUtils.pushPhotoToDevice(
      contact: widget.contact,
      imageBytes: widget.saropaPhoto,
    );                                              // ← async gap STARTS here, not before

    widget.onConfirm(result);
    if (mounted) context.closeDialog();             // ← correctly guarded post-await
  } on Object catch (error, stack) {
    debugException(error, stack, context: context.mounted ? context : null);
    if (mounted) setState(() => _isPushing = false);  // ← also correctly guarded
  }
}
```

The `setState` on the equivalent of line 282 is the **first** lexical `setState`, the **first** statement after a guard pair, and **before any** `await`. There is no async gap to be on the wrong side of.

A minimal isolated repro:

```dart
class _MyWidgetState extends State<MyWidget> {
  bool _busy = false;

  Future<void> doWork() async {
    try {
      if (!mounted) return;
      setState(() => _busy = true);   // expect NO lint
      await someAsyncCall();
      if (mounted) setState(() => _busy = false); // already correctly guarded
    } on Object {
      // …
    }
  }
}
```

**Frequency:** Always — any `async` method whose body is a single top-level statement (typically `try`/`if`/`switch`) that *internally* contains both a `setState` followed by an `await` will report on the pre-`await` `setState`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic on a `setState` that lexically precedes the first `await`. The rule's own message says "after async gap" — pre-gap calls don't qualify. |
| **Actual** | `[use_setstate_synchronously] setState called after async gap without mounted check.` fires on line 282 even though no `await` has executed yet. |

---

## AST Context

```
MethodDeclaration (_onConfirmPush) — async
  └─ BlockFunctionBody
      └─ Block
          └─ TryStatement                                  ← body.block.statements[0]
              ├─ Block (try body)
              │   ├─ IfStatement (if (_isPushing) return;)
              │   ├─ IfStatement (if (!mounted) return;)
              │   ├─ ExpressionStatement
              │   │   └─ MethodInvocation (setState)        ← reported HERE (incorrectly)
              │   ├─ VariableDeclarationStatement
              │   │   └─ AwaitExpression                    ← actual async gap STARTS here
              │   ├─ ExpressionStatement (widget.onConfirm)
              │   └─ IfStatement (if (mounted) closeDialog)
              └─ CatchClause
                  └─ Block
                      └─ IfStatement
                          └─ MethodInvocation (setState)    ← reported (correctly guarded — also flagged)
```

The rule's iteration (lines 2127–2146):

```dart
for (final Statement stmt in body.block.statements) {
  if (containsAwait(stmt)) {           // ← TRUE for the whole TryStatement (await is nested deep inside)
    seenAwait = true;
    hasGuard = false;
  }
  if (seenAwait && isNegatedMountedGuard(stmt)) {  // ← TryStatement is NOT a mounted guard
    hasGuard = true;
    continue;
  }
  if (seenAwait && !hasGuard) {
    _reportUnprotectedSetState(stmt, reporter);    // ← walks ALL setState inside try, including pre-await ones
  }
}
```

`_reportUnprotectedSetState` recursively visits every `MethodInvocation` named `setState` inside the statement and reports it — with no awareness of where the `await` is positioned relative to each `setState`.

---

## Root Cause

### Hypothesis (high confidence): traversal granularity is too coarse

The rule operates only on `body.block.statements`. For methods whose body is a flat sequence of statements with no compound wrappers, the order check works correctly: walk left-to-right, mark `seenAwait` on encountering the await, then flag subsequent `setState` calls.

For methods whose body is wrapped in any compound statement (`try`/`if`/`for`/`switch`/`while`), the entire compound statement is a single iteration. `containsAwait(stmt)` returns true for the whole compound (because `containsAwait` recurses), but the *order* of inner statements is collapsed: the rule cannot tell which inner `setState` comes before the inner `await` and which comes after.

The reporter then walks the compound statement bottom-to-top and flags every `setState` it encounters, regardless of position.

The Saropa Contacts codebase mandates `try { ... } on Object catch (e, st) { debugException(e, st); ... }` around every method body (per `.claude/rules/global.md` "Error Handling MANDATORY"), so **every** method in the project hits this false-positive shape.

---

## Suggested Fix

Replace the top-level statement iteration with a recursive visitor that tracks `seenAwait` in source order across nested compound statements.

```dart
@override
void runWithReporter(SaropaDiagnosticReporter reporter, SaropaContext context) {
  context.addMethodDeclaration((MethodDeclaration node) {
    final body = node.body;
    if (body is! BlockFunctionBody) return;
    if (!body.isAsynchronous) return;

    // Walk the entire body in source order, not just top-level statements.
    // Track `seenAwait` and `hasGuard` so a setState lexically BEFORE the
    // first await is not reported.
    final visitor = _SetStateOrderVisitor(reporter);
    body.accept(visitor);
  });
}

class _SetStateOrderVisitor extends RecursiveAstVisitor<void> {
  _SetStateOrderVisitor(this._reporter);
  final SaropaDiagnosticReporter _reporter;

  bool _seenAwait = false;
  bool _hasGuard = false;

  @override
  void visitAwaitExpression(AwaitExpression node) {
    _seenAwait = true;
    _hasGuard = false;
    super.visitAwaitExpression(node);
  }

  @override
  void visitIfStatement(IfStatement node) {
    // If this if-statement is a `if (!mounted) return;` early-exit, the
    // following statements in the parent block are guarded.
    if (_seenAwait && _isNegatedMountedReturnGuard(node)) {
      _hasGuard = true;
    }
    super.visitIfStatement(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_seenAwait && !_hasGuard && _isSetStateCall(node)) {
      _reporter.atNode(node);
    }
    super.visitMethodInvocation(node);
  }
}
```

Caveats:
- Guard tracking inside compound statements is harder than at the top level — an `if (mounted) setState(...)` inline-guarded call should be exempt. The existing `SetStateWithMountedCheckFinder` already handles that finer-grained case; this fix mainly needs to ensure the visitor reaches each `setState` only after correctly evaluating whether an `await` lexically preceded it in source order.
- Loop bodies are subtler: a `setState` inside a `while (true)` body may execute before *and* after an `await` across iterations. The current rule already cannot reason about loop iteration; preserving that limitation is acceptable.

A simpler intermediate fix that closes this specific false positive: in `containsAwait`, for any compound statement, return the *first* descendant `AwaitExpression` offset (or null if none). Then iterating top-level statements becomes order-aware: when entering a compound statement, the rule can compare the offset of any inner `setState` against the offset of the first inner `await` and flag only those whose offset is greater.

---

## Fixture Gap

The fixture at `example*/lib/widget/use_setstate_synchronously_fixture.dart` should include:

1. **Flat method, `setState` after `await`, no mounted check** — expect LINT (current correct case)
2. **Flat method, `await` then `if (!mounted) return;` then `setState`** — expect NO lint (current correct case)
3. **Method body is `try { setState(...); await foo(); } on Object catch { ... }`** — expect NO lint *(currently false positive)*
4. **Method body is `try { if (!mounted) return; setState(...); await foo(); ... } on Object catch { setState(...); }`** — expect NO lint on the pre-await setState; LINT only on un-guarded post-await ones *(currently both flagged)*
5. **Nested if-then `setState` before `await`**: `if (cond) { setState(...); } await foo();` — expect NO lint *(may be false positive)*
6. **Switch with `setState` in case body before await**: `switch (x) { case 1: setState(...); break; } await foo();` — expect NO lint *(likely false positive)*
7. **For-loop with `setState` before any `await` in body** — expect NO lint *(likely false positive)*

Cases 5–7 are the same root cause as the filed case but in different compound-statement shapes. A correct fix to the traversal closes all of them at once.

---

## Downstream

Tracked in `contacts/`. Once this report exists, `// ignore: use_setstate_synchronously` is added at `lib/components/contact/avatar/native_photo_write_back_dialog.dart:282` (and `lib/components/contact/reaction/contact_reaction_modal.dart:76` if that site is the same shape — to verify) with a comment pointing here.

Project context: every method body in this codebase is wrapped in `try { ... } on Object catch (e, st) { debugException(e, st); }` per the project's mandatory error-handling rule (`.claude/rules/global.md`). Without this fix, every `async` method that does any pre-await state mutation will trip the rule.

---

## Environment

- saropa_lints version: 12.5.1+
- Dart SDK: 3.9.x
- Triggering project: `d:/src/contacts`
- Platform: Windows 11
