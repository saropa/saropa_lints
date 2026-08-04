# avoid_datetime_constructor — new lint rule pair

The `DateTime()` and `DateTime.utc()` constructors silently roll over out-of-range values (month 13 becomes January of the following year) with no error, warning, or exception. This makes it impossible to detect invalid date components at the call site when arguments come from variables.

## Finish Report (2026-08-04)

### What changed

Two new WARNING-severity lint rules for DateTime constructor safety, plus a quick fix.

#### avoid_datetime_constructor

Flags all `DateTime()` and `DateTime.utc()` constructor calls with variable arguments or out-of-range literals. All-literal in-range calls are allowed via `allLiteralsInRange` (month 1-12, day 0-31, hour 0-23, minute/second 0-59, ms/us 0-999). Day 0 is permitted for the last-day-of-month idiom. Day upper bound is 31 (not calendar-aware). Negative integer literals are `PrefixExpression` nodes, not `IntegerLiteral`, so they are correctly flagged.

#### avoid_datetime_constructor_unvalidated

Companion rule that only fires when the DateTime constructor result is consumed inline — returned directly, passed as a function argument, used in a named expression (widget parameter), assigned to a field, or embedded in a ternary/binary expression — without being assigned to a local variable where post-construction range checks could follow. Uses the same `allLiteralsInRange` allowlist as the parent rule. This is a narrower, higher-confidence rule for teams that find `avoid_datetime_constructor` too broad.

#### Quick fix: ReplaceDateTimeConstructorFix

Converts `DateTime(y, m, d, h, min, sec, ms, us)` to `DateTime.tryParse('$y-$m-$d T$h:$min:$sec.$ms$us')`. Hardened against unsafe interpolation: bails out when any argument is a ternary, await, cascade, string literal, or other expression containing quotes/braces. Handles millisecond/microsecond as ISO 8601 fractional seconds. Appends `Z` for `DateTime.utc()`. Integer literals pass through directly; simple identifiers use `$name`; complex expressions use `${expr}`.

### Detection mechanism

Both rules use `addInstanceCreationExpression` callback, check `constructorName.type.name.lexeme == 'DateTime'`, and filter to unnamed and `utc` named constructors only. `DateTime.now()`, `.parse()`, `.tryParse()` are static methods (not constructors) so they never reach the callback. `fromMillisecondsSinceEpoch` and `fromMicrosecondsSinceEpoch` are named constructors filtered by the guard.

### Registration

Both rules: factory reference in `_allRuleFactories` (lib/saropa_lints.dart), rule name in `recommendedOnlyRules` (lib/src/tiers.dart), class in `lib/src/rules/data/json_datetime_rules.dart`.

### Tests

Instantiation pins for both rules in `test/rules/data/json_datetime_rules_test.dart` (count updated to 15). Fix smoke test entry in `test/scan/fix_application_smoke_test.dart`. Integrity (24), anti-pattern detection, json_datetime rules, and fix smoke tests all pass (70 total).

### Fixtures

- `avoid_datetime_constructor_fixture.dart` — 10 BAD cases, 9 GOOD near-miss cases
- `avoid_datetime_constructor_unvalidated_fixture.dart` — 4 BAD cases (return, argument, named parameter, field initializer), 2 GOOD cases (local variable with validation, all-literal in-range)

### Files changed

- `lib/src/rules/data/json_datetime_rules.dart` — two rule classes, `allLiteralsInRange` made public
- `lib/src/fixes/json_datetime/replace_datetime_constructor_fix.dart` — hardened quick fix with interpolation safety, ms/us support
- `lib/saropa_lints.dart` — factory registration for both rules
- `lib/src/tiers.dart` — tier assignment for both rules
- `test/rules/data/json_datetime_rules_test.dart` — two instantiation pins, count update
- `test/scan/fix_application_smoke_test.dart` — fix smoke test entry
- `example/lib/json_datetime/avoid_datetime_constructor_fixture.dart` — fixture with hardened edge cases
- `example/lib/json_datetime/avoid_datetime_constructor_unvalidated_fixture.dart` — new fixture
- `CHANGELOG.md` — entries under [14.4.0]
- `bugs/BUG_REPORT_GUIDE.md` — reference repointed

### Known limitations

- Day upper bound is 31, not calendar-aware: `DateTime(2026, 2, 31)` passes the allowlist
- Quick fix produces `DateTime?` — callers need null handling
- Quick fix bails out on complex expressions (ternary, await, cascade, strings with quotes)
- `avoid_datetime_constructor_unvalidated` does not verify that a local-variable assignment is ACTUALLY followed by validation — it only checks that the opportunity exists

### Closes bug

`plans/history/2026.08/2026.08.04/feature_lint_rule_avoid_datetime_constructor.md`
