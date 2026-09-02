# PROPOSAL: Configurable Class Name Prefix/Suffix Enforcement Engine

**Status: Open**

Created: 2026-09-02
Type: New rule (infrastructure)
Related rules: `banned_identifier_usage`, `use_notifier_suffix` (existing narrow suffix check)

---

## Summary

Add a generic, config-driven naming engine (`use_class_prefix` + `use_class_suffix`) that lets a project declare, in `analysis_options_custom.yaml`, a mapping of "classes matching pattern X (e.g. implementing an interface, extending a base class, or in a given directory) must carry prefix/suffix Y" — e.g. "every class in `lib/src/repositories/` must end in `Repository`," or "every class implementing `UseCase` must start with `Use`."

**Closes gap:** `many_lints` `use_class_prefix` and `use_class_suffix` (github.com/Nikoro/many_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` Gap Theme 2 "config-driven ban/require mechanisms."

---

## Motivation

saropa already has several *fixed* single-purpose naming rules (e.g. `use_notifier_suffix`, Bloc/Cubit-suffix checks), but each is hand-coded for one library's convention. `many_lints` ships a generic engine so teams can enforce their own house-style naming without waiting for saropa to add a bespoke rule per pattern — the same generic-mechanism gap already identified for `banned_identifier_usage` (annotation/type/directory-aware bans) in `GAP_ANALYSIS.md` Gap Theme 2. Naming and banning are the same underlying "match a pattern, assert a property" engine, so this is a natural pairing.

---

## Detection / Behavior

Config declares a list of `{match: {implements|extends|directory|annotation}, require: {prefix|suffix}}` entries. For each `ClassDeclaration` matching a configured `match` clause, flag when the class name does not start/end with the configured string.

### Should flag (bad code)

```yaml
# analysis_options_custom.yaml
saropa_lints:
  class_naming:
    - match: { implements: 'UseCase' }
      require: { prefix: 'Use' }
```

```dart
class FetchProfile implements UseCase<Profile> {} // LINT — must be prefixed "Use"
```

### Should pass (good code)

```dart
class UseFetchProfile implements UseCase<Profile> {} // OK — matches configured prefix
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Opt-in, config-driven — inert with no configuration, so it is safe to ship in Comprehensive without affecting projects that don't configure it; not Essential since it does nothing until a team writes rules for it.

---

## Edge Cases

1. **No config present** — should no-op entirely; the two rule IDs must not fire on a default install.
2. **A class matching multiple configured `match` clauses with conflicting prefix/suffix requirements** — needs discussion; likely flag both violations independently rather than silently picking one.
3. **Anonymous/private classes (leading underscore) matching a directory rule** — should still flag if the config doesn't explicitly exempt private classes; teams can scope their `directory` match to exclude private-only files if needed.
4. **Abstract classes/mixins matching an `implements`/`extends` clause** — should flag identically to concrete classes unless config adds an `excludeAbstract: true` option.

---

## Alternatives Considered

- **Ship as two separate hard-coded rules per common convention (Repository, UseCase, ViewModel, etc.)** — rejected; that's an unbounded and ever-growing rule count for what is fundamentally one pattern-matching engine, exactly the trap `banned_identifier_usage`'s Gap Theme 2 discussion already identifies.

---

## Decision

---

## Implementation Notes

---

## Commits
