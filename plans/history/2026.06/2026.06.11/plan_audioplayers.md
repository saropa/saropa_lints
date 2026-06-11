# Plan: new `audioplayers` lint rules

**Package:** audioplayers ^6.7.1 (Saropa Contacts). **saropa_lints coverage:** none (new file).

**API baseline (v6.7.1, verified):**
- `AudioPlayer` constructor: `AudioPlayer({String? playerId})` — UUID auto-assigned when omitted.
- Lifecycle: `play(Source, {volume, balance, ctx, position, mode})`, `pause()`, `resume()`, `stop()`, `seek()`, `release()`, `dispose()`.
- `dispose()` calls `release()` then closes all `StreamController`s. After disposal, the instance must not be reused.
- `release()` stops playback, frees native resources, and clears `_source`; does NOT close streams.
- Sources (sealed class hierarchy): `AssetSource`, `UrlSource`, `DeviceFileSource`, `BytesSource`.
- Streams: `onPlayerStateChanged`, `onPositionChanged`, `onDurationChanged`, `onPlayerComplete`, `onSeekComplete`, `onLog`.
- `ReleaseMode` enum (camelCase): `release` (default), `loop`, `stop`.
- `PlayerMode` enum: `mediaPlayer` (default), `lowLatency`.
- `lowLatency` mode: no `onPositionChanged`, no `onDurationChanged`, no `onPlayerComplete` events, no `seek()` support.
- `AudioCache` still exists in `audioplayers_internal`; the public `AudioPlayer` uses it internally for `AssetSource` — direct user construction is unnecessary and was marked as an anti-pattern in the migration guide.
- `AudioPool`: pool of pre-loaded `AudioPlayer`s; has its own `dispose()`.

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `audioplayers_player_not_disposed` | correctness | `AudioPlayer` constructed as a field without a corresponding `dispose()` call that calls `player.dispose()` | report-only | WARNING | skip when `dispose()` override calls `player.dispose()` on a recognized field; see FP section |
> **VALIDATION (2026-06-11) — KEEP (verified not redundant):** generic `require_dispose_implementation` (disposal_rules.dart:2109) hardcoded _disposableTypes EXCLUDES AudioPlayer/AudioPool.
| `audioplayers_stream_subscription_not_canceled` | correctness | `StreamSubscription` returned from `player.onXxx.listen(...)` stored in a field without a `cancel()` in `dispose()` | report-only | WARNING | same class-level `dispose()` presence check; narrow to subscriptions on `AudioPlayer` stream members |
> **VALIDATION (2026-06-11) — DROP (overlap):** covered by `require_stream_subscription_cancel` (disposal_rules.dart:1147) + `avoid_unassigned_stream_subscriptions` (async_rules.dart:552).
| `audioplayers_direct_audio_cache_construction` | best-practice | `AudioCache()` constructed directly by user code (non-internal) | report-only | INFO | library-URI check: `AudioCache` from `package:audioplayers_internal/audio_cache.dart` or `package:audioplayers/src/audio_cache.dart`; skip when called from a sub-class of `AudioPlayer` |
> **VALIDATION (2026-06-11) — FEASIBILITY:** AudioCache library URI is unverified (audioplayers_internal vs re-export); pin the URI before building.
| `audioplayers_low_latency_with_stream_listen` | correctness | `player.onPositionChanged.listen()`, `player.onDurationChanged.listen()`, or `player.onPlayerComplete.listen()` on a player whose `setPlayerMode(PlayerMode.lowLatency)` or `play(..., mode: PlayerMode.lowLatency)` is called in the same class/function | report-only | WARNING | only fire when `PlayerMode.lowLatency` is verifiably set on the same player expression in the same enclosing scope |
> **VALIDATION (2026-06-11) — GUARD NEEDED:** relies on same-name cross-statement variable matching (fragile); keep speculative, same-function-body only.
| `audioplayers_low_latency_with_seek` | correctness | `player.seek(...)` called on a player whose mode is `PlayerMode.lowLatency` in the same scope | report-only | WARNING | same `PlayerMode.lowLatency` scope check |
> **VALIDATION (2026-06-11) — GUARD NEEDED:** relies on same-name cross-statement variable matching (fragile); keep speculative, same-function-body only.
| `audioplayers_release_mode_loop_with_complete_listener` | best-practice | `onPlayerComplete.listen(...)` on a player that has `setReleaseMode(ReleaseMode.loop)` — `onPlayerComplete` does not fire in loop mode | report-only | INFO | confirm `ReleaseMode.loop` is set on the same player expression in the same class |
> **VALIDATION (2026-06-11) — GUARD NEEDED:** relies on same-name cross-statement variable matching (fragile); keep speculative, same-function-body only.
| `audioplayers_pool_not_disposed` | correctness | `AudioPool` constructed (via `AudioPool.create()` / `AudioPool.createFromAsset()`) without a corresponding `dispose()` call | report-only | WARNING | same class-level dispose check as `audioplayers_player_not_disposed` |
> **VALIDATION (2026-06-11) — KEEP (verified not redundant):** generic `require_dispose_implementation` (disposal_rules.dart:2109) hardcoded _disposableTypes EXCLUDES AudioPlayer/AudioPool.
| `audioplayers_url_source_in_asset_context` | best-practice | `UrlSource` constructed with a string that starts with `assets/` (should be `AssetSource`) | mechanical fix (swap to `AssetSource(path)`) | WARNING | literal string only; do NOT flag variables or expressions |
| `audioplayers_hardcoded_volume_above_one` | correctness | `setVolume(n)` or `play(..., volume: n)` where `n` is a numeric literal > 1.0 (API clamps but signals a misunderstanding) | report-only | WARNING | literals only; skip variables and expressions |

