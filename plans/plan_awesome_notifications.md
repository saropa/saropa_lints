# Plan: new `awesome_notifications` lint rules

**Package:** awesome_notifications ^0.11.0 (+ awesome_notifications_core ^0.10.1) (Saropa Contacts). **saropa_lints coverage:** none (new file).

**API baseline (verified from pub.dev documentation, official example, and GitHub issues):**
- `AwesomeNotifications` singleton; import `package:awesome_notifications/awesome_notifications.dart`.
- `initialize(String? defaultIcon, List<NotificationChannel> channels, {List<NotificationChannelGroup>? channelGroups, bool debug, String? languageCode}) → Future<bool>` — MUST be called before any other method; initializes channel registry.
- `setListeners({required ActionHandler onActionReceivedMethod, NotificationHandler? onNotificationCreatedMethod, NotificationHandler? onNotificationDisplayedMethod, ActionHandler? onDismissActionReceivedMethod}) → Future<bool>` — handlers MUST be `static` AND annotated `@pragma('vm:entry-point')` for background-isolate survival; the package emits a runtime error `"is not a valid global or static method"` when a non-static method is passed.
- `createNotification({required NotificationContent content, ...}) → Future<bool>` — silently discards the notification if `channelKey` in `NotificationContent` was not declared in `initialize()`'s channel list.
- `isNotificationAllowed() → Future<bool>` — checks OS-level permission; must be checked before showing notifications; required on Android 13+ and all iOS versions.
- `requestPermissionToSendNotifications({String? channelKey, List<NotificationPermission> permissions}) → Future<bool>`.
- `NotificationContent.id`: `int` — negative values (e.g., `id: -1`) are silently replaced with a random value (documented in changelog v0.6.14: "Defined the final standard to replace negative IDs by random values"). Hard-coded positive IDs cause the previous notification with that ID to be silently replaced.
- Notification handlers use `ReceivedAction` (for action/dismiss) and `ReceivedNotification` (for created/displayed).

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `awesome_notifications_missing_pragma_annotation` | correctness | Method passed as a `setListeners` handler argument that is static but lacks `@pragma('vm:entry-point')` — causes the handler to be tree-shaken in release builds, silently killing background notifications | report-only | WARNING | verify method is `static`; resolve the argument to a `MethodDeclaration` in the same compilation unit; skip if annotation already present |
| `awesome_notifications_non_static_listener` | correctness | Instance (non-static) method passed as a `setListeners` handler argument — the package throws a runtime error: "is not a valid global or static method" | report-only | ERROR | resolve argument to a `MethodDeclaration`; check `isStatic`; skip top-level functions (those ARE valid) |
| `awesome_notifications_undeclared_channel_key` | correctness | `NotificationContent(channelKey: 'x')` where `'x'` is a string literal not present in any `NotificationChannel(channelKey: 'x')` literal argument in the same file's `initialize()` call — notification is silently discarded | report-only | WARNING | literal-to-literal comparison only; skip variables/expressions; only flag when the same file has a resolvable `initialize()` call with a literal-only channel list |
| `awesome_notifications_create_without_permission_check` | best-practice | `AwesomeNotifications().createNotification(...)` call site with no enclosing `isNotificationAllowed()` guard in the same function or method body | report-only | WARNING | allow when the enclosing function name contains `_permissionGranted`, `_allowed`, or is itself named something that documents its precondition; skip `ProjectContext.isTestFile` paths |
| `awesome_notifications_negative_notification_id` | correctness | `NotificationContent(id: <negative literal>)` — negative IDs are silently replaced by a random value, making `cancel(id)` ineffective | mechanical fix (replace with `Random().nextInt(2147483647)` + import guard) | WARNING | integer literal only; do NOT flag variables or expressions |
| `awesome_notifications_hardcoded_notification_id` | best-practice | `NotificationContent(id: <positive non-zero integer literal>)` — hard-coded IDs cause the previous notification with that ID to be silently replaced when the same code path fires more than once | report-only | INFO | skip `id: 0` (common placeholder convention); only flag small positive literals (< 10000) that look like hand-typed constants rather than generated values; guard against test files |
| `awesome_notifications_listeners_before_display` | correctness | `createNotification()` or `requestPermissionToSendNotifications()` invoked before `setListeners()` at the top-level / `main()` call order — notification events are only delivered after `setListeners()` is first called | report-only | WARNING | order-of-call analysis limited to the same `main()` / `initState()` function body; do not attempt cross-function ordering |
| `awesome_notifications_handler_wrong_parameter_type` | correctness | Method used as a `setListeners` handler has a parameter type other than `ReceivedAction` (for `onActionReceivedMethod` / `onDismissActionReceivedMethod`) or `ReceivedNotification` (for `onNotificationCreatedMethod` / `onNotificationDisplayedMethod`) from `package:awesome_notifications/awesome_notifications.dart` — wrong type causes a cast failure at runtime | report-only | ERROR | resolve argument to the `MethodDeclaration`; check first parameter's static type against the expected handler typedef; skip when the argument is not resolvable |

