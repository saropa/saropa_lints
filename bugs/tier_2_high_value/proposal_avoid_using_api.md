# PROPOSAL: `avoid_using_api` — Generic Config-Driven Banned-API Mechanism

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `banned_identifier_usage` (near-identical existing mechanism — see Alternatives Considered); `avoid_banned_imports`, `avoid_banned_exports`, `avoid_banned_types`, `avoid_banned_annotations`, `avoid_banned_file_names` (sibling proposals covering other specific banned-surface node kinds)

---

## Summary

`solid_lints`' `avoid-using-api` is a single, generic config-driven rule: a project lists banned class/method/API identifiers (with optional reasons) in config, and the rule flags any use of a listed API anywhere in the project — one flexible mechanism instead of one rule per node kind.

**Closes gap:** `solid_lints` `avoid_using_api` (github.com/solid-software/solid_lints). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` solid_lints "Gaps" section.

---

## Motivation

Teams frequently need to forbid specific APIs project-wide: a deprecated internal helper pending deletion, a dangerous platform call (e.g. `Process.run` in code that must stay sandboxed), or a class that should only be constructed through a factory wrapper. `solid_lints` answers this with one broad, generically-named rule covering "any API surface" rather than a family of narrowly-scoped rules per Dart construct (import, type reference, annotation, export, file name).

**saropa_lints already has a closely overlapping mechanism.** `BannedUsageRule` (`banned_identifier_usage`, `lib/src/rules/code_quality/code_quality_avoid_rules.dart:4441`) is config-driven off `banned_usage_config.bannedUsageEntries`, visits every `SimpleIdentifier` in the project, matches against configured ban patterns (with `reason` and `allowedFiles` support), and already carries a `configAliases` getter returning `['banned_usage']` — this is functionally the same shape as `avoid_using_api`: a flat list of banned name patterns, matched project-wide, with per-file exceptions. Several sibling proposals already exist in this repo's `bugs/` directory extending the same family to other node kinds: `proposal_avoid_banned_imports.md` (import URIs), `proposal_avoid_banned_exports.md` (export directives), `proposal_avoid_banned_types.md` (type references), `proposal_avoid_banned_annotations.md` (annotation usage), `proposal_avoid_banned_file_names.md` (file naming), and `proposal_extend_banned_identifier_usage_dcm_parity.md` (further extending the identifier rule itself).

---

## Detection / Behavior

If pursued as scoped by solid_lints (rather than folded into the existing mechanism — see Alternatives Considered), the distinguishing feature over `banned_identifier_usage` would be matching **member access / method calls on a specific receiver type**, not just any bare identifier text — e.g. banning `SharedPreferences.getInstance()` specifically as a static method call on that class, distinguishable from an unrelated local variable or method elsewhere in the project that happens to be named `getInstance`. `banned_identifier_usage`'s current `SimpleIdentifier`-name matching cannot express "ban this method only when called on this receiver type" — it matches the bare name anywhere it appears.

### Should flag (bad code)

```dart
// analysis_options_custom.yaml:
// banned_api:
//   - receiver: "SharedPreferences"
//     member: "getInstance"
//     reason: "Use AppPreferences.instance — do not touch SharedPreferences directly."

final prefs = await SharedPreferences.getInstance(); // LINT — banned API
```

### Should pass (good code)

```dart
final prefs = await AppPreferences.instance; // OK — approved wrapper
```

---

## Proposed Tier

Tier: Comprehensive
Justification: empty-by-default config surface — produces zero diagnostics for any project that has not opted in, consistent with `banned_identifier_usage`'s own tier placement.

---

## Edge Cases

1. **Bare identifier with the banned member name but unrelated receiver type** (e.g. a local class also happens to define a `getInstance` method) — should pass; this is precisely the false-positive class receiver-aware matching exists to avoid, and the one genuine improvement this rule offers over `banned_identifier_usage`.
2. **Static member access through a type alias / import prefix** (`prefs_pkg.SharedPreferences.getInstance()`) — should flag; matching must resolve the receiver's static type, not the literal source text of the prefix.
3. **Instance method call through a variable of the banned type** (`SharedPreferences prefs = ...; prefs.someBannedInstanceMethod();`) — should flag if the config entry targets an instance member; requires resolving the static type of the receiver expression, not just constructor/static-call sites.

---

## Alternatives Considered

- **Build as a genuinely new, separate rule** — the receiver-aware matching capability (distinguishing `Type.member` calls from bare identifier collisions) is real and not something `banned_identifier_usage` does today, so there is a legitimate technical gap.
- **Extend `banned_identifier_usage` with an optional `receiver` field on each ban entry instead of shipping a new rule** — **this is the recommended path.** The existing rule already has the config plumbing (`banned_usage_config.dart`), the `allowedFiles` exception mechanism, and the `configAliases` pattern for exactly this kind of API-surface ban. Adding an optional `receiver: "TypeName"` field to each entry (matched via static-type resolution when present, falling back to today's bare-name match when absent) delivers everything `avoid_using_api` needs without a second parallel rule, a second config key, and a second set of documentation for what is conceptually one feature: "ban this API surface, optionally scoped to a receiver type." This is the same judgment already applied to the sibling `avoid_banned_imports`/`avoid_banned_exports`/`avoid_banned_types` proposals, which are kept as separate rules only because they inspect structurally different AST node kinds (`ImportDirective`, `ExportDirective`, `NamedType`) that `SimpleIdentifier`-based matching genuinely cannot reach — `avoid_using_api`'s target (member access on a receiver) does not have that structural justification, since it is still fundamentally an identifier-shaped check with one extra optional filter.
- **Recommendation:** do not ship `avoid_using_api` as a standalone rule. Extend `BannedUsageRule`/`banned_identifier_usage` with an optional per-entry `receiver` type filter, and cross-reference this proposal from `proposal_extend_banned_identifier_usage_dcm_parity.md` so the extension work is tracked in one place rather than split across proposals.

---

## Decision

---

## Implementation Notes

If the extension path is chosen: add an optional `receiver` (or `receiverType`) field to the ban-entry schema in `banned_usage_config.dart`; when present, resolve the static type of the identifier's containing `PrefixedIdentifier`/`MethodInvocation` target and require it to match before reporting, instead of matching the bare name unconditionally. `usesTypeResolution` is already `true` on `BannedUsageRule`, so the type-resolution capability needed for receiver matching is already available at the call site.

---

## Commits