---

## Rule detail

### `audioplayers_player_not_disposed`

- **What/why:** `AudioPlayer` holds native platform resources (Android `MediaPlayer`/`SoundPool`, iOS `AVAudioPlayer`) and a set of open `StreamController`s. If the instance is stored as a field in a `StatefulWidget.State`, a `ChangeNotifier`, or any other long-lived class and `dispose()` is never called, both the native handle and the Dart stream objects leak for the lifetime of the parent object. This is the most commonly reported audio memory leak in the Flutter community and in the official getting-started guide, which explicitly shows calling `player.dispose()` in `State.dispose()`.
- **Detection (AST, type-safe):** Match `VariableDeclaration` (field or top-level) whose static type resolves to `AudioPlayer` from library URI `package:audioplayers/audioplayers.dart`. Check whether the enclosing `ClassDeclaration` has a method named `dispose` that contains, somewhere in its body, a `MethodInvocation` with method name `dispose` on a receiver whose static type is `AudioPlayer`. If no such invocation is found, report the field declaration. Restrict to class-level fields (not local variables — locals created and used within a single function body are lower risk and subject to much higher FP rates).
- **Fix:** report-only. The caller decides where in their lifecycle to place `dispose()` (State, ChangeNotifier, provider scope) — no mechanical insertion is safe.
- **False positives:**
  - Players disposed via a helper method (not directly in `dispose()`) will be missed — acceptable; the rule is a conservative heuristic, not a proof.
  - Players used in short-lived objects that are themselves discarded without `dispose()` — the rule fires, but the underlying leak is real.
  - Tests and example files: suppress via `ProjectContext.isTestFile(path)`.
  - Players intentionally leaked at app scope (one per app) are a real FP. Users should suppress with `// ignore: audioplayers_player_not_disposed` and a comment explaining scope.

---

### `audioplayers_stream_subscription_not_canceled`

- **What/why:** All six event streams on `AudioPlayer` (`onPlayerStateChanged`, `onPositionChanged`, `onDurationChanged`, `onPlayerComplete`, `onSeekComplete`, `onLog`) are continuous broadcast streams. `listen()` returns a `StreamSubscription<T>`. If the subscription is stored in a field and `cancel()` is never called (typically in `dispose()`), the callback closure is retained, preventing the enclosing object from being garbage-collected even after the widget/provider is destroyed. The Dart linter rule `cancel_subscriptions` targets this generally; this rule narrows it to the audioplayers streams specifically and provides an audioplayers-aware message.
- **Detection (AST, type-safe):** Match `MethodInvocation` with name `listen` where the receiver's static type is one of `Stream<PlayerState>`, `Stream<Duration>`, `Stream<void>`, `Stream<String>` — AND the receiver expression is a `PropertyAccess` / `PrefixedIdentifier` whose target's static type is `AudioPlayer` from `package:audioplayers/audioplayers.dart`. When the `listen()` return value is assigned to a field, check the enclosing class for a `dispose()` method containing a `MethodInvocation` named `cancel` on the same field name. Report the `listen()` call site when no `cancel()` is found.
- **Fix:** report-only. Inserting a `cancel()` call requires knowing which `dispose()` to add it to.
- **False positives:** Subscriptions managed via `CompositeSubscription` / `StreamGroup` / `WidgetRef.listen` / `ref.listen` patterns will appear uncanceled to the AST; suppress with `// ignore:`. Subscriptions on a player that is `dispose()`d (which internally closes the StreamControllers) are technically safe — calling `cancel()` on a closed-stream subscription is a no-op, but omitting it is still a code-smell the rule legitimately flags.

