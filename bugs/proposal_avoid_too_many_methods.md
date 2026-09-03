# PROPOSAL: Flag Classes With Too Many Methods (Method-Count Budget)

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_god_class` (existing — flags a class with more than 15 fields OR more than 20 methods combined; this proposal is a narrower, method-count-only budget metric)

---

## Summary

Add `avoid_too_many_methods` to flag a class declaring more than N methods (configurable, default 20), independent of its field count. Where `avoid_god_class` already fires on *either* excessive fields *or* excessive methods as a combined SRP-violation signal, this rule isolates the method-count dimension as its own configurable budget, matching `many_lints`' narrower single-metric rule for teams that want to tune the method threshold separately from the field threshold.

**Closes gap:** `many_lints` `avoid_too_many_methods` (pub.dev, budget rule). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "Gap Theme 9" (budget rules).

---

## Motivation

A class that accumulates many methods over time — even one with a modest field count — is a common form of scope creep: a "utility" or "service" class that keeps growing one method at a time, each addition individually reasonable, until the class handles a dozen unrelated concerns. `avoid_god_class` already catches the extreme case combined with field bloat, but a class can rack up 25+ methods while staying under the field-count threshold (e.g. a stateless class exposing many static helper methods, or a widget's State class accumulating many small private handlers) — `avoid_god_class`'s OR-based trigger does catch pure method-count overflow too (it fires on methods > 20 alone), but it does not let a team configure the method threshold independently of the field threshold, and its correction message is framed around SRP/god-class terminology rather than a simple budget violation. A standalone, configurable method-count rule lets teams set a stricter or looser method budget than their field budget as separate policy knobs.

---

## Detection / Behavior

Count non-getter, non-setter `MethodDeclaration` members in a `ClassDeclaration` (mirroring `avoid_god_class`'s existing counting logic in `lib/src/rules/architecture/structure_rules.dart`) and flag when the count exceeds the configured threshold (default 20).

### Should flag (bad code)

```dart
class ReportGenerator { // LINT — 22 methods, exceeds the configured budget of 20
  void generateHeader() {}
  void generateFooter() {}
  void generateSummary() {}
  void generateChart1() {}
  // ... 18 more methods ...
  void exportAsPdf() {}
  void exportAsCsv() {}
}
```

### Should pass (good code)

```dart
class ReportHeaderGenerator { // OK — focused responsibility, well under the method budget
  void generateHeader() {}
  void generateFooter() {}
}

class ReportExporter { // OK — extracted export concerns into their own class
  void exportAsPdf() {}
  void exportAsCsv() {}
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: A configurable size-budget metric with a meaningful false-positive surface (large-but-cohesive facade/API classes) — matches the tier of other configurable-threshold structural rules; teams doing a deliberate architecture pass opt in and tune the threshold, rather than every project inheriting a default that may not fit their class-size conventions.

---

## Edge Cases

1. **Getters and setters** — excluded from the count, matching `avoid_god_class`'s existing convention (`!member.isGetter && !member.isSetter`); a class with many trivial property accessors is not the same smell as many behavioral methods.
2. **Static const/final fields do not affect this rule at all** — this rule only counts methods, unlike `avoid_god_class` which also tracks fields; no field-related edge cases apply.
3. **Abstract classes / interfaces with many method signatures but no bodies** — needs discussion; an interface naturally enumerates every operation a family of implementers must support, and a large interface is a different smell (interface segregation) than a large concrete implementation. Consider excluding abstract classes/mixins used purely as interfaces, or applying a higher default threshold for them.
4. **Generated classes** (`.g.dart`, `.freezed.dart`) — should pass; standard generated-file suppression applies, consistent with `avoid_god_class`.
5. **A class already flagged by `avoid_god_class`** — both rules may fire simultaneously on the same class; this is intentional and not treated as duplicate noise, since a team may have `avoid_god_class` at a higher tier and this rule at a different, more tunable tier.

---

## Alternatives Considered

- **Make this rule redundant and skip it, since `avoid_god_class` already covers method-count overflow** — rejected; `avoid_god_class`'s method threshold (20) is hardcoded and bundled with its field threshold as a single non-configurable pair, and its problem message frames every violation as a "god class / SRP violation," which is the wrong framing for a class that has excellent cohesion but simply exposes many small operations (e.g. a well-designed builder or fluent API). A standalone, independently-configurable method budget serves a real, distinct use case; `many_lints` shipping it as a separate rule from any field-count rule is itself evidence the split is useful.
- **Add a configurable threshold to `avoid_god_class` instead of a new rule** — rejected for scope/parity reasons; `avoid_god_class`'s combined field+method trigger is a deliberate, distinct signal (matches its DartDoc framing), and migrating users from `many_lints` want a rule they can map 1:1 to their existing suppressions/config rather than a reinterpretation of an existing saropa rule.

---

## Decision

---

## Implementation Notes

Candidate home: `lib/src/rules/architecture/structure_rules.dart`, alongside `AvoidGodClassRule` (~line 347) — reuse its method-counting loop (`bodyMembers` iteration, `isGetter`/`isSetter` exclusion) rather than reimplementing it. Threshold should be configurable via the rule's options mechanism (check how other configurable-threshold rules like `avoid_excessive_expressions` or `avoid_deep_nesting` in `lib/src/rules/code_quality/complexity_rules.dart` expose their threshold for the established pattern).

---

## Commits
