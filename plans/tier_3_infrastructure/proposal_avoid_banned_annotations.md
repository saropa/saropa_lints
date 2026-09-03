# PROPOSAL: Config-Driven Banned Annotation Usage

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `banned_identifier_usage` (name-only ban list — this proposal extends the ban mechanism to `@Annotation` usages, a distinct AST surface)

---

## Summary

Add a config-driven rule that flags usages of `@Annotation` markers listed in a project's `analysis_options_custom.yaml` ban list, analogous to how `banned_identifier_usage` bans plain identifiers today but scoped to annotation metadata specifically.

**Closes gap:** DCM `avoid-banned-annotations` (dcm.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` "DCM proper" TRUE GAPS section.

---

## Motivation

`saropa_lints` already has `banned_identifier_usage` (`lib/src/rules/code_quality/code_quality_avoid_rules.dart:4441`, config source `lib/src/banned_usage_config.dart`), which matches banned identifier names against `SimpleIdentifier` nodes anywhere in the file. That mechanism does not distinguish an annotation usage (`@Deprecated`, `@JS`, `@Riverpod`, a company-internal `@LegacyApi` marker) from any other identifier reference with the same name — a project cannot ban "use of `@LegacyApi` as an annotation" without also banning every other reference to the bare word `LegacyApi` elsewhere in the file (a method call, a class name, an import prefix), which is both too broad and produces confusing diagnostics on the wrong node.

DCM (dcm.dev) ships this as `avoid-banned-annotations`: a project lists banned annotation names in config, and the rule reports specifically on `Annotation` AST nodes matching those names. This is common in large codebases enforcing "no `@visibleForTesting` outside `test/`", "no `@deprecated` without a tracked ticket ID in the message", or "no legacy `@JsonKey` usage after a codegen migration" — all annotation-specific bans that `banned_identifier_usage`'s node-agnostic matching cannot express precisely.

---

## Detection / Behavior

Config-driven: a project lists banned annotation names (optionally with an `allowedFiles` glob list and a `reason` string, following the same shape as `banned_usage_config.dart`'s existing `BannedUsageEntry`) under a new `banned_annotations` key in `analysis_options_custom.yaml`. The rule visits `Annotation` nodes via `context.addAnnotation`, matches `node.name.name` (or the constructor name for `@Foo.named()` annotations) against the ban list, and reports on the `Annotation` node itself — never on unrelated identifier usages sharing the same text.

### Should flag (bad code)

```dart
// analysis_options_custom.yaml:
// banned_annotations:
//   - name: LegacyApi
//     reason: "Migrated off the legacy codegen path; use @RestApi instead."

@LegacyApi() // LINT — banned annotation
class UserEndpoint {
  void fetch() {}
}
```

### Should pass (good code)

```dart
@RestApi() // OK — not in the ban list
class UserEndpoint {
  void fetch() {}
}

// A plain reference to the identifier `LegacyApi` that is NOT an annotation
// usage (e.g. a variable named legacyApi, or a class reference in a type
// position) is out of scope for this rule — banned_identifier_usage covers
// that broader case if the project also wants it banned everywhere.
final String legacyApiUrl = fetchLegacyApiUrl(); // OK — not an @Annotation node
```

---

## Proposed Tier

Tier: Comprehensive
Justification: this is a project-specific governance mechanism with zero default entries — it only fires when a team explicitly configures a ban list, so it carries no signal for the median consumer. Comprehensive is where saropa's other opt-in, config-driven, team-governance-style rules (e.g. `banned_identifier_usage`) already live; Pedantic is reserved for stricter universal style preferences rather than empty-by-default config surfaces.

---

## Edge Cases

1. **Constructor-style annotations (`@Foo.named(...)`)** — should flag when the ban list names the base annotation class `Foo`, regardless of which named constructor is invoked, matching DCM's behavior and the existing `banned_identifier_usage`'s "match on identifier text" semantics.
2. **`allowedFiles` overrides** — a banned annotation used inside a file matching an `allowedFiles` glob (e.g. `**/legacy_bridge.dart` during a staged migration) should not report, reusing the same glob-matching logic already in `BannedUsageRule._matchesName`/`allowedFiles` handling so the two ban mechanisms share one config parsing path.
3. **Annotations on non-declaration positions** (e.g. `@pragma` on a parameter, `@Deprecated` on an enum value) — the rule should still fire; `Annotation` nodes can appear on any declaration or parameter, and the ban list is about the annotation identity, not its host node type.

---

## Alternatives Considered

- **Extend `banned_identifier_usage` to also match `Annotation.name`** — rejected because it conflates two different ban semantics (any identifier reference vs. a specific annotation usage) under one config key and one diagnostic message, making it unclear to users which surface a given ban list entry targets. A separate rule with its own config key (`banned_annotations`) keeps the intent explicit and lets a team enable one without the other.
- **Type-resolution-based matching (resolve to the annotation's declaring element)** — more precise (handles renamed imports correctly) but adds `usesTypeResolution` cost for a rule that only fires on explicitly configured, typically unambiguous team-internal names. Name-based matching (consistent with `banned_identifier_usage`'s existing approach) is proposed as the v1 implementation; element-based resolution can be a follow-up if false positives from import aliasing are reported.

---

## Decision

---

## Implementation Notes

---

## Commits
