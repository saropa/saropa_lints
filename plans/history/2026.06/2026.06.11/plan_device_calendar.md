# Plan: new `device_calendar` lint rules

**Package:** device_calendar (bardram fork ~4.x, API-compatible with pub `device_calendar` ~4.x) (Saropa Contacts).
**saropa_lints coverage:** none (new file).

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `device_calendar_missing_permission_check` | correctness | call to `retrieveCalendars()`, `retrieveEvents()`, `createOrUpdateEvent()`, or `deleteEvent()` in a file that contains no `hasPermissions()` or `requestPermissions()` call | report-only | WARNING | skip test files; skip if at least one of the two permission methods appears anywhere in the same compilation unit |
| `device_calendar_unchecked_result` | correctness | `await` on any `DeviceCalendarPlugin` method where the returned `Result<T>` value is not stored, or is stored but `.isSuccess` / `.hasErrors` / `.errors` is never accessed in the same function body | report-only | WARNING | skip if the call is inside a try/catch that wraps the whole expression; skip if the return type is `Result<void>` and caller only needs side-effect semantics (speculative — verify whether `void` Results exist in this API) |
| `device_calendar_retrieve_events_empty_params` | correctness | `retrieveEvents()` called with a `RetrieveEventsParams` where both `startDate`/`endDate` AND `eventIds` are all null (i.e., `RetrieveEventsParams()` with no arguments, or named args all explicitly null) | report-only | WARNING | only fire when the `RetrieveEventsParams` constructor call is the direct argument to `retrieveEvents`; skip if the params object is a variable whose initializer cannot be statically analyzed |
| `device_calendar_retrieve_events_missing_end_date` | correctness | `RetrieveEventsParams` constructed with `startDate` set but `endDate` null, or `endDate` set but `startDate` null — a half-specified date range that the plugin treats as invalid | report-only | WARNING | skip if `eventIds` is also provided (the ID-list path is independent of dates); only fire when the `RetrieveEventsParams` literal is statically visible |
| `device_calendar_event_missing_calendar_id` | correctness | `Event` constructor call where `calendarId` is null or not provided, when that `Event` instance is then passed to `createOrUpdateEvent()` | report-only | ERROR | only fire when the `Event()` constructor call and the `createOrUpdateEvent()` call are in the same function body and the same variable flows from one to the other; do not flag `Event` constructions that are not passed to `createOrUpdateEvent` |
| `device_calendar_event_utc_timezone` | correctness | `TZDateTime.utc(...)` used as the `start` or `end` of an `Event` passed to `createOrUpdateEvent()` — UTC events show at the wrong local time on device calendars due to a known Android timezone-name bug (EVENT_TIMEZONE receives display name instead of IANA ID) | report-only | WARNING | only fire if the `TZDateTime.utc` constructor (library `package:timezone/timezone.dart`) is the direct initializer; skip if the call site is already wrapped in a comment containing `// UTC` or `// ignore:`; skip test files |
| `device_calendar_result_data_before_success_check` | correctness | `.data` accessed on a `Result<T>` value before a successful `.isSuccess` guard — `Result.data` is nullable and meaningless when `isSuccess` is false, so reading it without the guard causes a silent null or stale value | report-only | WARNING | only fire when the `.data` access is not inside an `if (result.isSuccess)` / `if (!result.isSuccess) return` / `assert(result.isSuccess)` branch in the same function scope; skip test files where assert-based access is common |

---

## Rule detail

### `device_calendar_missing_permission_check`

> **VALIDATION (2026-06-11) — OVERLAP / DOWNGRADE:** iOS-plist enforcement already exists via `RequireIosPermissionDescription` (ios_capabilities_permissions_rules.dart:140) + IosPermissionMapping (info_plist_utils.dart:303 maps DeviceCalendar→NSCalendarsUsageDescription). The runtime-call angle is distinct but downgrade to INFO and note the overlap to avoid double-nagging.

