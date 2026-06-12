# Interprocedural (cross-method) cleanup tracking

## Why

The SEV-01 Bucket B audit (see `plans/history/2026.06/2026.06.12/SEV01_SEVERITY_AUDIT.md`)
left ~9 leak/disposal rules at WARNING with one shared residual false positive: cleanup performed
in a **helper method** that single-method AST scanning cannot see. The classic shape:

```dart
void dispose() { _teardown(); super.dispose(); }
void _teardown() { _socket.close(); }   // a dispose-body scan never sees this
```

The old workaround treated *any* receiver-less private call inside `dispose()` as cleanup. That was
wrong in both directions — it mis-suppressed a genuine leak when the helper did NOT clean up, and it
was too imprecise to justify a build-breaking ERROR. This work replaces that guess with a real
same-class call-graph walk, which is the capability the SEV-01 audit named as the trigger to
re-evaluate those rules for ERROR.

## Capability (landed)

`lib/src/interprocedural_cleanup_utils.dart`:
- `reachableSameClassMethods(start, classNode)` — `start` plus every method of the class
  transitively reachable by a same-class call (receiver-less `_teardown()` or `this._teardown()`).
  AST-only (resolves callees by name within the class body), cycle-safe, bounded by method count.
  Calls through a field/getter receiver or to inherited/mixed-in methods are intentionally not
  followed (would need the element model and could leave the class).
- `anyReachableBody(start, classNode, predicate)` — true if `predicate` holds for `start`'s body or
  any reachable same-class method body. The rule supplies the cleanup predicate (regex/AST).

Tests: `test/interprocedural_cleanup_utils_test.dart` (8 cases) — direct cleanup, called helper,
transitive chain, `this.`-prefixed call, **uncalled helper does NOT suppress** (the false-negative
the old heuristic had), field-receiver call not followed, mutually-recursive helpers terminate.

## Rollout status

All applicable rules done. Each was verified via the scan CLI: it fires on a real leak (helper
does nothing) and is silent on the helper-delegation case (cleanup extracted into a helper).

| Rule | File | Status |
|------|------|--------|
| `require_websocket_close` | resources/resource_management_rules.dart | DONE — class-based; follows dispose() into same-class helpers |
| `require_platform_channel_cleanup` | resources/resource_management_rules.dart | DONE — class-based; replaced the bare-helper heuristic |
| `require_file_close_in_finally` | resources/resource_management_rules.dart | DONE — per-method; follows the opener's same-class helpers |
| `require_http_client_close` | resources/resource_management_rules.dart | DONE — per-method; follows the opener's same-class helpers |
| `require_native_resource_cleanup` | resources/resource_management_rules.dart | DONE — per-method; follows helpers for an explicit `free()` only |

