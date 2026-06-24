# FEATURE: `require_named_for_acronym_drift_columns` — Pin SQL column name when a Drift getter contains an acronym

**Status: Fixed**

<!-- Status values: Open → Investigating → Fix Ready → Closed -->

Created: 2026-06-24
Rule: `require_named_for_acronym_drift_columns` (proposed — does not exist yet)
File: `lib/src/rules/packages/drift_rules.dart` (new rule)
Severity: Feature (prevents a runtime crash class — high value)
Rule version: n/a | Since: n/a | Updated: n/a

---

## Summary

A Drift `Table` column getter whose Dart name contains a run of **2+ consecutive
uppercase letters** (an acronym: `UUID`, `URL`, `JSON`, `HTML`, `ID`, `API`, …)
should be **required to pin its SQL column name** with `.named('snake_case')`.

Drift's default snake_case converter inserts an underscore before *every*
uppercase letter, so an acronym expands one-letter-per-underscore. `contactSaropaUUID`
becomes the SQL column `contact_saropa_u_u_i_d` — not the `contact_saropa_uuid` a
human reading the Dart name expects. Any raw SQL (`customSelect` /
`customStatement` / migration DDL) authored against the "obvious" name throws
`no such column` at runtime. A lint that forces `.named()` on acronym getters
makes the SQL name explicit and predictable, eliminating the entire mismatch
class before it can crash.

---

## Attribution Evidence

This is a **new rule request**, not a bug against an existing rule. Positive grep
returns zero matches, as expected for a rule that does not exist yet:

```bash
$ grep -rn "require_named_drift\|drift_column_named\|acronym_drift" lib/src/rules/
# 0 matches — rule not yet defined

$ ls lib/src/rules/packages/ | grep -i drift
drift_rules.dart   # existing Drift rule category — the natural home for this rule
```

The existing Drift rule category is `lib/src/rules/packages/drift_rules.dart`;
rules are registered in `lib/src/rules/all_rules.dart`.

---

## Real-World Incident That Motivated This

**Project:** Saropa Contacts (`d:\src\contacts`). **Date:** 2026-06-24.

Opening any contact threw, every time:

```
Drift ERROR SELECT: SELECT contact_saropa_uuid AS uuid, LENGTH(image) AS sz
FROM contact_avatars — SqliteException(1): while preparing statement,
no such column: contact_saropa_uuid, SQL logic error (code 1)
```

Root cause: the avatar byte-size audit ran a raw `customSelect` hardcoding
`contact_saropa_uuid`, but the `ContactAvatars` table getter is
`contactSaropaUUID` (all-caps `UUID`), so Drift generated the column
`contact_saropa_u_u_i_d`. The fix in the app was to stop hardcoding the name and
derive it from `db.contactAvatars.contactSaropaUUID.name`.

The codebase is **inconsistent** in a way that makes this a recurring trap:

| Table | Getter | `.named()`? | Generated SQL column |
|---|---|---|---|
| `ContactReactionRecords` | `contactSaropaUUID` | `.named('contact_saropa_uuid')` | `contact_saropa_uuid` |
| `NativeContactRollbacks` | `contactSaropaUUID` | `.named('contact_saropa_uuid')` | `contact_saropa_uuid` |
| `ImageBlurMeta` | `contactSaropaUUID` | `.named('contact_saropa_uuid')` | `contact_saropa_uuid` |
| `ContactAvatars` | `contactSaropaUUID` | **none** | `contact_saropa_u_u_i_d` |
| `ContactAvatarHistory` | `contactSaropaUUID` | **none** | `contact_saropa_u_u_i_d` |
| `Contacts`, `Activities`, `ContactPoints`, `CoachingSessions`, `AddressLatLongs`, `FacebookFriends`, `Connections`, `PersonalityQuizProgresses`, `QuickLaunchOrders`, `YouTubeApiCaches` | `contactSaropaUUID` | **none** | `contact_saropa_u_u_i_d` |

Three tables pin `contact_saropa_uuid`; the rest silently get
`contact_saropa_u_u_i_d`. A developer authoring raw SQL has no way to know which
name applies to which table without opening `.g.dart`. The proposed lint forces
`.named()` everywhere an acronym appears, so the generated name always equals the
name written in the source.