- **What/why:** `DeviceCalendarPlugin` requires `READ_CALENDAR` / `WRITE_CALENDAR` (Android) or `NSCalendarsUsageDescription` (iOS) permissions before any data operation can succeed. The plugin does not throw on permission denial — it returns a `Result` with `isSuccess == false` and an error in `.errors`, or silently returns an empty list. Developers who skip the `hasPermissions()` → `requestPermissions()` preamble ship an app that silently shows zero calendars/events on first install, with no user feedback. This is the single most commonly reported bug class in the upstream issue tracker.
- **Detection (AST, type-safe):** Scan the compilation unit for `MethodInvocation` nodes where the method name is one of `retrieveCalendars`, `retrieveEvents`, `createOrUpdateEvent`, `deleteEvent`, `deleteEventInstance`, `createCalendar`, `deleteCalendar` AND the resolved element's enclosing library URI equals `package:device_calendar/device_calendar.dart`. In the same compilation unit, check whether any `MethodInvocation` with `methodName.name` in `{'hasPermissions', 'requestPermissions'}` AND the same library URI exists. If the data-operation set is non-empty and the permission-method set is empty, report at the first data-operation site. Never match by bare method name alone — always resolve to the library URI.
- **Fix:** report-only. The permission flow (check → request → act on result) requires app-specific UX decisions and cannot be mechanically inserted.
- **False positives:** (a) files that call into a permission-handling helper defined in another file — this is a file-level heuristic and will FP on well-factored code. Use INFO severity or document the limitation in `correctionMessage`, directing the developer to verify that `hasPermissions`/`requestPermissions` is called before this code executes. (b) test files — skip via `ProjectContext.isTestFile(path)`.

---

### `device_calendar_unchecked_result`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** contains an unverified assumption ("skip if return type is Result<void> — verify void Results exist"); confirm before build.

- **What/why:** Every `DeviceCalendarPlugin` method returns `Future<Result<T>>` (or `Future<Result<T>?>`). The `Result` wrapper stores `isSuccess`, `hasErrors`, `errors`, and `data`. Developers who `await` a call without inspecting `isSuccess` silently swallow all failures — permission denials, platform exceptions, invalid argument errors — and proceed as if the operation succeeded. `Result.isSuccess` is a computed getter (`data != null && errors.isEmpty`), so an empty data value with no errors also returns false; reading `.data` directly is unsafe. This pattern is pervasive in Stack Overflow examples that omit error handling for brevity and get copied verbatim.
- **Detection (AST, type-safe):** Match `AwaitExpression` nodes whose static return type is `Result<dynamic>` (or any specialization) with library URI `package:device_calendar/device_calendar.dart`. Check whether the awaited expression's value is: (a) discarded (not assigned to any variable), or (b) assigned to a local variable that is subsequently never referenced for `.isSuccess`, `.hasErrors`, `.errors`, or `.data` within the same function body. For (a), report immediately on the discarded await. For (b), collect all `PropertyAccess` / `PrefixedIdentifier` nodes in the function body referencing that variable; if none of them access `isSuccess`, `hasErrors`, or `errors`, report on the assignment. Resolve `Result` by type element, not by name string.
- **Fix:** report-only. The correct error handling strategy is caller-dependent.
- **False positives:** (a) `createOrUpdateEvent` returns `Future<Result<String>?>` (nullable outer); null-check on the outer value is not the same as checking `isSuccess` — ensure the rule also fires when only the null-check is present but not `isSuccess`. (b) unit tests that intentionally call without checking — skip via `ProjectContext.isTestFile(path)`.

---

### `device_calendar_retrieve_events_empty_params`

- **What/why:** `retrieveEvents(calendarId, params)` requires at least one of: (a) non-null `startDate` AND `endDate`, or (b) non-null, non-empty `eventIds`. When all three fields of `RetrieveEventsParams` are null, the plugin adds a `ResultError` with code `invalidArguments` and message "invalid retrieve events params" — the returned `Result` has `isSuccess == false` and `data` is null. Callers who pass `RetrieveEventsParams()` with no arguments receive a guaranteed failure. The `RetrieveEventsParams` class itself performs no validation (all fields are nullable by design), so this foot-gun is invisible at construction time.
- **Detection (AST, type-safe):** Match `InstanceCreationExpression` where the constructor resolves to `RetrieveEventsParams` in library `package:device_calendar/device_calendar.dart`. Inspect the named arguments: if `startDate`, `endDate`, and `eventIds` are all absent from the argument list (or all explicitly set to `null` literals), and that expression is the direct argument to a `retrieveEvents` call (or assigned to a variable that flows directly into a `retrieveEvents` call in the same statement), report on the `RetrieveEventsParams` construction. Do not fire on constructions that are not passed to `retrieveEvents`.
- **Fix:** report-only. The correct fix depends on whether the caller wants date-range or ID-based lookup — mechanical insertion would guess wrong.
- **False positives:** if the `RetrieveEventsParams` is built and populated via `copyWith` or mutation before being passed — the rule cannot follow field-level mutations to a `const` object; since `RetrieveEventsParams` uses a `const` constructor with immutable fields, `copyWith` is not possible. If a variable is assigned `RetrieveEventsParams()` and then a different object replaces it before the call, the rule may FP — scope strictly to the direct-argument case first.

