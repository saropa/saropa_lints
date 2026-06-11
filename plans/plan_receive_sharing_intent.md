# Plan: new `receive_sharing_intent` lint rules

**Package:** receive_sharing_intent ^1.8.1 (Saropa Contacts). **saropa_lints coverage:** none (new file).

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `rsi_stream_subscription_not_canceled` | correctness | `getMediaStream().listen(…)` call whose `StreamSubscription` is not canceled in a `dispose()` method in the same class | report-only | WARNING | skip when the subscription variable is passed to a helper, stored in a field managed by another mixin, or the class is not a `State`/`ChangeNotifier`/`StatefulWidget` host |
| `rsi_missing_initial_media` | correctness | `getMediaStream()` called in a file that contains no `getInitialMedia()` call | report-only | WARNING | skip test files; skip if the class explicitly routes only to the warm-share path by design (no AST-detectable marker—document FP class) |
| `rsi_missing_reset_after_initial_media` | correctness | `getInitialMedia()` call in a `.then()` or `await` context with no `reset()` call reachable in the same callback/async block | report-only | WARNING | skip if `reset()` is called in a separate lifecycle method that the developer chains manually (speculative — verify); only fire when `reset()` is entirely absent from the containing class |
| `rsi_unchecked_shared_media_list` | correctness | result of `getInitialMedia()` or stream value from `getMediaStream()` accessed with `.first`, `.last`, or `[0]` without an `isNotEmpty`/`isEmpty` guard | mechanical fix: wrap access with `if (list.isNotEmpty)` guard | ERROR | only trigger on direct list-element access; skip if the access is already inside a guarded `if`/`?.` block |
| `rsi_unfiltered_shared_media_type` | best-practice | stream listener or `.then()` callback on `getMediaStream()`/`getInitialMedia()` that accesses `SharedMediaFile` items without any check on `.type` (i.e., no reference to `SharedMediaType` anywhere in the callback body) | report-only | INFO | skip if the handler explicitly processes ALL types equally by design; only fire when the callback body uses `.path` or similar fields but never references `.type` |

---

## Rule detail

### `rsi_stream_subscription_not_canceled`

> **VALIDATION (2026-06-11) — DROP (overlap):** covered by the StreamSubscription family (`require_timer_cancellation` widget_lifecycle_rules.dart:1709, `avoid_undisposed_instances` widget_lifecycle_rules.dart:3155, `avoid_stream_subscription_in_field` async_rules.dart:2963). Drop unless untyped-field-specific.

- **What/why:** `ReceiveSharingIntent.instance.getMediaStream()` returns a broadcast `Stream<List<SharedMediaFile>>`. Every `.listen()` call allocates a `StreamSubscription`; if it is never canceled the native platform channel keeps delivering events to a dead widget. This is the single most-cited footgun in the official README and the BLoC migration guide — the canonical example explicitly calls `_intentSub.cancel()` in `dispose()`.
- **Detection (AST, type-safe, library URI):** find every `MethodInvocation` where `methodName.name == 'getMediaStream'` and the resolved element's enclosing library URI starts with `'package:receive_sharing_intent/'`. Walk the parent chain to find the enclosing class declaration. Check whether a `MethodDeclaration` named `dispose` exists in that class body. If it does, check whether any expression statement in its body is a `MethodInvocation` with `methodName.name == 'cancel'` whose target resolves to the same `StreamSubscription` variable as the one assigned from `.listen()`. If no such cancellation exists, report at the `getMediaStream()` call site. Do NOT use bare-name matching on the receiver; require the library URI check via `ImportUtils.fileImportsPackage(node, {'package:receive_sharing_intent/'})` plus the static type of the method's target to be `ReceiveSharingIntent`.
- **Fix:** report-only. The variable name storing the subscription is caller-chosen; auto-inserting a cancel call requires knowing it, which cannot be done safely without a cross-statement rename.
- **False positives:** (a) the subscription is stored in a field of a collaborating class and canceled there — the rule will fire spuriously; recommend the developer use `// ignore: rsi_stream_subscription_not_canceled` with a comment. (b) The class uses `AutoDisposeMixin` or a third-party lifecycle helper that wraps `.cancel()` — those are not detectable from AST alone. (c) The subscription is stored in a list and canceled via `for` loop — the rule must also scan `ForStatement` / `forEach` bodies in `dispose()` for `.cancel()` calls.

---

### `rsi_missing_initial_media`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** file-level guard; warm-share + cold-start in different files → FP.