---

## Reproducer

Minimal Drift table that triggers the proposed lint:

```dart
import 'package:drift/drift.dart';

class ContactAvatars extends Table {
  IntColumn get id => integer().autoIncrement()();

  // LINT (proposed): getter name contains the acronym `UUID`; without
  // `.named()` Drift generates `contact_saropa_u_u_i_d`, which is surprising
  // and a magnet for `no such column` in raw SQL.
  TextColumn get contactSaropaUUID => text()();

  // OK: acronym getter with an explicit pinned SQL column name.
  TextColumn get reactionSaropaUUID =>
      text().named('reaction_saropa_uuid')();

  // OK: no acronym run — default snake_case is already unsurprising
  // (`display_name`), so `.named()` is not required.
  TextColumn get displayName => text()();
}
```

**Frequency:** Always, for any column getter whose identifier contains 2+
consecutive uppercase letters and omits `.named()`.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | LINT on `contactSaropaUUID` (acronym getter, no `.named()`); NO lint on `reactionSaropaUUID` (pinned) or `displayName` (no acronym) |
| **Actual** | No rule exists; the surprising column name ships and crashes only at runtime when raw SQL references the expected-but-wrong name |

---

## AST Context

The rule registers on getter declarations inside a class that extends `Table`
(Drift). The column-builder chain is the getter body's returned invocation
(`text()`, `integer()`, `blob()`, …, optionally with `.nullable()`, `.named()`,
`.map()`, `.withDefault()` etc.).

```
ClassDeclaration (ContactAvatars)   ← extendsClause type name == 'Table' (drift)
  └─ MethodDeclaration (isGetter == true, name: 'contactSaropaUUID')
      └─ FunctionBody
          └─ MethodInvocation chain   ← walk for a '.named(' call
                text() → ()           ← no .named() present  → REPORT on the getter name token
```

Detection sketch:

1. Class extends Drift `Table` (check the supertype element / name `Table` from
   `package:drift`).
2. Member is a getter returning a Drift column builder (chain rooted at
   `text()` / `integer()` / `blob()` / `boolean()` / `dateTime()` / `real()` /
   `int64()` etc.).
3. The getter identifier matches `[A-Z]{2,}` somewhere (a 2+ uppercase run).
   Treat a trailing `s` after the run as still matching (`contactSaropaUUIDs`).
4. The builder chain does **not** contain a `.named(` invocation.
5. → report on the getter name identifier.

---

## Root Cause (of the underlying problem the rule prevents)

Drift's `CaseFromDartToSql.snake_case` (the default `case_from_dart_to_sql`
option) inserts `_` before each uppercase letter and lowercases it. It does not
special-case acronyms, so `UUID` → `_u_u_i_d`. The generated name is correct and
stable — it is just not what a human predicts from the Dart identifier, and raw
SQL is authored by humans. `.named()` overrides the converter with a literal SQL
name, making source and schema agree.

---

## Suggested Fix (rule implementation)

Add `RequireNamedForAcronymDriftColumnsRule` to
`lib/src/rules/packages/drift_rules.dart`, register it in `all_rules.dart`, and
add it to the appropriate tier.

- Quick fix: insert `.named('<snake_case_of_getter>')` into the builder chain,
  computing the snake_case the way a human expects the acronym to read
  (`contactSaropaUUID` → `contact_saropa_uuid`, i.e. collapse the acronym run to
  a single token). The fix's suggested name is a starting point the developer
  confirms — but applying it also pins the *generated* name, so existing data
  must be considered (see Caveat).

### Caveat — do not auto-rewrite live columns blindly

Adding `.named('contact_saropa_uuid')` to a table that has **already shipped**
with `contact_saropa_u_u_i_d` renames the physical column and needs a migration.
The lint should therefore:

- Default to **report-only** (no auto-applied fix) for getters with no `.named()`,
  with a message steering toward `.named()` for *new* tables.
- Or scope the auto-fix to tables that have not yet been generated / shipped.

Recommend shipping report-only first; the value is preventing the next new
acronym column from repeating the trap, not mass-renaming existing schema.

---

## Fixture Gap

