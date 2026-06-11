# Plan: new `geocoding` lint rules

**Package:** geocoding ^4.0.0 (Saropa Contacts).
**saropa_lints coverage:** none (new file).
**Scope:** correctness, best-practice, migration (3.x → 4.x locale API).
**Related existing rules:** `geolocator_rules.dart` covers `geolocator` (a different package) and already has `prefer_geocoding_cache` — that rule must NOT be duplicated here; the rules below are orthogonal to it.

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `geocoding_unchecked_first` | correctness | `.first` / `.last` on `locationFromAddress` or `placemarkFromCoordinates` result without isEmpty / length guard | report-only | ERROR | only flags when the call is the immediate receiver of the `.first`/`.last` property access on the awaited list, resolved via library URI |
> **VALIDATION (2026-06-11) — OVERLAP:** `avoid_unsafe_collection_methods` (collection_rules.dart:386) already flags .first/.last/.single on API results; keep only if the geocoding-specific message is wanted.
| `geocoding_missing_exception_handler` | correctness | `locationFromAddress` / `placemarkFromCoordinates` call not enclosed in a try-catch that catches `PlatformException` or `NoResultFoundException` | report-only | WARNING | only within async contexts; skip if already inside a catch clause |
| `geocoding_prefer_no_result_found_catch` | best-practice | catch clause that catches `PlatformException` but not `NoResultFoundException` around a geocoding call | report-only | INFO | only fires when a geocoding call is present in the try body |
| `geocoding_locale_set_before_call` | migration/correctness | `locationFromAddress` or `placemarkFromCoordinates` called without a prior `setLocaleIdentifier` call in the same function body, when the project ships localized content | report-only | INFO | false-positive escape: skip if `setLocaleIdentifier` is called at any point earlier in the same enclosing function body |
> **VALIDATION (2026-06-11) — GUARD NEEDED:** single-locale apps never call setLocaleIdentifier → systematic FP.
| `geocoding_concurrent_locale_race` | correctness | `setLocaleIdentifier` called inside a loop body or alongside multiple concurrent geocoding `await` calls (parallel futures) | report-only | WARNING | only flags when `setLocaleIdentifier` appears inside a `for`/`while` body or between two unawaited geocoding futures |
> **VALIDATION (2026-06-11) — GUARD NEEDED:** over-fires on single-locale loops.
| `geocoding_missing_is_present_check` | best-practice | any geocoding call site not preceded by an `isPresent()` guard in the same function body | report-only | INFO | skip if caller is already inside a guard (null-check, early return) that wraps the whole body |
> **VALIDATION (2026-06-11) — GUARD NEEDED:** inter-procedural FP; INFO, low value.
| `geocoding_call_in_text_field_listener` | performance | `locationFromAddress` or `placemarkFromCoordinates` directly inside a `TextEditingController.addListener` callback or `onChanged` handler, without a visible debounce/throttle pattern | report-only | WARNING | only flags when the geocoding call is a direct await inside the listener body with no `Timer` / `debounce` / `Debounce` symbol visible in the enclosing closure |
> **VALIDATION (2026-06-11) — GUARD NEEDED:** debounce detection misses RxDart debounceTime / custom debounce utils.
| `geocoding_deprecated_locale_param` | migration | call to `locationFromAddress` or `placemarkFromCoordinates` with a `localeIdentifier:` named argument (removed in 3.0.0; does not compile, but guards upgrade paths) | report-only | ERROR | fires only when the named argument `localeIdentifier:` is present |

---

## Rule detail

### `geocoding_unchecked_first`

- **What/why:** `locationFromAddress` and `placemarkFromCoordinates` both return `Future<List<...>>`. The list may be empty when the platform geocoder finds no result (especially on simulators, in areas with no data, or after rate-limiting). Calling `.first` or `.last` on an empty list throws `StateError: No element`. This is the single most common crash pattern in geocoding code.
- **Detection (AST, type-safe):**
  Match a `PropertyAccess` or `PrefixedIdentifier` where the property name is `first` or `last`. Walk up to find whether the receiver is an `AwaitExpression` (or the result of one stored in a variable assigned from `locationFromAddress`/`placemarkFromCoordinates`). Resolve the enclosing method invocation element and confirm its enclosing library URI is `package:geocoding/geocoding.dart`. Guard: skip if the call is inside an `if (list.isNotEmpty)` / `if (list.length > 0)` block in the same scope.
- **Fix:** report-only. A mechanical replacement from `.first` → `.firstOrNull ?? <fallback>` cannot know the caller's intended fallback — document that `firstOrNull` from `package:collection` is the safe accessor.
- **False positives:** accessing `.first` on a user-declared `List<Placemark>` that was NOT directly returned from a geocoding call. Guard: element resolution to library URI prevents bare-name collisions.

---

### `geocoding_missing_exception_handler`

