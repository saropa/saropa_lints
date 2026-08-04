# avoid_datetime_constructor — new lint rule

The `DateTime()` and `DateTime.utc()` constructors silently roll over out-of-range values (month 13 becomes January of the following year) with no error, warning, or exception. This makes it impossible to detect invalid date components at the call site when arguments come from variables.

## Finish Report (2026-08-04)

### What changed

A new WARNING-severity lint rule `avoid_datetime_constructor` was added to flag direct `DateTime()` and `DateTime.utc()` constructor calls that could silently roll over invalid date components.

**Detection**: `addInstanceCreationExpression` callback checks `constructorName.type.name.lexeme == 'DateTime'` and allows only the unnamed and `utc` named constructors through. Other named constructors (`fromMillisecondsSinceEpoch`, `fromMicrosecondsSinceEpoch`) are skipped. `DateTime.now()`, `.parse()`, `.tryParse()` are static methods, not constructors, so they never reach the callback.

**False-positive mitigation**: An `_allLiteralsInRange` allowlist skips calls where every argument is an `IntegerLiteral` within valid ranges (month 1-12, day 0-31, hour 0-23, minute/second 0-59, ms/us 0-999). Day 0 is allowed because `DateTime(year, month, 0)` is a documented Dart idiom for "last day of previous month." Day upper bound is 31 (not calendar-aware — `DateTime(2026, 2, 31)` passes the allowlist). Negative integer literals are `PrefixExpression` nodes, not `IntegerLiteral`, so they are correctly flagged.

**Quick fix**: `ReplaceDateTimeConstructorFix` converts `DateTime(y, m, d)` to `DateTime.tryParse('$y-$m-$d')`, building an ISO 8601 interpolated string from the constructor arguments. Handles optional time components and appends `Z` for `DateTime.utc()` calls. Smoke-tested in `test/scan/fix_application_smoke_test.dart`.

**Registration**: factory reference in `_allRuleFactories` (lib/saropa_lints.dart), rule name in `recommendedOnlyRules` (lib/src/tiers.dart), class in `lib/src/rules/data/json_datetime_rules.dart`.

**Tests**: instantiation pin added to `test/rules/data/json_datetime_rules_test.dart`. Fix smoke test added to `test/scan/fix_application_smoke_test.dart`. Integrity test (24 tests) and anti-pattern detection test both pass. Rule count comment updated from 13 to 14.

**Fixture**: `example/lib/json_datetime/avoid_datetime_constructor_fixture.dart` — 10 BAD cases (variable args, mixed, out-of-range literals including negative and 60-minute) and 9 GOOD near-miss cases (in-range literals, day-0 idiom, year-only, tryParse, parse, now, fromMillisecondsSinceEpoch, fromMicrosecondsSinceEpoch).

### Files changed

- `lib/src/rules/data/json_datetime_rules.dart` — new `AvoidDateTimeConstructorRule` class with `fixGenerators`
- `lib/src/fixes/json_datetime/replace_datetime_constructor_fix.dart` — new quick fix
- `lib/saropa_lints.dart` — factory registration
- `lib/src/tiers.dart` — tier assignment (recommendedOnlyRules)
- `test/rules/data/json_datetime_rules_test.dart` — instantiation pin, count update
- `test/scan/fix_application_smoke_test.dart` — fix smoke test entry
- `example/lib/json_datetime/avoid_datetime_constructor_fixture.dart` — new fixture
- `CHANGELOG.md` — entry under [14.4.0]
- `bugs/BUG_REPORT_GUIDE.md` — reference repointed

### Known limitations

- Day upper bound is 31, not calendar-aware: `DateTime(2026, 2, 31)` passes the allowlist despite February never having 31 days. Adding month+leap-year logic would add complexity disproportionate to the benefit.
- The quick fix produces `DateTime.tryParse(...)` which returns `DateTime?` — callers need null handling. The fix does not insert null checks.
- Millisecond and microsecond arguments are not included in the ISO 8601 string produced by the fix (ISO 8601 supports fractional seconds but the interpolation would be complex).

### Closes bug

`plans/history/2026.08/2026.08.04/feature_lint_rule_avoid_datetime_constructor.md`
