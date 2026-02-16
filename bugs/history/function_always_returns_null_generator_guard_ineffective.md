# Bug: `function_always_returns_null` Generator Guard Not Working

## Status

**RESOLVED** — Added return-type guard (`Stream`/`Iterable`) as belt-and-suspenders
in `_checkFunctionBody` (code_quality_rules.dart). The existing `body.isGenerator` /
`body.star` guards remain; the new guard catches generators even when those fail to
resolve correctly in some analyzer versions. Test fixture updated with nullable
`Stream?` and extension method generator cases.

## Summary

The `function_always_returns_null` rule fires on `sync*` and `async*` generator
functions/methods despite a generator guard already being present in the source
code (lines 3230-3234 of `code_quality_rules.dart`). The guard was added in
response to two previous bug reports (see `bugs/history/`) but the rule
continues to produce false positives in the consuming project.

Generator functions emit values via `yield` — a bare `return;` ends the
iterable/stream, it does not return null. The concept of "always returns null"
is semantically meaningless for generators.

---

## Diagnostic Output

All instances produce the same diagnostic:

```json
{
  "code": "function_always_returns_null",
  "severity": 4,
  "message": "[function_always_returns_null] Function returns null on every code path, making the return type effectively void. Callers that check or use the return value are performing dead logic, and the nullable return type misleads developers into thinking the function can return meaningful data. {v6}\nChange the return type to void if the function is purely side-effecting, or add meaningful return values for different code paths to make the function useful to callers.",
  "source": "dart"
}
```

---

## Affected Files (All False Positives)

### 1. `sync*` class method — `PublicHolidayCN._goldenWeek`

**File:** `lib/data/public_holiday/countries/c/public_holiday_cn.dart`, line 57

```dart
static Iterable<PublicHolidayModel> _goldenWeek({required DateTimeRange? range}) sync* {
  if (range == null) return;                             // ends iterable

  for (final MapEntry<int, DateTimeRange> entry in _goldenWeekMap.entries) {
    final int year = entry.key;
    final DateTimeRange goldenRange = entry.value;

    if (goldenRange.start.isAfter(range.end)) return;    // early exit
    if (goldenRange.end.isBefore(range.start)) continue;

    // ... builds and yields PublicHolidayModel ...
    yield PublicHolidayModel(...);
  }
}
```

The function yields `PublicHolidayModel` values and uses `return;` to end
iteration when input is null or when the range boundary is passed. It never
returns null.

### 2. `async*` extension method — `watchActivitySafe`

**File:** `lib/database/isar_middleware/user_data/activity_io.dart`, line 156

```dart
Stream<List<ActivityDBModel>>? watchActivitySafe() async* {
  try {
    if (isEmpty) {
      return;                                            // ends stream
    }

    final Query<ActivityDBModel>? query = build();
    if (query == null) {
      return;                                            // ends stream
    }

    yield await query.findAll();                         // yields data
    yield* query.watch(fireImmediately: false);          // delegates stream
  } on Object catch (error, stack) {
    debugException(error, stack);
  }
}
```

The function yields query results and delegates to a watch stream. The `return;`
statements end the stream on guard clause failures. It never returns null.

### 3. `async*` override methods — Search providers

**File:** `lib/service/app_search/providers/emergency_tip_search_provider.dart`, line 23
**File:** `lib/service/app_search/providers/family_groups_search_provider.dart`, line 29

```dart
@override
Stream<List<AppSearchResultModel>> search(String query, {bool isFuzzySearch = true}) async* {
  final List<EmergencyTipDBModel>? allTips =
      await DatabaseEmergencyTipIO.dbLoadEmergencyTipList();

  if (allTips == null || allTips.isEmpty) {
    yield <AppSearchResultModel>[];
    return;                                              // ends stream
  }

  // ... builds and yields results ...
  yield results;
}
```

Standard search provider pattern: load data, yield empty list on no data and
end stream, otherwise score/filter and yield results. Multiple sibling providers
follow the identical pattern (mental model, born on this day, medical conditions,
superhero DC, etc.) and will all be affected.

---

## Root Cause: Guard Exists but Is Not Effective

### The existing guard (lines 3230-3234)

```dart
void _checkFunctionBody(
  FunctionBody body,
  TypeAnnotation? returnType,
  Token nameToken,
  SaropaDiagnosticReporter reporter,
) {
  // Skip generators — they emit values via yield, not return.
  // A bare `return;` in async*/sync* ends the stream/iterable,
  // it does not "return null".
  if (body.isGenerator) return;                          // LINE 3233
  if (body is BlockFunctionBody && body.star != null) return;  // LINE 3234

  // ... rest of analysis ...
}
```

Both `body.isGenerator` (line 3233) and the fallback `body.star != null` check
(line 3234) should catch all generator functions. Yet the rule continues to fire
on generators in practice.

### Caching ruled out

Running `dart run custom_lint` in the saropa_lints directory confirms:

```
[custom_lint client] [saropa_lints] createPlugin() called - version 4.14.5
[saropa_lints] Output: both — Problems tab capped at 500, all issues in report log.
[custom_lint client] [saropa_lints] Loaded 328 rules (tier: custom, enableAll: false)
```

Version 4.14.5 is loaded with the fix present in the source. **This is not a
caching issue.** The guard code is being compiled and loaded, but still not
catching generators.

### Remaining explanations

