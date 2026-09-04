# PROPOSAL: `avoid_disposing_late_fields` — Flag `.dispose()` Calls on Possibly-Uninitialized `late` Fields

**Status: Implemented**

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

---

## Finish Report (2026-09-04)

### Issues

- **Tier mismatch with the documented decision.** This proposal's "Proposed Tier" section (line 99) explicitly says `Recommended`, with the rationale "to avoid noisy false positives ... until the detection heuristic is proven on real fixtures" (line 100). The actual registration in `lib/src/tiers.dart` line 777 places `avoid_disposing_late_fields` inside `essentialRules` (the set starting at line 311), not `recommendedOnlyRules` (line 788). Essential ships to every user by default with the lowest FP tolerance — given the false-positive risks below, this contradicts the proposal's own risk assessment.
- **False positive: unconditional assignment via helper-method delegation is NOT recognized, and is then treated as "not provably initialized."** `_blockAssigns`/`_branchAssigns` (`avoid_disposing_late_fields_rules.dart:198-218`) only recognize three top-level statement shapes: `Block`, a bare `ExpressionStatement` wrapping an `AssignmentExpression`, and `IfStatement`. A very common Flutter pattern —
  ```dart
  @override
  void initState() {
    super.initState();
    _setupController(); // assigns _controller unconditionally inside the helper
  }
  void _setupController() { _controller = AnimationController(vsync: this); }
  ```
  — has `_setupController();` as the top-level statement, which is an `ExpressionStatement` wrapping a `MethodInvocation`, not an `AssignmentExpression`. `_branchAssigns` falls through to `return false` for this shape, so `_isProvablyInitialized` returns `false`, and the rule proceeds to flag the (actually always-safe) `dispose()` call. This directly contradicts the class doc comment at lines 34-36, which claims "helper-method delegation" is accepted as a **false negative** (i.e., silently not flagged) — the code in fact produces a **false positive** for this shape, the opposite of the documented trade-off.
- **Same false-positive mechanism for `try`/`catch` and any other unhandled statement kind at the top level of `initState()`.** An unconditional assignment inside a `TryStatement`, `ForStatement`, `WhileStatement`, `SwitchStatement`, etc. is invisible to `_branchAssigns` (no case for these node types), so it is scored as "not provably initialized" and — if the matching `dispose()` call is unguarded — flagged as a violation even though the field is always initialized. This is a real bug, not just a documented trade-off, because the default-safe (`return false` = unsafe) branch is backwards from the stated design intent ("accept false negatives ... rather than risk false positives," `avoid_disposing_late_fields_rules.dart:35`).
- **Silent whole-class skip for arrow-bodied `dispose()`.** `runWithReporter` (line 163) does `if (disposeBody is! BlockFunctionBody) return;` for the entire class when `dispose()` uses `=>` syntax (e.g. `void dispose() => _controller.dispose();`), a legal and not-uncommon Dart pattern for a single-statement override. No candidate field in that class is ever checked. Not covered by any fixture or test.
- **Silent per-class miss for arrow-bodied `initState()`.** `_isProvablyInitialized` (line 191) treats a non-`BlockFunctionBody` `initState()` as `true` (safe, never flag) unconditionally — so `void initState() => _controller = AnimationController(vsync: this);` is treated identically to `void initState() => doSomethingUnrelated();`. In the first case it happens to be correct by luck (the assignment is in fact unconditional); in a hypothetical arrow-cascade or conditional-expression body it would not be. Not exercised by any fixture.

### Concerns

