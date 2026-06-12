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

## ERROR re-evaluation (gated — needs sign-off)

Once a rule's helper-delegation FP is resolved, it becomes a candidate to flip WARNING -> ERROR.
The flip stays gated per the SEV-01 process (a build-breaking ERROR false positive breaks every
consumer). Candidates after rollout: the rules above whose ONLY residual was helper delegation.
`require_stream_subscription_cancel` (collection-ownership), `require_image_disposal`
(parent-owned), and the non-leak NEEDS_DISCUSSION rules are NOT addressed by this capability and
stay WARNING.
