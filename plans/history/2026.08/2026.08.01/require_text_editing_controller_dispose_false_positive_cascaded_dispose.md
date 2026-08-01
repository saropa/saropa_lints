# BUG: `require_text_editing_controller_dispose` — false positive when dispose() uses a cascade (`..dispose()`)

**Status: Fixed**

Created: 2026-07-30
Rule: `require_text_editing_controller_dispose`
File: `lib/src/rules/architecture/disposal_rules.dart` (line ~592)
Severity: False positive
Rule version: v3

---

## Summary

The rule reports a `TextEditingController` field as undisposed even though the owning `State.dispose()` disposes it — via a cascade (`_controller..removeListener(x)..dispose();`). The disposal detection only recognizes a plain `_controller.dispose()` method invocation, not a cascaded `..dispose()` section.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_text_editing_controller_dispose'" lib/src/rules/
# lib/src/rules/architecture/disposal_rules.dart:592:    'require_text_editing_controller_dispose',
```

**Emitter registration:** `lib/src/rules/architecture/disposal_rules.dart:592`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints` (via `dart run saropa_lints scan`)

---

## Reproducer

```dart
class _SheetState extends State<Sheet> {
  final TextEditingController _searchController = TextEditingController(); // LINT — but should NOT lint

  void _onSearchChanged() {}

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose(); // disposal IS here, as a cascade section
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(controller: _searchController);
}
```

**Frequency:** Always, when disposal is expressed as a `CascadeExpression` section rather than a standalone `MethodInvocation`.

Real-world trigger: `d:\src\contacts\lib\components\main_layout\grid_menu\grid_menu_launcher_sheet.dart:32` (field), disposed at lines 45-47 via cascade. Reported as ERROR by `dart run saropa_lints scan . --files ... --format json` on 2026-07-30. Worked around downstream by rewriting the cascade into two plain statements.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the controller is disposed in `dispose()` |
| **Actual** | `[require_text_editing_controller_dispose] ... fails to dispose ...` ERROR at the field declaration (line 32, col 31) |

---

## AST Context

```
MethodDeclaration (dispose)
  └─ Block
      └─ ExpressionStatement
          └─ CascadeExpression (target: SimpleIdentifier `_searchController`)
              ├─ MethodInvocation section (..removeListener(_onSearchChanged))
              └─ MethodInvocation section (..dispose())   ← disposal lives here
```

The disposal scan presumably walks `dispose()` looking for `MethodInvocation` nodes whose `target` is the field identifier and whose `methodName` is `dispose`. In a cascade, each section's `target` is null (the cascade target is on the enclosing `CascadeExpression`), so the match fails.

---

## Root Cause

### Hypothesis A: disposal detection matches `MethodInvocation.target` only

The check requires `invocation.target` (or `realTarget`) to resolve to the field. Cascade sections have `null` `target`; `realTarget` resolves to the `CascadeExpression`'s target expression, which the rule may not handle. Check the visitor in `disposal_rules.dart` for how the invocation target is matched.

---

## Suggested Fix

When scanning `dispose()` for disposal calls, treat a `MethodInvocation` that is a cascade section as targeting the enclosing `CascadeExpression.target`. `invocation.realTarget` already does this in the analyzer API — prefer `realTarget` over `target` when resolving which field a `.dispose()` call belongs to.

---

## Fixture Gap

The fixture for this rule should include:

1. **Cascaded disposal** — `_controller..removeListener(f)..dispose();` in `dispose()` — expect NO lint
2. **Cascade without dispose** — `_controller..removeListener(f);` only — expect LINT
3. **Plain disposal (existing)** — `_controller.dispose();` — expect NO lint

---

## Changes Made

1. **`lib/src/target_matcher_utils.dart`** — `_fieldCleanedUpPattern` regex now matches `..` (cascade) in addition to `.` and `?.`. This fixes `isFieldCleanedUp` and `isFieldCleanedUpInSource` for all callers (20+ disposal/cleanup rules).
2. **`lib/src/rules/architecture/disposal_rules.dart`** — `_disposeCallOnReceiver` regex now matches `..` cascade syntax. This fixes `_isFieldDisposed` used by `require_text_editing_controller_dispose`, `require_page_controller_dispose`, and other controller disposal rules that use the local helper path.
3. **`example/lib/disposal/require_text_editing_controller_dispose_fixture.dart`** — replaced stub fixture with real test cases: BAD (no dispose), BAD (cascade without dispose), GOOD (plain dispose), GOOD (cascade with dispose), GOOD (null-aware dispose).

---

## Tests Added

- `test/utils/target_matcher_utils_test.dart` — 6 tests for `isFieldCleanedUpInSource` covering plain dot, null-aware, cascade, cascade-without-target-method, cascade-close, and wrong-field-name cases.
- `example/lib/disposal/require_text_editing_controller_dispose_fixture.dart` — 5 fixture classes (2 BAD, 3 GOOD) including cascade patterns.

---

## Commits

<!-- Add commit hashes as fixes land. -->

---

## Environment

- saropa_lints version: per `d:\src\contacts` pubspec pin as of 2026-07-30
- Dart SDK version: Flutter stable toolchain in use by `d:\src\contacts`
- Triggering project/file: `d:\src\contacts\lib\components\main_layout\grid_menu\grid_menu_launcher_sheet.dart:32`
