# device_calendar_plus rule pack

A user request to extend the existing `device_calendar` rule pack to also cover
`device_calendar_plus` was declined after research showed the two packages share
no API surface. A dedicated `device_calendar_plus` rule pack was implemented
instead, targeting the newer package's actual API.

---

## Summary

`device_calendar_plus` bills itself on pub.dev as "a maintained replacement for
the abandoned `device_calendar` plugin," which reads as a drop-in successor.
Checking its actual public API (`DeviceCalendar.instance` singleton,
`listCalendars()`/`listEvents()`/`createEvent()`/`updateEvent()`,
`DeviceCalendarException`-based error handling, no `timezone` package
dependency) against `device_calendar`'s API (`DeviceCalendarPlugin`,
`retrieveCalendars()`/`retrieveEvents()`/`createOrUpdateEvent()`, `Result<T>`
return values, `TZDateTime`) showed it is a from-scratch rewrite, not a fork —
zero shared method or class names. Widening the existing pack's
`package:device_calendar/` import gate to also match
`package:device_calendar_plus/` would have made all 7 existing rules either
never fire (they key off names the newer package doesn't have) or fire with
correction messages describing an API the project isn't using.

## What changed

Three new rules were added in a separate `device_calendar_plus` rule pack,
grounded in device_calendar_plus's documented API and behavior (via its pub.dev
package page and dartdoc):

- `device_calendar_plus_missing_permission_check` (INFO) — a file that calls
  create/update/delete/list operations but never calls `hasPermissions()` /
  `requestPermissions()` / configures `autoPermissions` anywhere in the file.
- `device_calendar_plus_all_day_event_utc_conversion` (WARNING) — an
  `isAllDay: true` event given a `.toUtc()` / `DateTime.utc(...)` date. The
  package's own docs distinguish timed events (safe to convert to UTC) from
  all-day events, which float as calendar dates; converting first can shift
  the event across a day boundary for users west of UTC.
- `device_calendar_plus_empty_update_event` (INFO) — an `updateEvent(eventId:
  ...)` call with no other field, which the package documents as a silent
  no-op rather than a thrown error.

A fourth candidate rule (flagging a bare `catch` around a data op, to prevent
swallowing the `ArgumentError`/`StateError` "programmer errors" the package's
docs say should propagate rather than be caught) was researched and dropped:
the codebase already has general-purpose rules (`avoid_catch_all`,
`avoid_catch_exception_alone`) that push developers toward `on Object catch`
as the correct pattern — the opposite stance. Adding a package-specific rule
with the reverse recommendation would have created a direct policy conflict.

### Files touched

- `lib/src/rules/packages/device_calendar_plus_rules.dart` (new) — the 3 rules.
- `lib/src/import_utils.dart` — new `PackageImports.deviceCalendarPlus` gate,
  kept separate from `PackageImports.deviceCalendar`.
- `lib/src/rules/all_rules.dart`, `lib/saropa_lints.dart` — export + factory
  registration.
