# BUG: `avoid_context_in_initstate_dispose` — false positive when `context` is passed to a helper that performs no inherited-widget lookup

**Status: Open**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-10
Rule: `avoid_context_in_initstate_dispose`
File: `lib/src/rules/widget/widget_lifecycle_rules.dart` (rule at ~line 1; visitor `_ContextUsageVisitor` at ~line 81; identifier check at ~line 104)
Severity: False positive / Medium (forces `// ignore:` on a context use that does not touch the inherited tree)
Rule version: v7 | Since: unknown | Updated: 13.12.3 (current source)

---

## Summary

The rule reports every bare `context` identifier in `initState`/`dispose` unless it is lexically inside a small allowlist of deferring callbacks (`addPostFrameCallback`, `Future`, `Timer`, `microtask`, …). It does not analyze what is done with the `context`. Passing `context` as an argument to a project helper that only resolves a value from global state (e.g. a color enum whose `.from(context)` switches on a global `isDarkMode` flag and never calls `Theme.of`/`MediaQuery.of`/`*.of(context)`) is flagged even though no inherited-widget dependency is registered and no unmounted-tree lookup occurs — so the use is safe.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'avoid_context_in_initstate_dispose'" lib/src/rules/
# lib/src/rules/widget/widget_lifecycle_rules.dart:37:    'avoid_context_in_initstate_dispose',

# Negative — NOT in the sibling drift-advisor repo (source/owner label was ambiguous)
grep -rn "avoid_context_in_initstate_dispose" ../saropa_drift_advisor/lib/
# 0 matches
```

**Emitter registration:** `lib/src/rules/widget/widget_lifecycle_rules.dart:37` (`AvoidContextInInitstateDisposeRule`)
**Diagnostic `source` / `owner` as seen in Problems panel:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

```dart
import 'package:flutter/material.dart';

// A color token whose resolution depends on a GLOBAL flag, not on any
// InheritedWidget. The `context` parameter is accepted for API uniformity
// but never used for an `.of(context)` lookup.
bool get _isDark => DateTime.now().second.isEven; // stand-in for a global
Color resolveColor(BuildContext context) => _isDark ? Colors.black : Colors.white;

class Example extends StatefulWidget {
  const Example({super.key});
  @override
  State<Example> createState() => _ExampleState();
}

class _ExampleState extends State<Example> {
  late Color _seed;