---

### `audioplayers_direct_audio_cache_construction`

- **What/why:** Since the v1 Source-based API, `AudioCache` is an internal implementation detail. `AudioPlayer` constructs and manages its own `AudioCache` instance for `AssetSource` playback; end users should never instantiate `AudioCache` directly. The migration guide states: "the `AudioPlayer` itself is now capable of playing audio from any `Source`" and explicitly aimed to "kill" the `AudioCache` API from the user-facing surface. Direct construction bypasses the player's internal cache management, may double-copy assets, and produces code that will break if `AudioCache` is removed from the public API in a future major version.
- **Detection (AST, type-safe):** Match `InstanceCreationExpression` where the constructor element's enclosing class is `AudioCache` from library URI `package:audioplayers_internal/src/audio_cache.dart` (or the re-exported path `package:audioplayers/src/audio_cache.dart` — verify the exact URI at implementation time by checking the package's export tree). Do NOT match on class name alone; resolve via element.
- **Fix:** report-only. The correct replacement is `player.play(AssetSource('path'))` or `player.setSourceAsset('path')`, but the appropriate player instance is unknown from the construction site alone.
- **False positives:** Code that extends or sub-classes `AudioCache` for testing or custom cache directories is a legitimate use; guard by checking that the construction site is not inside a class that `extends AudioCache`.

---

### `audioplayers_low_latency_with_stream_listen`

- **What/why:** `PlayerMode.lowLatency` uses Android's `SoundPool` and iOS's low-level APIs; the native backend does not fire `onPositionChanged`, `onDurationChanged`, or `onPlayerComplete` events. Subscribing to these streams in `lowLatency` mode creates dead listeners that silently never fire — the logic depending on them (progress bars, completion callbacks, duration display) is unreachable. This is documented in the getting-started guide and confirmed in GitHub issues #1489 and #490.
- **Detection (AST, type-safe):** In a single `ClassDeclaration`, detect two patterns on the same receiver variable (matched by identifier name):
  1. `setPlayerMode(PlayerMode.lowLatency)` — `MethodInvocation` with name `setPlayerMode`, argument is `SimpleIdentifier` / `PrefixedIdentifier` resolving to `PlayerMode.lowLatency` from `package:audioplayers/audioplayers.dart`; OR `play(..., mode: PlayerMode.lowLatency)`.
  2. `onPositionChanged.listen(...)`, `onDurationChanged.listen(...)`, or `onPlayerComplete.listen(...)` on the same receiver.
  Report at the `listen()` call site.
- **Fix:** report-only. Whether to switch to `mediaPlayer` mode or remove the listener depends on the use case.
- **False positives:** When the same player switches modes dynamically (calls `setPlayerMode` multiple times with different modes), this rule may false-positive. Narrow by requiring both calls to be in the same function body or `initState`/constructor body for tighter scope matching. Mark as speculative for cross-method cases.

---

### `audioplayers_low_latency_with_seek`

- **What/why:** `seek()` is explicitly documented as unsupported in `PlayerMode.lowLatency` — the backend ignores the call silently. Calling `seek()` in low-latency mode is a no-op, not an error, but signals a misunderstanding of the mode's constraints.
- **Detection (AST, type-safe):** Same dual-pattern detection as `audioplayers_low_latency_with_stream_listen`: find `setPlayerMode(PlayerMode.lowLatency)` and `player.seek(...)` — `MethodInvocation` with name `seek`, receiver static type `AudioPlayer` from `package:audioplayers/audioplayers.dart` — on the same variable in the same class.
- **Fix:** report-only.
- **False positives:** Same cross-method caveat as above; same speculative note.