1. **`body.isGenerator` returning false unexpectedly**: In some analyzer
   versions or AST states, `FunctionBody.isGenerator` may not resolve correctly
   for method declarations vs function declarations. The base class
   `FunctionBody.isGenerator` returns `false`; only `BlockFunctionBody`
   overrides it to check `star != null`. If the runtime type isn't
   `BlockFunctionBody` (edge case), both guards fail.

2. **Visitor ordering**: If `addMethodDeclaration` fires before the AST is
   fully resolved, `body.isGenerator` and `body.star` may not yet reflect the
   `async*`/`sync*` modifier.

3. **Multiple rule instances**: If the rule class is instantiated more than
   once (e.g., by different custom_lint entry points), one instance may have
   the fix while another doesn't.

### How to diagnose

Add temporary debug logging to `_checkFunctionBody`:

```dart
void _checkFunctionBody(
  FunctionBody body,
  TypeAnnotation? returnType,
  Token nameToken,
  SaropaDiagnosticReporter reporter,
) {
  // TEMPORARY DEBUG — remove after diagnosis
  if (body is BlockFunctionBody) {
    print('[DEBUG function_always_returns_null] '
        'name=${nameToken.lexeme} '
        'isGenerator=${body.isGenerator} '
        'star=${body.star} '
        'keyword=${body.keyword} '
        'runtimeType=${body.runtimeType}');
  }

  if (body.isGenerator) return;
  if (body is BlockFunctionBody && body.star != null) return;
  // ...
}
```

Then restart the analyzer (`custom_lint restart` or IDE restart) and check
the output for the affected methods. This will reveal whether:
- The guard is being reached but `isGenerator`/`star` is false (analyzer bug)
- The guard is never being reached (wrong code path / cached old version)
- The guard works but something fires _after_ it (duplicate rule instance)

---

## Test Fixture Coverage

The test fixture at
`example_core/lib/code_quality/function_always_returns_null_fixture.dart`
already includes generator cases (lines 110-183) covering:

- Top-level `async*` with early exit (line 114)
- Top-level `sync*` with early exit (line 124)
- Top-level `async*` with no return (line 132)
- Top-level `sync*` with multiple exits (line 138)
- Class method `async*` override (line 157)
- Class method `async*` generator (line 168)
- Class method `sync*` generator (line 178)

**None of these have `// expect_lint:` annotations**, meaning the test framework
expects the rule to NOT fire on them. If the tests pass, the fix works in the
test environment but not in the IDE environment — confirming a caching or
compilation issue.

---

## Patterns That Trigger the False Positive

| Pattern | Generator? | Has `return;`? | Fires? | Should Fire? |
|---|---|---|---|---|
| `sync*` class method with `return;` | Yes | Yes | **Yes** | **No** |
| `async*` class method with `return;` | Yes | Yes | **Yes** | **No** |
| `async*` override method with `return;` | Yes | Yes | **Yes** | **No** |
| `async*` extension method with `return;` | Yes | Yes | **Yes** | **No** |
| `String? foo() { return null; }` | No | N/A | Yes | **Yes** |
| `int? bar() => null;` | No | N/A | Yes | **Yes** |

---

## Relationship to Previous Bug Reports

This is the **same root issue** as both previous reports:

- `bugs/history/function_always_returns_null_false_positive_async_generator.md`
- `bugs/history/function_always_returns_null_false_positive_async_generator_method.md`

The fix was implemented (lines 3230-3234) and test fixtures were added, but the
rule continues to fire in the consuming project (`d:\src\contacts`), which uses
saropa_lints via path dependency (`path: ../saropa_lints`).

---

## Suggested Next Steps

1. **Verify the fix is compiled**: Clear the custom_lint plugin cache and
   restart the analyzer. If the false positives disappear, the issue is purely
   a caching problem and should be documented as a "restart required after
   updating path dependencies" note.

2. **If the fix is compiled but still fires**: Add the debug logging described
   above to determine why `body.isGenerator` returns false for these specific
   AST nodes. This would indicate an analyzer version compatibility issue.

3. **Add a return-type guard as belt-and-suspenders**: As suggested in the
   previous report, also check the return type:

   ```dart
   // Additional guard: generator return types
   if (returnType is NamedType) {
     final String name = returnType.name2.lexeme;
     if (name == 'Stream' || name == 'Iterable') return;
   }
   ```

   This catches generators even if `body.isGenerator` fails, and a non-generator
   function returning `Stream?` that always returns null is an unlikely enough
   edge case to accept the trade-off.

4. **Consider an integration test**: The current test fixture relies on
   custom_lint's `// expect_lint:` mechanism. Add a test that runs analysis on
   a real project (or a fixture project with `analysis_options.yaml`) and
   asserts zero unexpected diagnostics, to catch caching-related regressions.

---

## Current Workaround

Suppress per-method:

```dart
// ignore: function_always_returns_null
Stream<List<AppSearchResultModel>> search(String query) async* {
```

This suppresses the rule entirely for that method, losing coverage for genuine
always-null returns in the same function.

---

## Environment

- **saropa_lints version**: 4.14.5 (path dependency from `d:\src\saropa_lints`)
- **custom_lint**: ^0.8.0
- **Consuming project**: `d:\src\contacts` (Flutter app)
- **Rule file**: `lib/src/rules/code_quality_rules.dart`, lines 3188-3269
- **Guard location**: lines 3230-3234
- **Test fixture**: `example_core/lib/code_quality/function_always_returns_null_fixture.dart`

## Priority

**High** — Multiple files affected across search providers, database watchers,
and data utilities. Every generator with an early-exit `return;` produces noise,
eroding developer trust in the rule. The fix is already written but not
functioning, making this a P1 for investigation.