`example*/lib/packages/require_named_for_acronym_drift_columns_fixture.dart`
should include:

1. `contactSaropaUUID` with no `.named()` — expect **LINT**
2. `contactSaropaUUID` with `.named('contact_saropa_uuid')` — expect **NO lint**
3. `youTubeApiCache` / `youTubeAPIId` (acronym `API`) no `.named()` — expect **LINT**
4. `displayName` (no acronym run) — expect **NO lint**
5. `contactSaropaUUIDs` (plural after acronym) no `.named()` — expect **LINT**
6. Acronym getter in a class that does **not** extend `Table` — expect **NO lint**
7. Acronym getter that is a normal field/method, not a Drift column builder — expect **NO lint**
8. `.nullable()` / `.map()` / `.withDefault()` present but `.named()` absent — expect **LINT** (chain-order independence)

---

## Complementary deeper check (different repo, optional)

A static lint cannot validate that a raw `customSelect('SELECT foo FROM bar')`
references a column that actually exists — that requires the real schema. The
**Saropa Drift Advisor** already profiles the live DB, so a check there that
parses `customSelect` / `customStatement` SQL string literals and flags column
references absent from the profiled schema would catch typos and stale names this
lint cannot. The two are complementary: this lint removes the *surprising-name*
class at the source; a drift-advisor SQL-reference check would catch *any* bad
column name in raw SQL. File separately in `saropa_drift_advisor/bugs/` if wanted.

---

## Environment

- saropa_lints version: (current)
- Dart SDK version: (current)
- Triggering project/file: Saropa Contacts —
  `lib/database/drift/tables/user_data/contact_avatar_table.dart` (getter
  `contactSaropaUUID`), consumed by
  `lib/database/drift_middleware/user_data/contact_avatar_drift_io.dart`
  (`dbContactAvatarByteSizes` raw `customSelect`).

---

## Finish Report (2026-06-24)

Implemented `require_named_for_acronym_drift_columns` as specified.

**What shipped**
- Rule `RequireNamedForAcronymDriftColumnsRule` in
  `lib/src/rules/packages/drift_rules.dart`. Registers on class declarations,
  gates on `extends Table` + the `package:drift` import, then iterates getter
  members: flags any whose name has a 2+ uppercase run (`RegExp([A-Z]{2,})`),
  whose body is a Drift column builder (root call in `text`/`integer`/`blob`/
  `boolean`/`dateTime`/`real`/`int64`/`intEnum`/`textEnum`/`customType`), and
  whose chain contains no `.named(`. Detection is chain-order independent — a
  helper collects every method name in the builder chain (walking the trailing
  `()` build call, chained calls, and parens) in one pass.
- Severity WARNING, Professional tier. **Report-only** (no quick fix) per the
  migration caveat — pinning a shipped column renames it and needs a migration.
- Registered in `lib/saropa_lints.dart` factories; added to
  `professionalOnlyRules` and `driftPackageRules` in `lib/src/tiers.dart`.
- Fixture `example_packages/lib/drift/require_named_for_acronym_drift_columns_fixture.dart`
  (stub, matching sibling drift fixtures — example_packages has no drift dep).
- Unit test entries in `test/rules/packages/drift_rules_test.dart`
  (instantiation + fixture-exists).
- CHANGELOG `[Unreleased] ### Added` entry. (ROADMAP.md is now a pointer stub —
  no per-rule table.)

**Verification**
- `dart test test/rules/packages/drift_rules_test.dart` — 67 pass.
- `dart test test/integrity/saropa_lints_test.dart` — 24 pass (tier↔plugin
  consistency clean).
- Behavior confirmed with the scan CLI against a temp reproducer covering all 8
  fixture-gap cases: fired on `contactSaropaUUID`, `youTubeAPIId`,
  `contactSaropaUUIDs`, and `profileURL` (`.nullable()` present, `.named()`
  absent); silent on the pinned `.named()` getter, `displayName` (no acronym),
  a `String` getter (not a column builder), and an acronym getter in a class
  that does not extend `Table`.

**Not done (deliberate)**
- No auto-fix (caveat: avoid blind live-column rename).
- The complementary `customSelect` SQL-reference check belongs in
  `saropa_drift_advisor` (a different repo) — not filed here.
