# PROPOSAL: Flag Method Tear-Offs Taken From a Reassignable Variable

**Status: Implemented**

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

## Finish Report (2026-09-04)

### Issues

- **Stale "Registration NOT performed" claim.** The proposal's own "Registration NOT performed (by design)" section (lines ~105-107) says the rule was deliberately left unwired from `_allRuleFactories`, `tiers.dart`, `all_rules.dart`, and `CHANGELOG.md`. That is no longer true: the rule is fully registered today — `MutableTearoffRule.new` is in `lib/saropa_lints.dart` (line 2920), `'mutable_tearoff'` is in `professionalOnlyRules` in `lib/src/tiers.dart` (line 1771), the export is in `lib/src/rules/all_rules.dart` (line 205), and CHANGELOG.md line 101 documents it under the "19 new tier-1 quick-win lint rules" entry. The rule is live in the Professional tier and ships to users. The doc should be corrected so a future reader doesn't waste time re-verifying registration or re-running the centralized wiring process against an already-wired rule.

### Concerns

- **False negative: tear-off stored inside a collection/record literal.** `_isStored` only recognizes a `VariableDeclaration` initializer or the RHS of an `AssignmentExpression`. `final List<VoidCallback> callbacks = [handler.handleTap];`, a `Map` value, or a record field (`final r = (handler.handleTap,);`) all retain the tear-off just as durably as a direct assignment, but the immediate AST parent of the `PrefixedIdentifier` in each case is the literal, not the declaration/assignment, so none of these fire. This is a real gap in the same bug class the rule targets — worth at least a documented limitation if not handled.
- **False negative: tear-off returned from a function/getter body.** `VoidCallback getCallback() => handler.handleTap;` (or `return handler.handleTap;`) hands the tear-off to the caller to store, which is exactly the staleness risk the rule exists to catch, but the parent is an `ExpressionFunctionBody`/`ReturnStatement`, not a `VariableDeclaration`/`AssignmentExpression` — not flagged. Not mentioned in the proposal's Edge Cases or Alternatives Considered, unlike the one-shot-argument exclusion, so it reads as an oversight rather than a deliberate scope cut.
- **False negative: constructor initializer list.** `Controller() : onTap = handler.handleTap;` stores the tear-off into a field via a `ConstructorFieldInitializer`, not an `AssignmentExpression` or `VariableDeclaration` — `_isStored` returns false and the rule misses it. This is a common way to wire up `late final` alternatives in const-constructor-style classes.
- **Untested code paths.** No test or fixture case exercises: a top-level (non-field, non-local) mutable variable as receiver (exercises the same `PropertyAccessorElement`/`PropertyInducingElement` unwrap path as fields, but via a different element subtype — `TopLevelVariableElement` — never confirmed to actually hit that branch); a `static` mutable field; an extension method tear-off (`memberElement is MethodElement` for `ExtensionElement`-enclosed methods is assumed, not verified); a compound assignment (`??=`) as the storing expression (mentioned nowhere, though `_isStored`'s `AssignmentExpression` branch should already cover it — untested assumption); or an import-prefixed call (`math.min`) confirmed not to crash `_isMutableReceiver` (the dartdoc/proposal asserts `PrefixElement` falls through safely, but nothing exercises it).
- **Flow-insensitivity is a known, accepted false-positive source.** Documented three times over (rule dartdoc, proposal Edge Case 1, Implementation Notes "Known limitation"), so this isn't a surprise — but it does mean any non-final receiver that is reassigned once at startup and never again (a very common real-world pattern, e.g. lazy-init fields set once in `initState`) will be flagged at Professional tier. Worth watching false-positive reports on this specific shape once the rule sees real-world traffic.

### Opportunities

- **Collection-literal and return-statement cases could reuse the same `_isStored` shape** by walking up through `ListLiteral`/`SetOrMapLiteral`/`RecordLiteral`/`ReturnStatement`/`ExpressionFunctionBody` parents before giving up, rather than only checking the immediate parent. Would close two of the false-negative gaps above without needing full data-flow analysis.
- **`ConstructorFieldInitializer` support** is a small, self-contained addition to `_isStored` (check `parent is ConstructorFieldInitializer && parent.expression == node`) — same conservative pattern already used for the other two cases, no new resolution machinery needed.
- Consider a fixture/test case for the top-level-variable receiver path specifically, since it is the one branch of `_isMutableReceiver` (`PropertyAccessorElement` → `PropertyInducingElement`) that is currently reached only incidentally (via implicit field access) and never directly asserted for a top-level variable.

### Recommendations

1. **(Priority: low, doc-only)** Correct the "Registration NOT performed (by design)" section — the rule is registered and shipping; update or strike that section so the proposal doc reflects reality.
2. **(Priority: medium)** Decide whether the collection-literal, return-statement, and constructor-initializer false negatives are in-scope for a v1.1 tightening or should be added to the dartdoc's list of documented out-of-scope cases (currently only chained receivers and flow-insensitivity are called out). Silent gaps that aren't documented are worse than documented ones — a future maintainer or user will assume the rule is exhaustive over "stored" tear-offs when it currently is not.
3. **(Priority: low)** Add the untested-but-assumed branches (top-level variable receiver, static field, extension method, `??=` compound assignment, import-prefix non-firing) as explicit test cases — they're cheap to add and would catch a regression in the `PropertyAccessorElement`/`MethodElement` resolution logic if the analyzer's element model shifts again (as it already has once, per the analyzer-12 split-element comment in the rule).