- **What/why:** The platform geocoder throws `PlatformException` for network errors (`IO_ERROR`) and not-found errors (`NOT_FOUND`), and `NoResultFoundException` when the address/coordinates yield no results. Unhandled, these propagate as uncaught exceptions that crash or silently drop the operation. Both are documented in the Baseflow issues tracker (issues #18, #23, #98).
- **Detection (AST, type-safe):**
  Match `MethodInvocation` where the static element's enclosing library URI is `package:geocoding/geocoding.dart` and the method name is `locationFromAddress` or `placemarkFromCoordinates`. Walk up the AST: if the node is NOT enclosed in a `TryStatement`'s try-body at any level, report. Also report if enclosed in a try-body whose `catch` clauses do not name `PlatformException` or `NoResultFoundException`.
- **Fix:** report-only. Inserting a try-catch without knowing the caller's error-handling strategy would be presumptuous.
- **False positives:** callers that use `Future.catchError(...)` rather than try-catch. This shape is partially detectable (check for `.catchError` chain on the same expression), but may miss indirect wrappers. The rule is best-effort; the false-positive rate is accepted and documented.

---

### `geocoding_prefer_no_result_found_catch`

- **What/why:** Before geocoding 2.x, all failure cases surfaced as `PlatformException`. In 2.x+, the package added `NoResultFoundException` specifically for the no-results case. Code written against the old API only catches `PlatformException` and will miss `NoResultFoundException`, causing unhandled exceptions in the no-results path.
- **Detection (AST, type-safe):**
  Find `TryStatement` nodes whose try-body contains a `locationFromAddress` or `placemarkFromCoordinates` call (resolved to `package:geocoding`). Inspect the catch clauses: if the clause list contains a clause matching `PlatformException` but none matching `NoResultFoundException`, report on the catch clause token.
- **Fix:** report-only. Adding a catch clause requires knowing the desired handling logic.
- **False positives:** code that intentionally re-throws or re-wraps `NoResultFoundException` inside the `PlatformException` handler. Rare; document as known acceptable FP.

---

### `geocoding_locale_set_before_call`

- **What/why:** In geocoding 3.0.0 the `localeIdentifier` parameter was removed from `locationFromAddress` and `placemarkFromCoordinates`. Locale must now be set once via `setLocaleIdentifier(...)` before each geocoding call. Omitting it means results are returned in the device's system locale, which may not match the app's selected language — a silent localization regression.
- **Detection (AST, type-safe):**
  Match `locationFromAddress` / `placemarkFromCoordinates` calls resolved to `package:geocoding`. Walk the enclosing function body: check whether `setLocaleIdentifier` (also resolved to `package:geocoding`) appears as a preceding statement or await expression in the same body. If absent, report as INFO.
- **Fix:** report-only. The correct locale value depends on app state unknown at the call site.
- **False positives:** apps that only support one locale and never need to call `setLocaleIdentifier`. This is a genuine FP class; severity kept at INFO. Apps can suppress per-call-site if single-locale design is intentional.

---

### `geocoding_concurrent_locale_race`

- **What/why:** `setLocaleIdentifier` mutates global shared state on both iOS and Android. If multiple concurrent geocoding calls use different locales (e.g., translating a list of coordinates in parallel), the locale set by one call may bleed into another. This is a documented race condition (Baseflow issue #198). The fix is to serialize geocoding calls when locale matters, not to fire them concurrently.
- **Detection (AST, type-safe):**
  Match `setLocaleIdentifier` calls inside a loop body (`ForStatement`, `WhileStatement`, `DoStatement`), OR where `setLocaleIdentifier` appears between two `locationFromAddress`/`placemarkFromCoordinates` calls that are each awaited inside a `Future.wait([...])` argument list or similar parallel-execution pattern.
- **Fix:** report-only. Serialization requires architectural changes.
- **False positives:** sequential single-locale use inside a loop where locale does not change between iterations. The rule does not attempt to track the locale value — it flags any `setLocaleIdentifier` inside a loop as risky, which may over-fire. Severity WARNING is appropriate.

---

### `geocoding_missing_is_present_check`

- **What/why:** `isPresent()` returns `false` when the Android device lacks the geocoder backend (common on older or de-Googled Android devices). Calling geocoding functions on such a device always throws. Checking `isPresent()` before any geocoding call allows graceful degradation.
- **Detection (AST, type-safe):**
  Match `locationFromAddress` / `placemarkFromCoordinates` calls resolved to `package:geocoding`. Walk up to the enclosing function body: if `isPresent` (also from `package:geocoding`) does not appear anywhere in that body as a function call result, report as INFO.
- **Fix:** report-only. The check must be wired to a UI affordance the linter cannot know.
- **False positives:** functions that are already called from an outer scope that already called `isPresent()`. This is an inter-procedural FP the rule cannot eliminate; severity INFO is appropriate.

---

### `geocoding_call_in_text_field_listener`

- **What/why:** geocoding is rate-limited at the platform level. Calling `locationFromAddress` inside a `TextEditingController.addListener` callback or a `TextField`'s `onChanged` handler fires a geocoding request on every keystroke. The platform geocoder will respond with `IO_ERROR` (rate limit) after a handful of calls, or degrade silently. A debounce `Timer` of 300–500ms is the standard mitigation.
- **Detection (AST, type-safe):**
  Match `addListener` `MethodInvocation` where the target element's static type library URI contains `flutter/src/widgets/text_editing_controller` (or the type name is `TextEditingController`). Also match assignment of a `Function` to an `onChanged` named parameter of a `TextField` or `TextFormField`. Inside the callback body, if `locationFromAddress` or `placemarkFromCoordinates` (resolved to `package:geocoding`) is present and no `Timer`, `debounce`, or `Debounce` identifier appears in the same closure body, report.
- **Fix:** report-only. Timer-based debounce requires state that the linter cannot insert automatically.
- **False positives:** apps using a reactive stream with debounce applied upstream (e.g., RxDart `debounceTime`). The debounce symbol heuristic may miss these; severity WARNING. If the outer stream has debounce, the listener would typically not call geocoding directly — acceptable FP surface.

---

### `geocoding_deprecated_locale_param`

- **What/why:** geocoding 3.0.0 removed the `localeIdentifier` named parameter from `locationFromAddress` and `placemarkFromCoordinates`. Code using the old API will fail to compile against 3.x/4.x. This rule catches the pattern during migration when a codebase is being upgraded from 2.x and the parameter is still present in source.
- **Detection (AST, type-safe):**
  Match `MethodInvocation` where method name is `locationFromAddress` or `placemarkFromCoordinates` AND a named argument with label `localeIdentifier` is present in the argument list. Resolution to `package:geocoding` library URI confirms the target package.
- **Fix:** mechanical. Remove the `localeIdentifier:` named argument and insert `await setLocaleIdentifier(<value>);` on the line immediately before the call. The fix can be made automatic because the transformation is deterministic.
- **False positives:** a user-defined function with the same name taking `localeIdentifier`. Library URI resolution eliminates this.

---

## Not lint-able (runtime-only concerns)

- **Per-request rate limiting:** the platform rate limit is enforced by the OS, not detectable statically. The `geocoding_call_in_text_field_listener` rule approximates the most common structural footgun but cannot cover all callsites.
- **Empty list on specific network conditions:** whether a call will return an empty list depends entirely on runtime state (GPS, network, device). The linter can only flag failure to HANDLE an empty result (`geocoding_unchecked_first`), not predict when it will occur.
- **Locale format validity:** whether a string passed to `setLocaleIdentifier` is a valid BCP-47 tag is a data concern, not statically decidable from the AST when the value is a variable.

---

## Implementation note

New file: `lib/src/rules/packages/geocoding_rules.dart`.

Registration:
1. **`lib/saropa_lints.dart`** `_allRuleFactories` (~line 157): add one entry per class (`GeocodingUncheckedFirstRule.new`, etc.).
2. **`lib/src/tiers.dart`**: assign rule codes — `geocoding_unchecked_first` and `geocoding_deprecated_locale_param` → `recommendedOnlyRules`; remaining rules → `comprehensiveOnlyRules`.
3. **`analysis_options.yaml`** (root): confirm `example*/` dirs are already excluded (they are per CLAUDE.md note).
4. **`ROADMAP.md`**: add section for geocoding rules.
5. **`CHANGELOG.md`**: add under `[Unreleased]`.

All rules use `SaropaLintRule` base class, `runWithReporter`, and resolve targets via element library URI — never bare method-name string matching.

---

## Sources

- [geocoding | Flutter package (pub.dev)](https://pub.dev/packages/geocoding)
- [geocoding changelog (pub.dev)](https://pub.dev/packages/geocoding/changelog)
- [geocoding Dart API docs](https://pub.dev/documentation/geocoding/latest/geocoding/)
- [placemarkFromCoordinates API](https://pub.dev/documentation/geocoding/latest/geocoding/placemarkFromCoordinates.html)
- [locationFromAddress API](https://pub.dev/documentation/geocoding/latest/geocoding/locationFromAddress.html)
- [Race condition with setLocaleIdentifier — Baseflow issue #198](https://github.com/Baseflow/flutter-geocoding/issues/198)
- [PlatformException(NOT_FOUND) — Baseflow issue #18](https://github.com/Baseflow/flutter-geocoding/issues/18)
- [PlatformException(IO_ERROR) — Baseflow issue #23](https://github.com/Baseflow/flutter-geocoding/issues/23)
- [flutter-geocoding README](https://github.com/Baseflow/flutter-geocoding/blob/main/geocoding/README.md)
- [flutter-geocoding example/main.dart](https://github.com/baseflow/flutter-geocoding/blob/main/geocoding/example/lib/main.dart)
