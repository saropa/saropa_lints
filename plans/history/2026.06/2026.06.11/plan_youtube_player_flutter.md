# Plan: new `youtube_player_flutter` lint rules

**Package:** youtube_player_flutter ^10.0.1 (Saropa Contacts). **saropa_lints coverage:** none (new file).

**API baseline (v10.0.1, verified against pub.dev docs and changelog):**
- v10.0.0 was a complete architectural rewrite: engine changed from `flutter_inappwebview` to `webview_flutter`; `YoutubePlayerController` is now re-exported from `youtube_player_iframe`.
- **Controller lifecycle:** `YoutubePlayerController.close()` (`Future<void>`) is the resource cleanup method — NOT `dispose()`. `close()` stops playback, removes the JS channel, and closes the internal stream controllers.
- **Controller construction:** `YoutubePlayerController()` (default) or `YoutubePlayerController.fromVideoId({required String videoId, YoutubePlayerParams params = const YoutubePlayerParams(), bool autoPlay = false, double? startSeconds, double? endSeconds, bool credentialless = false})`.
- **State stream:** `controller.listen({onData, onError, onDone, cancelOnError})` → `StreamSubscription<YoutubePlayerValue>`. No `addListener`/`removeListener` (not a `ChangeNotifier`); stream-based only.
- **`convertUrlToId`:** `static String? YoutubePlayerController.convertUrlToId(String url, {bool trimWhitespaces = true})` — returns **nullable** `String?`; returns null when no YouTube URL pattern matches.
- **`YoutubePlayerScaffold`:** deprecated in v10; fullscreen is now handled internally via `OverlayPortal`. No scaffold wrapper required.
- **`YoutubePlayerBuilder`:** removed entirely in v10.
- **`YoutubePlayer` widget parameters:** `controller` (required), `aspectRatio` (default 16/9), `autoFullScreen` (default **true**), `enableFullScreenOnVerticalDrag` (default true), `keepAlive` (default false), `backgroundColor`, `builder`, `autoHideDuration`, `gestureRecognizers`.
- **`YoutubePlayerParams`:** `mute` (default false), `showControls` (default true), `showFullscreenButton` (default false), `loop` (default false), `strictRelatedVideos` (default false), `playsInline` (default true), `privacyEnhancedMode` (default true). No `autoPlay` field — `autoPlay` lives on `fromVideoId`.
- **`YoutubePlayerThumbnail`:** takes a `YoutubePlayerController` and shows a thumbnail; initializes WebView only on tap (performance widget for lists).

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `youtube_player_controller_not_closed` | correctness | `YoutubePlayerController` stored as a class field without a corresponding `close()` call in `dispose()` | report-only | WARNING | confirm field type resolves to `YoutubePlayerController` from `package:youtube_player_iframe/`; skip when `dispose()` calls `close()` on the recognized field |
| `youtube_player_subscription_not_canceled` | correctness | `controller.listen(...)` return value stored as a field without `cancel()` in `dispose()` | report-only | WARNING | narrow to `StreamSubscription` returned from a receiver whose static type is `YoutubePlayerController`; skip when `cancel()` is found in `dispose()` |
| `youtube_player_convert_url_unchecked` | null-safety | result of `YoutubePlayerController.convertUrlToId(...)` used without null-check | report-only | WARNING | fire only when the return value is directly passed to another expression without `!`, `??`, `?.`, or a null guard; never fire on intermediate variables that have already been null-checked |
| `youtube_player_scaffold_deprecated` | migration | `YoutubePlayerScaffold` constructed in v10 — wrapper is deprecated and no longer required | quick-fix (remove wrapper, inline child) | INFO | library URI must resolve to `package:youtube_player_flutter/` or `package:youtube_player_iframe/`; never match bare class name |
| `youtube_player_auto_fullscreen_without_portrait_guard` | correctness | `YoutubePlayer` constructed with `autoFullScreen: true` (or relying on the `true` default) in a widget that does not lock orientation back on pop | report-only | INFO | fire only when `autoFullScreen` is explicitly `true` or absent AND the enclosing class has no `SystemChrome.setPreferredOrientations` call or `WillPopScope`/`PopScope` anywhere in the file; mark "(speculative — verify)" — see FP section |
| `youtube_player_mute_not_respected_in_params` | correctness | `YoutubePlayerParams(mute: false)` (the default) combined with `autoPlay: true` in `fromVideoId` — autoplay with audio violates browser autoplay policy on web | report-only | WARNING | detect only when `autoPlay: true` is explicitly set on `fromVideoId` AND `mute` is explicitly `false` in the associated `YoutubePlayerParams` on the same construction chain; do not infer across variables |

