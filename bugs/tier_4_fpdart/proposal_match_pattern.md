# PROPOSAL: Config-Driven Pattern Ban Engine

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `banned_identifier_usage` (if present), `avoid_banned_imports`, `avoid_banned_types`

---

## Summary

Add `match_pattern` — a generic, configuration-driven rule that flags any code construct matching a team-supplied regex/AST pattern list in `analysis_options_custom.yaml`. Unlike the existing `avoid_banned_*` rules (which target specific construct kinds: imports, types, exports, identifiers), `match_pattern` is a catch-all engine for arbitrary project-specific conventions the built-in rule set doesn't anticipate.

**Closes gap:** `many_lints` `match_pattern` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Every large codebase accumulates a handful of "don't do X here" conventions too specific or short-lived to justify a dedicated rule: banning a deprecated internal helper's call signature, banning a string literal pattern (e.g. a hardcoded URL), or banning a particular method-chain shape. A single config-driven pattern-matching rule lets teams express these without waiting on a saropa_lints release, complementing (not replacing) the existing typed `avoid_banned_*` family which stays for the common, well-defined cases.

---

## Detection / Behavior

Read a list of pattern entries from `analysis_options_custom.yaml` (e.g. under `plugins.saropa_lints.match_pattern.patterns`), each with a `pattern` (regex matched against the source text of a node, or a simplified AST-shape selector) and a `message`. Flag any node in the source whose textual/structural form matches a configured pattern.

### Should flag (bad code)

```yaml
# analysis_options_custom.yaml
plugins:
  saropa_lints:
    match_pattern:
      patterns:
        - pattern: 'print\('
          message: "Use the project logger instead of print()."
```

```dart
void debugDump() {
  print('debug'); // LINT — matches configured pattern 'print\('
}
```

### Should pass (good code)

```dart
void debugDump() {
  logger.debug('debug'); // OK — does not match any configured pattern
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Opt-in, config-driven rule with zero effect until a team supplies patterns; placed alongside other configuration-surface rules that require explicit setup.

---

## Edge Cases

1. **No patterns configured** — rule is a no-op; must not error or warn about missing config.
2. **Pattern matches inside a string literal or comment (not code)** — needs discussion; regex-on-source-text matching can't distinguish code from literals/comments without care — recommend matching against token/AST text only, not raw file bytes, to avoid matching inside unrelated string content.
3. **Invalid regex in config** — should fail fast with a clear config-validation error at analysis startup, not silently skip the pattern.
4. **Overlap with an existing typed rule (e.g. a pattern that re-implements `avoid_banned_imports`)** — should pass through both; this rule doesn't need to detect overlap, duplicate flags are an acceptable config-authoring issue, not a bug.

---

## Alternatives Considered

- **Extend `avoid_banned_types`/`banned_usage` config to cover arbitrary regex instead of a new rule** — considered; if saropa_lints already has a generic banned-usage config surface (see `analysis_options_custom.yaml` `banned_usage` per project memory), prefer extending that surface over adding a new rule id. Needs a codebase check before implementation to avoid duplicating an existing mechanism.

---

## Decision

---

## Implementation Notes

---

## Commits
