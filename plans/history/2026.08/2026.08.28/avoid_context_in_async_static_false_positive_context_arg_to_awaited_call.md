# BUG: `avoid_context_in_async_static` — False positive when context is only passed as arg to awaited call

**Status: Fixed**

Created: 2026-08-28
Rule: `avoid_context_in_async_static`
File: `lib/src/rules/core/context_rules.dart` (line ~996)
Severity: False positive
Rule version: v5 (mounted-guard FP fixed in v13.0.0) | Since: early | Updated: v13.0.0
Suppression count in downstream project: **156**

---

## Summary

The rule flags every `BuildContext` parameter on an `async static` method, but
the most common pattern (156 suppressions, 100% FP rate in a sample of 9) is a
static launcher that passes `context` as an argument to the single awaited call
and never reads it after the `await` resumes. The caller cannot use a stale
context because it never touches `context` post-await — the callee receives it
synchronously before any suspension point.

A prior FP for the mounted-guard case was fixed in v13.0.0 (rule v5). This is
the residual unaddressed pattern.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_context_in_async_static'" lib/src/rules/
# lib/src/rules/core/context_rules.dart:996:    'avoid_context_in_async_static',
```

**Emitter registration:** `lib/src/rules/core/context_rules.dart:996`

---

## Reproducer

```dart
class ContactGroupAddContact {
  // LINT — but should NOT lint (false positive)
  static Future<void> showDialogAddContactPicker(
    BuildContext context, {
    required ContactGroupModel contactGroup,
    ValueChanged<ContactModel?>? onPressed,
  }) async {
    try {
      // context is consumed here, synchronously, before any await resumes
      await showDialogCommon(
        context: context,
        headerBar: CommonHeaderBar(
          text: l10n.actionAddToTarget(contactGroup.displayName),
        ),
        // ...
      );
      // context is NEVER accessed after this point
    } on Object catch (error, stack) {
      debugException(error, stack);
    }
  }
}
```

**Frequency:** Always — fires on every `async static` with a `BuildContext`
parameter, regardless of whether context is used post-await.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — context is consumed as an argument to the awaited call, never read after resumption |
| **Actual** | `[avoid_context_in_async_static] Avoid passing BuildContext to async static methods` reported on the parameter |

---

## AST Context

```
ClassDeclaration (ContactGroupAddContact)
  └─ MethodDeclaration (showDialogAddContactPicker) [static, async]
      └─ FormalParameterList
          └─ SimpleFormalParameter (BuildContext context)  ← node reported here
      └─ Block
          └─ TryStatement
              └─ AwaitExpression
                  └─ MethodInvocation (showDialogCommon)
                      └─ ArgumentList
                          └─ NamedExpression (context: context)  ← only usage
```

---

## Root Cause

### Hypothesis A: Rule flags parameter declaration without flow analysis

The rule registers on the `SimpleFormalParameter` node and checks that the
enclosing method is `static` + `async`. It does not perform flow analysis to
determine whether `context` is actually read after any `await` expression. The
safe pattern — passing context as an argument to the awaited call itself — is
indistinguishable from the unsafe pattern (reading `context.size` after an
`await`) because the rule never inspects usage sites.

---

## Suggested Fix

After confirming the method is `static` + `async` with a `BuildContext`
parameter, walk the method body's `AwaitExpression` nodes. For each usage of
the context parameter (`SimpleIdentifier` resolving to the parameter element):

1. If the usage appears **inside** the argument list of an awaited call (i.e.,
   the usage's ancestor chain includes a `MethodInvocation` / `FunctionExpressionInvocation`
   that is the direct child of an `AwaitExpression`), it is consumed
   synchronously — not a violation.
2. If ALL usages are of this form (no post-await reads), suppress the
   diagnostic.
3. If any usage appears after an `AwaitExpression` in the block's statement
   sequence, flag normally.

---

## Fixture Gap

The fixture should include:

1. **Context passed only as arg to awaited call** — expect NO lint
2. **Context read after await (e.g., `context.size`)** — expect LINT
3. **Context passed to awaited call AND read after** — expect LINT
4. **Multiple awaits, context only in first** — expect NO lint
5. **Context in try-catch error handler with mounted guard** — expect NO lint (already fixed in v5)

---

## Environment

- saropa_lints version: 15.2.4
- Dart SDK version: 3.13.1
- Triggering project: `contacts` (d:\src\contacts)
- Downstream suppression count: 156 sites