- **What/why:** The package delivers intents via two separate paths: `getMediaStream()` handles warm-starts (app already running in memory), and `getInitialMedia()` handles cold-starts (app launched *because* of the share). An implementation that only subscribes to `getMediaStream()` silently drops every cold-start share — the user shares a file, the app opens, and nothing happens. This is the second most-reported bug pattern in GitHub issues. Both paths must be wired in the same widget/screen that handles sharing.
- **Detection (AST, type-safe, library URI):** file-level pass. Collect all `MethodInvocation` nodes whose `methodName.name == 'getMediaStream'` AND library URI check passes. Then collect all `MethodInvocation` nodes whose `methodName.name == 'getInitialMedia'` with the same library URI check. If the file contains at least one `getMediaStream` call and zero `getInitialMedia` calls, report on the first `getMediaStream` call site.
- **Fix:** report-only. Inserting `getInitialMedia()` requires knowing the developer's intent-processing logic and state shape; no safe mechanical insertion exists.
- **False positives:** a deliberate architectural split where one widget handles only warm-share and a different file handles cold-start (e.g., the home route calls `getInitialMedia`, a detail route subscribes to `getMediaStream`). The file-level check will fire on the detail route file. Document this FP class; developers should use `// ignore:` with a comment naming the companion file.

---

### `rsi_missing_reset_after_initial_media`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** self-flagged speculative; base-class reset() FP.

- **What/why:** The native layer (both Android and iOS) caches the initial intent until `reset()` is called. Without `reset()`, every subsequent app resume re-delivers the same shared file — the user sees the sharing sheet re-open on the next app launch even if they already processed the file. The official README example calls `ReceiveSharingIntent.instance.reset()` immediately inside the `.then()` callback of `getInitialMedia()`. Omitting it causes the stale-intent-on-resume bug.
- **Detection (AST, type-safe, library URI):** find every `MethodInvocation` where `methodName.name == 'getInitialMedia'` and the library URI check passes. Walk upward to find the enclosing class declaration. Check whether any `MethodInvocation` with `methodName.name == 'reset'` and the same library URI exists anywhere in the enclosing class body. If no `reset()` call is found in the entire class, report at the `getInitialMedia()` call site.
- **Fix:** report-only. The correct placement of `reset()` depends on whether processing is synchronous or async; inserting it in the wrong position (e.g., before async I/O completes) would lose the intent data before it is fully consumed.
- **False positives:** `reset()` called in a separate mixin or base class not visible in the current file. Scope the check to the class body in the current compilation unit only; add a note that a base-class `reset()` will produce a false positive, and the developer should use `// ignore:`.

---

### `rsi_unchecked_shared_media_list`

> **VALIDATION (2026-06-11) — DROP (overlap):** subsumed by `avoid_unsafe_collection_methods` (collection_rules.dart:388) for .first/.last/.single and `prefer_list_first` (collection_rules.dart:1841) for `[0]`.