- `lib/src/tiers.dart` — all 3 rules placed in `comprehensiveOnlyRules`
  (matching the sibling pack's placement); new `deviceCalendarPlusPackageRules`
  set, `packageRuleMap`, `allPackages`, and `defaultPackages` entries.
- `tool/generate_rule_pack_registry.dart` — new pubspec marker entry; the
  generator was then re-run to regenerate `lib/src/config/rule_pack_codes_generated.dart`
  and the three `extension/src/rulePacks/*.ts` files.
- `example_packages/lib/device_calendar_plus/*_fixture.dart` (new, 3 files) —
  one BAD/GOOD fixture per rule.
- `test/rules/packages/device_calendar_plus_rules_test.dart` (new) — rule
  instantiation + fixture-existence tests, matching the sibling pack's test
  shape.
- `CHANGELOG.md` — new `[Unreleased]` section.

### Verification

The scan CLI's default file-exclusion list matches any path containing
`/example`, which silently excludes `example_packages/**` from `dart run
saropa_lints scan` regardless of the target path passed — a pre-existing tool
limitation, not something introduced or fixed here. Fixture verification was
done by copying each fixture into a scratch directory outside any
`*example*`-named path and running the scan CLI there (with `--resolve` to
confirm the `DateTime.utc(...)` case, which needs full type resolution to
parse as an `InstanceCreationExpression` under the tool's default fast
syntactic pass). All three rules were confirmed to fire at the exact
`// expect_lint:`-marked line and stay silent on the paired `good()` case.

One real fixture bug was caught this way: the first draft of the
missing-permission-check fixture included a `good()` function in the same
file that called `requestPermissions()` — since that rule scans the whole
file for a permission call, the compliant call suppressed the diagnostic
being tested. Fixed by removing the `good()` counterpart from that one file
(the rule is file-scoped by design, matching the sibling pack's rule).

A delegated code review (general-purpose subagent) surfaced two worth-fixing
gaps before this was considered complete:

- Rules 2 and 3 lacked the `_isTestFilePath` guard rule 1 has (and 4 of the
  sibling pack's 7 rules have), risking false positives inside the plugin's
  own or a consumer project's test fixtures. Added the same guard to both.
- Rule 1 lacked the `requiredPatterns` fast-path filter rules 2 and 3 already
  had, meaning every file importing `device_calendar_plus` triggered a full
  `RecursiveAstVisitor` traversal even with zero calendar operations. Added
  `requiredPatterns => _dataOps`.

The review's remaining findings (bare method-name matching with no
receiver-type check; narrow UTC-shape detection covering only
`.toUtc()`/`DateTime.utc(...)`) were initially left as-is, matching an
accepted existing tradeoff in the sibling `device_calendar_rules.dart` — see
the Follow-up section below for why that changed. The private
`_isTestFilePath`/`_namedArg`-per-file duplication was left alone; it matches
a project-wide accepted convention (14+ `lib/src/rules/packages/*_rules.dart`
files already do this).

All 3 rules re-verified against their fixtures after the review fixes; the
new unit test and the pre-existing `test/integrity/saropa_lints_test.dart`
and `test/config/rule_packs_*` tests all pass.

## Follow-up: receiver-type checks and wider UTC-shape detection

A follow-up request asked for the two false-positive risks left open above to
be addressed, plus the missing `DateTime.fromMillisecondsSinceEpoch(...,
isUtc: true)` / `DateTime.parse('...Z')` UTC shapes the review flagged as
undetected. Three changes to `lib/src/rules/packages/device_calendar_plus_rules.dart`:

- Added `_isDeviceCalendarCall`, mirroring the established
  `node.realTarget?.staticType?.element?.name == _typeName` idiom already used
  by `local_auth_rules.dart`, `in_app_review_rules.dart`, and
  `quick_actions_rules.dart`. All three rules now require their `MethodInvocation`
  matches to resolve to a `DeviceCalendar` receiver, so a same-named method on
  an unrelated class in the same file no longer counts.
- Replaced the bare `simpleIdentifierNames.contains('autoPermissions')` check
  with a resolved-receiver check on `PropertyAccess`/`PrefixedIdentifier`
  nodes, so an unrelated local variable/field named `autoPermissions` no
  longer suppresses the missing-permission-check diagnostic.
- Extended `_isUtcTaintedExpression` to also match
  `DateTime.fromMillisecondsSinceEpoch`/`fromMicrosecondsSinceEpoch` with
  `isUtc: true`, and `DateTime.parse(...)` of a string literal ending in `Z`.

These checks require full type resolution (the same requirement the three
sibling-pattern rules above already carry), which cannot be exercised against
an ad hoc scratch file with no real dependency — an ad hoc verification
attempt against files with no real `device_calendar_plus` dependency returned
zero diagnostics because `staticType` never resolves without one. Verification
was instead done against a throwaway pub package with `device_calendar_plus:
any` actually fetched via `dart pub get` (resolved to 0.7.1) and scanned with
`--resolve`. Confirmed: all 3 original fixtures still fire at their marked
lines; both new UTC shapes fire; a same-named method on an unrelated class
produces no diagnostic; and a real data-op call with an unrelated local
`autoPermissions` variable and no real permission call still fires (proving
the fix, not just a null result).

## Follow-up 2: regression coverage for the receiver-type fix, and a style fix

A second independent review of the receiver-type commit (a fresh subagent, no
memory of the first review) confirmed `_isDeviceCalendarCall` and the
`PropertyAccess`/`PrefixedIdentifier` receiver checks are correct — verified
directly against `device_calendar_plus 0.7.1`'s source, including cascade and
null-aware-access shapes. It surfaced two findings worth acting on:

- `_isUtcTaintedExpression`'s new `DateTime.parse(...)` branch read
  `expr.target` instead of `expr.realTarget`, inconsistent with every other
  receiver check added in the same commit (cascades are not a realistic shape
  for a static `DateTime.parse` call, so this was style, not a functional
  bug). Changed to `realTarget` for consistency.
- None of the new logic — the receiver-type guard on all three rules, the
  `autoPermissions` fix, or the two new UTC shapes — had any fixture or test
  coverage. The prior round's verification was a one-off manual run against a
  throwaway pub package, not a durable, reproducible check. Fixed by adding
  false-positive-guard cases to all three fixtures (an unrelated class
  exposing a same-named method with the exact argument shape each rule looks
  for, which must NOT trigger; an unrelated local `autoPermissions` variable,
  which must NOT suppress the missing-permission-check diagnostic) and two
  additional `expect_lint`-marked BAD cases plus a non-tainted `DateTime.parse`
  GOOD case to the all-day-event fixture, covering the two newly-detected UTC
  shapes.

The review also named two accepted, non-blocking gaps, left as-is and
recorded here for a future reader: (1) `DateTime.parse`'s receiver is still
checked by bare identifier name (`target.name == 'DateTime'`), not resolved
type, matching the pre-existing `DateTime.utc(...)` lexeme check — a project
that shadowed `dart:core`'s `DateTime` would false-positive; (2) all three
rules are now resolution-dependent end to end, so this project's own `scan`
CLI under its default (non-`--resolve`) fast path will under-report them —
consistent with the custom_lint IDE plugin always resolving, and with the
same tradeoff three sibling rules (`local_auth`, `in_app_review`,
`quick_actions`) already carry.

Re-verified against a fresh throwaway pub package with `device_calendar_plus`
actually fetched (0.7.1) and `--resolve`: all three fixtures fire at their
exact `expect_lint`-marked lines and stay silent on every `good()`/OK case,
including the two new receiver-type FP guards proving (not just asserting)
the fix. Unit test re-run: pass.

## Outcome

Shipped. Both packages' rule packs remain fully independent — enabling
`device_calendar_plus` in a project's `rule_packs.enabled` list has no effect
on `device_calendar` rules or vice versa.
