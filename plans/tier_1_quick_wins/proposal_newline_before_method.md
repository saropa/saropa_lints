# PROPOSAL: Require a Blank Line Before Method Declarations

**Status: Duplicate** — already exists as `prefer_blank_line_before_method` (alias `newline_before_method`) in `formatting_rules.dart`

Created: 2026-09-02
Type: New rule
Related rules: `newline_before_case`, `newline_before_constructor`, `newline_before_return`

---

## Summary

Add `newline_before_method` to flag a method (or getter/setter) declaration inside a class body that immediately follows a preceding member with no blank line separating them.

**Closes gap:** `awesome_lints` `newline_before_method` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Class bodies with methods packed directly against each other, with no vertical breathing room, are harder to scan for method boundaries — especially once a method's body spans several lines and the closing brace of one method sits right against the signature of the next. A required blank line before every method gives every member a consistent visual boundary.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class Service {
  void start() {
    _running = true;
  }
  void stop() { // LINT — no blank line before this method
    _running = false;
  }
}
```

### Should pass (good code)

```dart
class Service {
  void start() {
    _running = true;
  }

  void stop() { // OK — blank line separates the methods
    _running = false;
  }
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: pure whitespace/formatting preference with zero behavioral impact.

---

## Edge Cases

1. **Method is the first member in the class body** — should pass; nothing precedes it.
2. **Simple one-line getters grouped together (`int get a => _a; int get b => _b;`)** — needs discussion; tightly related trivial getters are often intentionally grouped without blank lines.
3. **Method preceded by a field with a trailing inline comment, no blank line** — should flag; the comment doesn't substitute for the required blank line.
4. **Override methods clustered together (`@override` block)** — needs discussion; some style guides keep all overrides adjacent without blank lines.

---

## Alternatives Considered

- **Exempt getter/setter pairs for the same property from the blank-line requirement** — considered; getter/setter pairs are conventionally kept adjacent and may warrant a built-in exception.

---

## Decision

---

## Implementation Notes

---

## Commits
