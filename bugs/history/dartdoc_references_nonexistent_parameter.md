# Bug: Dartdoc `[paramName]` references parameters not in function signature

**Rule:** NEW — no existing rule covers this
**Related Rule:** `require_parameter_documentation` (checks the inverse direction only)
**File:** `lib/src/rules/documentation_rules.dart`
**Severity:** Correctness / misleading documentation
**Status:** OPEN
**Version:** saropa_lints 4.10.0

---

## Summary

There is no lint rule that detects when a dartdoc comment references a parameter name via `[paramName]` that does **not actually exist** in the function, method, or constructor signature. The existing `require_parameter_documentation` rule only checks the **inverse** — that real parameters are documented — but never validates that documented parameters actually exist.

This means stale, renamed, or copy-pasted parameter documentation silently persists and misleads readers.

---

## Root Cause

The `require_parameter_documentation` rule iterates over the **actual parameters** and checks whether each one appears as `[paramName]` in the doc comment. It never iterates over the **`[bracketedNames]` in the doc comment** to verify they correspond to real parameters.

```dart
// Current logic (simplified from RequireParameterDocumentationRule):
for (final FormalParameter param in params.parameters) {
  final String? paramName = _getParameterName(param);
  if (!docText.contains('[$paramName]')) {
    reporter.atNode(param, code);  // "param X is undocumented"
  }
}
// ^^^ Only checks: real param → doc
// Missing check: doc → real param
```

There is no reverse pass that extracts `[bracketedNames]` from the doc comment and verifies each one exists in the parameter list.

---

## Concrete Examples

### Example 1: `fileRestore` — ghost `[context]` parameter

**File:** `lib/components/user/backup_restore/icons/file_restore_icon.dart:43-44`

```dart
/// - [context] for the toast
Future<bool> fileRestore(String filePath) async {
```

**Problem:** `[context]` is documented but the function only has `filePath`. The `context` parameter was likely removed during a refactor but the doc comment was never updated.

---

### Example 2: `calculateLifePathNumber` — type name instead of parameter name

**File:** `lib/utils/event/spirituality/life_path_number_utils.dart:16-20`

```dart
/// Calculates the Life Path Number for the given [DateTime].
///
/// - [DateTime] parameter must be a valid date in the format `mm/dd/yyyy`.
///
/// Throws a [FormatException] if the [DateTime] parameter is not in the correct format.
static LifePathNumbers? calculateLifePathNumber(DateTime? date) {
```

**Problem:** `[DateTime]` is the type, not the parameter name. The actual parameter is `date`. A reader looking for the `DateTime` parameter in the signature won't find one by that name. Note: `[FormatException]` is a valid type reference and should NOT be flagged — this rule must distinguish parameter-style references (`/// - [name]`) from type references.

---

### Example 3: `getRandomButtonTypeIcons` — type name instead of parameter name

**File:** `lib/components/games/matrix_slider_game/game_button_type.dart:206-213`

```dart
/// This function takes a [MatrixGameButtonTypes] enum value and a [maxLimit]
/// parameter as arguments and returns a random list of [IconData] objects
/// from the [matrixGameButtonTypesIcons] map.
///
/// The length of the returned list is determined by the [maxLimit] parameter.
///
/// - [seed] Using a fixed seed value when creating our random object to the
///       generate a list of numbers will be the same every time we run this code.
///
List<IconData>? getRandomButtonTypeIcons(
  MatrixGameButtonTypes type,
  final int maxLimit, {
  int? seed,
}) {
```

**Problem:** The first parameter `type` is documented as `[MatrixGameButtonTypes]` (the type name). `[maxLimit]` and `[seed]` are correct. `[IconData]` and `[matrixGameButtonTypesIcons]` are type/field references and should not be flagged.

---

### Example 4: `DoubleSequenceDropList` — duplicate parameter docs

**File:** `lib/components/primitive/number_drop_list/double_sequence_drop_list.dart:10-17`

```dart
/// - [maxValue] parameter must be greater than or equal to [minValue] and is required.
/// - [textStyle] parameter can be used to specify the text style of the items in the dropdown list.
/// - [defaultSelection] parameter can be used to specify the initial value to be selected in the dropdown list.
/// - [textStyle] parameter can be used to specify the text style of the items in the dropdown list.
/// - [increment] parameter specifies the increment between values in the dropdown list and has a default value of 1.
/// - [minValue] parameter specifies the minimum value in the dropdown list and has a default value of 1.
/// - [decimalPlaces] parameter specifies the number of decimal places to format the values in the dropdown list and has a default value of 2.
```

