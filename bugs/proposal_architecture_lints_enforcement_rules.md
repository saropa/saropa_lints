# PROPOSAL: Configurable Architecture-Enforcement Rule Engine (arch_* family)

**Status: Open**

Created: 2026-09-02
Type: New rule (infrastructure-level, 16 rule IDs)
Related rules: existing dependency/import-boundary rules if present, otherwise `none`

---

## Summary

Add a config-driven architecture-enforcement engine — a set of 16 rules, all sourced from a single project config file (analogous to `architecture_lints`' `architecture.yaml`), that lets a team declare its layered/modular architecture (modules, allowed dependencies, naming conventions, required/forbidden annotations, exception-handling boundaries, member visibility rules) and have saropa_lints statically enforce it. This is infrastructure work: one shared config schema + parser, then 16 thin rule implementations that each check one facet of the declared architecture against the AST.

**Closes gap:** `architecture_lints` `arch_annot_forbidden`, `arch_annot_missing`, `arch_annot_strict`, `arch_dep_module`, `arch_exception_conversion`, `arch_exception_forbidden`, `arch_exception_missing`, `arch_member_forbidden`, `arch_member_missing`, `arch_naming_antipattern`, `arch_naming_grammar`, `arch_naming_pattern`, `arch_orphan_file`, `arch_parity_missing`, `arch_safety_param_forbidden`, `arch_safety_param_strict` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

`architecture_lints` is the most structurally different package in the landscape: instead of shipping fixed rules, it ships a rule *engine* driven entirely by a project-authored `architecture.yaml` that names modules (by path glob), declares allowed/forbidden dependencies between them, and layers naming/annotation/exception/member conventions on top. This is prior art for a class of enforcement saropa_lints does not currently offer: teams with a Clean Architecture / modular-monolith / DDD layering who want the analyzer itself to fail a PR when a `data/` file imports from `presentation/`, or when a domain-layer class is missing a required `@Entity` annotation, or when a repository method throws a raw `Exception` instead of a declared domain exception type.

Building this as one coherent config-driven system (rather than 16 independent one-off rules) matches how the source package itself is designed and avoids 16 duplicated config-parsing implementations.

---

## Detection / Behavior

All 16 rules share one config file, e.g. `architecture_rules.yaml` at the project root, declaring:
- **Modules**: named path-glob groups (`domain: lib/**/domain/**`, `data: lib/**/data/**`, `presentation: lib/**/presentation/**`).
- **Dependency rules**: allowed/forbidden import edges between modules (`presentation -> domain: allowed`, `domain -> presentation: forbidden`).
- **Naming rules**: required suffix/prefix patterns per module (`domain` classes must not end in `Impl`; `data` repository implementations must end in `RepositoryImpl`), plus a grammar check (e.g. use-case classes should be verb-phrase named).
- **Annotation rules**: required/forbidden/strict-set annotations per module (`domain` entities must carry `@immutable`; `presentation` widgets forbidden from `@visibleForTesting` production members).
- **Exception rules**: required conversion at layer boundaries (a `data`-layer method calling a `dio`/`http` client must catch and convert to a declared domain exception type before it crosses into `domain`), forbidden raw exception types crossing a boundary, and missing-catch detection.
- **Member rules**: required/forbidden member declarations per module (e.g. every `Repository` interface in `domain` must have a matching abstract method surface; implementations forbidden from exposing extra public members not on the interface — this also covers `arch_parity_missing`, method-parity between an interface and its implementation).
- **Orphan-file detection**: a file inside a declared module glob that matches none of the module's expected role patterns (e.g. a stray file directly in `lib/domain/` that isn't a recognized entity/usecase/repository shape).
- **Safety-param rules**: forbidden/strict-required parameters on cross-boundary calls (e.g. a `data`-layer public method must not accept a `BuildContext` parameter; a `domain` use-case's public method parameters must all be declared value objects, not raw primitives, under `strict` mode).

### Rule-to-facet mapping

| Rule ID | Facet |
|---|---|
| `arch_dep_module` | Forbidden/required import edges between declared modules |
| `arch_annot_missing` | Required annotation absent on a module's members |
| `arch_annot_forbidden` | Forbidden annotation present on a module's members |
| `arch_annot_strict` | Only-allowlisted annotation set enforced strictly |
| `arch_naming_pattern` | Required name suffix/prefix per module/role |
| `arch_naming_antipattern` | Forbidden name pattern (e.g. `Manager`, `Helper` in domain layer) |
| `arch_naming_grammar` | Structural naming convention (verb-phrase use cases, noun-phrase entities) |
| `arch_exception_missing` | Required exception handling/conversion absent at a boundary |
| `arch_exception_forbidden` | Forbidden raw exception type crossing a boundary |
| `arch_exception_conversion` | Exception not converted to the declared domain exception type |
| `arch_member_missing` | Required member/method absent on a declared contract |
| `arch_member_forbidden` | Forbidden member exposed beyond its declared contract |
| `arch_parity_missing` | Interface/implementation method-signature parity mismatch |
| `arch_orphan_file` | File inside a module glob matching no recognized role |
| `arch_safety_param_forbidden` | Forbidden parameter type/name crossing a boundary |
| `arch_safety_param_strict` | Strict parameter-shape enforcement (value objects only, etc.) |

### Should flag (bad code, `arch_dep_module` example)

```dart
// lib/presentation/user_screen.dart
import 'package:app/data/user_repository_impl.dart'; // LINT — presentation must depend on domain, not data, per architecture_rules.yaml
```

### Should pass (good code)

```dart
// lib/presentation/user_screen.dart
import 'package:app/domain/user_repository.dart'; // OK — presentation -> domain is an allowed edge
```

---

## Proposed Tier

Tier: Pedantic (opt-in via config presence)
Justification: Zero-effect unless a project authors `architecture_rules.yaml`; the 16 rules are meaningless noise without an explicit config, so they must be off by default and only activate for teams that opt in by creating the config file. Pedantic/opt-in matches saropa's existing pattern for config-driven, project-specific enforcement (see `banned_usage` in `analysis_options_custom.yaml`).

---

## Edge Cases

1. **No `architecture_rules.yaml` present in the project** — all 16 rules must be silent no-ops; never fire on a project that hasn't opted in.
2. **Malformed/invalid config file** (unknown module glob syntax, contradictory allow/forbid edge for the same pair) — should surface one clear config-validation diagnostic (not 16 silent failures or 16 duplicate errors), and rules should degrade to no-op rather than crash the analyzer.
3. **A file matches two module globs simultaneously** (overlapping glob patterns) — needs discussion; likely resolve via most-specific-glob-wins or flag as a config error (ambiguous module membership) rather than silently picking one.
4. **Generated code (`.g.dart`, `.freezed.dart`) inside a governed module** — should pass; standard generated-file suppression applies across all 16 rules uniformly via the shared engine, not per-rule.
5. **Monorepo/multi-package project with per-package architecture configs** — needs discussion; initial scope should support one config per analyzed project root, with multi-config/package-scoped support deferred.

---

## Alternatives Considered

- **Ship 16 independent rules, each with its own bespoke config parsing** — rejected; duplicates the module-resolution and glob-matching logic 16 times, and risks the per-rule configs drifting out of sync with each other (a module renamed in one rule's config but not another's). A single shared config + parser + module-resolver, with 16 thin rule bodies consuming it, is both less code and less likely to produce inconsistent behavior across the family.
- **Fold this into saropa's existing `banned_usage`/`analysis_options_custom.yaml` config surface instead of a new file** — considered; the scope (modules, dependency graphs, per-module naming/annotation/exception/member rules) is large enough to warrant its own schema and file for readability, but the *loading mechanism* (custom config surface pattern) should reuse `saropa-lints-config-and-tiers` conventions rather than invent a new one.

---

## Decision

---

## Implementation Notes

- This is the largest single proposal in this batch by implementation surface — treat it as its own mini-project: one config schema/parser module shared by all 16 rule classes, not 16 independent implementations.
- Load `Skill(lint-rules)` and `Skill(saropa-lints-config-and-tiers)` before implementation; the config-loading pattern should follow existing `analysis_options_custom.yaml`/`banned_usage` precedent for where/how project-level config is read.
- Consider phased delivery: `arch_dep_module` (dependency edges) first as the highest-value, most self-contained facet; annotation/naming/exception/member/orphan/safety-param facets as follow-on phases sharing the same module-resolution core.

---

## Commits