---

### `audioplayers_release_mode_loop_with_complete_listener`

- **What/why:** In `ReleaseMode.loop`, playback restarts automatically when the audio ends — `onPlayerComplete` is not fired because there is no logical "completion". Code that registers on `onPlayerComplete` to implement loop logic (manual re-play) alongside `setReleaseMode(ReleaseMode.loop)` has dead or double-play logic. The documentation confirms: "`ReleaseMode.loop` — Keeps buffered data and plays again after completion."
- **Detection (AST, type-safe):** In a single `ClassDeclaration`, detect:
  1. `setReleaseMode(ReleaseMode.loop)` — `MethodInvocation` with arg resolving to `ReleaseMode.loop` from `package:audioplayers/audioplayers.dart`.
  2. `onPlayerComplete.listen(...)` on the same receiver variable.
  Report at the `listen()` call site.
- **Fix:** report-only. The developer either wants loop (remove the `onPlayerComplete` listener) or wants completion detection (switch to `ReleaseMode.stop` or `ReleaseMode.release`).
- **False positives:** An `onPlayerComplete` listener used purely for logging or analytics (not re-play logic) is a mild FP — the listener won't fire but the code is not incorrect. Severity is INFO to reflect this.

---

### `audioplayers_pool_not_disposed`

- **What/why:** `AudioPool` manages between `minPlayers` and `maxPlayers` `AudioPlayer` instances, each holding native resources. `AudioPool.dispose()` disposes all of them. A pool stored as a field without a matching `dispose()` call leaks every player it contains.
- **Detection (AST, type-safe):** Match `MethodInvocation` with name `create` or `createFromAsset` where the target static type resolves to `AudioPool` from `package:audioplayers/audioplayers.dart` (static factory methods). Alternatively match `VariableDeclaration` field assignments of type `AudioPool`. Check the enclosing `ClassDeclaration` for a `dispose()` method containing a `MethodInvocation` named `dispose` on the same field name. Report the factory call / field declaration when absent.
- **Fix:** report-only. Same lifecycle reasoning as `audioplayers_player_not_disposed`.
- **False positives:** Same patterns as `audioplayers_player_not_disposed` — helper disposal methods, app-scope singletons. Same `ProjectContext.isTestFile` guard.

---

### `audioplayers_url_source_in_asset_context`

- **What/why:** `UrlSource` is for remote HTTP/HTTPS audio streams. If a developer passes a path like `'assets/sounds/click.wav'` to `UrlSource(...)`, the player will attempt an HTTP request for a literal string `'assets/sounds/click.wav'` instead of loading the bundled asset — resulting in a network error or silent failure. The correct type for bundled assets is `AssetSource('sounds/click.wav')` (the `assets/` prefix is the default `AudioCache.prefix` and is automatically prepended).
- **Detection (AST, type-safe):** Match `InstanceCreationExpression` constructing `UrlSource` from `package:audioplayers/audioplayers.dart` whose single argument is a `StringLiteral` (or adjacent `StringInterpolation` with a literal prefix) that begins with `assets/` or `asset/`. Do NOT match on variable arguments — only literal strings are safe to flag.
- **Fix:** mechanical. Replace `UrlSource('assets/foo.wav')` with `AssetSource('foo.wav')` — strip the `assets/` prefix and swap the constructor name. Safe because the `AudioCache.prefix` default is `'assets/'`.
- **False positives:** A remote server that happens to serve content at a URL path beginning with `assets/` (e.g., `https://cdn.example.com/assets/audio.mp3` — but the `UrlSource` argument would include the full https URL so the `assets/` prefix check would not match). Flag only bare relative paths starting with `assets/` not containing `://`.

---

### `audioplayers_hardcoded_volume_above_one`