---

## Rule detail

### `awesome_notifications_missing_pragma_annotation`

- **What/why:** `setListeners` delivers notification events to Dart methods invoked from native code — including from a background isolate when the app is killed or suspended. The Dart AOT/tree-shaker removes any Dart symbol that is not reachable through the normal call graph unless it is explicitly preserved. `@pragma('vm:entry-point')` tells the compiler to preserve the method's address so the native layer can call back into Dart. Without the annotation, the handler compiles and works in debug mode (where tree-shaking is disabled) but is silently dropped in profile/release builds, causing background notifications to be received with no Dart handler executing. This is documented in the package README: "You need to use `@pragma('vm:entry-point')` in each static method to identify to the Flutter engine that the dart address will be called from native and should be preserved."
- **Detection (AST, type-safe):** Match `MethodInvocation` with method name `setListeners` on a receiver whose static type is `AwesomeNotifications` from library URI `package:awesome_notifications/awesome_notifications.dart`. For each named argument (`onActionReceivedMethod`, `onNotificationCreatedMethod`, `onNotificationDisplayedMethod`, `onDismissActionReceivedMethod`) whose value is a `PrefixedIdentifier` or `SimpleIdentifier` resolving to a `MethodDeclaration` in the same or imported compilation unit: resolve the `MethodDeclaration`, check that it bears a `NormalAnnotation` or `MarkerAnnotation` whose name resolves to the `pragma` identifier with string argument `'vm:entry-point'`. Report the argument expression when the annotation is absent. Only apply to handlers that are `static` methods (top-level functions do not require the annotation — they are implicitly preserved).
- **Fix:** report-only. Inserting `@pragma('vm:entry-point')` requires locating the method declaration, which may be in a different file; a mechanical fix is theoretically possible but high blast-radius if the declaration is in a shared file. Document expected fix pattern in `correctionMessage`.
- **False positives:** Top-level functions (not class methods) do not require `@pragma('vm:entry-point')` — guard by checking `parent is ClassDeclaration`. Handlers already annotated are excluded by the check. Methods in third-party code not accessible in the compilation unit are unresolvable — skip silently.

---

### `awesome_notifications_non_static_listener`

- **What/why:** The package explicitly requires all `setListeners` handlers to be either top-level functions or `static` class methods. When an instance method is passed, the package detects this at runtime and throws: `"[Awesome Notifications - ERROR]: onActionNotificationMethod is not a valid global or static method."` This means notifications are silently swallowed — no error in debug mode beyond the log message, and the handler never runs in background mode. Because the error is a log message (not an exception), it is easily missed.
- **Detection (AST, type-safe):** Same `setListeners` invocation match as above. For each handler argument that resolves to a `MethodDeclaration` within a `ClassDeclaration`: check `isStatic`. If `!isStatic`, report the argument expression. Do NOT report top-level function references — those are valid. Do NOT report when the argument is a `FunctionExpression` (lambda) — those are a separate concern.
- **Fix:** report-only. Changing an instance method to static changes its access to `this` and requires a design decision about how state is passed in.
- **False positives:** A `static` method that explicitly `@override`s a base class static declaration (unusual but valid Dart) — the `isStatic` check still passes, so no FP. Lambdas/closures passed inline are not resolved to a `MethodDeclaration` and are skipped — they are a runtime error too, but require a different detection path and should be a separate rule if desired in future.

