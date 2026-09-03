# Gap Theme Build Priorities

Source: `plans/GAP_ANALYSIS.md` § Gap Themes (14 themes, compiled 2026-09-02). Every individual rule
named in each theme already has a proposal filed (336 total, see `CHANGELOG.md`): 287 buildable
proposals under `bugs/*/proposal_*.md` (tier_1/2/3/5), 22 rejected under `plans/declined/`, and 27
parked under `plans/deferred/fpdart/` pending product sign-off. This document ranks the *themes* so
implementation work has a build order instead of 336 unordered files.

Ranking factors: gap size (rule count), implementation effort (incremental vs. new infrastructure),
and value (how commonly the affected package/pattern shows up in real Flutter projects).

> **Note:** "Estimated theme total" counts below sum the themes listed in each tier section, not the
> tier folder file counts. Tier folders hold proposals from all themes (including unlisted ones), so
> `bugs/tier_1_quick_wins/` contains 121 files, not ~24. See folder counts in the handover record at
> `plans/history/2026.09/2026.09.03/tier_folders_and_cleanup.md`.

## Tier 1 — Quick wins (small effort, self-contained, no new infra)

| # | Theme | Gaps | Why first |
|---|---|---|---|
| 6 | JSON-codegen annotation-contract enforcement | 2 | Narrow, mechanical: annotation present → member must exist. `bugs/tier_1_quick_wins/proposal_json_serializable_enforcement_rules.md`. |
| 11 | Dart 3.12/3.13 language-feature rules | 3 | Extends existing dot-shorthand/primary-constructor detection saropa already has for other syntax forms. |
| 10 | Test hygiene | 4 | Standalone AST checks (`skip:`, `solo: true`, missing mirror test file) — no cross-file reasoning needed beyond a glob check. |
| 12 | Documentation conventions | 5 | Same shape as saropa's existing doc-comment rules (`document_public_api` family) — extend, don't invent. |
| 14 | Miscellaneous single-rule gaps | ~10 | Grab-bag but each rule is independently trivial; `use_gap`, `prefer_container` (3x-repeated across packages), `prefer_iterable_any/every`, etc. |

**Estimated theme total: ~24 rules, all Tier 1/2 implementation complexity.**

## Tier 2 — Medium effort, high value (popular libraries, moderate new logic)

| # | Theme | Gaps | Why | Complexity note |
|---|---|---|---|---|
| 3 | Riverpod lifecycle/naming completeness | 13 | Riverpod is saropa's best-covered ecosystem already — this closes the last gap in a heavily-used library. `dart_code_metrics_presets`' own `riverpod.yaml` audit was the worst-scoring preset (16/18 GAP), signaling real user pain. | Naming/completeness checks, same shape as existing Riverpod rules. |
| 4 | Bloc ecosystem completeness | 13 | Same argument as Riverpod — Bloc is saropa's other major state-management target, deduped across 3 packages independently raising the same gaps. | Naming/completeness checks, same shape as existing Bloc rules. |
| 9 | Budget/count-style rules with missing variants | 7 | Extends saropa's existing function-length/param-count/cyclomatic-complexity budget infrastructure with sibling counters (file length, etc.) — same config pattern, new counters. | Low — reuse existing budget-rule scaffolding. |
| 5 | Uncovered ecosystem packages (Mocktail, Patrol, get_it, easy_localization, Flame) | 17 | Zero coverage today for widely-used testing/DI packages (Mocktail especially — almost every Flutter test suite uses it). Each package's rules are few (2-7) and self-contained. | Medium — five small independent rule families, no shared infra. |

**Estimated theme total: ~50 rules, moderate complexity, high real-world applicability.**

## Tier 3 — Strategic infrastructure investments (large gaps, need new engines)

