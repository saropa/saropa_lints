# BUG: `require_https_only` — False positive on string-inspection pattern arguments

**Status: Fixed**

Created: 2026-05-03
Resolved: 2026-05-03
Rule: `require_https_only` (and shared logic powering `require_https_only_test`)
File: `lib/src/rules/security/security_network_input_rules.dart` (line ~3476)
Severity: False positive (Medium — fired on rule-author code and any defensive HTTP-URL detection)
Rule version: v4 | Since: v4.8.2 | Updated: v4.13.0

---

## Summary

The rule fired on string literals like `'http://'` whenever they appeared in **search/comparison positions** — i.e. as the needle argument to a string-inspection method (`url.startsWith('http://')`, `text.contains('http://')`, `body.indexOf('http://')`) or as the operand of an equality/inequality comparison (`prefix == 'http://'`). In those positions the literal is a pattern being searched for or compared against, **not** a URL being requested over the network. The MITM threat model the rule targets does not apply.

A previous carve-out (`_isSafeReplacementPattern`) handled `String.replaceFirst('http://', 'https://')` (and `replaceAll`/`replace` shaped the same way), but inspection-only methods — `startsWith`, `endsWith`, `contains`, `indexOf`, `lastIndexOf`, `split` — were not covered, nor were `==` / `!=` operands.

This was visible inside the project's own source:

- `lib/src/rules/platforms/ios_ui_security_rules.dart:614` — `if (!url.startsWith('http://'))` inside `_isInsecureUrl(String)` (defensive HTTP detection).
- `lib/src/rules/platforms/ios_ui_security_rules.dart:959` — `if (!value.startsWith('http://'))` inside an ATS-comment audit rule.
- `lib/src/rules/security/security_network_input_rules.dart:3553` — `first.value == 'http://' && second.value == 'https://'` inside the rule's own `_isSafeReplacementPattern` body.
- `lib/src/rules/security/security_network_input_rules.dart:3618`, `:3643` — `value.startsWith('http://')` inside `checkHttpUrls`.

Because the project bans `// ignore:` and `// ignore_for_file:` (see `CLAUDE.md` § "Lint suppressions"), the false positives could not be silenced — only fixed.

---

## Reproducer

```dart
// All of these are search/comparison patterns, not URLs being requested.
// Pre-fix: rule fires on each 'http://' literal.

bool isInsecureUrl(String url) => url.startsWith('http://');
bool endsWithHttpPrefix(String t) => t.endsWith('http://');
bool containsHttp(String body) => body.contains('http://');
int findHttp(String t) => t.indexOf('http://');
int findLastHttp(String t) => t.lastIndexOf('http://');
List<String> chunks(String t) => t.split('http://');
bool prefixIsHttp(String prefix) => prefix == 'http://';
bool prefixIsNotHttp(String prefix) => prefix != 'http://';
```

---

## Fix

Added `_isStringInspectionPattern(SimpleStringLiteral)` helper to `RequireHttpsOnlyRule` and short-circuited `checkHttpUrls` when the helper returns true.

The carve-out covers two AST shapes:

**Shape 1 — String-API needle:**

1. The literal's parent is an `ArgumentList`.
2. The grandparent is a `MethodInvocation`.
3. The method name is one of: `startsWith`, `endsWith`, `contains`, `indexOf`, `lastIndexOf`, `split`.
4. The literal is the **first** positional argument (`identical(args.first, node)`) — guards against `something.contains(other, http_literal)` shapes where the literal is not the search pattern.

**Shape 2 — Equality / inequality comparison:**

1. The literal's parent is a `BinaryExpression`.
2. The operator lexeme is `==` or `!=`.

Because `RequireHttpsOnlyTestRule` reuses `checkHttpUrls`, both production and test variants benefit.

URL construction (`Uri.parse('http://example.com')`, hardcoded HTTP endpoints, arguments to `http.get` / `dio.get` / etc.) is unaffected and still fires — those literals are neither method needles nor `==` operands.

---

## Files Changed

- `lib/src/rules/security/security_network_input_rules.dart` — added `_isStringInspectionPattern`, called inside `checkHttpUrls`.
- `example/lib/security/require_https_only_fixture.dart` — added `HttpDetectionPatterns` class covering all six inspection methods.
- `CHANGELOG.md` — entry under `[Unreleased] → Fixed`.

---

## Validation

- `dart analyze --fatal-infos` on `lib/src/rules/platforms/ios_ui_security_rules.dart` — both prior `require_https_only` warnings (lines 614, 959) cleared.
- Fixture additions (`HttpDetectionPatterns`) demonstrate the carve-out without introducing new BAD examples.

---

## Why this bug doc exists

The repo policy bans `// ignore:` / `// ignore_for_file:` (CLAUDE.md § "Lint suppressions" / Anti-Patterns). When a rule fires on its own author's defensive code, the only correct response is to fix the rule. This file records the defect, the carve-out's exact scope, and why narrower scopes (only `startsWith`, only `replaceFirst`) would still leave gaps.