- **What/why:** The `setVolume(double)` method and the `volume` parameter in `play()` expect a value in the range `[0.0, 1.0]`. The native backend clamps values above 1.0 silently to 1.0. A literal such as `setVolume(100)` (a common mistake from percentage-scale thinking) will compile and run silently without any feedback that it's wrong — the player just plays at full volume as if `setVolume(1.0)` were called. The clamping behavior is not guaranteed to be stable across platforms.
- **Detection (AST, type-safe):** Match:
  1. `MethodInvocation` with name `setVolume` where the first positional argument is a `DoubleLiteral` or `IntegerLiteral` with numeric value > 1.0, on a receiver whose static type is `AudioPlayer` from `package:audioplayers/audioplayers.dart`.
  2. `MethodInvocation` with name `play` on an `AudioPlayer` receiver, where the named argument `volume:` is a `DoubleLiteral` or `IntegerLiteral` with value > 1.0.
  Literals only — no variables.
- **Fix:** report-only. The correct fix (divide by 100 vs. set to 1.0) depends on developer intent.
- **False positives:** None for literals; numeric literals > 1.0 passed to a volume API are unambiguously wrong.

---

## Implementation note

**New file:** `lib/src/rules/packages/audioplayers_rules.dart`

**Registration (3 required steps — see MEMORY.md "Rule Implementation Checklist"):**
1. Implement all rule classes in `audioplayers_rules.dart`.
2. Add `MyRuleClass.new` for each rule to `_allRuleFactories` in `lib/saropa_lints.dart` (~line 157).
3. Add each rule code string to the appropriate tier set in `lib/src/tiers.dart`.

**Suggested tiers:**
- `comprehensiveOnlyRules`: `audioplayers_player_not_disposed`, `audioplayers_pool_not_disposed`, `audioplayers_stream_subscription_not_canceled`.
- `recommendedOnlyRules`: `audioplayers_low_latency_with_stream_listen`, `audioplayers_low_latency_with_seek`, `audioplayers_url_source_in_asset_context`, `audioplayers_hardcoded_volume_above_one`.
- `professionalOnlyRules`: `audioplayers_release_mode_loop_with_complete_listener`, `audioplayers_direct_audio_cache_construction`.

**Migration rules:** None of the above rules are version-gated because all nine target the v6.x API directly. If rules for pre-v5 deprecated symbols (`AudioCache.play()`, `play(String)`, `setUrl()`, old `UPPER_CASE` enum values) are added later, gate them using the migration-pack recipe in `plans/plan_migration_plugin_system.md`.

**`ProjectContext` gate:** Wrap the entire rule file with a `ProjectContext.usesPackage('audioplayers')` guard inside each rule's `run()` method to avoid false positives in projects that don't use the package.

**Speculative notes (verify at implementation time):**
- The exact library URI for `AudioCache` must be confirmed by inspecting the `audioplayers` package export tree — it may be re-exported via a different path in v6.7.1.
- The cross-method scope limitation for `audioplayers_low_latency_with_stream_listen` and `audioplayers_low_latency_with_seek` means initial implementation should restrict detection to the same function body or `initState`; cross-method tracking requires data-flow analysis beyond standard AST visitors.
- `AudioPlayer` stream property types (`Stream<PlayerState>`, `Stream<Duration>`, `Stream<void>`) should be confirmed against the live `audioplayer.dart` source before implementing `audioplayers_stream_subscription_not_canceled`.

---

## Sources

