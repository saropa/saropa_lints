# PROPOSAL: `avoid_disposing_late_fields` — Flag `.dispose()` Calls on Possibly-Uninitialized `late` Fields

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Flag `dispose()` (or another `.dispose()`-shaped call) on a `late`-declared field inside a `State.dispose()` override when the field's initialization is conditional (e.g. only assigned inside `initState()` under an `if`, or assigned lazily on first use), since accessing an unassigned `late` field throws `LateInitializationError`.

**Closes gap:** DCM `avoid-disposing-late-fields` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

`late` fields defer initialization, and Dart does not verify at compile time that a `late` field is assigned before every read. A common Flutter crash pattern: a controller declared `late final AnimationController _controller;` is initialized in `initState()` behind a conditional (e.g. only when a feature flag or a data-dependent branch is true), but `dispose()` unconditionally calls `_controller.dispose()`. If `initState()` took the branch that skipped assignment, `dispose()` throws `LateInitializationError: Field '_controller' has not been initialized` — and because this happens during widget teardown, it is easy to miss in manual testing (the crash only reproduces on the specific navigation path that skips the conditional).

DCM ships `avoid-disposing-late-fields` for this pattern. `saropa_lints` has extensive dispose-related coverage (`lib/src/rules/architecture/disposal_rules.dart`, `lib/src/rules/widget/widget_lifecycle_rules.dart`) but none of it currently cross-references `late` field declarations against conditional initialization before flagging the `dispose()` call site.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({super.key, required this.autoPlay});
  final bool autoPlay;

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Only initialized when autoPlay is true — conditional assignment.
    if (widget.autoPlay) {
      _controller = AnimationController(vsync: this);
    }
  }

  @override
  void dispose() {
    _controller.dispose(); // LINT — may never have been assigned
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
```

### Should pass (good code)

```dart
class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({super.key});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller; // OK

  @override
  void initState() {
    super.initState();
    // Unconditional assignment — always initialized before dispose() runs.
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose(); // OK — provably initialized
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
```

---

## Proposed Tier

Tier: Recommended
Justification: Crash risk (`LateInitializationError` at teardown) is real but the trigger is narrow — only conditional `late` initialization inside `initState()`, a less common pattern than unconditional initialization. Placed at Recommended rather than Essential to avoid noisy false positives on codebases with more complex init-guard patterns (see Edge Cases) until the detection heuristic is proven on real fixtures.

---

## Edge Cases

1. **`late` field assigned unconditionally in `initState()`** — should pass; this is the safe, common case (Edge Case detection must special-case an unconditional top-level assignment statement in `initState()`).
2. **`late` field assigned in a constructor initializer list** (rare for `State` classes, but possible via a factory pattern) — should pass.
3. **Field is lazily initialized on first read** (`late final _x = _compute();` — implicit lazy `late`, no explicit assignment statement) — should pass; this form always initializes exactly once on first access and cannot throw at `dispose()` unless the field is never read at all before `dispose()`, which is a different (unreachable-init) problem out of scope for this rule.
4. **Conditional assignment guarded by a flag that is also checked before the `dispose()` call** (`if (widget.autoPlay) _controller.dispose();`) — should pass; the guard at the call site proves safety even though initialization was conditional.
5. **Field assigned in multiple branches of an `if`/`else` that together cover all paths** — should pass; requires basic branch-coverage reasoning, not just "any `if` present ⇒ flag."

---

## Alternatives Considered

- **Flag every `late` field access in `dispose()` regardless of `initState()` shape** — rejected as too broad; unconditional initialization (the common case) would false-positive on every dispose method in the codebase, making the rule useless.
- **Require dataflow analysis across the whole class** — the precise version of this check needs control-flow analysis of `initState()` to prove all-paths coverage; scope v1 to the simpler heuristic (flag when assignment is nested inside any `if`/`else if`/`switch` branch without an else covering all cases) and accept conservative false negatives on complex branching, consistent with the AST-visitor-only detection model documented for other lifecycle rules in `lib/src/rules/architecture/disposal_rules.dart`.

---

## Decision

Not yet decided.

---

## Implementation Notes

Candidate home: `lib/src/rules/architecture/disposal_rules.dart` (existing dispose-lifecycle rule cluster) or `lib/src/rules/widget/widget_lifecycle_rules.dart` (existing `State` lifecycle rule cluster) — both files already register dispose-adjacent checks and are natural siblings for this rule's `initState`/`dispose` cross-reference logic.

---

## Commits

None yet.
