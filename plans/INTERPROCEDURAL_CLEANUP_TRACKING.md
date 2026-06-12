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

| Rule | File | Status |
|------|------|--------|
| `require_websocket_close` | resources/resource_management_rules.dart | DONE (pilot) — verified via scan CLI: fires on real leak, not on helper-delegation close |
| `require_platform_channel_cleanup` | resources/resource_management_rules.dart | TODO |
| `require_isolate_kill` | resources/resource_management_rules.dart | TODO |
| `require_file_close_in_finally` | resources/resource_management_rules.dart | TODO |
| `require_database_close` | resources/resource_management_rules.dart | TODO |
| `require_http_client_close` | resources/resource_management_rules.dart | TODO |
| `require_native_resource_cleanup` | resources/resource_management_rules.dart | TODO |
| `require_field_dispose` | widget/widget_lifecycle_rules.dart | TODO |

Each TODO rule replaces its single-method cleanup scan (and any bare-helper heuristic) with
`anyReachableBody(disposeMethod, classNode, <cleanup predicate>)`, and updates its
`// SEV-01` comment to reflect the resolved FP.

## ERROR re-evaluation (gated — needs sign-off)

Once a rule's helper-delegation FP is resolved, it becomes a candidate to flip WARNING -> ERROR.
The flip stays gated per the SEV-01 process (a build-breaking ERROR false positive breaks every
consumer). Candidates after rollout: the rules above whose ONLY residual was helper delegation.
`require_stream_subscription_cancel` (collection-ownership), `require_image_disposal`
(parent-owned), and the non-leak NEEDS_DISCUSSION rules are NOT addressed by this capability and
stay WARNING.
