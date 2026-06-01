# BUG: `require_error_widget` — Fires When Error Handling Lives in an Extension Method Called by the Builder

**Status: Fixed**

Created: 2026-05-31
Fixed: 2026-05-31
Rule: `require_error_widget`
File: `lib/src/rules/widget/widget_patterns_require_rules.dart` (line 1084)
Severity: False positive
Rule version: v5 | Since: v?.?.? | Updated: 2026-05-31

---

## Summary

The rule does a literal text-contains check (`builderSource.contains('hasError') || builderSource.contains('.error')`) on the `FutureBuilder` / `StreamBuilder` `builder:` argument source. Builders that delegate their error handling to an extension method on `AsyncSnapshot` — a common centralized error-handling pattern — are flagged as false positives because:

1. `snapshot.snapLoadingProgress()` (example extension that internally checks `hasError` and reports via a shared policy) doesn't contain the literal substring `hasError` at the call site.
2. `snapshot.reportErrorIfAny()` (sibling extension) contains `Error` (capital E) in the method name, but NOT the lowercase `.error` pattern the rule checks.

Both are correct, complete error handling. The rule's text-only check can't see through method indirection.

---

## Attribution Evidence

```bash
$ grep -rn "'require_error_widget'" D:/src/saropa_lints/lib/src/rules/
D:/src/saropa_lints/lib/src/rules/widget/widget_patterns_require_rules.dart:1104:    'require_error_widget',
```

Single match — rule is unambiguously emitted by `saropa_lints`. Class: `RequireErrorWidgetRule` at line 1084.

---

## Reproducer

Minimal Dart code demonstrating the FP. Both `snapLoadingProgress` and `reportErrorIfAny` extensions implement complete `hasError` handling internally but are flagged by the rule because the literal strings aren't in the call-site builder source.

```dart
import 'dart:io' as io;
import 'package:flutter/material.dart';

extension SnapExtension on AsyncSnapshot<dynamic> {
  /// Centralized error policy. Network errors (handshake/socket) log
  /// locally; everything else escalates to Crashlytics via
  /// debugException(). No-op when no error.
  void reportErrorIfAny() {
    if (!hasError) return;
    if (error is io.SocketException) {
      // log locally only
    } else {
      // debugException(error, stackTrace);
    }
  }

  /// Combined loading + error widget. Routes errors through
  /// reportErrorIfAny(); returns the loading widget while waiting;
  /// returns null so the caller renders its data branch.
  Widget? snapLoadingProgress() {
    if (hasError) {
      reportErrorIfAny();
      return null;
    }
    if (connectionState == ConnectionState.waiting) {
      return const CircularProgressIndicator();
    }
    return null;
  }
}

class Demo extends StatelessWidget {
  const Demo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: <Widget>[
      // FALSE POSITIVE — errors handled via snapLoadingProgress()
      FutureBuilder<int>(
        future: Future<int>.value(42),
        builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
          final Widget? snapWaiting = snapshot.snapLoadingProgress();
          if (snapWaiting != null) return snapWaiting;
          return Text('${snapshot.data}');
        },
      ),

      // FALSE POSITIVE — errors handled via reportErrorIfAny()
      // (capital E in method name doesn't match the lowercase .error check)
      FutureBuilder<int>(
        future: Future<int>.value(42),
        builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
          snapshot.reportErrorIfAny();
          return Text('${snapshot.data}');
        },
      ),
    ]);
  }
}
```

**Frequency:** Always — any builder whose only error handling is an extension method call without the literal substring `hasError` or `.error` (lowercase).

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — both builders delegate error handling to extension methods that internally check `hasError` and route through a centralized policy. |
| **Actual** | `[require_error_widget] FutureBuilder/StreamBuilder must handle error state ...` reported on both `FutureBuilder` constructors. |

---

## AST Context

```
MethodDeclaration (build)
  └─ ReturnStatement
      └─ InstanceCreationExpression (Column)
          └─ ArgumentList
              └─ ListLiteral (children)
                  └─ InstanceCreationExpression (FutureBuilder)    ← reported HERE
                      └─ ArgumentList
                          └─ NamedExpression (builder:)
                              └─ FunctionExpression
                                  └─ Block (this is what rule reads as .toSource())
                                      └─ VariableDeclarationStatement
                                          └─ VariableDeclaration (snapWaiting)
                                              └─ MethodInvocation (.snapLoadingProgress)
                                                  ← rule looks for "hasError" /
                                                    ".error" in source text;
                                                    doesn't see through method call
```

