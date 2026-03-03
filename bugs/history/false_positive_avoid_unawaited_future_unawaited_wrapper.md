# False positive: `avoid_unawaited_future` and `unawaited()` wrapper (RESOLVED)

**Rule:** `avoid_unawaited_future`  
**Fixed:** 2026-03-03

## Summary

The rule was reporting on expression statements that were already wrapped in `unawaited(...)`, because it checked `node.parent` (the enclosing block) for a `MethodInvocation` named `unawaited` instead of checking `node.expression`. For `unawaited(someFuture());` the expression of the statement *is* that call, so the fix was to return early when `expr is MethodInvocation && expr.methodName.name == 'unawaited'`. Any statement of the form `unawaited(...);` is now never reported.

**Changes:** `lib/src/rules/core/async_rules.dart` (early return on `node.expression`), fixture and tests updated, CHANGELOG and template comment updated. Quick fix "Wrap in unawaited()" added.

**Resolution:** Rule returns early when `node.expression` is a `MethodInvocation` with method name `unawaited`, so `unawaited(someFuture());` is never reported.
