# PROPOSAL: Extend `prefer_unmodifiable_collections` Beyond Equatable/State/Event Classes

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `prefer_unmodifiable_collections`

---

## Summary

Extend `prefer_unmodifiable_collections` to flag any mutable collection literal assigned to a field or variable that is never mutated after creation, regardless of the enclosing class's supertype — not only classes extending `Equatable`, ending in `State`/`Event`, or annotated `@immutable` — matching DCM's `prefer-unmodifiable-of`, which is a general check independent of class role.

**Closes gap:** DCM `prefer-unmodifiable-of` (dcm.dev) — currently PARTIAL via saropa's `prefer_unmodifiable_collections`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" PARTIAL matches table.

---

## Motivation

`lib/src/rules/packages/equatable_rules.dart:1236-1330+` implements `PreferUnmodifiableCollectionsRule`. Its gate is an explicit allowlist of "immutable-intent" class shapes before any field is even inspected:

```dart
context.addClassDeclaration((ClassDeclaration node) {
  final ExtendsClause? extendsClause = node.extendsClause;
  bool isImmutableClass = false;

  if (extendsClause != null) {
    final String superName = extendsClause.superclass.name.lexeme;
    if (superName == 'Equatable' ||
        superName.endsWith('State') ||
        superName.endsWith('Event')) {
      isImmutableClass = true;
    }
  }

  for (final Annotation annotation in node.metadata) {
    if (annotation.name.name == 'immutable') {
      isImmutableClass = true;
      break;
    }
  }

  if (!isImmutableClass) return;
  ...
```

A plain class, a `ChangeNotifier`, a repository, a service, or any ordinary Dart class with a `final List<Item> items = [1, 2, 3];` field that is never mutated after construction gets no coverage at all — the rule returns immediately at `if (!isImmutableClass) return;`. DCM's `prefer-unmodifiable-of` is not scoped to any particular class role: it flags any mutable collection literal (`[]`, `{}`, `<K,V>{}`) assigned to a field or variable when static analysis shows the collection is never mutated (no `.add`, `.remove`, `[]=`, `.clear`, `.addAll`, etc. called on it) anywhere in its lifetime, because an unmutated mutable collection is a latent bug: any future edit that adds a mutation elsewhere in the class silently breaks the "never mutated" invariant the original author relied on, and callers holding a reference to the field can mutate it externally regardless of whether the class itself ever does — the exact class-agnostic version of the risk the Equatable-scoped rule already documents ("External code can modify the collection contents without creating a new instance").

## Detection / Behavior

### Should flag (bad code)

```dart
// Plain class — no Equatable, no State/Event suffix, no @immutable.
// Today's rule does not even inspect this class. Should now flag.
class ThemeConfig {
  final List<Color> palette = [Colors.red, Colors.blue]; // LINT
}

class ApiService {
  // Local field, never mutated anywhere in the class — LINT
  final Map<String, String> _headers = {'Accept': 'application/json'};
}
```

### Should pass (good code)

```dart
class ThemeConfig {
  final List<Color> palette = List.unmodifiable([Colors.red, Colors.blue]); // OK
}

class MutableCache {
  final List<Item> _items = []; // OK — mutated below, so mutability is intentional
  void add(Item item) => _items.add(item);
}
```

## Proposed Tier

Tier: Professional

Justification: keep parity with the existing rule's tier — `prefer_unmodifiable_collections` is in `professionalOnlyRules` (`lib/src/tiers.dart` line 2390). Widening the class-role gate does not change the nature of the check (still requires walking the enclosing class for mutation call sites), so the same tier and false-positive tolerance apply.

## Edge Cases

1. **Field mutated via a method within the same class** (`void add(x) => _items.add(x);`) — must NOT flag; this is the primary discriminator DCM's version relies on, and is exactly the "Find collection fields ... Check if constructor makes it unmodifiable" style scan already present in the existing rule's body, generalized from "is it wrapped at construction" to "is it ever mutated anywhere in the class."
2. **Collection exposed via a public getter and mutated by external callers** (`List<Item> get items => _items;` where callers do `config.items.add(x)`) — cannot be detected by a single-file/single-class AST walk (requires cross-file call-site analysis of every caller); document this as a known limitation and do NOT attempt to flag or clear based on external-caller behavior — treat "no mutation calls found within the declaring class" as the entire signal, same limitation profile as the existing rule.
3. **Collection reassigned as a whole** (`_items = newList;`) rather than mutated in place — this is not the same hazard (whole-reference reassignment doesn't corrupt a shared mutable instance the way in-place mutation does) and should NOT count as "mutation" for this rule's purposes; only in-place mutating methods/operators count.
4. **`const` collection literals** (`static const List<int> x = [1, 2, 3];`) — already effectively unmodifiable at compile time (mutating a `const` list throws); should NOT flag, since wrapping it in `List.unmodifiable()` would be redundant.
5. **Collections built with a spread or collection-if/for** (`final items = [...base, if (x) extra];`) — still a mutable collection literal at runtime; should flag under the same "never mutated after creation" rule if applicable.
6. **Fields typed via a generic type parameter or inferred `var`** — the existing rule already string-matches `typeSource.startsWith('List'|'Set'|'Map')`; the widened version should keep that approach or upgrade to `usesTypeResolution`-based `DartType` checks (the file already sets `usesTypeResolution => true`) to correctly handle aliased/generic collection types.

## Alternatives Considered

- **New standalone rule** (`prefer_unmodifiable_collection_fields`) for the general case, leaving the Equatable-scoped rule as-is — considered, but the detection logic (find collection-typed field, scan class body for mutating calls, check for `.unmodifiable`/`List.of`/`.toList()` wrapping) is identical between the scoped and general cases; the only difference is the `isImmutableClass` gate. Removing that gate (rather than adding a parallel rule) is the smaller, more maintainable change and matches DCM's single `prefer-unmodifiable-of` rule id.
- **Keep the class-role gate but expand its allowlist** (add `ChangeNotifier`, `freezed`-generated classes, etc.) — rejected; any allowlist approach still misses the general "any class, any mutable field, never mutated" case DCM's rule targets, and each addition just narrows the gap without closing it.

---

## Decision

---

## Implementation Notes

In `PreferUnmodifiableCollectionsRule.runWithReporter` (`lib/src/rules/packages/equatable_rules.dart`), remove (or make optional/config-gated) the `isImmutableClass` early return, and generalize the existing per-class "find collection fields ... check if made unmodifiable" loop to also scan for in-place mutating method calls (`.add`, `.addAll`, `.remove`, `.removeAt`, `.clear`, `.insert`, `.sort`, `[]=` via `IndexExpression` on the LHS of an `AssignmentExpression`) on the field anywhere in the class body, suppressing the report when any such call is found.

---

## Commits
