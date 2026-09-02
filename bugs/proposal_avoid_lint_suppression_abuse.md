# PROPOSAL: Flag `// ignore:` Suppression of Configured High-Value Rules

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `avoid_lint_suppression_abuse` — a configurable rule that flags `// ignore:` / `// ignore_for_file:` comments naming any rule from a project-configured "protected" rule set. This generalizes flutter_skill_lints' `avoid_flutter_skill_lint_rule_suppression` (which hard-codes suppression-of-itself as a banned pattern) into a saropa mechanism where the project declares which of ITS OWN configured rules are too important to silently suppress, and the rule catches attempts to `// ignore:` them.

**Closes gap:** flutter_skill_lints `avoid_flutter_skill_lint_suppression`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

A team that has deliberately turned on a security- or correctness-critical rule (e.g. `avoid_hardcoded_secrets`, `require_mounted_check_after_await`) can have that protection silently defeated one file at a time by `// ignore:` comments that nobody reviews as carefully as the code itself. Letting a project name a small "protected" allowlist and flagging any suppression of those specific rules closes the loop: the rule that matters cannot be turned off without the suppression itself being visible and reviewable.

---

## Detection / Behavior

Configuration (in `analysis_options_custom.yaml`) declares a `protected_rules` list. The rule scans for `// ignore: <rule_name>` and `// ignore_for_file: <rule_name>` comments naming any rule in that list, and reports at the suppression site.

### Should flag (bad code)

```dart
// analysis_options_custom.yaml declares:
// plugins:
//   saropa_lints:
//     protected_rules: [avoid_hardcoded_secrets]

// ignore: avoid_hardcoded_secrets
const apiKey = 'sk-live-abc123'; // LINT — suppressing a protected rule
```

### Should pass (good code)

```dart
// ignore: avoid_unused_local_variable
final unused = computeDebugValue(); // OK — not in the protected_rules list
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Opt-in governance rule that only does anything once a project configures `protected_rules`; not meaningful as a default-on rule with no configuration.

---

## Edge Cases

1. **`// ignore_for_file:` at the top of the file naming a protected rule** — should flag; file-wide suppression is the most dangerous form and must be caught too.
2. **Suppression comment includes a justification (`// ignore: avoid_hardcoded_secrets — test fixture only`)** — needs discussion; consider allowing suppression when a `justification:` prefix is present AND the file matches a configured test/fixture glob, otherwise still flag. Ungated exceptions risk becoming the new loophole.
3. **`protected_rules` list is empty or unset** — should pass everywhere (rule is a no-op until configured).
4. **Suppression of a rule not in `protected_rules`** — should pass; only the configured list is protected.

---

## Alternatives Considered

- **Hard-code a single self-referential rule name (mirroring flutter_skill_lints' literal approach)** — rejected; a configurable list is strictly more useful and lets each project protect the rules that matter to it, rather than saropa dictating one rule as untouchable.

---

## Decision

---

## Implementation Notes

---

## Commits
