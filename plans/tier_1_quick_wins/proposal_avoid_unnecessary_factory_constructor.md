# PROPOSAL: Flag `factory` Constructors That Just Return `ClassName(...)`

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `AvoidUnnecessaryConstructorRule` (`lib/src/rules/code_quality/unnecessary_code_rules.dart`)

---

## Summary

Add `avoid_unnecessary_factory_constructor` to flag a `factory` constructor whose body is only `return ClassName(...)` (or `=> ClassName(...)`) forwarding directly to the class's own generative constructor with no branching, caching, subclass selection, or side effects — the `factory` keyword buys nothing here and a normal generative constructor (or constructor redirection, `ClassName.name() : this(...)`) is simpler and avoids the misleading signal that "something special happens" on construction.

**Closes gap:** DCM `avoid-unnecessary-factory` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

`factory` is a signal to readers: "this constructor might not return a fresh instance of this exact class, might cache, might delegate to a subclass, might validate before allocating." When a `factory` constructor's body is a single unconditional `return ClassName(...)` call to its own class, that signal is false — nothing factory-like happens, and a plain generative (possibly redirecting) constructor communicates intent more accurately. This sits alongside the codebase's existing `AvoidUnnecessaryConstructorRule` (which flags a *default* constructor that adds nothing over the implicit one) as a sibling "constructor that isn't earning its keep" check. DCM ships `avoid-unnecessary-factory` as prior art for exactly this pattern.

---

## Detection / Behavior

Flag a `ConstructorDeclaration` with the `factory` modifier whose body is exactly:
- `return ClassName(...);` (a `ReturnStatement` wrapping an `InstanceCreationExpression` of the *same* class), or
- `=> ClassName(...);` (expression-bodied equivalent),

with no other statements, no conditional logic, and no cached/static-instance lookup.

### Should flag (bad code)

```dart
class Point {
  Point(this.x, this.y);
  final double x;
  final double y;

  factory Point.origin() {
    return Point(0, 0); // LINT — unconditional forward to own constructor; factory adds nothing
  }
}
```

### Should pass (good code)

```dart
class Point {
  Point(this.x, this.y);
  final double x;
  final double y;

  // OK — plain redirecting generative constructor, no misleading `factory` keyword
  Point.origin() : this(0, 0);
}

class Shape {
  // OK — genuine factory use: branches to different subclasses.
  factory Shape.fromType(String type) {
    if (type == 'circle') return Circle();
    return Square();
  }
}

class Singleton {
  Singleton._();
  static final Singleton _instance = Singleton._();

  // OK — genuine factory use: returns a cached instance, not a fresh one.
  factory Singleton() => _instance;
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: This is a readability/intent-signaling improvement, not a correctness issue — an unnecessary `factory` compiles and runs identically to the redirecting-constructor alternative. Comprehensive matches saropa's placement for constructor-shape style rules like the sibling `AvoidUnnecessaryConstructorRule`.

---

## Edge Cases

1. **`factory` returning a cached/static instance** (singleton pattern) — should pass; this is exactly what `factory` is for.
2. **`factory` with conditional branching to different constructors/subclasses** — should pass; genuine dynamic-return use case.
3. **`factory` forwarding to a *named* constructor of the same class** (`factory Point.origin() => Point._raw(0, 0);`) — should discuss; this could arguably also be a redirecting generative constructor (`Point.origin() : this._raw(0, 0);`), so likely should still flag, but confirm no edge case (e.g. private constructor visibility) blocks the redirecting-constructor alternative.
4. **`factory` that validates arguments before forwarding** (`if (x < 0) throw ArgumentError(); return Point(x, y);`) — should pass; validation is a legitimate reason to keep `factory` (a redirecting constructor can't run arbitrary statements first).
5. **`factory` forwarding to a *different* class** (e.g. `factory Shape.circle() => Circle();` where `Circle` implements `Shape`) — should pass; this is polymorphic factory selection, a core legitimate use.
6. **Const factory constructors** (`const factory Point.origin() = Point.zero;`) — this redirecting-const-factory syntax is a separate, already-idiomatic pattern; should pass and not be confused with the flagged pattern (this proposal targets bodied factories with a `return`/`=>` statement, not `const factory X.y() = Z;` redirects).

---

## Alternatives Considered

- **Also flag `factory` constructors redirecting via the `= ClassName.ctor` const-factory-redirect syntax** — rejected; that syntax (`const factory Foo() = Bar;`) is Dart's own idiomatic mechanism for const redirection and has no simpler alternative — flagging it would fight the language, not the code author's mistake.
- **Suggest auto-fix to rewrite as a redirecting constructor** — noted as a natural follow-up quick fix once the base rule ships; deferred from this proposal to keep scope tight (mirrors how `AvoidUnnecessaryConstructorRule` shipped detection before a fix).

---

## Decision

---

## Implementation Notes

---

## Commits
