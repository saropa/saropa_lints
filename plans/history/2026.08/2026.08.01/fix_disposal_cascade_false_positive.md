# Fix: Disposal rules false positive on cascade syntax

All disposal and cleanup rules (`require_text_editing_controller_dispose`, `require_page_controller_dispose`, stream/timer cancel rules, and others using `isFieldCleanedUp`) failed to recognize cascade-style cleanup calls (`_field..removeListener(f)..dispose()`), reporting a false positive. The root cause was two independent regex patterns that only matched direct (`.`) and null-aware (`?.`) method calls, not cascade (`..`) sections.

## Finish Report (2026-08-01)

### Root Cause

Two regex-based disposal-detection functions — `_fieldCleanedUpPattern` in `lib/src/target_matcher_utils.dart` (shared by 20+ rules) and `_disposeCallOnReceiver` in `lib/src/rules/architecture/disposal_rules.dart` (used by controller disposal rules) — required the field name to be immediately followed by `.` or `?.` and then the cleanup method name. In a multi-section cascade like `_ctrl..removeListener(f)..dispose()`, the `dispose` section is separated from the field name by intervening sections, so neither regex matched.

### Fix

Two-layer approach:

1. **AST-based cascade detection (primary)** — `hasCascadeCleanup` / `hasCascadeCleanupWhere` in `target_matcher_utils.dart` walks the `FunctionBody` AST, finds `CascadeExpression` nodes whose target matches the field name, and checks whether any `cascadeSections` entry is a `MethodInvocation` matching the cleanup method. This handles arbitrary cascade depth and closures with semicolons — no regex edge cases.

2. **Regex fallback (for string-only callers)** — `isFieldCleanedUpInSource` and `_disposeCallOnReceiver` use a two-alternative regex: direct call (`field.method(` / `field?.method(`) and cascade call (`field\.\.(anything-except-semicolons\.\.)*method\(`). The `[^;]` boundary guard prevents cross-statement false suppressions but can't handle closures with semicolons inside cascade sections.

`isFieldCleanedUp` (AST body available) uses the AST path. `isFieldCleanedUpInSource` (string only) falls back to regex. `_isFieldDisposed` in disposal_rules.dart uses both: regex for direct/alias calls, AST for cascade detection when the body node is available.

### Files Changed

| File | Change |
|---|---|
| `lib/src/target_matcher_utils.dart` | Added `hasCascadeCleanup` / `hasCascadeCleanupWhere` (AST-based), `_CascadeCleanupVisitor`; split `_fieldCleanedUpPattern` into `_directCallPattern` (for `isFieldCleanedUp`) and `_fieldCleanedUpInSourcePattern` (regex cascade fallback for `isFieldCleanedUpInSource`) |
| `lib/src/rules/architecture/disposal_rules.dart` | Added `_getDisposeBodyNode`, `_isDisposeName`; `_isFieldDisposed` accepts optional `bodyNode` for AST cascade detection; `_reportUndisposedFields` extracts and threads body node; `_disposeCallOnReceiver` regex updated with cascade alternative |
| `example/lib/disposal/require_text_editing_controller_dispose_fixture.dart` | Replaced stub with 5 real fixture classes: 2 BAD (no dispose, cascade without dispose), 3 GOOD (plain, cascade with dispose, null-aware) |
| `test/utils/target_matcher_utils_test.dart` | New: 9 tests covering plain, null-aware, single/multi/triple cascade, cascade-without-target, wrong field, cross-statement boundary |
| `CHANGELOG.md` | Entry under `[Unreleased] > Fixed` |

### Scope of Impact

The `isFieldCleanedUp` fix propagates to all 20+ callers across `disposal_rules.dart`, `bloc_rules.dart`, `animation_rules.dart`, `state_management_rules.dart`, `image_rules.dart`, `resource_management_rules.dart`, `drift_rules.dart`, `isar_rules.dart`, `speech_to_text_rules.dart`, and `getx_rules.dart`. The `_isFieldDisposed` AST enhancement covers `RequireTextEditingControllerDisposeRule`, `RequirePageControllerDisposeRule`, and other controller-specific rules using the `_reportUndisposedFields` helper.

### Remaining Limitation

`isFieldCleanedUpInSource` (string-only path) still uses regex with `[^;]` boundary guard. Cascades containing closures with semicolons (e.g., `_ctrl..addListener(() { doSomething(); })..dispose()`) are not handled by this path. The AST-based `isFieldCleanedUp` path has no such limitation. Callers using `isFieldCleanedUpInSource` should prefer the AST variant when a `FunctionBody` is available.