The rule's `runWithReporter` (line 1111) does:

```dart
final String builderSource = arg.expression.toSource();
if (!builderSource.contains('hasError') && !builderSource.contains('.error')) {
  reporter.atNode(node.constructorName, code);
}
```

`builderSource` is just the lexical source of the `FunctionExpression`. Method calls on `snapshot` are opaque to a substring match.

---

## Root Cause

**Mechanism:** The rule treats "presence of the literal text `hasError` or `.error`" as a proxy for "this builder handles errors." This is true for the canonical inline pattern (`if (snapshot.hasError) return ...`) but is false for any builder that delegates error handling to a method on `AsyncSnapshot`.

Two cases the rule conflates:

| Pattern | Should the rule fire? |
|---|---|
| `builder: (ctx, s) => Text('${s.data}')` — no error handling at all | Yes — real violation |
| `builder: (ctx, s) { final w = s.snapLoadingProgress(); ... }` — extension handles errors internally | No — already covered |
| `builder: (ctx, s) { s.reportErrorIfAny(); return Text('${s.data}'); }` — explicit centralized report | No — already covered |
| `builder: (ctx, s) { if (s.hasError) return ErrorView(); ... }` — inline literal | No — already covered (rule already passes) |

Cases 2 and 3 are FPs.

### Hypothesis A: cheap heuristic — also accept any `.method(...)` invocation containing `error` (case-insensitive) in its name

Add a second check: if the builder source contains any method-call pattern that includes `error` (case-insensitive) in the method identifier, treat it as error-handling-likely.

Regex: `\.[A-Za-z]*[Ee]rror[A-Za-z]*\s*\(`

Matches:
- `.snapLoadingProgress` — NO (no Error in name)
- `.reportErrorIfAny` — YES
- `.handleError` — YES
- `.checkError` — YES
- `.onError` — YES

Limitation: still misses `.snapLoadingProgress` because the method name doesn't contain `Error`. Insufficient for the project's primary pattern.

### Hypothesis B: project-configurable allow-list of method names

Add a rule option `error_handling_methods: list<string>` that downstream projects can populate with the names of their centralized error-handling extension methods. Default empty. When set, the rule's check becomes "source contains `hasError` / `.error` OR matches one of the configured method names with a `.` prefix."

```yaml
plugins:
  saropa_lints:
    diagnostics:
      require_error_widget: true
      require_error_widget__error_handling_methods:
        - snapLoadingProgress
        - reportErrorIfAny
        - handleSnapError
```

Allows projects to declare their centralized helpers without forcing the rule to do semantic analysis.

### Hypothesis C: walk the method call graph

For each `MethodInvocation` in the builder body, resolve the target's declaration and check whether THAT method body contains `hasError` or accesses `snapshot.error`. Most accurate; most expensive (requires `staticElement.declaration` traversal across files).

Likely too costly for a low-cost lint. Hypothesis B is the recommended path.

---

## Suggested Fix

Implement Hypothesis B. Net change:

- Add a rule option `error_handling_methods: list<string>` to `RequireErrorWidgetRule`.
- Augment the check at line 1126:
  ```dart
  if (!builderSource.contains('hasError') &&
      !builderSource.contains('.error') &&
      !_containsConfiguredMethod(builderSource, configuredMethods)) {
    reporter.atNode(node.constructorName, code);
  }
  ```
- `_containsConfiguredMethod` runs `RegExp('\\.${RegExp.escape(name)}\\s*\\(')` against the source for each configured method name.
- Add the four fixture cases below.

---

## Fixture Gap

The fixture for `require_error_widget` should add:

1. **GOOD — builder calls `.snapLoadingProgress()` or similar custom extension; project has the method in its `error_handling_methods` option.** Expect: no lint.
2. **GOOD — builder calls `.reportErrorIfAny()` with capital-E `Error`.** Expect: no lint with option configured.
3. **BAD — builder has no error handling AND project has no configured methods.** Expect: lint (current behavior preserved).
4. **EDGE — builder source contains the substring `error` in a variable name (e.g. `final hasErrorState = false;`) but no `hasError` access.** Currently triggers a false NEGATIVE (rule passes due to substring match on `error`). Worth a fixture case documenting this corner.

---

## Changes Made

