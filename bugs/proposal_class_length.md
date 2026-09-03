# PROPOSAL: Flag Classes Exceeding a Line-Count Budget

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_god_class` (measures MEMBER COUNT, not lines — see Alternatives Considered for why both signals are needed), `avoid_long_length_files`/`avoid_very_long_length_files` (measure FILE line count, not per-class)

---

## Summary

Add `avoid_long_class` to flag a class whose body exceeds a configurable line-count budget (default ~250-300 lines), independent of how many fields or methods it declares.

**Closes gap:** klin_dart `class-length` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`saropa_lints` already measures class size two different ways, and neither one is a line-count budget. `AvoidGodClassRule` (`lib/src/rules/architecture/architecture_rules.dart`, line ~347) flags a class with more than 15 fields or 20 methods — a *member-count* metric aimed at Single Responsibility violations (too many unrelated things bolted onto one class). `AvoidLongFilesRule`/`AvoidVeryLongFilesRule` (`lib/src/rules/architecture/structure_rules.dart`, line ~777 and ~836) flag a *file* exceeding 500/1000 lines — but a file can hold several small classes under budget individually, or one file can legitimately hold one enormous generated-adjacent class alongside short helpers, so file-level LOC does not localize the problem to the specific class. Neither metric catches the common real-world case this rule targets: a class with a small, clean member count (say, 8 methods) where a handful of those methods are each 150+ lines of nested logic, a giant `switch`, or a long imperative algorithm — pushing total class LOC well past what a reader can hold in working memory, while looking entirely reasonable by `avoid_god_class`'s member-count test. Line count and member count are complementary signals, not substitutes for each other; a class can fail either one independently.

---

## Detection / Behavior

### Should flag (bad code)

```dart
// LINT — this class has only 3 methods (would pass avoid_god_class easily)
// but its body spans 400+ lines because parseOrder() is one giant
// hand-rolled state machine with dozens of branches.
class OrderParser {
  Order parseOrder(String raw) {
    // ... 380 lines of nested switch/if logic ...
  }

  bool _isValidHeader(String line) { /* ... */ }
  void _logParseError(String reason) { /* ... */ }
}
```

### Should pass (good code)

```dart
// OK — logic extracted into focused, independently readable helper classes,
// keeping OrderParser itself under the line budget.
class OrderParser {
  Order parseOrder(String raw) {
    final header = _headerParser.parse(raw);
    final lines = _lineItemParser.parseAll(raw);
    return Order(header: header, lines: lines);
  }

  final _headerParser = OrderHeaderParser();
  final _lineItemParser = OrderLineItemParser();
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: A pure size-budget style rule with no correctness impact — matches saropa's existing placement for `avoid_long_length_files`/`avoid_very_long_length_files` at similarly opinionated tiers, since "acceptable class size" is a team-configurable threshold, not a universal defect.

---

## Edge Cases

1. **Generated classes** (`.g.dart`, `.freezed.dart`, `_$` mixins) — should pass; standard generated-file suppression applies, since generated serialization/copyWith classes are routinely hundreds of lines by design.
2. **A class made almost entirely of DartDoc comments and blank lines, with little actual code** — should pass; count non-comment, non-blank code lines only, matching the counting method already used by `AvoidLongFilesRule` ("comments and blank lines excluded", per its own diagnostic message).
3. **A class that is a large enum-like data table** (e.g. a class holding many `static const` field declarations, no behavior) — needs discussion; could argue for exclusion similar to how `AvoidVeryLongFilesRule`'s DartDoc explicitly calls out "data, enums, constants, configs" files as legitimately large. Default to flagging but document the `// ignore_for_file:`/`// ignore:` escape hatch prominently in the rule's DartDoc, consistent with how the file-length rules handle the same tension, rather than trying to auto-detect "is this a data class" heuristically.
4. **A class split across `part`/`part of` files** — should sum lines across all parts contributing to the same class declaration if feasible; if implementation cannot cheaply resolve part-file contents, document as a known limitation (false negative) rather than under-scoping the rule to a single file's fragment.
5. **Nested/local classes** — should apply the same budget to any `ClassDeclaration` node regardless of nesting, consistent with how `avoid_god_class` already visits every `ClassDeclaration` without special-casing nesting.

---

## Alternatives Considered

- **Lower the `avoid_god_class` member-count thresholds instead of adding a new metric** — rejected; member count and line count catch different failure shapes (see Motivation — a class can independently fail either test), and conflating them into one adjusted threshold would either miss the "few large methods" case this rule targets or produce false positives on legitimately large-but-few-member data classes.
- **Measure per-method length only** (already covered by the existing `avoid_long_functions`-style rule per the project's function-length enforcement) instead of a class-level rollup — rejected as insufficient on its own; a class can exceed a reasonable total size even when every individual method stays under a per-function limit, simply by having many medium-length methods (e.g. 15 methods at 25 lines each = 375 lines, none of which trips a 50-line function budget).

---

## Decision

---

## Implementation Notes

Candidate home: `lib/src/rules/architecture/architecture_rules.dart`, adjacent to `AvoidGodClassRule` (line ~347) so the two size-related class rules stay co-located and their DartDoc can cross-reference each other; alternatively `lib/src/rules/architecture/structure_rules.dart` alongside the file-length rules, reusing their `_checkFileLength`-style line-counting helper adapted to a single `ClassDeclaration`'s `offset`/`end` span instead of the whole file, with the same comment/blank-line exclusion logic.

---

## Commits
