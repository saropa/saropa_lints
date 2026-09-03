# PROPOSAL: Config-Driven Banned Type Usage

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `banned_identifier_usage` (sibling config-driven ban mechanism — matches any identifier reference; this proposal is scoped to type-annotation positions specifically)

---

## Summary

Add a config-driven rule that flags usages of a type name in a type-annotation position (variable declarations, parameters, return types, field types, generic type arguments) when that type name is listed in a project's ban list — e.g. banning `dynamic`, a deprecated internal model class, or a legacy collection type in favor of a replacement.

**Closes gap:** DCM `avoid-banned-types` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

Teams frequently need to ban specific *types* project-wide, independent of whether that type is also used as a value or a call target: "no `dynamic` outside generated code," "no raw `Map<String, dynamic>` for domain models — use a typed class," "no references to the pre-migration `LegacyUser` model now that `User` has replaced it everywhere." `banned_identifier_usage` matches `SimpleIdentifier` nodes generically and does not distinguish "this identifier appears in a type-annotation position" from any other usage — a ban list entry for `LegacyUser` under that rule would also (correctly, but coincidentally) catch a `LegacyUser` constructor call or a variable literally named `legacyUser`, conflating three distinct AST situations with three different correction stories under one diagnostic.

DCM (dcm.dev) ships `avoid-banned-types` specifically for the type-annotation-position case: a project lists banned type names and the rule reports only where that name is used as a type (a `NamedType` node), not every other identifier occurrence. saropa_lints has no rule that visits `NamedType` nodes against a configurable ban list today.

---

## Detection / Behavior

Config-driven via a new `banned_types` key in `analysis_options_custom.yaml`, matching the entry shape of `banned_usage_config.dart` (`pattern`, optional `reason`, optional `allowedFiles`). The rule visits `NamedType` nodes via `context.addNamedType`, matches `node.name.lexeme` against the ban list, and reports on the `NamedType` node — leaving other identifier occurrences of the same text (constructor calls, variable names) to `banned_identifier_usage` if a project also wants that broader ban.

### Should flag (bad code)

```dart
// analysis_options_custom.yaml:
// banned_types:
//   - name: LegacyUser
//     reason: "Use User (lib/src/models/user.dart) — LegacyUser is scheduled for removal."

LegacyUser fetchUser(String id) { ... } // LINT — banned type in return position

class Repository {
  final LegacyUser? cachedUser; // LINT — banned type in field position
}
```

### Should pass (good code)

```dart
User fetchUser(String id) { ... } // OK — approved replacement type

// A value named legacyUser (not a type usage) is out of scope for this rule.
final legacyUser = migrateFromLegacyFormat(raw); // OK — not a NamedType node
```

---

## Proposed Tier

Tier: Comprehensive
Justification: empty-by-default config surface, matching the tier placement rationale for the sibling `avoid_banned_annotations`/`avoid_banned_imports`/`avoid_banned_exports`/`avoid_banned_file_names` proposals in this batch and the existing `banned_identifier_usage` rule — no diagnostics fire until a team opts in.

---

## Edge Cases

1. **Generic type arguments (`List<LegacyUser>`, `Map<String, LegacyUser>`)** — `NamedType` nodes appear inside `TypeArgumentList` as well as top-level positions, so the rule must visit all `NamedType` occurrences regardless of nesting depth, not just top-level declarations, otherwise `List<LegacyUser> fetchAll()` would silently bypass the ban.
2. **`dynamic` as a special case** — `dynamic` parses as a `NamedType` in the analyzer AST, so banning it (a common request — "no `dynamic` outside generated/interop code") works naturally with this mechanism without special-casing, but the rule should still respect `allowedFiles` so codegen output or FFI/interop bridges that legitimately need `dynamic` can be excluded.
3. **Type usage in `as`/`is` expressions vs. declaration positions** — DCM's rule (and this proposal) targets declaration-position type annotations. A banned type appearing in an `is LegacyUser` check or `as LegacyUser` cast is a different AST node shape (`TypeAnnotation` used in `IsExpression`/`AsExpression`, still ultimately a `NamedType`) and should also be caught, since `context.addNamedType` fires regardless of the enclosing context — document this as intentional breadth rather than an afterthought.

---

## Alternatives Considered

- **Folding into `banned_identifier_usage`** — rejected for the same reason as `avoid_banned_annotations`: it would conflate "any identifier reference" with "type-annotation-position usage," which have different false-positive profiles (a banned type name that happens to also be a legitimate local variable name would be a spurious hit under the broader rule) and different correction messages ("replace this type" vs. "replace this reference").
- **Type-resolution-based matching (compare against the declaring `Element`, not the source-text name)** — more precise for cases involving import aliasing or shadowed local names, but adds `usesTypeResolution` overhead for what is typically an unambiguous team-internal type name. Name-based `NamedType.name.lexeme` matching is proposed as v1, consistent with the sibling `avoid_banned_annotations` proposal's same tradeoff.

---

## Decision

---

## Implementation Notes

---

## Commits