- **Guard detection at the dispose() call site does not check that the guard condition matches the initialization condition.** `_DisposeCallFinder._isGuarded` (lines 263-271) returns `true` for *any* enclosing `IfStatement`, regardless of what it tests. A dispose() call wrapped in an unrelated conditional — most notably the extremely common Flutter pattern `if (mounted) { _controller.dispose(); }`, or any other guard unrelated to the field's init condition — will suppress the lint even when the underlying `LateInitializationError` risk is real and unfixed. This matches what the class doc comment says the code does (lines 240-244), so it is "working as documented," but the documented behavior itself is a significant false-negative surface that the proposal's Edge Case 4 (line 109) describes more narrowly ("guarded by the same condition") than what is implemented (guarded by *anything*).
- **`.dispose()`-only matching narrower than the stated scope.** The rule doc comment and this proposal both describe the target as "another `.dispose()`-shaped call" (rule doc line 14-15; proposal title), matching the breadth of sibling rules in `disposal_rules.dart` which also cover `.close()`/`.cancel()` for `StreamController`/`StreamSubscription`. `_DisposeCallFinder.visitMethodInvocation` (line 252) only matches `node.methodName.name == 'dispose'` literally — a `late StreamSubscription _sub;` conditionally assigned and unconditionally `.cancel()`-ed in `dispose()` is not covered at all.
- **`??=` counted as a full/safe assignment.** `assignmentTargetFieldName` (in `target_matcher_utils.dart`) matches any `AssignmentExpression`, including `_controller ??= x`. On a genuinely uninitialized `late` field, evaluating `_controller ??= x` itself reads `_controller` first and throws `LateInitializationError` before the assignment can run — so treating `??=` as proof of safe initialization is incorrect, though this is a narrow/unusual pattern.
- **Nesting depth exceeds the project's own 3-level guideline.** The candidate-field collection loop in `runWithReporter` (lines 138-148) nests `addClassDeclaration` closure → `for` member → `if FieldDeclaration` → `for` variable → `if initializer == null`, five levels deep, versus the "nesting ≤3" rule stated in the project's `CLAUDE.md`. Not a functional bug, but works against the self-reviewer's own enforced limit.
- **`_extendsState` only matches the literal type name `State`.** A project-specific base class (e.g. `abstract class BaseState<T extends StatefulWidget> extends State<T>`) with concrete subclasses is invisible to this rule — accepted as an in-scope false negative per the rule's own docstring, but worth naming since Saropa/Flutter codebases commonly introduce such base classes.

### Opportunities

- Reuse the existing regex-based `isFieldCleanedUp`-style helper in `target_matcher_utils.dart` (already used by sibling disposal rules for `.dispose()`/`.close()`/`.cancel()` matching) instead of the hand-rolled literal `'dispose'` string comparison in `_DisposeCallFinder`, to close the `.close()`/`.cancel()` gap without new code.
- Extract the candidate-field-collection loop (lines 138-148) into a small `_lateUninitializedFields(ClassDeclaration node)` helper to flatten nesting to ≤3 and shrink `runWithReporter` toward the project's function-length guidance.
- Tighten `_isGuarded` to require the enclosing `IfStatement`'s condition to reference the same field-initialization guard (e.g. compare against the condition(s) found by a similar walk of `initState()`'s `if` chain) rather than accepting any enclosing `if`, closing the "guarded by `mounted`" false-negative class.

### Recommendations

1. **Priority 1 — fix the default-safe/unsafe polarity bug.** In `_branchAssigns`, an unrecognized statement shape (helper-method call, `try`, loop, `switch`) must not silently count as "unsafe" when it's actually just "unanalyzable." Either (a) treat unanalyzable top-level statements in `initState()` as proof of safety (matching the stated false-negative-only design and the existing handling of missing/arrow-bodied `initState()`), or (b) bail out of the whole-field check (skip flagging, same effect) the moment an unrecognized statement shape is seen anywhere in `initState()`'s top level. Add fixture cases for helper-method delegation and `try`/`catch` assignment to prove the fix (both currently untested and currently mis-scored).
2. **Priority 2 — re-run the tier decision.** Given finding #1 is a real, not just theoretical, false-positive source, either fix it before shipping in `essentialRules`, or move the rule to `recommendedOnlyRules` per the proposal's own original rationale until the fix lands and is proven against real fixtures. Update the proposal's "Decision" section (currently "Not yet decided" despite "Status: Implemented" at the top) to reflect whichever is chosen.
3. **Priority 3 — add regression fixtures** for: arrow-bodied `dispose()` (should still flag / currently silently skipped), arrow-bodied `initState()`, and a `mounted`-guarded dispose call on a conditionally-initialized field (documents the current false-negative rather than leaving it unverified).
4. **Priority 4 — widen call-site matching** to `.close()`/`.cancel()` alongside `.dispose()`, matching the scope already stated in the rule's own doc comment and this proposal's title, reusing sibling-rule utilities per the Opportunities section.
