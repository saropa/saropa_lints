# PROPOSAL: Flag Method Tear-Offs Taken From a Reassignable Variable

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `mutable_tearoff` to flag a method tear-off (`final callback = someVar.method;`) whose receiver is a non-`final` local variable, field, or parameter. A tear-off captures the *current* value of the receiver at the moment it is taken — if the receiver is later reassigned, the tear-off silently keeps pointing at the old instance, which reads as a live binding but is not one.

**Closes gap:** `essential_lints` `mutable_tearoff` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Tear-offs look like references to "the current value of `x.method`", but they are actually bound to the object `x` held *at tear-off time*. When `x` is mutable, a reader reasonably assumes reassigning `x` changes what the stored callback does — it doesn't. This is a common source of stale-callback bugs in controller/notifier patterns where a field is swapped out (e.g. hot-reload, re-initialization) after a tear-off was already handed to a listener.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class Controller {
  Handler handler = Handler();
  late final VoidCallback onTap = handler.handleTap; // LINT — tear-off from mutable field `handler`

  void swapHandler(Handler next) {
    handler = next; // onTap still calls the OLD handler's handleTap
  }
}
```

### Should pass (good code)

```dart
class Controller {
  final Handler handler = Handler(); // OK — final receiver, tear-off is safe
  late final VoidCallback onTap = handler.handleTap;
}
```

---

## Proposed Tier

Tier: Professional
Justification: catches a real stale-reference correctness bug, but only in the specific case of tearing off from a mutable receiver — not common enough to be Essential, but a genuine bug class worth Professional-tier coverage.

---

## Edge Cases

1. **Tear-off from a local variable that is reassigned before the tear-off is taken** — should pass; only the receiver's mutability at the point of tear-off matters, not its later history.
2. **Tear-off from `this` inside a class with mutable fields** — should pass; `this` itself cannot be reassigned even if fields are mutable.
3. **Tear-off from a `final` field whose *object* is internally mutable (e.g. a `final` controller with mutable state)** — should pass; the rule only concerns reassignment of the receiver reference, not the receiver's internal state.
4. **Tear-off immediately invoked (`someVar.method()`)** — should pass; this is a normal call, not a stored tear-off.

---

## Alternatives Considered

- **Flag tear-offs from any non-final receiver regardless of whether the tear-off is stored** — rejected; a tear-off passed directly as a one-shot argument (e.g. `list.forEach(mutableVar.method)`) is not a staleness risk since it isn't retained past the call.

---

## Decision

Implemented.

---

## Implementation Notes

- **Rule name string:** `mutable_tearoff`
- **Class name:** `MutableTearoffRule`
- **Rule file:** `lib/src/rules/code_quality/mutable_tearoff_rules.dart`
- **Fixture:** `example/lib/code_quality/mutable_tearoff_fixture.dart` (4 `expect_lint: mutable_tearoff` markers, 5 GOOD near-miss cases)
- **Unit test:** `test/rules/code_quality/mutable_tearoff_test.dart` (11 cases via `resolved_rule_harness`, all passing)
- **Tier recommendation:** Professional, per the original proposal — real correctness risk (stale-callback bug) but scoped narrowly enough (only method tear-offs, only stored ones) not to warrant Essential.
- **Category:** `code_quality/` — no existing rule covered this pattern (confirmed by grep of `lib/src/tiers.dart` and `lib/src/rules/` before implementation; other "tear-off" hits were unrelated rules that merely mention tear-offs in comments/messages).

### Detection approach

Registers on `PrefixedIdentifier` (the `x.y` shape a two-identifier tear-off parses as). Fires only when ALL of:

1. **Stored** — the node is the initializer of a `VariableDeclaration` (covers both `final x = ...;` and field declarations, which share the same AST shape) or the right-hand side of an `AssignmentExpression`. A tear-off passed as a bare call argument (`list.forEach(mutableVar.method)`) is deliberately out of scope, per the proposal's "Alternatives Considered".
2. **Genuine method tear-off** — `node.identifier.element is MethodElement`. A field/getter read of function type (`handler.onTapCallback`) is skipped; it re-reads the receiver's current value on every access and is a different concern.
3. **Mutable receiver** — `node.prefix.element` resolves to a `LocalVariableElement`/`FormalParameterElement` that is not `final`/`const`, or a `FieldElement`/`PropertyAccessorElement` (implicit field access resolves to its synthetic getter in analyzer 12's split element model — unwrapped via `PropertyAccessorElement.variable` to reach the underlying `isFinal`) that is not `final`/`const`.

Any unresolved element at steps 2 or 3 causes a conservative skip (false-positive doctrine) — this also naturally excludes import prefixes (`math.min`), which resolve to a `PrefixElement`.

`this.method` tear-offs are automatically excluded without special-casing: `this` is a `ThisExpression`, so `this.bump` parses as `PropertyAccess`, not `PrefixedIdentifier` — the rule never even visits it. Chained receivers (`obj.field.method`) are also out of scope for v1 — the rule only inspects a direct two-identifier tear-off.

### Known limitation (documented in the rule's dartdoc)

The rule is flow-insensitive: it flags based on the receiver's *declared* mutability, not on whether the receiver is provably never reassigned again after the tear-off is taken. Edge Case 1 in this proposal ("reassigned before the tear-off is taken — should pass") would require full data-flow analysis to distinguish from the bug case and is out of scope; this rule will still flag a non-final receiver even if, by chance, it's never reassigned again after the tear-off site.

### Registration NOT performed (by design)

Per the task instructions and the established convention (see the comment header in `avoid_futureor_return_type_test.dart`), this implementation deliberately did **not** touch `lib/saropa_lints.dart` (`_allRuleFactories`), `lib/src/tiers.dart`, `lib/src/rules/all_rules.dart`, or `CHANGELOG.md` — a separate centralized process handles that three-way wiring across parallel rule-authoring agents to avoid merge conflicts. The rule is fully implemented and verified but not yet live in any build.

### Verification performed

The `dart run saropa_lints scan` CLI could not be used for verification since it depends on the rule being registered in `_allRuleFactories`, which was deliberately left undone (see above). Verification was instead done via the `resolved_rule_harness` test oracle (full type/element resolution, no dependency on global registration):

- `dart test test/rules/code_quality/mutable_tearoff_test.dart` — 11/11 passing.
- Fixture liveness spot-check: ran `MutableTearoffRule` directly against the full contents of `mutable_tearoff_fixture.dart` — 4 diagnostics fired, at lines 22, 37, 45, 52, exactly matching the 4 `expect_lint: mutable_tearoff` markers. No firings on the 5 GOOD cases.

### Incident note

Mid-implementation, `git reflog` showed the working tree was reset to `HEAD` twice by a concurrent external process (consistent with the "separate process handles registration centrally" convention noted above, or another parallel agent operating on this shared checkout), which silently deleted the first draft of all three new files before verification. All three files were recreated from scratch and re-verified; the second attempt is what is reflected in this repo. No data loss occurred beyond wasted first-pass effort, but this is worth flagging as a real hazard for concurrent agent work against a single shared working directory.

---

## Commits
