# PROPOSAL: Require DartDoc on Enums and Enum Values

**Status: Implemented**

Created: 2026-09-02
Type: New rule
Related rules: `document_interface` (proposed alongside), `document_fake_parameters` (proposed alongside)

---

## Summary

Add `document_enum` to flag public `enum` declarations and their individual enum values (constants) that lack a DartDoc comment, mirroring the same discoverability expectation saropa already applies to public classes/methods but currently misses for enums.

**Closes gap:** `ripplearc_linter` `document_enum`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Documentation conventions" section.

---

## Motivation

Enum values are public API surface exactly like class members, but IDE tooltips and pub.dev API docs only show useful information when a DartDoc comment exists. Undocumented enum values are common because they read as "self-explanatory" at write time but leave future readers guessing at intent, valid ranges, or when to choose one value over another.

---

## Detection / Behavior

### Should flag (bad code)

```dart
enum OrderStatus { // LINT — public enum missing DartDoc
  pending,
  shipped, // LINT — enum value missing DartDoc
  canceled,
}
```

### Should pass (good code)

```dart
/// Lifecycle states for a customer order.
enum OrderStatus {
  /// Order has been placed but not yet shipped.
  pending,

  /// Order has left the warehouse.
  shipped,

  /// Order was canceled before shipping.
  canceled,
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: documentation-completeness rule, high-volume but low-severity; matches saropa's placement for other blanket "public API must be documented" style rules.

---

## Edge Cases

1. **Private enum (`enum _Internal`)** — should pass; not public API.
2. **Enum value whose name is fully self-describing (e.g. `true`/`false`-style booleans)** — should flag anyway; consistency over per-value judgment calls, matches DCM/ripplearc precedent of "always require, no exceptions."
3. **Enhanced enum with documented members but undocumented values (or vice versa)** — each documentation target (enum itself, each value) is checked independently.
4. **Generated enums (`.g.dart`)** — should pass; standard generated-file suppression applies.

---

## Alternatives Considered

- **Only require documentation on the enum declaration, not each value** — rejected; individual enum values are the part developers most need explained (what does `pending` vs `shipped` actually mean), so skipping them defeats the purpose.

---

## Decision

---

## Implementation Notes

Can likely share the existing "has DartDoc" detection helper already used by any current public-API documentation rule, if one exists — check `lib/src/rules/` for a `public_member_api_docs`-style helper before writing a new DartDoc-presence check.

---

## Commits

## Finish Report (2026-09-04)

### Issues

None identified. Core logic is correct: private-enum skip (`document_enum_rules.dart:94`), independent enum-declaration check (`:97-99`), and independent per-constant check via the existing `bodyConstants` compat getter (`:104-108`) all match the proposal's stated behavior and are exercised by the fixture (`OrderStatus`, `ShipmentPriority`, `PaymentStatus`, `_InternalRetryPhase`).

### Concerns

- **Doc-comment-before-annotation ordering is untested and is a realistic false-positive source.** Enum constants that carry serialization annotations (`@JsonValue(...)`, `@JsonKey(...)`, `@Deprecated(...)`) are common in this codebase's domain (order/payment/status enums are exactly the DartDoc example used). The analyzer only recognizes a `///` block as `documentationComment` when it precedes the annotation(s); `@JsonValue('a') /// Doc. aValue` is NOT recognized as documented and will fire. Neither the fixture nor the test covers an annotated constant, documented or not, so this ordering trap ships unverified. `require_public_api_documentation` (`documentation_rules.dart`) has the identical exposure and is likewise untested for it — this is an inherited risk, not new, but `document_enum` is more likely to hit it in practice given how often serializable enums carry per-value annotations.
- **Test file is instantiation-only** (`document_enum_rules_test.dart`): it checks the `LintCode` shape and that the fixture file exists, but never runs the rule against the fixture to confirm the `expect_lint` markers actually fire (or don't) at the annotated lines. This is the established project-wide pattern (per project memory: fixture verification happens via the scan CLI, not `dart test`), so it's not a defect unique to this PR, but it means a silent-rule regression here would only be caught by manually running `dart run saropa_lints scan` against the fixture — worth doing once before considering this closed out (see Recommendations).
- **`expect(rule.code.problemMessage.length, greaterThan(50))`** uses the weaker of two thresholds seen elsewhere in the test suite (`compound_performance_rules_test.dart` uses `greaterThan(200)`, matching the project's own ">200 chars" problem-message rule). The actual message is 333 chars, so it passes either way today, but the test itself doesn't enforce the real requirement and would not catch a future regression that shortened the message below 200 but above 50. Pre-existing inconsistency across the test suite, not introduced by this rule.
- **Scope is enum declaration + constants only** — fields, getters, and methods declared inside an enhanced enum body are not checked. This matches the proposal's explicit scope (never discusses enum members beyond constants) and mirrors `require_public_api_documentation`'s class-level scope, so it's a documented limitation rather than a bug, but it means an enhanced enum with an undocumented public getter/method will pass this rule silently — something a future contributor might expect it to catch.

### Opportunities

- The proposal's Implementation Notes suggested reusing an existing "has DartDoc" helper. No such helper exists — `documentation_rules.dart` (2 call sites) and `document_enum_rules.dart` (2 call sites) all inline `node.documentationComment == null` directly. Given there are now 4 near-identical call sites across 2 files, extracting a tiny shared `bool isUndocumented(AnnotatedNode node)` (or similar) into a shared rules-utils location would remove duplication, but the check is a one-line null comparison — low value, optional.
- `bodyConstants` (the analyzer-version-compat getter in `analyzer_compat.dart:112`) is exactly the right existing utility and is correctly reused rather than re-implemented — no changes needed there.

### Recommendations

1. (Medium) Add an annotated-constant case to the fixture (e.g. a `@Deprecated('...')` or a plain custom annotation on an enum constant, both documented and undocumented) to lock in the doc-before-annotation ordering behavior, and note the expected behavior explicitly in the rule's DartDoc if it's surprising.
2. (Low) Before archiving this proposal, run `dart run saropa_lints scan example/lib/core --files document_enum_fixture.dart --format json` to positively confirm every `// expect_lint: document_enum` line actually fires and the two GOOD blocks stay silent — the current test suite doesn't do this.
3. (Low) Tighten `document_enum_rules_test.dart`'s message-length assertion to `greaterThan(200)` to match the project's own documented requirement, independent of this PR if the team wants consistency across all rule tests.
4. (Optional) No action required on the shared-helper suggestion in Implementation Notes — the duplication is trivial and extracting it is not worth the churn unless a fifth call site appears.
