# BUG: `prefer_setup_teardown` — False positive on parameterized SUT call (const inputs vary, signature ignores const)

**Status: Fixed**

Created: 2026-04-29
Resolved: 2026-04-29
Rule: `prefer_setup_teardown`
File: `lib/src/rules/testing/testing_best_practices_rules.dart` (`_buildSetupSignature` / `_isSimpleLocalInit`)
Severity: False positive
Rule version: v7 (lint message tag); prior behavior: v6

---

## Summary

The rule treated the first identical SUT call line across tests as duplicated setup while skipping `const`/literal locals, so parameterized arrange–act–assert tests collided. Signatures now prepend normalized simple-local init source so different inputs produce different buckets.

---

## Attribution

```
$ grep -rn "'prefer_setup_teardown'" lib/src/rules/
lib/src/rules/testing/testing_best_practices_rules.dart
```

## Problem

The rule flags 3+ tests sharing the same first non-skipped statement signature. Const variable declarations are skipped via `_isSimpleLocalInit`, but the *call statement* that consumes them is not. When tests follow the pattern "set up parameterized const inputs → invoke SUT with those named variables → assert", the SUT-call line becomes the matched signature across tests — even though each test passes different concrete values.

Moving the SUT call to `setUp()` is impossible because each test needs different inputs. The "duplication" is an artifact of using stable variable names for varying const values, not real shared initialization.

## Reproduction

```dart
group('namesForDate', () {
  test('valid Swedish Jan 1', () {
    const NameDayCalendarType calendar = NameDayCalendarType.swedish;
    const int month = 1;
    const int day = 1;
    final List<String>? result = NameDayUtils.namesForDate(
      calendar: calendar, month: month, day: day);
    expect(result, isNotNull);
  });

  test('valid Finnish Jan 1', () {
    const NameDayCalendarType calendar = NameDayCalendarType.finnish; // different value
    const int month = 1;
    const int day = 1;
    final List<String>? result = NameDayUtils.namesForDate(
      calendar: calendar, month: month, day: day);
    expect(result, isNotNull);
  });

  test('invalid Feb 30', () {
    const NameDayCalendarType calendar = NameDayCalendarType.swedish;
    const int month = 2;
    const int day = 30; // different value
    final List<String>? result = NameDayUtils.namesForDate(
      calendar: calendar, month: month, day: day);
    expect(result, isNull);
  });
});
```

All three tests' first non-skipped statement is identical source-text:
`final List<String>? result = NameDayUtils.namesForDate(calendar: calendar, month: month, day: day);`

Const decls are skipped, but the actual *values* differ per test. The rule fires on the first test.

## Why this is wrong

1. **The flagged statement is the test action, not setup.** It is what each test exercises.
2. **The variation is real but invisible to the lint.** Tests differ via `calendar`, `month`, `day` const values that the signature builder skipped.
3. **Suggested fix doesn't apply.** Moving to `setUp()` would force one set of inputs across all three tests, breaking them — the whole point is exercising different inputs against the same SUT.
4. **This pattern is idiomatic.** Arrange-Act-Assert with named const inputs is exactly how Saropa tests are structured (see CLAUDE.md `.claude/rules/testing.md`).

## Affected sites in `D:\src\contacts`

Files where the flagged "duplication" is a parameterized SUT call:

- `test/lib/data/contact/pet_fun_facts_data_test.dart:8`
- `test/lib/data/events/name_day/name_day_utils_test.dart:11`
- `test/lib/database/file_backup/import/vcard_import_utils_test.dart:28`
- `test/lib/service/device_home_screen_widget/device_home_screen_widget_service_test.dart:14`
- `test/lib/service/network/speed_test_service_test.dart:14`
- `test/lib/service/notification/content/birthday_timezone_utils_test.dart:84`
- `test/lib/utils/contact/pet/pet_quiz_scoring_utils_test.dart:18`
- `test/lib/utils/event/anniversary_material_utils_test.dart:7`
- `test/lib/utils/event/astronomical/astronomical_utils_test.dart:282`
- `test/utils/contact/signature/signature_block_splitter_test.dart:11`
- `test/utils/contact/signature/signature_input_normalizer_test.dart:60`
- `test/utils/contact/signature/signature_vcard_extractor_test.dart:46`
- `test/utils/contact/signature/email_signature_parser_test.dart:14`
- `test/utils/contact/signature/email_signature_contact_builder_test.dart:38`

In each case, the flagged tests use parameterized const inputs and invoke the SUT — moving the call to `setUp()` is not an option.

## Suggested fix (implemented)

**Include const/literal initializer values in the signature** via a preface of normalized `_isSimpleLocalInit` statements before the first 1–2 non-assertion body statements.

## Workaround

Previously: `// ignore: prefer_setup_teardown` at affected sites. **After the fix**, those ignores can be removed when convenient.

## Resolution

`_buildSetupSignature` now prepends normalized source for each `_isSimpleLocalInit` statement encountered (in order) before the first 1–2 non-assertion body statements, so different `const` / literal arrange values yield different signatures. Fixture: `example/lib/testing_best_practices/prefer_setup_teardown_fixture.dart`. Lint message tag bumped to `{v7}`.