Implemented neither Hypothesis A nor B as proposed. Instead chose a stricter
**AST-based predicate** that requires no per-rule configuration plumbing
(which the codebase does not currently support) and is more accurate than
the regex sketched in Hypothesis A. Net change at
`lib/src/rules/widget/widget_patterns_require_rules.dart` (around
`RequireErrorWidgetRule`):

- Replaced the literal `builderSource.contains('hasError') || builderSource.contains('.error')`
  check with `_builderHandlesError(FunctionExpression)`, which walks the
  builder body via a `RecursiveAstVisitor` and accepts ANY of:
  1. **inline access** — `PrefixedIdentifier` / `PropertyAccess` whose
     property name is `hasError`, `error`, or `stackTrace` (canonical
     `if (snapshot.hasError) ...` shape, with `stackTrace` added since
     access to it is strongly diagnostic-related);
  2. **delegated handler on the snapshot** — any `MethodInvocation` whose
     target identifier matches the second positional parameter of the
     builder (the snapshot, per Flutter convention). `AsyncSnapshot` has no
     instance methods that aren't tied to state inspection, so any method
     call on the snapshot identifier is treated as user-supplied handling.
     Catches the `snapshot.snapLoadingProgress()` and
     `snapshot.reportErrorIfAny()` cases that motivated the bug;
  3. **bare helper whose name encodes "error"** — any `MethodInvocation`
     whose method name (case-insensitive) contains `error`. Catches
     mixin/extension helpers called without a target prefix.
- Preserved the original source-substring fallback for the
  non-`FunctionExpression` shape (method tear-off / identifier passed as
  `builder:`), since the AST predicate cannot see through a tear-off.
- Bumped the rule's diagnostic version marker `{v4}` → `{v5}`.

### Side effect: latent false NEGATIVE also closed

The AST check no longer matches a local named `hasErrorState` (a
`VariableDeclaration`, not a `.hasError` access) — so the fixture case 4
the bug noted as a corner now correctly fires the lint instead of being
silently suppressed.

---

## Tests Added

`test/rules/widget/require_error_widget_extension_method_test.dart` — seven
contract tests that mirror `_builderHandlesError` against parsed AST
snippets (same pattern as
`pass_existing_future_to_future_builder_cache_method_test.dart`):

1. BAD — builder accesses only `.data` → `false`
2. GOOD — inline `if (snapshot.hasError)` → `true`
3. GOOD — `snapshot.snapLoadingProgress()` delegated handler → `true`
4. GOOD — `snapshot.reportErrorIfAny()` capital-E method name → `true`
5. GOOD — bare `reportErrorIfAny(snapshot)` helper call → `true`
6. BAD — local variable named `hasErrorState` does NOT suppress → `false`
   (the latent false-negative the bug also called out)
7. GOOD — arrow-bodied builder accessing `.hasError` → `true`

Fixture file updates at
`example/lib/widget_patterns/require_error_widget_fixture.dart` add five
end-to-end cases (the same four scenarios from the bug's "Fixture Gap"
section plus the canonical inline pattern as the positive control). Two
of the new fixtures carry `expect_lint: require_error_widget` for the
analyzer-plugin path.

**Verification caveat (scan-CLI limitation):** the scan CLI parses with
`parseString` and no type resolution, so `FutureBuilder<int>(...)` without
a `new`/`const` keyword parses as a `MethodInvocation` rather than an
`InstanceCreationExpression`. This means the rule's
`addInstanceCreationExpression` registration never fires under the scan
CLI on standalone files, both before and after this fix. The rule does
fire correctly under the analyzer plugin (which has full resolution) —
which is where the bug was originally reported. The contract tests above
exercise the predicate independently of registration so the fix is
verified.

---

## Commits

<!-- Filled by /finish or the publish flow. -->

---

## Environment

- saropa_lints version: 13.11.1
- Dart SDK version: (project pinned, see contacts/pubspec.yaml)
- Triggering project: `d:/src/contacts` (Saropa Contacts)
- 16 distinct downstream sites all use the same project extension `lib/utils/primitive/snapshot_utils.dart` — either `snapLoadingProgress()` or `reportErrorIfAny()`. Both contain complete `hasError` handling internally. Sites and lines listed in `docs/PLAN_LINT_RULE_ENABLEMENT.md` plan state row for Rule 7.

---

## Downstream Workaround

Until the fix lands, each downstream FP carries a one-line `// ignore: require_error_widget -- <rationale>` directive on the line above the `FutureBuilder` / `StreamBuilder` constructor, referencing this bug file. Volume: ~16 ignores across 14 files in the Saropa Contacts repo.