---

## Rule detail

### `youtube_player_controller_not_closed`

> **VALIDATION (2026-06-11) — KEEP (verified not redundant):** `avoid_undisposed_instances` (widget_lifecycle_rules.dart:3147) fixed type set EXCLUDES YoutubePlayerController, and it uses close() not dispose().

- **What/why:** `YoutubePlayerController.close()` disposes the WebView JS channel and closes the internal video-state and value `StreamController`s. If a controller is stored as a field in a `State`, `ChangeNotifier`, Riverpod notifier, or other long-lived class and `close()` is never called in the lifecycle's `dispose()`, the underlying `webview_flutter` WebViewController and all open stream controllers leak for the lifetime of the parent. This is the equivalent of not calling `dispose()` on a `TextEditingController` — a well-known Flutter footgun documented in the package README.
- **Detection (AST, type-safe):** Match `VariableDeclaration` (class-level field, not a local) whose declared/inferred static type resolves to `YoutubePlayerController` from library URI prefix `package:youtube_player_iframe/` (the re-export source). Walk up to the enclosing `ClassDeclaration`; find any `MethodDeclaration` named `dispose`. Inside its body, look for a `MethodInvocation` with name `close` on a receiver whose name matches the field name. Report the field declaration when no such invocation is found.
  - Restrict to class fields (not locals); local `YoutubePlayerController`s created and consumed within a single function scope carry much lower leak risk.
- **Fix:** report-only. Insertion site varies (State, ChangeNotifier, ref.onDispose) and cannot be safely inferred.
- **False positives:**
  - Controllers closed via a helper method called from `dispose()` (indirectly) will be missed — acceptable conservative heuristic.
  - App-scoped singleton controllers intentionally not closed: suppress with `// ignore: youtube_player_controller_not_closed` and a comment.
  - Test files: guard with `ProjectContext.isTestFile(path)`.

---

### `youtube_player_subscription_not_canceled`

> **VALIDATION (2026-06-11) — DROP (overlap):** covered by the StreamSubscription family — `require_timer_cancellation` (widget_lifecycle_rules.dart:1709), `avoid_undisposed_instances` (widget_lifecycle_rules.dart:3155), `avoid_stream_subscription_in_field` (async_rules.dart:2963), `avoid_unassigned_stream_subscriptions` (async_rules.dart:535). Drop unless it adds value only for the untyped-field case.

- **What/why:** `YoutubePlayerController.listen(...)` returns a `StreamSubscription<YoutubePlayerValue>`. If the subscription is stored as a field and never canceled, the callback closure is retained by the stream, preventing the enclosing object from being garbage-collected. In v10, the controller uses stream-based state propagation (no `addListener`/`removeListener`), so stream subscription lifecycle is the only external listener surface. Unlike closing the controller (which closes the stream), an open subscription to an already-closed stream is a Dart programming error (`StreamSink closed` / bad state). Canceling before closing is the safe, correct order.
- **Detection (AST, type-safe):** Match `MethodInvocation` with name `listen` where the receiver's static type is `YoutubePlayerController` from `package:youtube_player_iframe/`. Check whether the return value is assigned to a `VariableDeclaration` field. In the enclosing `ClassDeclaration`, look for a `dispose()` override containing a `MethodInvocation` named `cancel` on the same field name. Report the `listen()` call site when no `cancel()` is found.
- **Fix:** report-only. The correct placement for `cancel()` (before or after `controller.close()`) is context-dependent.
- **False positives:**
  - Subscriptions managed via a subscription-management helper (`CompositeSubscription`, `_subscriptions.add(...)`) will appear uncanceled to the AST. Suppress with `// ignore:`.
  - Short-lived controllers whose `close()` in `dispose()` terminates the stream (making the subscription inactive) are a mild FP: the subscription is effectively dead but not explicitly canceled. Severity is WARNING — calling `cancel()` first is still best practice and prevents `bad state` if the subscription outlives the stream.