| # | Theme | Gaps | Why deliberate | Infra required |
|---|---|---|---|---|
| 2 | Generic, user-configurable architecture/import-boundary engine | 30+ | **The single most-repeated pattern in the entire audit** — 6 independent packages built the same kind of engine. Closing this as one configurable engine (not 6 separate proposals) would out-compete the whole category at once. | A project-configurable (YAML-driven) rule engine: layer graph, naming-per-role, base-type requirements. Proposals already scoped: `bugs/tier_3_infrastructure/proposal_architecture_lints_enforcement_rules.md`, `bugs/tier_3_infrastructure/proposal_clean_architecture_enforcement_rules.md`, `bugs/tier_3_infrastructure/proposal_infra_configurable_import_boundary_dsl.md`, `bugs/tier_3_infrastructure/proposal_infra_configurable_widget_ban_mechanism.md`, `bugs/tier_3_infrastructure/proposal_infra_configurable_class_naming_rules.md`. |
| 7 | Accessibility semantic-IR reasoning | 6 | High value (a11y is a compliance surface) but requires cross-widget ancestor/descendant reasoning saropa's single-pass AST visitors don't currently do. | A semantic-tree IR (WidgetNode → SemanticTree) — new analysis pass, not an incremental rule. |
| 8 | Design-system token provenance | 6 | Generalizes saropa's per-value-type hardcoded-literal heuristics into a "trace every literal back to an `@designSystem`-annotated source" engine. | A provenance-tracing engine — new analysis pass. |

**Estimated theme total: ~42 rules, but each requires new shared infrastructure that then also benefits future rules — build the infra once, not per-rule.**

## Tier 4 — Deliberate scope decision required (large, single ecosystem)

| # | Theme | Gaps | Why held back |
|---|---|---|---|
| 1 | fpdart / functional-programming ecosystem | 26 | Single largest unaddressed family in the audit, but 100% GAP because it requires modeling a *third-party type system* (`Either`/`Option`/`Task`/`TaskEither`/`Do`-notation) that saropa has zero prior art for. This is an "adopt fpdart support" product decision, not an incremental rule batch — needs explicit sign-off before starting. |

## Tier 5 — Low ROI unless specifically requested

| # | Theme | Gaps | Why deprioritized |
|---|---|---|---|
| 13 | Niche third-party package APIs (context_plus, logd, all_observer, mad_lint) | ~57 | Each targets one company's/package's internal API surface with no broader applicability. Proposals exist (`bugs/tier_5_niche/proposal_context_plus_ref_validation_rules.md`, `bugs/tier_5_niche/proposal_logd_linters_rules.md`, `bugs/tier_5_niche/proposal_mad_lint_mapped_fields_rules.md`) but only worth building if saropa specifically wants to support that dependency. |

## Suggested build order

1. **Tier 1** (quick wins) — clears ~24 rules with minimal risk, immediately shrinks the migration-guide TODO count.
2. **Tier 2** (Riverpod + Bloc completeness, budget variants, Mocktail/Patrol/get_it/easy_localization/Flame) — ~50 rules, highest real-world-usage payoff per rule.
3. **Tier 3, starting with #2 (configurable architecture engine)** — highest strategic value (competes with 6 packages at once) but is the largest single build. Do this before #7/#8 since all three need "new engine" investment and #2 has the widest payoff.
4. **Tier 3 continued** (#7 a11y IR, #8 design-token provenance) — smaller infra investments, do after the architecture engine proves out the "new engine" pattern.
5. **Tier 4 (fpdart)** — flag to the user for an explicit go/no-go before scoping; do not start speculatively.
6. **Tier 5 (niche package APIs)** — only on demand.

## Cross-reference

Every rule in this document has a filed proposal — see `doc/guides/migration_guides/README.md` for the
per-package migration guides and `bugs/*/proposal_*.md` (buildable), `plans/declined/` (rejected), or
`plans/deferred/fpdart/` (parked) for implementation-ready specs. This document adds the ordering; it
does not duplicate the per-rule detail already in the proposals.