---

### `awesome_notifications_undeclared_channel_key`

> **VALIDATION (2026-06-11) — FEASIBILITY:** needs same-file cross-node correlation (collect initialize() channel-key set, then check NotificationContent(channelKey:)); the "bail on any non-literal key" guard is load-bearing.

- **What/why:** Notifications sent to an undeclared channel are silently discarded by the plugin — no exception, no log in release mode, no user-visible notification. The channel registry is populated exclusively by the `List<NotificationChannel>` passed to `initialize()`. A typo or refactor that renames a channel key in one place but not the other produces invisible notification failure. This is confirmed in GitHub issue #482 ("Notification channel 'basic_channel' does not exist") and in the official documentation: "If you create a notification using an invalid channel key, the notification will be discarded." Notably, even the official `example/lib/main.dart` file contains a mismatch — it declares `'alerts'` in `initialize()` but uses `'basic_channel'` in one `createNotification` call.
- **Detection (AST, type-safe):** Within a single compilation unit: (a) collect all `InstanceCreationExpression`s constructing `NotificationChannel` from `package:awesome_notifications/awesome_notifications.dart` that appear as elements of the `List<NotificationChannel>` literal passed to the second positional argument of `AwesomeNotifications().initialize()`; for each, extract the `channelKey:` named argument when it is a `StringLiteral` and build a `Set<String>` of declared keys. (b) For each `InstanceCreationExpression` constructing `NotificationContent` from the same library where the `channelKey:` argument is a `StringLiteral`, check whether the literal value is in the set. Report the `channelKey:` argument when it is not. Only fire when step (a) found at least one literal key (guard: if `initialize()` uses variables for keys, the rule would produce FPs, so bail out when no literal keys are found in the channel list).
- **Fix:** report-only. The correct fix is to either add the missing channel to `initialize()` or correct the typo — both require human judgment.
- **False positives:** Channel keys set via variables or `const` fields defined in other files will not match. The rule explicitly limits to literal-to-literal comparison, so it never flags what it cannot verify. FP rate is very low when the codebase uses literal channel keys (the dominant pattern).

---

### `awesome_notifications_create_without_permission_check`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** name-heuristic guard blind to permission checks in a separate gating method/file; high FP.

- **What/why:** On Android 13+ (API 33+) and all iOS versions, showing a notification without OS-level permission granted results in a silently ignored notification (Android) or a permission dialog appearing at the worst possible moment (iOS). The official documentation and example code both show the required pattern: `bool isAllowed = await AwesomeNotifications().isNotificationAllowed(); if (!isAllowed) return;` before every `createNotification()` call. Skipping this guard causes invisible notification failures that are hard to diagnose because `createNotification()` returns `true` even when the OS blocks the notification.
- **Detection (AST, type-safe):** Match `MethodInvocation` with name `createNotification` on a receiver whose static type is `AwesomeNotifications` from `package:awesome_notifications/awesome_notifications.dart`. Walk up to the enclosing `FunctionBody` / `BlockFunctionBody` and search for a prior `AwaitExpression` whose expression is a `MethodInvocation` with name `isNotificationAllowed` on an `AwesomeNotifications` receiver. If no such `await` expression exists anywhere in the same function body, report the `createNotification` call site.
- **Fix:** report-only. The permission-check pattern requires an `async` context and may need a rationale dialog — no mechanical single-line fix is safe.
- **False positives:** Functions that accept a `bool isAllowed` parameter and are called only from code that already checked permission will be false-positived. Guard: if the enclosing function has a boolean parameter whose name contains `allowed`, `permitted`, or `isNotification` in any casing, suppress. Additionally, suppress for `ProjectContext.isTestFile(path)`.

---

### `awesome_notifications_negative_notification_id`