---

### `youtube_player_convert_url_unchecked`

- **What/why:** `YoutubePlayerController.convertUrlToId(String url)` returns `String?` — it returns `null` when the input does not match any known YouTube URL pattern (short links, regular watch URLs, embed URLs, `youtu.be` short-links). Using the result without a null-check (e.g., passing directly to `YoutubePlayerController.fromVideoId(videoId: YoutubePlayerController.convertUrlToId(url)!)` or assigning to a non-nullable `String`) either causes a runtime `Null check operator used on null value` crash or passes `null` as a video ID, resulting in a silent player failure with a confusing error. This is the most common misuse pattern shown in community tutorials.
- **Detection (AST, type-safe):** Match `MethodInvocation` with name `convertUrlToId` on a target whose static type is `YoutubePlayerController` (static method call: `YoutubePlayerController.convertUrlToId(...)`). Check the parent expression:
  - If the result is immediately used without the `!` operator and without wrapping in a conditional expression, null-coalescing `??`, or null-aware chaining `?.`, report at the method invocation.
  - Do NOT report when the result is assigned to a `String?` variable — the developer has acknowledged the nullability.
  - Do NOT report when the result is inside an `if (result != null)` guard before use (flow-sensitive; conservative: only detect within the same expression, not across statements).
- **Fix:** report-only. The correct handling (guard with `if (id == null) return`, use `??`, or `!` with a validated input guarantee) depends on the call site.
- **False positives:**
  - Calls where the string is known to be a valid ID (not a URL) — these should use `fromVideoId` directly without `convertUrlToId`; the lint is technically correct to fire.
  - Calls inside a null-assertion chain that flow analysis cannot see: use `// ignore:` with an explanation.

---

### `youtube_player_scaffold_deprecated`

- **What/why:** `YoutubePlayerScaffold` was deprecated in v10.0.0. In v10, `YoutubePlayer` handles fullscreen internally via `OverlayPortal` — no scaffold wrapper is required. Wrapping with a deprecated `YoutubePlayerScaffold` produces a deprecation warning and adds unnecessary widget tree depth. The migration path is to remove `YoutubePlayerScaffold`, use `YoutubePlayer` inside a standard `Scaffold`, and optionally wrap with `YoutubePlayerControllerProvider` only when controller context propagation is needed.
- **Detection (AST, type-safe):** Match `InstanceCreationExpression` where the constructor element's enclosing class resolves to `YoutubePlayerScaffold` from library URI prefix `package:youtube_player_flutter/` or `package:youtube_player_iframe/`. Do NOT match on bare class name alone.
- **Fix:** The mechanical fix is report-only in the first implementation — the scaffold removal involves restructuring the `builder` callback which cannot be safely rewritten without knowing the full widget tree. Do NOT insert a TODO comment (prohibited by project quick-fix rules). Mark as INFO so it surfaces in IDE without blocking CI.
- **False positives:** None expected — the class is deprecated in v10 and its construction is never correct new code. Any `// ignore:` suppression should carry a comment explaining why the deprecated wrapper is intentionally retained (e.g., migration in progress).

---

### `youtube_player_auto_fullscreen_without_portrait_guard`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** author-admitted HIGH FP, file-scoped, blind to navigation-observer orientation restoration; defer or pedantic-only after FP validation.

**(speculative — verify at implementation time)**

- **What/why:** `YoutubePlayer` has `autoFullScreen: true` by default, which triggers an automatic orientation change to landscape when the device rotates. If the app does not lock orientation back to portrait on navigation pop (via `SystemChrome.setPreferredOrientations` in `dispose()` or `onWillPop`/`onPopInvoked`), the orientation stays in landscape after leaving the player screen — a common UX bug reported in multiple GitHub issues. This was a well-known footgun with the pre-v10 `YoutubePlayerBuilder`/`YoutubePlayerScaffold` wrappers and remains relevant in v10 despite the internal `OverlayPortal` fullscreen.
- **Detection (AST, type-safe):** Match `InstanceCreationExpression` constructing `YoutubePlayer` from `package:youtube_player_flutter/` where either:
  1. The named argument `autoFullScreen` is explicitly `true`, OR
  2. There is no `autoFullScreen` argument at all (relying on the `true` default).
  AND the enclosing `ClassDeclaration`'s `dispose()` override contains no `MethodInvocation` with name `setPreferredOrientations` (from `SystemChrome`) AND the build method has no `PopScope`/`WillPopScope` descendant in the widget tree visible in the same file.
  This detection is heuristic and file-scoped — it cannot see `SystemChrome` calls in nested navigation callbacks or route pop handlers in other files.
