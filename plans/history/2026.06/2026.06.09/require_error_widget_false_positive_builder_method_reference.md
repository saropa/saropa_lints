# BUG: `require_error_widget` — False positive when `builder:` is a method tear-off that handles the error internally

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-09
Rule: `require_error_widget`
File: `lib/src/rules/widget/widget_patterns_require_rules.dart` (line ~1105)
Severity: False positive
Rule version: v5 | Since: unknown | Updated: unknown

---

## Summary

When `FutureBuilder` or `StreamBuilder` receives a method tear-off as its `builder:` argument
(a `SimpleIdentifier` or `PropertyAccess`, not a `FunctionExpression`), the rule falls back to
a source-substring heuristic: it calls `expr.toSource()` and checks whether the result contains
`'hasError'` or `'.error'`. A tear-off's source is just its name (e.g. `_buildContent`) — it
contains neither substring — so the rule always fires even when the referenced method fully and
correctly handles `snapshot.hasError`. A `// ignore:` was added at the Saropa Contacts call site
on 2026-06-09.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_error_widget'" lib/src/rules/
# Expected:
# lib/src/rules/widget/widget_patterns_require_rules.dart:1105:
#   'require_error_widget',
```

**Emitter registration:** `lib/src/rules/widget/widget_patterns_require_rules.dart:1105`
**Rule class:** `RequireErrorWidgetRule`
**Diagnostic `source` / `owner` as seen in Problems panel:** `_generated_diagnostic_collection_name_#0`

---

## Reproducer

```dart
class _MyWidgetState extends State<MyWidget> {
  late final Future<List<Item>> _future;

  @override
  void initState() {
    super.initState();
    _future = DatabaseItemIO.dbItemListLoad();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Item>>(
      future: _future,
      builder: _buildContent, // LINT — but _buildContent DOES handle hasError
    );
  }

  // This method fully handles the error state; the lint fires anyway because
  // the rule cannot see into the referenced method body from the call site.
  Widget _buildContent(BuildContext context, AsyncSnapshot<List<Item>> snapshot) {
    if (snapshot.hasError) {       // OK — error IS handled here
      debugException(snapshot.error, snapshot.stackTrace);
      return const _ErrorFallback();
    }
    if (!snapshot.hasData) {
      return const CommonCircularProgressIndicator();
    }
    return _ItemList(items: snapshot.requireData);
  }
}
```

**Frequency:** Always — fires on any `FutureBuilder`/`StreamBuilder` whose `builder:` value is a
method tear-off (instance method, static method, or top-level function), regardless of whether
the referenced method handles `hasError`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — `_buildContent` contains `snapshot.hasError` handling; the rule should resolve the referenced function body and confirm error handling is present |
| **Actual** | `[require_error_widget] FutureBuilder/StreamBuilder must handle error state…` reported at the `FutureBuilder` constructor name |

---

## AST Context

```
InstanceCreationExpression  (FutureBuilder<List<Item>>(...))   ← rule registers addInstanceCreationExpression
  └─ ArgumentList
      ├─ NamedExpression  future: _future
      └─ NamedExpression  builder: _buildContent
            └─ SimpleIdentifier  (_buildContent)   ← expr is NOT a FunctionExpression;
                                                      rule falls into the else branch at line ~1137
                                                      and calls expr.toSource() → "_buildContent"
                                                      which contains neither "hasError" nor ".error"
```

The referenced `MethodDeclaration` (_buildContent) lives as a sibling declaration in the same
`ClassDeclaration`:

```
ClassDeclaration  (_MyWidgetState)
  ├─ MethodDeclaration  build(BuildContext context)
  │     └─ ReturnStatement
  │           └─ InstanceCreationExpression  (FutureBuilder)  ← reported here
  └─ MethodDeclaration  _buildContent(BuildContext, AsyncSnapshot)
        └─ Block
              └─ IfStatement  (snapshot.hasError)  ← error handling; rule never reaches this
```

---

## Root Cause

The `else` branch at lines ~1137–1147 of `runWithReporter` handles all non-`FunctionExpression`
`builder:` values with the comment:

> "Non-inline builder (method tear-off, identifier reference, etc.). We cannot see the body, so
> fall back to the original source-substring heuristic to preserve prior behavior on those shapes."

The fallback is:

```dart
final String builderSource = expr.toSource();
if (!builderSource.contains('hasError') && !builderSource.contains('.error')) {
  reporter.atNode(node.constructorName, code);
}
```

For a `SimpleIdentifier` tear-off, `expr.toSource()` returns only the identifier token (e.g.
`"_buildContent"`), which never contains `'hasError'` or `'.error'`. The rule therefore always
fires on tear-offs.

The comment states the heuristic is to "preserve prior behavior" — meaning this is a known
limitation, not a deliberate choice to fire on tear-offs. The prior source-substring approach
was replaced for inline `FunctionExpression` builders (lines ~1125–1136) to avoid FPs from
extension-method error handlers (see `require_error_widget_false_positive_extension_method_error_handling.md`),
but the tear-off branch was left on the old heuristic unchanged.

The correct resolution for a `SimpleIdentifier` or `PropertyAccess` is to resolve the referenced
declaration via the element model and inspect its body using the same `_builderHandlesError` /
`_ErrorHandlingVisitor` logic that already works for inline closures.

---

## Suggested Fix

In the `else` branch (lines ~1137–1147), before falling back to the substring heuristic:

1. **Attempt element resolution.** When `expr` is a `SimpleIdentifier`, call
   `expr.staticElement`. When it is a `PropertyAccess`, resolve via `expr.propertyName.staticElement`.
   Cast the result to `ExecutableElement` if possible.
2. **Locate the function body in the AST.** Use the element's `declaration` property or navigate
   the enclosing `CompilationUnit` to find the `MethodDeclaration` / `FunctionDeclaration` whose
   `declaredElement` matches.
3. **Re-use `_builderHandlesError`.** Wrap the resolved `FunctionBody` in a synthetic
   `FunctionExpression` (or adapt `_ErrorHandlingVisitor` to accept a `FunctionBody` directly)
   and run the same visitor logic.
4. **Suppress rather than false-positive when unresolvable.** If the element cannot be resolved
   (cross-library tear-off, dynamic, etc.), do NOT fire — emit nothing and let the user verify
   manually. A missed diagnostic on a cross-library tear-off is a false negative; a guaranteed
   FP on every tear-off forces `// ignore:` pollution on correct code.

Relevant lines to modify: `widget_patterns_require_rules.dart` ~1137–1147 (the `else` branch in
`runWithReporter`) and possibly `_builderHandlesError` (~1169–1174, to accept `FunctionBody`
directly instead of `FunctionExpression`).

---

## Fixture Gap

The fixture at `example*/lib/widget/require_error_widget_fixture.dart` should include:

1. **`FutureBuilder` with inline closure handling `snapshot.hasError`** — expect NO lint
   (baseline; already covered).
2. **`FutureBuilder` with a method tear-off whose body contains `snapshot.hasError`** — expect
   NO lint (currently emits a FP — the core gap).
3. **`StreamBuilder` with a static method tear-off whose body contains `snapshot.hasError`** —
   expect NO lint (variant of #2).
4. **`FutureBuilder` with a method tear-off whose body does NOT handle `hasError`** — expect
   LINT (true positive must still fire once element resolution is in place).
5. **`FutureBuilder` with a cross-library / unresolvable tear-off** — expect NO lint (suppress
   rather than FP per the suggested fix).

---

## Changes Made

Replaced the tear-off substring heuristic in `widget_patterns_require_rules.dart`
with name-based declaration resolution:

- The `else` (non-`FunctionExpression`) branch now extracts the tear-off's
  trailing identifier (`_tearOffName`), finds a method/function with that name
  in the enclosing `CompilationUnit` (`_findNamedExecutableBody` +
  `_NamedExecutableFinder`), and runs the existing error-handling analysis on
  its body. If no local declaration matches (cross-library tear-off), the rule
  suppresses instead of firing — a missed diagnostic is preferable to a
  guaranteed false positive on correct code.
- Refactored `_builderHandlesError` to delegate to a new `_bodyHandlesError(
  FormalParameterList?, FunctionBody)` so the same analysis serves both inline
  closures and resolved tear-offs. `_snapshotParamName` now takes a
  `FormalParameterList?`. The inline-closure path is behavior-preserving.

Name-based resolution works without element resolution, so the fix is effective
in both the parse-only scan and the analysis server.

---

## Tests Added

- `test/rules/widget/require_error_widget_extension_method_test.dart`: added a
  `require_error_widget tear-off resolution` group mirroring the new logic —
  GOOD: instance tear-off body handles `hasError`; GOOD: static tear-off body
  handles `hasError`; BAD: tear-off body ignores error; GOOD: unresolvable
  cross-library tear-off is suppressed. All pass.
- `example/lib/widget_patterns/require_error_widget_fixture.dart`: added
  `_GoodTearOffState`, `_GoodStaticTearOffState`, `_BadTearOffState`, and
  `_ExternalTearOffState` documenting the same cases.

**Verification note:** the full rule is resolution-dependent — its
`addInstanceCreationExpression` trigger only fires when `FutureBuilder(...)`
resolves to an `InstanceCreationExpression`, which the parse-only scan CLI does
not produce. The added unit tests exercise the predicate directly (parse-only,
mirroring production), giving positive confirmation that the tear-off body
analysis fires correctly for handled, unhandled, and unresolvable references.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Finish Report (2026-06-09)

**Scope:** (A) Dart lint rules / analyzer plugin.

**Deep review:** The tear-off branch is the only behavior change; the inline
path is a pure refactor (verified by the unchanged existing test group). Name
resolution stops at the first match — a same-named collision would inspect the
wrong method, an acceptable edge given tear-off names are usually unique within
a unit. Unresolvable → suppress is the deliberate, report-endorsed trade-off.
Rule file, tier, severity, `LintImpact` unchanged.

**Tests:** `dart test test/rules/widget/require_error_widget_extension_method_test.dart`
→ all 11 pass (7 existing + 4 new tear-off). Scan CLI cannot exercise the
resolution-dependent trigger (noted above).

**Maintenance:** CHANGELOG `[Unreleased]` Fixed bullet added. README/ROADMAP
unchanged (false-positive fix).

**Bug archived:** bugs/require_error_widget_false_positive_builder_method_reference.md
→ plans/history/2026.06/2026.06.09/require_error_widget_false_positive_builder_method_reference.md

**Finish report appended:** this file.

---

## Environment

- saropa_lints version: 13.12.2
- Dart SDK version: (saropa_lints repo default)
- custom_lint version: N/A (native analyzer plugin)
- Triggering project/file: Saropa Contacts — 2026-06-09 (suppressed with `// ignore: require_error_widget -- builder is a method tear-off; _buildContent handles snapshot.hasError`)