  @override
  void initState() {
    super.initState();
    // LINT — but `context` is only forwarded to resolveColor, which performs
    // NO inherited-widget lookup, so this is safe. The value is also recomputed
    // in didChangeDependencies (the correct place for any inherited lookup).
    _seed = resolveColor(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _seed = resolveColor(context);
  }
}
```

**Frequency:** Always, whenever `context` appears in `initState`/`dispose` outside the deferred-callback allowlist — including the common, safe case of forwarding it to a helper that does not depend on inherited widgets.

Real-world site: `d:/src/contacts/lib/utils/system/shared_avatar_overlay.dart:68`
- `initState`: `_dotDecoration = _buildDotDecoration(context);`
- `_buildDotDecoration` reads `widget.contact.statusColor?.from(context)`, and `ThemeCommonColor.from(BuildContext)` (theme_common_color.dart:534) resolves via the global `ThemeUtils.isDarkMode` — it never calls `Theme.of(context)` / `MediaQuery.of(context)`.
- The same decoration is also recomputed in `didChangeDependencies` (line 101), the correct site for any genuine inherited dependency.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `context` is forwarded to a helper that performs no `*.of(context)` inherited lookup, so it neither registers a dependency nor reads the unmounted tree unsafely. |
| **Actual** | `[avoid_context_in_initstate_dispose] BuildContext used in initState or dispose may reference an unmounted widget…` reported on the `context` identifier. |

---

## AST Context

```
ClassDeclaration (_ExampleState)
  └─ MethodDeclaration (initState)
      └─ Block
          └─ ExpressionStatement
              └─ AssignmentExpression (_seed = resolveColor(context))
                  └─ MethodInvocation (resolveColor)
                      └─ ArgumentList
                          └─ SimpleIdentifier (context)   ← reported here
```

`_ContextUsageVisitor.visitSimpleIdentifier` matches `node.name == 'context'` with `_safeCallbackDepth == 0` (the enclosing call `resolveColor` is not in `_safeCallbackMethods`), and `_isContextParameter` returns false (it is an argument, not a parameter declaration) → added to `unsafeContextUsages`.

---

## Root Cause

`_ContextUsageVisitor` (line ~81) decides safety purely on **lexical position**:

- `visitSimpleIdentifier` (line ~104) reports any `context` when `_safeCallbackDepth == 0` and it is not a parameter declaration.
- `_safeCallbackDepth` is only raised inside a hard-coded allowlist of deferring callbacks (`_safeCallbackMethods`, line ~92) — `addPostFrameCallback`, `Future`, `Timer`, `microtask`, etc.

There is no analysis of what the `context` is used FOR. Forwarding it as an argument to a function that does not perform an inherited-widget lookup (`Theme.of`, `MediaQuery.of`, `*.of(context)`, `dependOnInheritedWidgetOfExactType`, `context.watch`, etc.) is treated identically to a direct `Theme.of(context)` call. The rule's own correction message contemplates "a pre-captured reference" as the safe pattern, but it cannot recognize the equally-safe "context forwarded to a context-independent helper" case.

### Hypothesis A (confirmed): the rule reports on syntactic presence of `context`, not on an unsafe inherited lookup

The flagged use never reaches `Theme.of`/`MediaQuery.of`. It is over-broad: presence of the `context` token is treated as unsafe regardless of the downstream call.

---

## Suggested Fix

Narrow the report to `context` usages that actually perform (or are passed into) an inherited-widget lookup, rather than every textual `context`. Concretely, only report when the `context` identifier is:

1. the target of a method invocation whose method is a known inherited accessor (`watch`/`read`/`select`/`dependOnInheritedWidgetOfExactType`/`getInheritedWidgetOfExactType`), OR
2. the argument to a static `*.of(context)` accessor (`Theme.of`, `MediaQuery.of`, `Navigator.of`, `Scaffold.of`, `Directionality.of`, etc. — the `X.of(context)` shape), OR
3. used directly to read `context.size`, `context.findRenderObject`, etc.

A bare `context` forwarded as an argument to an ordinary helper (whose body the rule cannot resolve) is, at minimum, too weak a signal to warrant a WARNING-severity diagnostic; if such cases must be kept, demote them or require the receiver/callee to match the `.of`/inherited-accessor shape.

This mirrors the over-broad-then-narrowed fixes already applied to sibling rules in 13.12.2/13.12.3 (e.g. `avoid_context_in_async_static` now keys on actual unsafe usage rather than mere presence).

---

## Fixture Gap

The fixture at `example*/lib/widget/avoid_context_in_initstate_dispose_fixture.dart` should include:

1. **`context` forwarded to a helper that performs no inherited lookup** (e.g. `_helper(context)` where `_helper` resolves from global state) — expect NO lint.
2. **`Theme.of(context)` / `MediaQuery.of(context)` directly in initState** — expect LINT (genuine unsafe lookup, regression guard).
3. **`context` used inside `addPostFrameCallback`** — expect NO lint (already covered; keep as guard).
4. **`context.read<T>()` in initState** — expect LINT (inherited accessor on context).

---

## Changes Made

<!-- Fill in when a fix is written. -->

---

## Tests Added

<!-- Fill in when a fix is written. -->

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: plugin pinned `13.12.1` in the triggering project's `analysis_options.yaml`; resolved `13.12.2` in `pubspec.lock`. Current source under investigation: `13.12.3`. The visitor logic is unchanged across these versions, so the FP reproduces on all three.
- Dart SDK version: `>=3.10.7 <4.0.0` (project constraint)
- analyzer version: `12.1.0`
- custom_lint version: n/a — saropa_lints is a native analysis_server plugin (top-level `plugins:` block)
- Triggering project/file: `d:/src/contacts/lib/utils/system/shared_avatar_overlay.dart:68`