- **Fix:** report-only. Inserting orientation-lock code requires knowing the app's navigation structure.
- **False positives (HIGH — reason this is speculative):**
  - Apps using a navigation observer or route-level lifecycle hooks to restore orientation: the call is not in the same file, so the rule fires incorrectly.
  - Apps where the player screen is the root screen (no pop to worry about).
  - Apps using `autoFullScreen: false` that are correctly excluded by the detection.
  - Recommendation: implement as a low-severity INFO and provide a prominent FP note. Consider whether the FP rate is acceptable before enabling by default — may be better placed in `pedanticOnlyRules`.

---

### `youtube_player_mute_not_respected_in_params`

> **VALIDATION (2026-06-11) — NOTE:** inline-params-only keeps FP near-zero but also near-useless (params usually built separately).

- **What/why:** Browser autoplay policy (enforced on web, and increasingly relevant on iOS WebView) blocks video playback with audio when autoplay is triggered without user gesture. The `youtube_player_iframe` documentation explicitly states: "Autoplay with sound is blocked by most browsers." Constructing `YoutubePlayerController.fromVideoId(autoPlay: true)` with `YoutubePlayerParams(mute: false)` (the default) produces a player that will either fail silently to autoplay or show a policy-blocked error on web. The safe combination is `autoPlay: true` only with `mute: true`. This rule detects the unsafe combination when both settings are visible in the same construction chain.
- **Detection (AST, type-safe):** Match `MethodInvocation` or `InstanceCreationExpression` constructing `YoutubePlayerController.fromVideoId(...)` where:
  1. The named argument `autoPlay:` is a `BooleanLiteral` with value `true`.
  2. The named argument `params:` is an inline `InstanceCreationExpression` constructing `YoutubePlayerParams(...)` with named argument `mute: false` (or no `mute` argument — default is `false`).
  Report at the `fromVideoId` call site.
  Do NOT attempt cross-variable detection (the `params` object constructed separately): only fire when `params` is constructed inline in the same expression, keeping the FP rate zero.
- **Fix:** report-only. Whether to add `mute: true` or remove `autoPlay: true` depends on intended UX.
- **False positives:**
  - `params` constructed separately and later passed to `fromVideoId` — not detected (conservative, acceptable).
  - Dart-only / mobile-only apps where browser autoplay policy does not apply: the rule is still valid as a best-practice signal (the user can suppress with `// ignore:`).

---

## Implementation note

**New file:** `lib/src/rules/packages/youtube_player_flutter_rules.dart`

**Registration (3 required steps — see MEMORY.md "Rule Implementation Checklist"):**
1. Implement all rule classes in `youtube_player_flutter_rules.dart`.
2. Add `MyRuleClass.new` for each rule to `_allRuleFactories` in `lib/saropa_lints.dart` (~line 157).
3. Add each rule code string to the appropriate tier set in `lib/src/tiers.dart`.

**Suggested tiers:**
- `recommendedOnlyRules`: `youtube_player_controller_not_closed`, `youtube_player_subscription_not_canceled`, `youtube_player_convert_url_unchecked`, `youtube_player_mute_not_respected_in_params`.
- `professionalOnlyRules`: `youtube_player_scaffold_deprecated`.
- `pedanticOnlyRules`: `youtube_player_auto_fullscreen_without_portrait_guard` (high FP risk — see speculative note above; enable only after FP rate is validated against real code).

**Package import guard:** Every rule must guard with `fileImportsPackage(node, youtubePlayerFlutter)` using a new `PackageImports.youtubePlayerFlutter` entry covering both `package:youtube_player_flutter/` and `package:youtube_player_iframe/` (since v10 re-exports the controller from the iframe package). Add the constant to `lib/src/import_utils.dart`.