- **What/why:** Since changelog v0.6.14, any negative `id` value in `NotificationContent` is silently replaced with a random integer by the plugin. This means: (a) the caller cannot cancel the notification by ID because the ID they passed is not the ID the notification was registered under; (b) `id: -1` is a common copy-paste from tutorials (including the official example) and gives a false sense of explicit control. The behavior is surprising and the silent replacement is not documented at the API call site.
- **Detection (AST, type-safe):** Match `InstanceCreationExpression` constructing `NotificationContent` from `package:awesome_notifications/awesome_notifications.dart`. Check the `id:` named argument; if its value is an `IntegerLiteral` with `intValue < 0`, report the `id:` argument expression.
- **Fix:** mechanical — replace the negative literal with a call to generate a proper random ID, e.g., `Random().nextInt(2147483647)`. The fix builder should also add `import 'dart:math';` if not already present (check existing imports). The `correctionMessage` should explain that the caller must retain the returned ID (or use a known constant) to be able to cancel later.
- **False positives:** None for literals — a negative integer literal passed as `id:` to `NotificationContent` is unambiguously the wrong pattern.

---

### `awesome_notifications_hardcoded_notification_id`

> **VALIDATION (2026-06-11) — DROP (overlap):** thin overlap with `avoid_notification_same_id` (notification_rules.dart:568); the hardcoded-id-overwrite story is already told. Also the `<10000` magic threshold is arbitrary.

- **What/why:** `createNotification()` with a hard-coded positive integer ID (e.g., `id: 1`) causes each subsequent call to silently replace the previously displayed notification that carries the same ID. This is occasionally intentional (progress updates, ongoing-status notifications), but is most often a copy-paste mistake — the developer assumed IDs are irrelevant and picked a small constant. When the app shows multiple independent notifications (e.g., per-contact reminders), they silently overwrite each other. The documentation notes: "If you want to be able to display multiple instances of a specific notification, you must provide a unique id."
- **Detection (AST, type-safe):** Match `InstanceCreationExpression` constructing `NotificationContent` from `package:awesome_notifications/awesome_notifications.dart`. The `id:` argument is an `IntegerLiteral` with `intValue > 0 && intValue < 10000` (threshold chosen to distinguish hand-typed constants from generated values; adjust at implementation time). Report the `id:` argument.
- **Fix:** report-only. Whether to assign unique IDs (e.g., derived from entity primary key) or to use `id: -1` (random) depends on whether the developer wants replace-or-stack behavior.
- **False positives:** Intentional replace semantics (progress notification, ongoing status) are legitimate uses of a stable ID. Severity is INFO to reflect this — the rule is advisory. A `// ignore: awesome_notifications_hardcoded_notification_id` with a comment explaining the replace intent is the correct suppression path.

---

### `awesome_notifications_listeners_before_display`

> **VALIDATION (2026-06-11) — NOTE:** statement-index ordering defeated by any conditional/early-return; low yield, acceptable.

- **What/why:** The package documentation states: "Only after `setListeners` being called, the notification events start to be delivered." Calling `createNotification()` or `requestPermissionToSendNotifications()` before `setListeners()` in the startup sequence means any notification event that fires immediately (e.g., the action that re-launched the app from a tapped notification) is lost because no listener is registered to receive it. The correct order in `main()` / `initState()` is: `initialize()` → `setListeners()` → other calls.
- **Detection (AST, type-safe):** In the body of a single `FunctionDeclaration` or `MethodDeclaration` (restrict to `main`, `initState`, `didChangeDependencies`, and any function that calls all three methods in sequence — i.e., where both `setListeners` and `createNotification`/`requestPermissionToSendNotifications` appear): collect the statement indices (ordinal position in the block) for: (a) `setListeners(...)` on an `AwesomeNotifications` receiver; (b) `createNotification(...)` or `requestPermissionToSendNotifications(...)` on an `AwesomeNotifications` receiver. If any (b) statement appears at a lower index than the first (a) statement, report the (b) call site.
- **Fix:** report-only. Re-ordering async startup calls requires understanding the full init sequence — not mechanically safe.
- **False positives:** Code that conditionally calls `createNotification` (wrapped in an `if`) before `setListeners` may be intentional if the branch cannot reach `createNotification` before listeners are set. The statement-index check is conservative; a more precise analysis would require control-flow analysis beyond AST. Restrict to same-block (same `BlockFunctionBody`) to limit FP surface.

---

### `awesome_notifications_handler_wrong_parameter_type`

