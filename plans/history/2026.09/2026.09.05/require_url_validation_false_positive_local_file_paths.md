# BUG: `require_url_validation` — False positive on local file path URIs and pre-validated URLs

**Status: Fixed**

Created: 2026-09-05
Rule: `require_url_validation`
File: `lib/src/rules/security/security_network_input_rules.dart` (grep for exact line)
Severity: False positive
Rule version: v5

---

## Summary

Both findings are false positives:

1. **`info_plist_utils.dart:128`** — `Uri.parse(trimmed)` parses a local analyzer file path/URI from the analysis context, not attacker-controlled network input. SSRF does not apply to parsing local `file://` paths.

2. **`saropa_lints.dart:188`** — Already explicitly mitigated with scheme validation: `rootUri.startsWith('file://')` is checked before parsing, and `parsedUri.scheme != 'file'` is re-verified after, with a comment documenting the guard. The rule's heuristic does not recognize pre/post scheme-guard patterns.

---

## Attribution Evidence

```bash
grep -rn "'require_url_validation'" lib/src/rules/
# (match in security_network_input_rules.dart)
```

---

## Reproducer

```dart
// FP: Scheme already validated before and after parse
if (!rootUri.startsWith('file://')) return;
final parsed = Uri.parse(rootUri); // LINT — but should NOT lint
if (parsed.scheme != 'file') return;
```

---

## Suggested Fix

1. If `Uri.parse()` is preceded by a `startsWith('file://')` or similar scheme check on the same string, suppress.
2. If the parsed URI's `.scheme` is checked immediately after parsing (within the same block), suppress.
3. Exempt strings sourced from internal analyzer APIs (not user input).

---

## Affected Files

- `info_plist_utils.dart:128`
- `saropa_lints.dart:188`

---

## Environment

- saropa_lints version: current (unreleased)