- **What/why:** Both `getInitialMedia()` (returns `Future<List<SharedMediaFile>>`) and the stream emitted by `getMediaStream()` (emits `List<SharedMediaFile>`) can yield an empty list — for example, when the app is launched normally (not via a share), when the share is canceled mid-flight on some Android OEMs, or when an error occurs in the platform channel (issue #403 reports silent empty results from Google Photos). Code that calls `.first`, `.last`, `[0]`, or `.single` on the result without an `isEmpty` / `isNotEmpty` guard throws a `StateError` (for `.first`/`.last`/`.single`) or `RangeError` (for `[0]`) at runtime.
- **Detection (AST, type-safe, library URI):** find `MethodInvocation` nodes with `methodName.name` in `{'getInitialMedia'}` (or the stream's emitted value). In the `.then()` callback or `await`-ed result assignment, scan the callback body (or subsequent statements) for `PropertyAccess` / `IndexExpression` applied to the result variable with `.first`, `.last`, `.single`, or `[0]`. Check that the enclosing statement or the immediately preceding `if` does NOT contain an `isNotEmpty` or `length > 0` guard on the same variable. Report at the unsafe access site. For the stream case: inside the `.listen()` callback, apply the same check on the emitted `value` parameter.
- **Fix:** mechanical — prepend an `if (list.isNotEmpty)` guard wrapping the existing access. Priority 80.
- **False positives:** the developer has already guarded via a `for` loop (empty list = no iterations = no crash) or `?.` on the element — skip if no unconditional direct element access is found. Also skip if a `if (list.isEmpty) return;` early-return appears before the access in the same block.

---

### `rsi_unfiltered_shared_media_type`

> **VALIDATION (2026-06-11) — GUARD NEEDED:** heuristic (.path used but SharedMediaType unreferenced); helper-method filtering FPs; INFO.

- **What/why:** The Android intent filter in `AndroidManifest.xml` can match multiple MIME types. If the manifest accepts `image/*`, `video/*`, and `*/*`, the callback will receive `SharedMediaFile` objects of type `SharedMediaType.image`, `SharedMediaType.video`, `SharedMediaType.file`, `SharedMediaType.text`, and `SharedMediaType.url`. Code that blindly calls `.path` and passes it to an image decoder will crash or silently produce garbage on video or text items. Filtering on `.type` before processing is a best practice that prevents silent type errors.
- **Detection (AST, type-safe, library URI):** find `.listen()` callbacks attached to `getMediaStream()` calls (library URI check on the `getMediaStream` receiver) and `.then()` callbacks attached to `getInitialMedia()`. Inspect the callback `FunctionExpression` body. Check whether `SharedMediaType` appears anywhere in that body as a `PrefixedIdentifier` or `PropertyAccess` (e.g., `SharedMediaType.image`, `file.type == SharedMediaType.video`). If the body accesses `SharedMediaFile` members (`.path`, `.thumbnail`, `.duration`, `.mimeType`) but contains no reference to `SharedMediaType`, report INFO at the callback site. The library URI for `SharedMediaType` also starts with `'package:receive_sharing_intent/'`.
- **Fix:** report-only. The correct type filter is domain-specific.
- **False positives:** (a) a helper method called from inside the callback does the filtering — that method body is not visible from the call-site AST. In this case the rule fires spuriously; the developer should use `// ignore:`. (b) The app intentionally handles all types identically (e.g., storing the path regardless of type) — this is valid but unusual; again `// ignore:` with a comment. Rate this as INFO precisely to make suppression low-friction.

---

## Implementation note

New file: `lib/src/rules/packages/receive_sharing_intent_rules.dart`

Register all five rule classes in `lib/saropa_lints.dart` by adding them to `_allRuleFactories` (the static list near line 157):
```
ReceiveSharingIntentStreamNotCanceledRule.new,
ReceiveSharingIntentMissingInitialMediaRule.new,
ReceiveSharingIntentMissingResetRule.new,
ReceiveSharingIntentUncheckedMediaListRule.new,
ReceiveSharingIntentUnfilteredTypeRule.new,
```

Add to tier in `lib/src/tiers.dart`:
- `rsi_stream_subscription_not_canceled` → `essentialRules` (memory leak / silent event delivery to dead widget)
- `rsi_missing_initial_media` → `essentialRules` (silent data loss on cold-start)
- `rsi_missing_reset_after_initial_media` → `recommendedOnlyRules` (stale-intent-on-resume, annoying but not a crash)
- `rsi_unchecked_shared_media_list` → `essentialRules` (runtime `StateError`/`RangeError` crash)
- `rsi_unfiltered_shared_media_type` → `comprehensiveOnlyRules` (best-practice guard, INFO severity)

Import guard: every rule's `runWithReporter` must gate on `fileImportsPackage(node, {'package:receive_sharing_intent/'})` before any further AST inspection — identical to the pattern used in `url_launcher_rules.dart` and `geolocator_rules.dart`.

Class names (follow the project's `*Rule` suffix convention):
- `ReceiveSharingIntentStreamNotCanceledRule`
- `ReceiveSharingIntentMissingInitialMediaRule`
- `ReceiveSharingIntentMissingResetRule`
- `ReceiveSharingIntentUncheckedMediaListRule`
- `ReceiveSharingIntentUnfilteredTypeRule`

---

## Sources

- [receive_sharing_intent on pub.dev](https://pub.dev/packages/receive_sharing_intent) — official pub listing, API overview, example code
- [receive_sharing_intent GitHub repo (KasemJaffer)](https://github.com/KasemJaffer/receive_sharing_intent) — README, example/lib/main.dart, 217 open issues
- [receive_sharing_intent Dart API docs](https://pub.dev/documentation/receive_sharing_intent/latest/) — `SharedMediaType` enum values (`image`, `video`, `text`, `file`, `url`), `SharedMediaFile` fields (`path`, `type`, `thumbnail`, `duration`, `mimeType`, `message`)
- [How to receive sharing intents in Flutter — muetsch.io](https://muetsch.io/how-to-receive-sharing-intents-in-flutter.html) — lifecycle pitfall: official docs code only handles closed-app case
- [Flutter BLoC + receive_sharing_intent — Medium](https://mohammedshamseerpv.medium.com/implementing-flutter-bloc-to-handle-receive-sharing-intent-60ea6a3a3fdb) — anti-pattern: `.listen()` without storing or canceling the `StreamSubscription`; potential duplicate delivery from both paths firing simultaneously
- GitHub issue #403 (silent empty result from Google Photos — speculative FP for `rsi_unchecked_shared_media_list`)
