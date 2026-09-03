# PROPOSAL: Flag Inline String Literal Error Codes Instead of Named Constants

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_local_contract_key_constants`

---

## Summary

Add `avoid_inline_error_codes` to flag string literals used as error/failure codes (e.g. `throw AppException('ERR_NETWORK_TIMEOUT')`, `Failure(code: 'AUTH_401')`) written inline at the call site instead of referencing a shared named constant — inline error codes cannot be grepped reliably, drift out of sync between the throw site and any place that switches on the code, and typos silently produce a new, unmatched code instead of a compile error.

**Closes gap:** flutter_skill_lints `avoid_inline_error_codes`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Error codes are contracts — something downstream (a UI error mapper, an analytics pipeline, a support runbook) matches against the exact string. When that string is typed inline at every throw site, a rename or typo breaks the contract silently: the code still compiles, the exception still throws, but nothing downstream recognizes it anymore. A shared constant makes the contract greppable, typo-proof, and renameable via IDE refactor.

---

## Detection / Behavior

Flag a `StringLiteral` argument passed to a parameter conventionally named `code`/`errorCode`/`failureCode` (configurable parameter-name list) in a constructor or function call, where the argument is a raw string literal rather than a reference to a `static const` / top-level `const` identifier.

### Should flag (bad code)

```dart
throw AppException(code: 'ERR_NETWORK_TIMEOUT', message: 'Request timed out'); // LINT — inline error code
```

### Should pass (good code)

```dart
throw AppException(code: ErrorCodes.networkTimeout, message: 'Request timed out'); // OK — named constant
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Style/maintainability rule requiring a configurable parameter-name convention to be useful; appropriate for a deep-review tier rather than default-on.

---

## Edge Cases

1. **Error code string used in a `switch`/`case` statement matching against it** — should flag the same; both the throw site and the match site should reference the shared constant.
2. **One-off internal exception never surfaced outside the throwing function (caught and rethrown as a different typed exception immediately)** — needs discussion; still flag by default since "internal only, for now" tends to change, but document the guidance to allow suppression with justification for genuinely private, non-contractual strings.
3. **Parameter name doesn't match the configured convention (e.g. `reason:` instead of `code:`)** — should pass; only configured parameter names are checked, keeping the rule predictable and low-noise.
4. **String literal that happens to be assigned to a local `const` variable first, then passed** — should pass; that already achieves the single-source-of-truth goal even if the constant isn't shared globally.

---

## Alternatives Considered

- **Require an enum instead of string constants** — rejected as the rule's requirement; many codebases intentionally use string codes for cross-platform/analytics compatibility (enums don't serialize as cleanly), so the rule only requires "not inline," not a specific representation.

---

## Decision

---

## Implementation Notes

---

## Commits