---

### `device_calendar_retrieve_events_missing_end_date`

- **What/why:** `retrieveEvents` validates that when a date range is used, both `startDate` and `endDate` must be non-null and `startDate` must precede `endDate`. A `RetrieveEventsParams(startDate: someDate)` with no `endDate` (or vice-versa) will cause the plugin to produce a `Result` with `invalidArguments` error. This is a distinct footgun from the all-null case: the developer clearly intends to use a date range but accidentally omits one bound, which is a common off-by-one in copy-paste from examples.
- **Detection (AST, type-safe):** Match `InstanceCreationExpression` for `RetrieveEventsParams` (same library URI check as above). Inspect named arguments: if exactly one of `startDate` or `endDate` is present (and non-null) while the other is absent or explicitly null, AND `eventIds` is also absent or null, report on the construction. The condition: `(startDate provided XOR endDate provided) AND eventIds absent/null`.
- **Fix:** report-only.
- **False positives:** if `eventIds` is also non-null, the date range incompleteness is harmless because the plugin uses the ID-based path — skip in that case, as stated in the condition above.

---

### `device_calendar_event_missing_calendar_id`

> **VALIDATION (2026-06-11) — FEASIBILITY:** needs intra-function value flow (Event() → var → createOrUpdateEvent + calendarId setter between); most complex rule, ERROR severity raises the bar.

