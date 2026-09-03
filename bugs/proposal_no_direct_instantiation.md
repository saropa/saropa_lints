# PROPOSAL: Flag Direct Construction of Classes That Must Go Through a Factory/DI Boundary

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `no_direct_instantiation` to flag `ClassName(...)` constructor calls for classes on a project-configured "must be injected" list, outside of the class's own designated factory/provider/registration site. This lets teams enforce that services, repositories, and other DI-managed types are always obtained through the container instead of being hand-constructed at arbitrary call sites.

**Closes gap:** `ripplearc_linter` `no_direct_instantiation` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Dependency-injected architectures rely on every consumer obtaining a service through the container so that mocking, lifecycle management, and singleton guarantees hold. A stray `MyRepository()` call sidesteps all of that — it silently creates an unmanaged instance that isn't the one tests substitute or the one other code shares. These bugs are invisible until a test's mock doesn't take effect or two "singletons" turn out to be two different objects.

---

## Detection / Behavior

### Should flag (bad code)

```dart
class OrderScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final repo = OrderRepository(); // LINT — OrderRepository is DI-managed, must not be constructed directly
    return repo.build();
  }
}
```

### Should pass (good code)

```dart
class OrderScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final repo = context.read<OrderRepository>(); // OK — obtained through the DI container
    return repo.build();
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: requires project-specific configuration of which classes are DI-managed; not useful without setup, so it belongs in an opt-in tier rather than firing by default.

---

## Edge Cases

1. **Construction inside the class's own registered factory/provider function** — should pass; that is the designated construction site.
2. **Construction inside a test file for a fake/mock double, not the real class** — should pass; the rule targets the real DI-managed class name, not test doubles subclassing it.
3. **Class not in the configured list** — should pass; the rule is entirely opt-in per class via configuration.
4. **Constant/`const` construction of an otherwise DI-managed class** — needs discussion; `const` instances are typically stateless value types and may not need DI in practice.

---

## Alternatives Considered

- **Detect DI-managed classes automatically via an annotation the class must carry (e.g. `@injectable`)** — considered as an alternative activation mechanism to explicit configuration; would remove the need for a project-wide class list at the cost of requiring the annotation package as a dependency.

---

## Decision

---

## Implementation Notes

---

## Commits