- **What/why:** `setListeners` uses `typedef ActionHandler = Future<void> Function(ReceivedAction)` for `onActionReceivedMethod` and `onDismissActionReceivedMethod`, and `typedef NotificationHandler = Future<void> Function(ReceivedNotification)` for `onNotificationCreatedMethod` and `onNotificationDisplayedMethod`. Passing a method with a mismatched parameter type (e.g., `ReceivedNotification` to an `ActionHandler` slot) compiles without error in many IDE configurations because the typedef compatibility check can be deferred, but throws a cast exception at runtime when the handler is invoked. This is a category of mistake that static analysis can fully prevent.
- **Detection (AST, type-safe):** For each named argument of `setListeners(...)` on an `AwesomeNotifications` receiver: resolve the argument to a `MethodDeclaration`; extract the first parameter's declared type; resolve it to its element; check that the library URI begins with `package:awesome_notifications/`. For `onActionReceivedMethod` / `onDismissActionReceivedMethod`: the parameter type must resolve to `ReceivedAction`. For `onNotificationCreatedMethod` / `onNotificationDisplayedMethod`: must resolve to `ReceivedNotification`. Report at the argument expression when the type is wrong or unresolvable to either expected class.
- **Fix:** report-only. The correct fix (change parameter type) requires editing the handler declaration, which may be in a different file.
- **False positives:** Generic-typed handlers, `dynamic` parameters, or handlers using the base class `ReceivedBase` (if one exists in the hierarchy) may be flagged. Guard: if the parameter type's static type is `dynamic`, skip. Only fire when the type is concretely resolved to a known wrong type from `package:awesome_notifications/awesome_notifications.dart`.

---

## Implementation note

New file `lib/src/rules/packages/awesome_notifications_rules.dart`. Register each rule class in `lib/saropa_lints.dart` under `_allRuleFactories` (e.g., `AwesomeNotificationsMissingPragmaAnnotationRule.new`). Add each rule code string to the appropriate tier set in `lib/src/tiers.dart`:

- `awesome_notifications_non_static_listener` → ERROR severity → `essentialRules`
- `awesome_notifications_handler_wrong_parameter_type` → ERROR severity → `essentialRules`
- `awesome_notifications_missing_pragma_annotation` → WARNING → `recommendedOnlyRules`
- `awesome_notifications_undeclared_channel_key` → WARNING → `recommendedOnlyRules`
- `awesome_notifications_create_without_permission_check` → WARNING → `recommendedOnlyRules`
- `awesome_notifications_negative_notification_id` → WARNING → `recommendedOnlyRules`
- `awesome_notifications_listeners_before_display` → WARNING → `professionalOnlyRules`
- `awesome_notifications_hardcoded_notification_id` → INFO → `comprehensiveOnlyRules`

No migration rules are proposed: `awesome_notifications` has no widely-used predecessor package in Saropa Contacts (it was adopted directly); the migration-pack wiring in `plans/plan_migration_plugin_system.md` §2 is therefore not applicable here.

**Key type-safety note for all rules:** NEVER match on class/method name alone. All `AwesomeNotifications`, `NotificationContent`, `NotificationChannel`, `ReceivedAction`, `ReceivedNotification` references must be resolved via element and verified to have library URI starting with `package:awesome_notifications/`. Use `element?.library?.identifier` or `element?.librarySource?.uri?.toString()` at implementation time, following the pattern in `lib/src/rules/packages/workmanager_rules.dart`.

---

## Sources

- [awesome_notifications pub.dev](https://pub.dev/packages/awesome_notifications)
- [awesome_notifications Dart API docs](https://pub.dev/documentation/awesome_notifications/latest/)
- [AwesomeNotifications class API docs](https://pub.dev/documentation/awesome_notifications/latest/awesome_notifications/AwesomeNotifications-class.html)
- [official example main.dart](https://github.com/rafaelsetragni/awesome_notifications/blob/master/example/lib/main.dart)
- [awesome_notifications changelog](https://pub.dev/packages/awesome_notifications/changelog)
- [GitHub issue #482 — channel key does not exist](https://github.com/rafaelsetragni/awesome_notifications/issues/482)
- [awesome_notifications README / pub.dev package page](https://pub.dev/packages/awesome_notifications)
- [Awesome Notifications docs site](https://awesome-notification-docs.vercel.app/)