Per-method rules resolve the enclosing class via `node.thisOrAncestorOfType<ClassDeclaration>()`
(a MethodDeclaration's direct parent is the ClassBody in analyzer 10+, not the ClassDeclaration).

### Not applicable (interprocedural same-class walk does not address their residual)

| Rule | Why not |
|------|---------|
| `require_isolate_kill` | Already scans the WHOLE class for `.kill(`, so a kill in a helper is already recognized. Its residual is an intentional app-lifetime worker that never kills — not a helper case. |
| `require_database_close` | Its residual is a `Future<Database>` factory whose CALLER (a different class/scope) closes the connection — cross-class, not same-class-helper. Same-class walk cannot see the caller. |
| `require_field_dispose` | Already has its own helper expansion (`_expandMethodCalls`, depth-limited). Its residuals are AutoDispose-mixin disposal and the lexeme-only `State` check — neither is a helper-delegation FP. |

## ERROR re-evaluation (done 2026-06-12)

Each of the 5 rolled-out rules was re-audited for residuals BEYOND helper delegation:

- **`require_platform_channel_cleanup` → flipped to ERROR.** Helper teardown is now followed
  interprocedurally, and the setup trigger is AST-based (a string literal mentioning
  `setMethodCallHandler` no longer triggers it — the same self-trigger class the isolate rule had).
  An un-torn-down handler crashes with setState on an unmounted widget. Verified via scan CLI:
  fires (severity ERROR) on a real handler with no teardown; silent on the string-mention and
  cleaned cases.
- **`require_websocket_close` → kept WARNING.** Added a parent-owned-socket skip (`= widget.x`),
  but kept WARNING NOT for lack of precision: `avoid_websocket_memory_leak` already covers the
  constructed-channel leak at ERROR, so promoting this too would double-report ERROR on the same
  code. Stays the broader WARNING (it also catches dart:io `WebSocket`).
- **`require_file_close_in_finally`, `require_http_client_close`, `require_native_resource_cleanup`
  → kept WARNING.** Per-method, local-handle rules: a handle passed to a top-level/other-class
  function that closes it, or wrapped in a returned object, escapes the same-class walk and would
  be a build-breaking false positive at ERROR. Acceptable as a warning, not as an error.

Net: 1 flipped (platform_channel), 4 kept WARNING with the residual named at each rule's
`severity:` field. `require_stream_subscription_cancel` (collection-ownership) and
`require_image_disposal` (parent-owned) are not addressed by this capability and stay WARNING.

## Finish Report (2026-06-12)

### What changed and why

Several leak/disposal lint rules detected the absence of a cleanup call by scanning a single
method body. When teardown was moved out of `dispose()` into a helper — the routine extract-method
refactor `dispose()` → `_teardown()` → `_socket.close()` — that scan saw no close and reported a
leak that did not exist. The prior workaround treated any receiver-less private call inside
`dispose()` as cleanup, which was wrong in both directions: it suppressed a genuine leak when the
helper did NOT clean up, and was too imprecise to support ERROR severity.

A reusable capability resolves this by following the call graph instead of guessing.
`lib/src/interprocedural_cleanup_utils.dart` adds `reachableSameClassMethods(start, classNode)` —
the start method plus every method transitively reachable from it by a same-class invocation
(receiver-less or `this.`-prefixed). It is AST-only (callees resolved by name against the class's
own declarations, which is sound because a class cannot declare two methods with one name), so it
runs in the single-file analysis path; it is cycle-safe and bounded by the class's method count.
`anyReachableBody(start, classNode, predicate)` runs a cleanup predicate over the start body and
every reachable helper body.

Five resource-cleanup rules now use it: `require_websocket_close` and
`require_platform_channel_cleanup` (class-based, follow `dispose()` into helpers) and
`require_file_close_in_finally`, `require_http_client_close`, `require_native_resource_cleanup`
(per-method, follow the opener's same-class helpers). `require_native_resource_cleanup` follows only
an explicit `free()` into helpers, not the structural `finally`/`Arena`/`using` patterns, which
describe a method's own scope and would over-suppress if matched in an unrelated helper.

The per-method rules resolve their enclosing class with
`node.thisOrAncestorOfType<ClassDeclaration>()`. A `MethodDeclaration`'s direct parent is the
`ClassBody` in analyzer 10+, not the `ClassDeclaration`, so a plain `node.parent is ClassDeclaration`
check silently disabled the helper follow — surfaced by scan-CLI verification, which showed the
rules firing on the helper-delegation case before the ancestor lookup was corrected.

### ERROR re-evaluation outcome

`require_platform_channel_cleanup` was promoted to ERROR: its substring setup trigger
(`classSource.contains('setMethodCallHandler')`, which a string literal or comment could trip) was
replaced with an AST visitor requiring a real `setMethodCallHandler`/`receiveBroadcastStream`
invocation, and teardown is followed interprocedurally. An un-torn-down handler fires callbacks
after dispose and crashes with setState on an unmounted widget. `require_websocket_close` gained a
parent-owned-socket skip (`= widget.x`) but stays WARNING because `avoid_websocket_memory_leak`
already covers the constructed-channel leak at ERROR and a second ERROR would double-report on the
same code. The three per-method rules stay WARNING: a local handle passed to a function in another
file (or wrapped in a returned object) escapes the same-class walk, which is acceptable for a
warning but would be a build-breaking false positive at ERROR.

### Verification

`lib/src/interprocedural_cleanup_utils.dart` is covered by
`test/interprocedural_cleanup_utils_test.dart` (8 cases): direct cleanup, called helper, transitive
chain, `this.`-prefixed call, uncalled-helper-does-NOT-suppress (the false negative the old
heuristic produced), field-receiver-not-followed, and mutually-recursive-helper termination. Each
rule change was verified end-to-end with the scan CLI on fixtures pairing a helper-delegation case
(must not fire) against a real-leak case (must fire); `require_platform_channel_cleanup` was
additionally confirmed to fire at severity ERROR on a real handler, stay silent on a string-literal
mention and on a cleaned class, and `require_websocket_close` to skip a `= widget.channel` field.
`dart analyze --fatal-infos` is clean across the package; the affected rule, integrity
(anti-pattern `.contains()` gate), and utility test suites pass.

### Files

- Added: `lib/src/interprocedural_cleanup_utils.dart`,
  `test/interprocedural_cleanup_utils_test.dart`
- Modified: `lib/src/rules/resources/resource_management_rules.dart` (5 rules + 1 severity flip),
  `CHANGELOG.md`

Finish report appended: plans/INTERPROCEDURAL_CLEANUP_TRACKING.md
Plan archived: plans/INTERPROCEDURAL_CLEANUP_TRACKING.md → plans/history/2026.06/2026.06.12/INTERPROCEDURAL_CLEANUP_TRACKING.md
No bug archive — task did not close a bugs/*.md file
