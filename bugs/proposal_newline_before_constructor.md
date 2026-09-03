# PROPOSAL: Require a Blank Line Before Constructor Declarations

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `newline_before_case`, `newline_before_method`, `newline_before_return`

---

## Summary

Add `newline_before_constructor` to flag a constructor declaration inside a class body that immediately follows a preceding member (field, another constructor, or method) with no blank line, so constructors are visually separated from surrounding members the way methods usually are.

**Closes gap:** `awesome_lints` `newline_before_constructor` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Constructors are the entry point of a class and deserve to stand out from the field list above them, especially in classes with many fields where a constructor packed directly against the last field is easy to skim past. A consistent blank line before every constructor makes class layout predictable: fields, blank line, constructors, blank line, methods.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class Point {
  final double x;
  final double y;
  Point(this.x, this.y); // LINT — no blank line before the constructor
}
```

### Should pass (good code)

```dart
class Point {
  final double x;
  final double y;

  Point(this.x, this.y); // OK — blank line separates fields from constructor
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: pure whitespace/formatting preference with zero behavioral impact.

---

## Edge Cases

1. **Constructor is the first member in the class body** — should pass; nothing precedes it to separate from.
2. **Consecutive constructors (default + named factory)** — needs discussion; some style guides group related constructors together without blank lines between them.
3. **A single-field class with a one-line constructor immediately after (very short class)** — needs discussion; may be too strict for trivial value classes.
4. **Constructor preceded only by a DartDoc comment with no blank line above the comment itself** — should pass; the blank line requirement is about separating from the previous *member*, not from its own doc comment.

---

## Alternatives Considered

- **Only require the blank line before the first constructor, not between multiple constructors** — considered as the default behavior; grouping constructors together is common enough that the rule should treat consecutive constructors as exempt unless configured otherwise.

---

## Decision

---

## Implementation Notes

---

## Commits