- **What/why:** `createOrUpdateEvent(Event event)` validates that `event.calendarId?.isNotEmpty ?? false` is true for both new and existing events. When `calendarId` is null or empty, the plugin returns a `Result` with an `invalidArguments` error and the event is not persisted. The error message is "New events must specify a calendar id" (confirmed in upstream issue #113). Because `Event.calendarId` is typed `String?` and has no required annotation in the constructor, it is easy to construct an `Event()` without it and only discover the failure at runtime.
- **Detection (AST, type-safe):** Match `InstanceCreationExpression` for `Event` in library `package:device_calendar/device_calendar.dart`. Check named arguments: if `calendarId` is absent from the argument list or is explicitly a `null` literal. Then check whether the resulting `Event` value flows (via local variable or direct expression) into the first argument of a `createOrUpdateEvent` call in the same function body. Only report when both conditions hold — do not flag `Event` constructions used for display-only or testing purposes. Resolve `Event` by its class element identity, not by bare name (an unrelated `Event` class must not match).
- **Fix:** report-only. The `calendarId` to insert depends on the user's selected calendar — mechanical insertion would be wrong.
- **False positives:** (a) an `Event` whose `calendarId` is assigned via a setter after construction (before being passed to `createOrUpdateEvent`) — the rule would FP if the setter assignment is between construction and the call. Mitigate by checking for any `target.calendarId = ...` assignment between the construction and the call in the same block. (b) `Event` constructions where `calendarId` is set via a factory or copyWith pattern — out of scope for v1; document in `correctionMessage`.

---

### `device_calendar_event_utc_timezone`

- **What/why:** `Event.start` and `Event.end` are typed `TZDateTime` from `package:timezone`. On Android, `DeviceCalendarPlugin` sets the `Events.EVENT_TIMEZONE` column using the timezone's `displayName` instead of its IANA `id` (confirmed bug in upstream issue #182). When the developer uses `TZDateTime.utc(year, month, day, ...)`, the UTC timezone's `displayName` is "UTC" — which happens to be a valid IANA ID, so UTC events display correctly. However, the bug is masked, and any non-UTC `TZDateTime` will produce a wrong timezone string on the device calendar side. More critically, encouraging `TZDateTime.utc` usage normalizes a pattern that breaks for every other timezone. Events stored as UTC display at the wrong local time on users' device calendars in non-UTC locales. The correct pattern is `TZDateTime.from(dateTime, tz.getLocation(ianaId))` with the user's local timezone.
- **Detection (AST, type-safe):** Match `InstanceCreationExpression` where the constructor resolves to `TZDateTime.utc` in library `package:timezone/timezone.dart`. Check whether this expression is used as the value of the `start` or `end` named argument in an `Event(...)` constructor call in the same statement, OR is assigned to a variable that is subsequently used as `event.start` or `event.end` before being passed to `createOrUpdateEvent`. The `TZDateTime` class element must be resolved from `package:timezone/timezone.dart`, not matched by name string.
- **Fix:** report-only. The correct IANA timezone must come from the device locale (e.g., `flutter_native_timezone` or `timezone` package's `local`) — a mechanical fix would require knowing the intended local timezone.
- **False positives:** (a) UTC-based events that are intentionally stored in UTC (e.g., multi-timezone meeting slots where UTC is the canonical representation) — these are edge cases; the `correctionMessage` should acknowledge the exception. (b) test files — skip via `ProjectContext.isTestFile(path)`.

---

### `device_calendar_result_data_before_success_check`

- **What/why:** `Result<T>.isSuccess` is a computed getter: `data != null && errors.isEmpty`. Reading `.data` without first confirming `isSuccess == true` can return null silently — or return a non-null but meaningless partial value from a failed operation. Since `data` is typed `T?` (nullable), the null-dereference is possible but easy to miss when the caller does `result.data!.someField` — the `!` forces a null-pointer exception that traces back to an unchecked result rather than to the original failure. This is the companion bug to `device_calendar_unchecked_result`: one catches completely discarded results; this one catches results that are checked superficially (stored) but whose data is extracted unsafely.
- **Detection (AST, type-safe):** Within a function body, find `PropertyAccess` / `PrefixedIdentifier` nodes where the target variable has static type `Result<T>` (library `package:device_calendar/device_calendar.dart`) and the accessed property is `data`. Walk up the AST to determine whether this access is inside an `if` block (or ternary) that guards on `variable.isSuccess` (a preceding `if (!result.isSuccess) return` or `if (result.isSuccess) { ... }` around the access point). If no such guard exists in the containing function scope, report at the `.data` access. Resolve `Result` by type element identity.
- **Fix:** report-only. Wrapping with an `isSuccess` guard is trivial but the recovery logic (what to do on failure) is caller-dependent.
- **False positives:** (a) `assert(result.isSuccess)` before `.data` access — treat `assert` as a valid guard for non-release code; do not fire. (b) code in a `try/catch` block that catches a rethrown exception from `hasErrors` — unusual but possible; document the edge case. (c) test files — skip.

---

## Migration note

`device_calendar_plus` (pub.dev, maintained by Bullet) is the upstream-recommended successor to the now-unmaintained `device_calendar` package. It is a full API rewrite: the `Result<T>` wrapper is replaced by typed `DeviceCalendarException` / `DeviceCalendarError` enum error handling, and the `timezone` package dependency is removed (timezones are handled natively). The API is not compatible — method signatures, parameter types, and the entire error-handling contract differ. Migration from `device_calendar` to `device_calendar_plus` is out of scope for a lint rule (the transform is not mechanical) but should be tracked as a planned upgrade for Saropa Contacts. The bardram fork (used by Saropa Contacts) only changes the timezone version constraint; the Dart API surface is identical to upstream `device_calendar` ~4.x.

---

## Implementation note

- **New file:** `lib/src/rules/packages/device_calendar_rules.dart`
- **Registration:** add `DeviceCalendarMissingPermissionCheckRule.new`, `DeviceCalendarUncheckedResultRule.new`, `DeviceCalendarRetrieveEventsEmptyParamsRule.new`, `DeviceCalendarRetrieveEventsMissingEndDateRule.new`, `DeviceCalendarEventMissingCalendarIdRule.new`, `DeviceCalendarEventUtcTimezoneRule.new`, `DeviceCalendarResultDataBeforeSuccessCheckRule.new` to `_allRuleFactories` in `lib/saropa_lints.dart`
- **Tier:** `comprehensiveOnlyRules` in `lib/src/tiers.dart` (all seven rules); the two `ERROR`-severity rules (`device_calendar_event_missing_calendar_id`) could be promoted to `professionalOnlyRules` after validation — decide at implementation time
- **Library URI constant:** define `const _deviceCalendarUri = 'package:device_calendar/device_calendar.dart'` and `const _timezoneUri = 'package:timezone/timezone.dart'` at the top of the rules file; never hardcode URI strings inline
- **`all_rules.dart`:** no change needed — the barrel export picks up the new category file automatically if it is exported from the packages barrel

---

## Sources

- [DeviceCalendarPlugin class — pub.dev API docs](https://pub.dev/documentation/device_calendar/latest/device_calendar/DeviceCalendarPlugin-class.html)
- [device_calendar library reference — pub.dev](https://pub.dev/documentation/device_calendar/latest/device_calendar/)
- [device_calendar Flutter package — pub.dev](https://pub.dev/packages/device_calendar)
- [builttoroam/device_calendar — GitHub (develop branch)](https://github.com/builttoroam/device_calendar)
- [RetrieveEventsParams source — GitHub develop](https://github.com/builttoroam/device_calendar/blob/develop/lib/src/models/retrieve_events_params.dart)
- [Event model source — GitHub develop](https://github.com/builttoroam/device_calendar/blob/develop/lib/src/models/event.dart)
- [DeviceCalendarPlugin implementation — GitHub develop](https://github.com/builttoroam/device_calendar/blob/develop/lib/src/device_calendar.dart)
- [Incorrect EVENT_TIMEZONE bug — issue #182](https://github.com/builttoroam/device_calendar/issues/182)
- ["New events must specify a calendar id" — issue #113](https://github.com/builttoroam/flutter_plugins/issues/113)
- [device_calendar_plus — pub.dev (successor package)](https://pub.dev/packages/device_calendar_plus)
- [device_calendar_plus — GitHub (bullet-to/device_calendar_plus)](https://github.com/bullet-to/device_calendar_plus)
- [Using Device_Calendar Library in Flutter (ITNEXT article)](https://itnext.io/using-device-calendar-library-in-flutter-to-communicate-with-android-ios-calendar-95b2d8c77b40)

---

## Finish Report (2026-06-11)

**Scope:** (A) Dart lint rules. All 7 rules implemented; 3 validation callouts
addressed.

### Validation fixes applied

- `device_calendar_missing_permission_check` → **downgraded to INFO** (overlaps the
  existing iOS-plist `require_ios_permission_*` enforcement) and runs at compilation-
  unit scope, reporting once at the first data op; message names the helper-file FP.
- `device_calendar_unchecked_result` → the `Result<void>` assumption is avoided
  entirely: the rule now flags only the **discarded bare-statement await** of a data
  op (no return-type reasoning). The stored-but-unchecked case is covered by
  `..._result_data_before_success_check`.
- `device_calendar_event_missing_calendar_id` → intra-function flow implemented:
  inline `createOrUpdateEvent(Event(...))` plus the variable path (`final e = Event(...)`
  → `createOrUpdateEvent(e)`), with an intervening `e.calendarId = ...` setter
  rescuing it (no false positive).

### Delivered

`device_calendar_missing_permission_check` (INFO), `device_calendar_unchecked_result`,
`device_calendar_retrieve_events_empty_params`,
`device_calendar_retrieve_events_missing_end_date`,
`device_calendar_event_missing_calendar_id` (ERROR),
`device_calendar_event_utc_timezone`,
`device_calendar_result_data_before_success_check`. All gated by
`fileImportsPackage(PackageImports.deviceCalendar)`; detection is syntactic
(constructor names + method-name member scans). `RuleType.bug`/`codeSmell`.
Comprehensive tier. Registered across all five sites.

### Verification

- `dart analyze --fatal-infos` → No issues found. Unit (14) + registration integrity pass.
- **Scan-verified (6/7 fire):** `missing_permission_check`, `unchecked_result`,
  `result_data_before_success_check`, `retrieve_events_empty_params`,
  `retrieve_events_missing_end_date`, `event_missing_calendar_id` all fire on their
  BAD case (the constructor rules verified with explicit `new`, since an unresolved
  mock parses a bare `Foo()` as a call, not a constructor).

### Not yet verified

- `device_calendar_event_utc_timezone` — uses the same `InstanceCreationExpression`
  mechanism as the verified constructor rules, but its **named** constructor
  `TZDateTime.utc` cannot be triggered in an unresolved mock (the parser reads
  `TZDateTime.utc` as a prefixed type). It fires in resolved code; not positively
  scan-verified here.
- The stored-but-unchecked `Result` case (beyond a `.data` read) is intentionally
  out of `unchecked_result`'s scope.