- [AudioPlayer class — audioplayers Dart API](https://pub.dev/documentation/audioplayers/latest/audioplayers/AudioPlayer-class.html)
- [AudioPool class — audioplayers Dart API](https://pub.dev/documentation/audioplayers/latest/audioplayers/AudioPool-class.html)
- [ReleaseMode enum — audioplayers Dart API](https://pub.dev/documentation/audioplayers/latest/audioplayers/ReleaseMode.html)
- [PlayerMode enum — audioplayers Dart API](https://pub.dev/documentation/audioplayers/latest/audioplayers/PlayerMode.html)
- [audioplayers package — pub.dev](https://pub.dev/packages/audioplayers)
- [audioplayers changelog — pub.dev](https://pub.dev/packages/audioplayers/changelog)
- [getting_started.md — bluefireteam/audioplayers GitHub](https://github.com/bluefireteam/audioplayers/blob/main/getting_started.md)
- [migration_guide.md — bluefireteam/audioplayers GitHub](https://github.com/bluefireteam/audioplayers/blob/main/migration_guide.md)
- [AudioPlayer source — bluefireteam/audioplayers GitHub](https://github.com/bluefireteam/audioplayers/blob/main/packages/audioplayers/lib/src/audioplayer.dart)
- [AudioCache source — bluefireteam/audioplayers GitHub](https://github.com/bluefireteam/audioplayers/blob/main/packages/audioplayers/lib/src/audio_cache.dart)
- [Issue #1489: PlayerMode.lowLatency and setReleaseMode don't work together](https://github.com/bluefireteam/audioplayers/issues/1489)
- [Issue #490: iOS Fatal Error with PlayerMode.LOW_LATENCY](https://github.com/bluefireteam/audioplayers/issues/490)
- [cancel_subscriptions — dart.dev linter rules](https://dart.dev/tools/linter-rules/cancel_subscriptions)


---

## Finish Report (2026-06-11)

## audioplayers rules — validation reconciliation and final state

### Prior state discovered
The rules file `lib/src/rules/packages/audioplayers_rules.dart`, all 6 fixtures under `example_packages/lib/audioplayers/`, were already present from an in-progress attempt. Only the test file was missing. I created `test/rules/packages/audioplayers_rules_test.dart` (instantiation pins + fixture-existence checks mirroring `geocoding_rules_test.dart`). No rule logic or fixtures were modified — they already match the live `geocoding_rules.dart` / `image_picker_rules.dart` conventions (`SaropaLintRule`, `runWithReporter`, `fileImportsPackage(node, PackageImports.audioplayers)`, `ReplaceNodeFix` for the one quick fix).

### Reconciliation against existing coverage (grepped `lib/src/rules/` before keeping anything)
The plan proposed 9 rules. Three were dropped as duplicates of shipped rules:

| Dropped proposal | Subsumed by | Note |
|---|---|---|
| `audioplayers_player_not_disposed` | `require_media_player_dispose` (disposal_rules.dart:85-96) | Its `_mediaControllerTypePatterns` already includes `\bAudioPlayer\b`. The plan's KEEP note cited only the generic `require_dispose_implementation`; it overlooked the dedicated media-player rule. |
| `audioplayers_direct_audio_cache_construction` | `require_media_player_dispose` lists `\bAudioCache\b` | The plan also flagged the AudioCache library URI as unverified/infeasible. Dropped rather than guess a URI. |
| `audioplayers_stream_subscription_not_canceled` | `require_stream_subscription_cancel` (disposal_rules.dart:1147) + `avoid_unassigned_stream_subscriptions` (async_rules.dart:552) | Matches the plan's own DROP annotation. |

`AudioPool` is genuinely uncovered — no existing disposal rule lists it — so `audioplayers_pool_not_disposed` was kept.

### Kept rules and tier assignments (6)

| rule | type | severity | tier | fix | rationale |
|---|---|---|---|---|---|
| `audioplayers_pool_not_disposed` | bug | WARNING | comprehensive | no | Heuristic field/dispose match (same-class), conservative; comprehensive keeps it opt-in for stricter consumers. |
| `audioplayers_low_latency_with_stream_listen` | bug | WARNING | recommended | no | Real dead-code bug (events never fire in lowLatency); tightly scoped to same member body, low FP — earns recommended. |
| `audioplayers_low_latency_with_seek` | bug | WARNING | recommended | no | `seek()` is a silent no-op in lowLatency; same same-body guard, low FP. |
| `audioplayers_release_mode_loop_with_complete_listener` | codeSmell | INFO | professional | no | Listener never fires under loop, but a logging-only listener is a mild FP — INFO + professional reflects the softer signal. |
| `audioplayers_url_source_in_asset_context` | bug | WARNING | recommended | yes | Literal `assets/` path in `UrlSource` is unambiguously wrong; mechanical fix swaps to `AssetSource` and strips the prefix. |
| `audioplayers_hardcoded_volume_above_one` | bug | WARNING | recommended | no | Numeric literal >1.0 to a 0.0-1.0 volume API is unambiguously wrong (literals only). |

### Verification
`dart analyze lib/src/rules/packages/audioplayers_rules.dart` reports only the expected 6 `undefined_getter` errors for `PackageImports.audioplayers` (one per rule's import gate), resolved by the shared-file merge. No syntax errors, no other diagnostics. Shared files (import_utils.dart, all_rules.dart, saropa_lints.dart, tiers.dart, CHANGELOG.md) were not touched, per scope.