**Problem:** `[textStyle]` is documented twice (lines 11 and 13, identical text). While both references resolve to a real parameter, the duplication suggests copy-paste error. This is a secondary issue the rule could optionally flag.

---

### Example 5: `MapIcon` — external package parameters in local docs

**File:** `lib/components/contact/detail_panels/country/map_icon.dart:129-147`

```dart
/// - [exclude] argument can be used to exclude(remove) one ore more
/// country from the countries list. It takes a list of country code(iso2).
///
/// - [countryFilter] argument can be used to filter the
/// list of countries. It takes a list of country code(iso2).
/// Note: Can't provide both [countryFilter] and [exclude]
///
/// - [favorite] argument can be used to show countries
/// at the top of the list. It takes a list of country code(iso2).
///
/// - [showSearch] argument can be used to show/hide the search bar.
```

**Problem:** `[exclude]`, `[countryFilter]`, `[favorite]`, and `[showSearch]` are parameters of an external package widget (CountryPicker), not of the local function. The doc comment misleads readers into thinking these are parameters of the local method.

---

## Why This Matters

### 1. Stale docs are worse than no docs

A developer reading `/// - [context] for the toast` on `fileRestore(String filePath)` will waste time looking for a `context` parameter that doesn't exist. They may assume the function needs to be called with a context and wonder why the signature doesn't include it.

### 2. Refactoring leaves ghost parameters

When parameters are renamed or removed, IDEs update call sites but **do not update doc comments**. The existing `require_parameter_documentation` rule will catch the new/renamed parameter being undocumented, but won't catch the old parameter name lingering in the docs.

### 3. Copy-paste propagation

Developers copy doc comments from similar methods. If the target method has a different signature, the copied `[paramName]` references silently persist. Example 5 shows this clearly — package documentation was copied into a local method's doc comment.

### 4. Type names masquerading as parameter names

Example 2 shows `[DateTime]` used where `[date]` should be. This passes the existing `require_parameter_documentation` rule (which would flag `date` as undocumented, a separate issue) but the `[DateTime]` reference is misleading because it looks like a parameter reference in context.

---

## Current Behavior (No Lint)

All of these pass without any warning:

```dart
// Ghost parameter — no warning
/// - [context] for the toast
Future<bool> fileRestore(String filePath) async {

// Type name instead of param name — no warning
/// Calculates the Life Path Number for the given [DateTime].
static LifePathNumbers? calculateLifePathNumber(DateTime? date) {

// External package params in local docs — no warning
/// - [exclude] argument can be used to exclude one or more country
void _showCountryPicker(BuildContext context) {
```

---

## Expected Behavior

The linter should warn when a doc comment contains `[name]` where `name`:
1. Is NOT a parameter in the function/method/constructor signature, AND
2. Is NOT a known type, class, enum, or field reference (to avoid false positives)

```dart
// Ghost parameter — WARNING: [context] is not a parameter of fileRestore
/// - [context] for the toast
Future<bool> fileRestore(String filePath) async {

// Type used as param name — WARNING: [DateTime] is a type, not a parameter; did you mean [date]?
/// - [DateTime] parameter must be a valid date
static LifePathNumbers? calculateLifePathNumber(DateTime? date) {

// Valid type reference — no warning (correct)
/// Throws a [FormatException] if invalid
static LifePathNumbers? calculateLifePathNumber(DateTime? date) {
```

---

## Proposed Rule

### Rule Name: `verify_documented_parameters_exist`

**Severity:** WARNING
**Category:** Professional Only (consistent with other documentation rules)
**Impact:** Low
**Cost:** Medium

### Detection Logic

```
1. For each function/method/constructor declaration with a doc comment:
   a. Extract all `[bracketedName]` references from the doc comment
   b. Build a set of actual parameter names from the signature
   c. For each `[bracketedName]`:
      - If bracketedName is in the parameter set → OK
      - If bracketedName matches a known type/class in scope → OK (type reference, skip)
      - If bracketedName matches a field/property of the enclosing class → OK (field reference, skip)
      - Otherwise → FLAG as warning
```

### Distinguishing Parameter References from Type References

This is the hardest part. Heuristics to reduce false positives:

| Pattern | Classification | Action |
|---------|---------------|--------|
| `/// - [name]` (bullet-style param doc) | Very likely parameter reference | Flag if not in params |
| `/// [Name]` where Name starts uppercase | Likely type reference | Skip (e.g., `[FormatException]`) |
| `/// [name]` where name starts lowercase | Ambiguous — could be param or field | Flag if not in params AND not a class field |
| `/// [name] parameter` (word "parameter" follows) | Definitely parameter reference | Flag if not in params |
| `/// [name] argument` (word "argument" follows) | Definitely parameter reference | Flag if not in params |
| `/// returns a [Name]` | Type reference | Skip |
| `/// throws a [Name]` | Type reference | Skip |