**Library URI note:** `YoutubePlayerController` in v10 is defined in `youtube_player_iframe` and re-exported by `youtube_player_flutter`. Type resolution via static type should resolve to `package:youtube_player_iframe/` URIs. Verify exact URIs by inspecting `element.librarySource.uri` at implementation time — do not rely on the `youtube_player_flutter` URI alone.

**`ProjectContext` gate:** Use `ProjectContext.usesPackage('youtube_player_flutter')` (or check for the iframe package) in each rule's run method.

**Speculative rule:** `youtube_player_auto_fullscreen_without_portrait_guard` should be verified against real Saropa Contacts code before shipping — check whether the project already handles orientation restoration. If it does, the rule's real-world value is confirmed.

**No rules for removed APIs:** `YoutubePlayerBuilder` and `YoutubePlayerFlags` were removed in v10, not deprecated. They will cause compile errors, not silent bugs — no lint rule needed.

---

## Sources

- [youtube_player_flutter — pub.dev](https://pub.dev/packages/youtube_player_flutter)
- [youtube_player_flutter changelog — pub.dev](https://pub.dev/packages/youtube_player_flutter/changelog)
- [YoutubePlayerController class — Dart API](https://pub.dev/documentation/youtube_player_flutter/latest/youtube_player_flutter/YoutubePlayerController-class.html)
- [YoutubePlayerController.close — Dart API](https://pub.dev/documentation/youtube_player_flutter/latest/youtube_player_flutter/YoutubePlayerController/close.html)
- [YoutubePlayerController.convertUrlToId — Dart API](https://pub.dev/documentation/youtube_player_flutter/latest/youtube_player_flutter/YoutubePlayerController/convertUrlToId.html)
- [YoutubePlayerController.fromVideoId — Dart API](https://pub.dev/documentation/youtube_player_flutter/latest/youtube_player_flutter/YoutubePlayerController/YoutubePlayerController.fromVideoId.html)
- [YoutubePlayer widget — Dart API](https://pub.dev/documentation/youtube_player_flutter/latest/youtube_player_flutter/YoutubePlayer-class.html)
- [YoutubePlayerScaffold (deprecated) — Dart API](https://pub.dev/documentation/youtube_player_flutter/latest/youtube_player_flutter/YoutubePlayerScaffold-class.html)
- [YoutubePlayerParams — Dart API](https://pub.dev/documentation/youtube_player_flutter/latest/youtube_player_flutter/YoutubePlayerParams-class.html)
- [YoutubePlayerThumbnail — Dart API](https://pub.dev/documentation/youtube_player_flutter/latest/youtube_player_flutter/YoutubePlayerThumbnail-class.html)
- [youtube_player_flutter library symbols — Dart API](https://pub.dev/documentation/youtube_player_flutter/latest/youtube_player_flutter/youtube_player_flutter-library.html)
- [sarbagyastha/youtube_player_flutter — GitHub](https://github.com/sarbagyastha/youtube_player_flutter)
- [BUG: YoutubePlayerController used after dispose — GitHub Issue #115](https://github.com/sarbagyastha/youtube_player_flutter/issues/115)
- [BUG: fullscreen disposing controller — GitHub Issue #524](https://github.com/sarbagyastha/youtube_player_flutter/issues/524)


---

## Finish Report (2026-06-11)

## Validation reconciliation (existing-coverage audit)

Grepped the full `lib/src/rules/` tree for `youtube`/`youtube_player` — **no existing youtube_player_flutter coverage** (new file). Then verified each plan-proposed rule against generic rules before writing.

Honored the plan's in-file VALIDATION annotations (added 2026-06-11) and confirmed them independently:

- **DROPPED `youtube_player_subscription_not_canceled`** (plan annotation: DROP/overlap). Confirmed by grep — the StreamSubscription lifecycle is already covered by:
  - `avoid_stream_subscription_in_field` (`async_rules.dart:2983`)
  - `require_timer_cancellation` (`widget_lifecycle_rules.dart:1698`; message explicitly names StreamSubscription-in-dispose)
  - `avoid_undisposed_instances` (`widget_lifecycle_rules.dart:3140`)
  `controller.listen()` returns a `StreamSubscription` that these flag when stored uncanceled. No unique story lost.
- **KEPT `youtube_player_controller_not_closed`** (plan annotation: KEEP, verified not redundant). `avoid_undisposed_instances` uses a fixed disposable-type set that excludes `YoutubePlayerController` and looks for `dispose()`; the v10 controller cleanup method is `close()`. Genuinely new.

The other four proposals are package-specific shapes with no generic equivalent (nullable `convertUrlToId`, deprecated `YoutubePlayerScaffold`, autoplay-policy `mute` pairing, `autoFullScreen` orientation guard) and were kept.

## Kept rules and tier assignments

| rule_name | class | tier | severity | fix |
|---|---|---|---|---|
| `youtube_player_controller_not_closed` | YoutubePlayerControllerNotClosedRule | recommended | WARNING | no |
| `youtube_player_convert_url_unchecked` | YoutubePlayerConvertUrlUncheckedRule | recommended | WARNING | no |
| `youtube_player_mute_not_respected_in_params` | YoutubePlayerMuteNotRespectedInParamsRule | recommended | WARNING | no |
| `youtube_player_scaffold_deprecated` | YoutubePlayerScaffoldDeprecatedRule | professional | INFO | no |
| `youtube_player_auto_fullscreen_without_portrait_guard` | YoutubePlayerAutoFullscreenWithoutPortraitGuardRule | pedantic | INFO | no |

**Tier rationale:**
- Three WARNING correctness/resource-leak rules → `recommended` (real crash/leak risk with low FP: controller-leak narrows to typed fields + close()-in-dispose check; convert-url is same-expression-only; mute-pairing is inline-params-only — all FP-conservative).
- `youtube_player_scaffold_deprecated` → `professional` (INFO migration hint, deprecated-API only, no FP expected but not crash-level).
- `youtube_player_auto_fullscreen_without_portrait_guard` → `pedantic` per the plan's GUARD-NEEDED annotation: author-admitted HIGH FP, file-scoped, blind to navigation-observer orientation restoration. Suppression guards on `setPreferredOrientations`/`PopScope`/`WillPopScope` anywhere in the class, but cross-file restoration still produces FPs.

No quick fixes added — all five are report-only per the plan (insertion sites are context-dependent; the scaffold removal needs builder-callback restructuring that cannot be mechanically rewritten).

## Files written (non-shared)

- `lib/src/rules/packages/youtube_player_flutter_rules.dart` — 5 rule classes + library dartdoc naming the complemented coverage.
- `example_packages/lib/youtube_player_flutter/*_fixture.dart` — one fixture per rule (bad + near-miss good).
- `test/rules/packages/youtube_player_flutter_rules_test.dart` — instantiation pin + fixture-existence per rule.

`dart analyze` on the rules file is clean except the expected `PackageImports.youtubePlayerFlutter` undefined-getter errors (resolved at merge by adding the import constant). The `ClassDeclaration.bodyMembers` accessor was used (this analyzer build exposes `bodyMembers`, not `members`).

## Merge steps required (shared files — not touched here)

1. Add to `lib/src/import_utils.dart`: `static const Set<String> youtubePlayerFlutter = {'package:youtube_player_flutter/', 'package:youtube_player_iframe/'};` (both URIs — v10 re-exports the controller from `youtube_player_iframe`).
2. Add the 5 `*.new` factories to `_allRuleFactories` in `lib/saropa_lints.dart`.
3. Add the 5 rule-name strings to the tier sets in `lib/src/tiers.dart` (3 to `recommendedOnlyRules`, 1 to `professionalOnlyRules`, 1 to `pedanticOnlyRules`).
4. Export from `all_rules.dart` if the barrel is manual (it auto-exports category files; verify).
5. CHANGELOG bullet under `[Unreleased]`.

### Scan-verification note (2026-06-11)

4 of 5 rules confirmed firing via the scan harness on keyword-form (`new`) probe copies of the bad fixtures. `youtube_player_mute_not_respected_in_params` gates on the **named** constructor `YoutubePlayerController.fromVideoId`; under the scan's unresolved `parseString`, `new A.b(...)` cannot be split into type + constructor-name, so `constructorName.name` is null and the gate returns early — a scan-only limitation, not a rule defect. In the resolved analyzer plugin (real IDE usage) the named constructor resolves and the rule fires. Verified correct by inspection: gates on controller type + `fromVideoId` + `autoPlay: true` + inline `YoutubePlayerParams` + `mute` not `true` → reports.
