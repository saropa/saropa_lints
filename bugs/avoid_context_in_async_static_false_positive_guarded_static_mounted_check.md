# BUG: `avoid_context_in_async_static` — Fires on Every Async Static with a Context Parameter, Regardless of Mounted Guards

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `avoid_context_in_async_static`
File: `lib/src/rules/core/context_rules.dart` (line ~992)
Severity: False positive
Rule version: v2

---

## Summary

`avoid_context_in_async_static` fires on **every** `static async` method that declares a
`BuildContext` parameter, regardless of whether the method body uses the context safely
(before the first `await`, or only after a `mounted` guard). The sibling rule
`avoid_context_across_await` already implements flow analysis recognizing `if (!context.mounted) return;`
and several other guard forms; this rule performs no equivalent body inspection. ~119 sites in
Saropa Contacts were worked around with `// ignore: avoid_context_in_async_static -- guarded utility static`
on 2026-06-09.

---

## Attribution Evidence

Positive attribution — rule IS defined in `saropa_lints`:

```
# Positive — rule IS defined here
grep -rn "'avoid_context_in_async_static'" lib/src/rules/
lib/src/rules/core/context_rules.dart:991: 'avoid_context_in_async_static',
```

**Emitter registration:** `lib/src/rules/core/context_rules.dart:991`
**Rule class:** `AvoidContextInAsyncStaticRule` — registered in `lib/src/rules/all_rules.dart`
**Diagnostic `source` / `owner` as seen in Problems panel:** `_generated_diagnostic_collection_name_#N`
(the IDE analysis-server plugin; negative attribution against sibling repos not required for this owner label)

---

## Reproducer

```dart
class ShowHelper {
  // LINT fires here (on `BuildContext context` parameter) — but should NOT lint.
  // Context is only used after a mounted guard; pattern is identical to what
  // avoid_context_across_await recognizes as safe.
  static Future<void> showThing(BuildContext context) async {
    final data = await load();
    if (!context.mounted) return;   // guard — context is safe below this point
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => Detail(data)));
  }
}

class ShowHelper2 {
  // LINT fires here too — but context is used ONLY before the first await.
  // No async gap has opened yet; the context cannot be stale.
  static Future<void> showPrompt(BuildContext context) async {
    final result = await showDialog<bool>(context: context, builder: (_) => MyDialog());
    // context is never touched again after the await
    if (result == true) doSomething();
  }
}
```

**Frequency:** Always — every `static async` method with a `BuildContext` parameter, without exception.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic when every post-`await` use of the `BuildContext` parameter is behind a `mounted` guard, OR when the parameter is used only before the first `await` |
| **Actual** | `[avoid_context_in_async_static] BuildContext in async static method may become invalid during async operations. {v2}` reported on the parameter declaration at every matching method signature |

---

## AST Context

```
FunctionDeclaration / ClassDeclaration
  └─ MethodDeclaration (showThing — static, async)
      └─ FormalParameterList
          └─ SimpleFormalParameter (BuildContext context)  ← node reported here
      └─ BlockFunctionBody (isAsynchronous = true)
          └─ Block
              ├─ AwaitExpression (await load())
              ├─ IfStatement (!context.mounted → return)  ← mounted guard, not seen by rule
              └─ ExpressionStatement (Navigator.of(context).push(...))
```

The rule reports on the `SimpleFormalParameter` node. It never enters the `BlockFunctionBody`
to inspect how the parameter is used.

---

## Root Cause

`AvoidContextInAsyncStaticRule.runWithReporter` (`context_rules.dart`, lines 1002–1020) registers
a `methodDeclaration` visitor. The detection logic is:

```
1. if (!node.isStatic) return;          // must be static
2. if body is not BlockFunctionBody → return;
3. if (!body.isAsynchronous) return;    // must be async
4. for each parameter: if isBuildContextParam(param) → reporter.atNode(param)
```

Step 4 fires unconditionally on the parameter declaration. **The rule never reads the method body.**
It does not check:

- Whether the `BuildContext` is used before or after the first `await`.
- Whether a mounted guard (`if (!context.mounted) return;`, `if (mounted) { ... }`,
  `context.mounted ? context : null`, etc.) precedes every post-`await` use.

By contrast, the sibling rule `AvoidContextAcrossAsyncRule` (`context_rules.dart`, lines ~158–270)
implements exactly this body inspection. Its `_checkAsyncBody` helper tracks `await` positions
and recognizes the full set of mounted guard forms (early-exit `if (!mounted) return;`,
positive-block `if (mounted) { ... }`, compound `&&` guards, guarded ternaries). The
detection logic — the tracking state machine and the guard recognizer — already exists in
the same file and could be reused or called from this rule.

The net effect is that the rule cannot distinguish a dangerous unguarded pattern from a
correctly guarded one. Any call site that follows the same safe pattern accepted by
`avoid_context_across_await` must add `// ignore:` to suppress this rule.

---

## Suggested Fix

In `AvoidContextInAsyncStaticRule.runWithReporter` (lines 1002–1020), after confirming the
method is `static async` and has a `BuildContext` parameter, do NOT report immediately.
Instead, inspect the method body using the existing body-analysis machinery:

**Option A — full flow analysis (preferred):** Call `_checkAsyncBody` (or an equivalent
extracted from `AvoidContextAcrossAsyncRule`) on `body.block`. Report only if that analysis
finds a post-`await` use of the parameter that is NOT behind a mounted guard.

**Option B — conservative exemption:** Report only when the `BuildContext` parameter is
actually referenced at least once AFTER an `await` statement in the method body, without an
intervening mounted guard. A parameter used only before the first `await` cannot be stale.

**Option C — sync-before-first-await exemption only:** Cheaper to implement: scan
`body.block.statements` for the first `AwaitExpression`-containing statement. If all
`context` references appear before that statement, suppress the diagnostic. This handles the
second reproducer above without requiring full guard flow analysis.

Any of these options mirrors the behavior the codebase already relies on from
`avoid_context_across_await`, making the two rules consistent with each other.

Reference lines in `context_rules.dart`:
- Mounted-guard recognizer: ~lines 100–155 (the `_isMountedGuard` / `_isProtectedByMountedCheck` helpers).
- Async body scanner: ~lines 263–350 (`_checkAsyncBody`, `_checkStatements`).

---

## Fixture Gap

The fixture at `example*/lib/core/context_rules_fixture.dart` (or equivalent) should include:

1. **Async static + context used before first await only** — expect NO lint. The context
   cannot be stale before the async gap opens.
2. **Async static + `if (!context.mounted) return;` before every post-`await` use** — expect NO lint.
3. **Async static + `if (mounted) { Navigator.of(context)... }` positive block guard** — expect NO lint.
4. **Async static + `context.mounted ? context : null` guarded ternary** — expect NO lint.
5. **Async static + unguarded post-`await` context use** — expect LINT. This is the genuinely
   dangerous case the rule was designed for.
6. **Async static + mixed: some uses guarded, one unguarded post-`await`** — expect LINT only
   on the unguarded use.

---

## Changes Made

<!-- Fill in when a fix is written. -->

---

## Tests Added

<!-- List new or updated fixture/test files and what they verify. -->

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: (project Dart SDK — see Saropa Contacts pubspec)
- custom_lint version: N/A (saropa_lints is a native analysis_server_plugin, not custom_lint)
- Triggering project/file: Saropa Contacts — ~119 sites across `lib/` as of 2026-06-09;
  worked around with `// ignore: avoid_context_in_async_static -- guarded utility static`
