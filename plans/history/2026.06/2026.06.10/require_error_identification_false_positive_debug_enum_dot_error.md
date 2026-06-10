# BUG: `require_error_identification` — Fires on a non-color enum/label ternary (`DebugLevels.Error`)

**Status: Fixed**

Created: 2026-06-10
Rule: `require_error_identification`
File: `lib/src/rules/ui/accessibility_rules.dart` (line ~2025)
Severity: False positive
Rule version: v2

---

## Summary

The rule is meant to catch "error state conveyed by COLOR alone" (`condition ? Colors.red : ...`). Its color detector is the regex `\.error\b` (case-insensitive), which matches the enum value `DebugLevels.Error` and even the string literal `'[Error]'`. So a debug-log ternary that selects a **severity enum / text label** — no color anywhere — is flagged as a color-only error indicator.

---

## Attribution Evidence

```bash
# Positive — rule IS defined here
grep -rn "'require_error_identification'" lib/src/rules/
# lib/src/rules/ui/accessibility_rules.dart:1999:    'require_error_identification',

# Negative — NOT in sibling repo
grep -rn "'require_error_identification'" ../saropa_drift_advisor/lib/
# 0 matches
```

**Emitter registration:** `lib/src/rules/ui/accessibility_rules.dart:1999`
**Rule class:** `RequireErrorIdentificationRule`
**Diagnostic `source` / `owner`:** `dart` / `_generated_diagnostic_collection_name_#5`

---

## Reproducer

```dart
enum DebugLevels { Warning, Error }

void log(String? title, String? text, Object? error) {
  // LINT (false positive): this is a debug-log severity selection, not a UI
  // color. `error == null` puts "error" in the condition; `DebugLevels.Error`
  // matches the \.error\b color regex — but no color is involved at all.
  debug(
    '$title: $text',
    level: error == null ? DebugLevels.Warning : DebugLevels.Error,
  );
}
```

Real site: `D:\src\contacts\lib\components\primitive\error\common_error_section.dart:49`
`level: error == null ? DebugLevels.Warning : DebugLevels.Error,` — and the
surrounding widget already renders a `CommonErrorIcon` plus a `'[Error]'` text
label, i.e. non-color cues exist; the flagged node is purely a log-level enum.

**Frequency:** Always, when a ternary's condition mentions "error"/"invalid" and either branch references any identifier ending in `.error` / `.Error` (enum value, getter, field), with no `Icon(`/`errorText`/`helperText` in the nearest 10 ancestors.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — no color is used; the branches are enum values / text labels. |
| **Actual** | `[require_error_identification] Error or alert states are indicated only by color...` reported at the `ConditionalExpression`. |

---

## AST Context

```
MethodInvocation (debug)
  └─ ArgumentList
      └─ NamedExpression (level:)
          └─ ConditionalExpression          ← node reported here
              ├─ condition: BinaryExpression (error == null)   contains "error"
              ├─ then:  PrefixedIdentifier (DebugLevels.Warning)
              └─ else:  PrefixedIdentifier (DebugLevels.Error)  matches \.error\b
```

---

## Root Cause

`accessibility_rules.dart:2006-2046`:

```dart
static final RegExp _errorColorPattern = RegExp(
  r'colors\.red|\.red\b|\.error\b|errorcolor|redaccent',
  caseSensitive: false,
);
...
// condition mentions "error"/"invalid" → passes
if (!_errorColorPattern.hasMatch(thenSource) &&
    !_errorColorPattern.hasMatch(elseSource)) {
  return;
}
```

The "is this an error color?" test includes the alternative `\.error\b`. That matches **any** dotted identifier ending in `error`/`Error`: `DebugLevels.Error`, `LogLevel.error`, `colorScheme.error` (a real color, fine), but also non-color members. The rule then walks up to 10 ancestors looking for a non-color indicator (`Icon(`, `errorText`, `helperText`, or `decoration:` + `error`). In a `debug(...)` call there is none, so it reports.

Two compounding problems:
1. `\.error\b` is far too broad — it treats `<anything>.error`/`.Error` as a color. It should require an actual color context (e.g. `Colors.red`, `colorScheme.error` resolving to a `Color`, `Color(...)`, `*Color` type), not any member named `error`.
2. The rule never confirms either branch is a `Color`-typed expression. `DebugLevels.Error` is an enum value; its static type is not `Color`. A `staticType` check against `Color` on the then/else expression would eliminate this class of false positive entirely.

---

## Suggested Fix

In the `addConditionalExpression` body:

- Before treating the ternary as color-only, require at least one branch's `staticType` to be (or assign to) `Color` / `MaterialColor`. Enum values, `String` labels, and `bool` flags should drop out immediately.
- Tighten `_errorColorPattern`: replace the bare `\.error\b` alternative with one that only matches in a color context — e.g. `colorscheme\.error`, `theme\.colorscheme\.error`, `\.errorcolor\b` — and rely on the new `staticType == Color` gate for the general case.

---

## Fixture Gap

`example*/lib/ui/require_error_identification_fixture.dart` should include:

1. `color: hasError ? Colors.red : Colors.green` with no icon/text — expect LINT.
2. `level: error == null ? LogLevel.warning : LogLevel.error` — expect **NO** lint (enum, not Color).
3. `label: isError ? '[Error]' : '[OK]'` — expect **NO** lint (String labels are themselves the non-color cue).
4. `color: hasError ? Colors.red : Colors.green` accompanied by `Icon(Icons.error)` in the same widget — expect **NO** lint (non-color indicator present).

---

## Environment

- saropa_lints version: ^13.12.2
- Dart SDK version: >=3.10.7 <4.0.0
- custom_lint version: native analyzer plugin (analysis_server_plugin), not custom_lint
- Triggering project/file: `D:\src\contacts\lib\components\primitive\error\common_error_section.dart:49`

## Finish Report (2026-06-10)

Fixed in WS-5. Added a mandatory Color-staticType gate after the existing error-color regex: at least one ternary branch must be `Color`-typed (display name `Color` or `*Color`, nullable-aware). A `DebugLevels.Error` enum value or a String label is dropped. Kept the regex as the branch heuristic to avoid regressing `Colors.red` detection. Verified: real site `common_error_section.dart:49` now clean; `Colors.red` ternaries still fire. Fixture extended: `example/lib/accessibility/require_error_identification_fixture.dart`.