### Contextual Keywords That Confirm Parameter Intent

If the word immediately following `[name]` is one of these, treat it as a parameter reference regardless of casing:

- `parameter`, `param`, `argument`, `arg`
- `is required`, `is optional`, `must be`, `must not be`
- `specifies`, `determines`, `controls`, `sets`, `defines`
- `can be used to`, `defaults to`

### Quick Fix

**Primary fix:** Remove the stale parameter documentation line.

**Secondary fix (for type-as-param-name):** Replace `[TypeName]` with `[actualParamName]` when a parameter of that type exists. E.g., replace `[DateTime]` with `[date]` when `DateTime? date` is in the signature.

---

## Relationship to Existing Rules

| Rule | Direction | What it checks |
|------|-----------|----------------|
| `require_parameter_documentation` | Signature → Docs | "Parameter X exists but is not documented" |
| **`verify_documented_parameters_exist`** (NEW) | Docs → Signature | "Doc references [X] but X is not a parameter" |

These are complementary — together they ensure a bidirectional match between documentation and signature.

---

## Edge Cases

### 1. Constructor field parameters (`this.name`)
The `_getParameterName` helper already handles `FieldFormalParameter`. The new rule should reuse this helper to extract parameter names from `this.name` syntax.

### 2. Super parameters (`super.key`)
`super.key` is a valid parameter but unlikely to be documented. The rule should include `super.*` parameters in the valid set but not require their documentation.

### 3. Inherited/overridden methods
When overriding a method, docs may reference parameters by the parent's naming. The rule should use the actual override's parameter names, not the parent's.

### 4. Generic type parameters
`[T]`, `[E]`, `[K]`, `[V]` etc. are type parameter references, not function parameters. The rule should recognise single-uppercase-letter bracketed names as type parameters and skip them.

### 5. Enum values and constants
`[BackupOptionEnum.contact]` or `[ThemeCommonIcon.BackupRestore]` — dotted references are field/enum accesses, not parameter references. Skip anything containing a dot.

### 6. Properties and getters
Class-level doc comments may reference properties like `[filePath]` that are fields, not constructor parameters. The rule should include class fields in the "valid" set when checking constructor/class-level docs.

---

## Test Cases

| # | Scenario | Expected |
|---|----------|----------|
| 1 | `/// [context]` on method without `context` param | WARNING |
| 2 | `/// [filePath]` on method with `filePath` param | No warning |
| 3 | `/// [FormatException]` (uppercase, known type) | No warning |
| 4 | `/// [DateTime]` used as parameter doc (`/// - [DateTime] param`) | WARNING (type used as param name) |
| 5 | `/// [T]` single-letter type parameter | No warning |
| 6 | `/// [BackupOptionEnum.contact]` dotted reference | No warning |
| 7 | `/// - [name] parameter` where `name` not in params | WARNING |
| 8 | `/// returns a [Widget]` type reference | No warning |
| 9 | `/// throws a [StateError]` type reference | No warning |
| 10 | `/// [filePath]` on class with `this.filePath` field | No warning |
| 11 | `/// [textStyle]` documented twice, param exists | Optional INFO (duplicate) |
| 12 | `/// [exclude]` from external package, not local param | WARNING |
| 13 | `/// [super.key]` or `[key]` with `super.key` in constructor | No warning |
| 14 | Empty doc comment, no bracketed names | No warning (nothing to check) |
| 15 | `/// [callback]` on method with `VoidCallback? callback` | No warning |

---

## Impact on Existing Codebases

In the `contacts` project (`d:\src\contacts`), a preliminary scan found **5+ files** with ghost parameter references. The rule would surface these as warnings, prompting developers to clean up stale documentation. No working code would be affected — only doc comments.

---

## References

- Existing rule implementation: `lib/src/rules/documentation_rules.dart`
- `RequireParameterDocumentationRule` (lines ~480-570) — inverse check, reusable `_getParameterName` helper
- Rule registration: `lib/src/rules/all_rules.dart` (line 26)
- Tier classification: `lib/src/tiers.dart` — `professionalOnlyRules`
- Consumer codebase example: `d:\src\contacts\lib\components\user\backup_restore\icons\file_restore_icon.dart:43-44`
