# PROPOSAL: Flag Locally-Duplicated Key Constants Instead of a Shared Contract

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_inline_error_codes`, `avoid_repeated_property_aliases`

---

## Summary

Add `avoid_local_contract_key_constants` to flag a file-local `const`/`static const` string constant whose value duplicates a key already defined in a project's designated shared contract file (e.g. `lib/core/keys.dart`, a project-configured path) — a second, locally-scoped constant with the same string value is a silent fork of the contract: both compile, both work today, and nothing prevents them from drifting apart on the next rename.

**Closes gap:** flutter_skill_lints `avoid_local_contract_key_constants`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Shared string keys (API field names, storage keys, analytics event names, route names) are contracts between subsystems. When a developer needs the same key in a new file and doesn't know (or doesn't check) that a shared constant already exists, they define a local one with the same literal value. It works until the shared constant is renamed or the value changes — the local copy silently goes stale while still compiling, producing a runtime mismatch with no compiler signal.

---

## Detection / Behavior

Configuration names the shared contract file(s)/class(es). Flag any `const`/`static const` `String` declaration outside those files whose literal value exactly matches a value already declared in one of the configured contract sources.

### Should flag (bad code)

```dart
// lib/core/keys.dart (the shared contract):
// class StorageKeys { static const userId = 'user_id'; }

// lib/features/profile/profile_repository.dart:
class ProfileRepository {
  static const _userIdKey = 'user_id'; // LINT — duplicates StorageKeys.userId
}
```

### Should pass (good code)

```dart
class ProfileRepository {
  static const _userIdKey = StorageKeys.userId; // OK — references the shared contract
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Requires project configuration naming the contract source(s) to be meaningful; appropriate for a deep-review tier rather than default-on.

---

## Edge Cases

1. **Value collision is coincidental, not a real contract key (e.g. both happen to be `'default'`)** — needs discussion; false positives are likely for very short/common strings — consider a minimum-length threshold or an explicit "this is a contract key" naming heuristic (identifier ends in `Key`/`Code`) to reduce noise.
2. **Local constant is itself inside the configured contract file(s)** — should pass; the contract file(s) are the source of truth and are excluded from self-comparison.
3. **Local constant references the shared constant with an added transformation (`'${StorageKeys.userId}_v2'`)** — should pass; not a literal duplicate, a derived value.
4. **No `protected`/contract source configured** — should pass everywhere (rule is a no-op until configured), same pattern as `avoid_lint_suppression_abuse`.

---

## Alternatives Considered

- **Flag ALL local string constants regardless of a configured contract source, using cross-file duplicate detection generically** — rejected; without a designated "source of truth" file, the rule can't tell which of two duplicate constants is the canonical one to point developers toward, producing an unhelpful diagnostic.

---

## Decision

---

## Implementation Notes

---

## Commits
