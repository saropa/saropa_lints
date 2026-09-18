# BUG: `require_data_encryption` — `_authKeywordPattern` matches non-credential identifiers like `authStatusFields`/`authRequiredMessage`

**Status: Fixed**

Created: 2026-09-18

Rule: `require_data_encryption`
File: `lib/src/rules/security/security_auth_storage_rules.dart` (line ~1517)
Severity: False positive
Rule version: v7 (LintCode message suffix) | Since: v1.7.8 | Updated: v4.13.0 | doc comment says "Rule version: v6" — discrepancy noted, not resolved here (message suffix `{v7}` is what the scan report shows).

Rule source unchanged between v16.2.1 and 16.3.0 (HEAD); line numbers cite HEAD.

---

## Summary

`require_data_encryption` reports on four `res.write(jsonEncode(...))` calls whose payloads are non-secret capability/version metadata and a static rejection-message string. The trigger is the rule's own documented `_authKeywordPattern` (`security_auth_storage_rules.dart:1438`), which matches the bare substring `auth` (with an exclusion only for `...or` unless `...oriz`) anywhere in the lowercased argument-list source. Three of the four sites spread `_ctx.authStatusFields` into the written map; the fourth writes `ServerConstants.authRequiredMessage`. Both identifiers legitimately contain `auth` as a substring, but neither denotes a credential — `authStatusFields` is a `Map<String, dynamic>` of auth-configuration booleans/strings (whether auth is required, which scheme), and `authRequiredMessage` is a static, non-parameterized rejection string.

**Correction to the originating downstream report:** the downstream draft (`saropa_drift_advisor/bugs/BUG_REQUIRE_DATA_ENCRYPTION_FALSE_POSITIVE_NON_SECRET_RESPONSE_BODIES.md`) speculated the trigger was structural — "`res.write(jsonEncode(...))` inside a handler class whose file/method name is auth-adjacent" — and stated that "None of the four flagged sites contains such an identifier [keyword] in the written payload." That speculation is wrong: reading the rule source shows detection is keyword-based exactly as documented elsewhere (there is no file-name or enclosing-handler-name check anywhere in `RequireDataEncryptionRule.runWithReporter`, `security_auth_storage_rules.dart:1486-1539`), and re-reading the actual argument-list source at each flagged call site (not the reduced snippets in the draft) shows all four *do* contain a keyword match: `..._ctx.authStatusFields` (sites 1-3) and `ServerConstants.authRequiredMessage` (site 4), both matched by `_authKeywordPattern`.

---

## Attribution Evidence

```bash
cd /Users/craighathaway/Documents/src/saropa_lints && grep -rn "'require_data_encryption'" lib/src/rules/
# lib/src/rules/security/security_auth_storage_rules.dart:1361:    'require_data_encryption',

grep -rn "'require_data_encryption'" /Users/craighathaway/Documents/src/saropa_drift_advisor/lib/src/ /Users/craighathaway/Documents/src/saropa_drift_advisor/extension/src/
# (no output — 0 matches)
```

**Emitter registration:** `lib/src/rules/all_rules.dart:90` (`export 'security/security_auth_storage_rules.dart';`)
**Rule class:** `RequireDataEncryptionRule` — defined in `lib/src/rules/security/security_auth_storage_rules.dart:1327`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Reduced from `lib/src/server/generation_handler.dart:138-146` and `lib/src/server/auth_handler.dart:107-111` in `saropa_drift_advisor` (a loopback-only debug HTTP server; not FlutterSecureStorage/Hive/SQL persistence, but the rule's method-name filter (`write`) matches `HttpResponse.write` too):

```dart
import 'dart:convert';
import 'dart:io';

class ServerContext {
  Map<String, dynamic> get authStatusFields =>
      <String, dynamic>{'authRequired': false, 'authScheme': null};
}

class Handler {
  final ServerContext ctx = ServerContext();

  void sendHealth(HttpResponse res) {
    res.write(
      // LINT (false positive) — `authStatusFields` is a boolean/string
      // capability-metadata map, not a credential.
      jsonEncode(<String, dynamic>{'ok': true, ...ctx.authStatusFields}),
    );
  }

  void sendUnauthorized(HttpResponse res) {
    const String authRequiredMessage = 'Authentication required';
    res.write(
      // LINT (false positive) — a static, non-parameterized rejection
      // message string, matched only because its identifier contains "auth".
      jsonEncode(<String, String>{'error': authRequiredMessage}),
    );
  }
}
```

**Frequency:** Always, for any `write`/`setString`/`put`/`writeAsString`/`writeAsBytes`/`insert` call whose argument list contains an identifier with `auth` as a substring (not immediately followed by `or` unless `oriz`), regardless of whether the referenced value is a credential.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic — the written values are auth-status/config metadata and a static message, not credentials. |
| **Actual** | `[require_data_encryption] Unencrypted sensitive data exposes credentials to attackers via device access or backup extraction. {v7}` reported at each `res.write(...)` call. |

---

## AST Context

```
MethodDeclaration (sendUnauthorized)
  └─ Block
      └─ ExpressionStatement
          └─ MethodInvocation (res.write(...))  ← node reported here (reporter.atNode(node))
              └─ ArgumentList
                  └─ MethodInvocation (jsonEncode(...))
                      └─ ArgumentList
                          └─ SetOrMapLiteral ({'error': authRequiredMessage})
                              └─ MapLiteralEntry
                                  └─ SimpleIdentifier (authRequiredMessage)  ← substring "auth" matched here via node.argumentList.toSource().toLowerCase()
```

---

## Root Cause

`security_auth_storage_rules.dart:1486-1539` (`RequireDataEncryptionRule.runWithReporter`):

```dart
context.addMethodInvocation((MethodInvocation node) {
  final String methodName = node.methodName.name;
  if (methodName != 'setString' && methodName != 'put' && methodName != 'write' &&
      methodName != 'writeAsString' && methodName != 'writeAsBytes' && methodName != 'insert') {
    return;
  }
  ...
  final String argsSource = node.argumentList.toSource().toLowerCase();
  ...
  if (_authKeywordPattern.hasMatch(argsSource)) {
    reporter.atNode(node);
    return;
  }
  ...
});
```

with `_authKeywordPattern` defined at `security_auth_storage_rules.dart:1438`:

```dart
static final RegExp _authKeywordPattern = RegExp(r'auth(?!or(?!iz))');
```

This matches the bare substring `auth` anywhere in the lowercased argument-list source, excluding only `author`/`authority`/`authored`/`authoring` (via the negative lookahead documented at `security_auth_storage_rules.dart:1430-1439`). `authStatusFields` and `authRequiredMessage` are not excluded by that lookahead (`auth` is followed by `S`/`R`, neither of which is `or`), so both match. The rule's own doc comment (`security_auth_storage_rules.dart:1291-1327`) documents this as an intentionally lightweight heuristic and explicitly calls out one prior narrowing for `token` (`_tokenKeywordPattern`, excluding `searchTokens`/`lexerTokens`/etc. — see `bugs/require_data_encryption_false_positive_search_index_tokens.md`, referenced at line 1401) and one for `auth` itself (the `author`/`authority` exclusion, evidenced in the fixture at `example/lib/security/require_data_encryption_fixture.dart:275-305`). Neither existing exclusion covers **auth-status/configuration metadata** or **static rejection-message** identifiers (`authStatusFields`, `authConfigured`, `authRequiredMessage`, `authScheme` when used to describe non-secret configuration rather than carry a secret value) — this is a gap of the same shape as the two precedents, just not yet covered.

The draft's structural "auth-adjacent file/handler" theory does not correspond to any code in the rule — there is no `resolver.path`/enclosing-class-name check anywhere in this rule.

---

## Suggested Fix

Add an argument-identifier exclusion list/pattern symmetric to the existing `_argumentEncryptionSignalPatterns` (`security_auth_storage_rules.dart:1477-1484`) and `_argumentSearchIndexContextPatterns` (`security_auth_storage_rules.dart:1449-1463`) precedents — e.g. `authStatusFields`, `authConfigured`, `authRequired(Message)?`, `authScheme` (case-insensitive) — recognized as auth-**status**/config metadata rather than auth-**credential** data, and skip reporting when the argument source matches one of those and does not also match `_sensitiveKeywords`/`_tokenKeywordPattern`/`_pinKeywordPattern`. Alternatively (more general, but higher effort): only match `_authKeywordPattern` when the identifier ends in a credential-shaped suffix (`Token`, `Password`, `Secret`, `Key`, `Header`) rather than any `auth`-prefixed identifier at all, mirroring how `_tokenKeywordPattern` already requires the bare word `token(s)` rather than any substring.

---

## Fixture Gap

`example/lib/security/require_data_encryption_fixture.dart` already has a "GOOD: Authorship / authority columns are NOT credentials" section (lines 275-305, `_AuthorshipCompanion1010`) covering the `author`/`authority`/`authored`/`authoring` exclusion, but has no case for:

1. **Case:** a map/`Companion` write whose args spread or reference an `auth*StatusFields`/`auth*Configured`-shaped identifier (auth **configuration** metadata: booleans/enums describing whether/how auth is set up) — expect **NO lint**.
2. **Case:** a map/`Companion` write of a static, non-parameterized `auth*Message`/`auth*RequiredMessage` string constant (a human-readable rejection message, not a credential) — expect **NO lint**.

---

## Changes Made

_Not yet — open report._

---

## Tests Added

_Not yet — open report._

---

## Commits

_Not yet — open report._

---

## Finish Report (2026-09-18)

**Verdict:** Valid. The report's own root-cause analysis was correct
(including its explicit correction of the downstream draft's wrong
"structural"/file-name theory).

**Revision note:** the first implementation of this fix (a blanket early
`return` when any auth-status pattern matched) was caught by an Opus review
as itself introducing a false-negative: it skipped the *entire* call,
so a real credential sitting alongside a metadata field in the same
argument list (e.g. `{'authScheme': 'basic', 'password': pwd}`) went
unflagged, and the exclusion patterns had no leading `\b`, so prefixed
identifiers like `userAuthScheme` could have matched too (bare-substring
risk of the same shape as the original bug). Both issues were fixed before
this report was closed — see **Fix** below for the corrected behavior.

**Root cause:** `_authKeywordPattern = RegExp(r'auth(?!or(?!iz))')` in
`RequireDataEncryptionRule` (`lib/src/rules/security/security_auth_storage_rules.dart`)
matches the bare substring `auth` anywhere in the lowercased argument-list
source, with an exclusion only for `author`/`authority`/`authored`/`authoring`.
It has no exclusion for auth-**status**/configuration metadata identifiers
(`authStatusFields`, `authConfigured`, `authScheme`) or static rejection
messages (`authRequiredMessage`), so `res.write(jsonEncode(...))` calls
spreading/referencing those identifiers were flagged even though none of the
referenced values are credentials.

**Fix:** Added `_argumentAuthStatusContextPatterns` (a `List<RegExp>` matching
`\bauthstatusfields?\b`, `\bauthconfigured\b`, `\bauthrequired(?:message)?\b`,
`\bauthscheme\b` — anchored with `\b` on both ends so `userAuthScheme` /
`isAuthRequired` do NOT match). In `runWithReporter`, instead of returning
early on a match, each matched pattern is **stripped out of a scanned copy**
of the lowercased argument-list source (`scannedArgsSource`) via
`replaceAll(pattern, ' ')`; the `pin`/`token`/`auth`/sensitive-keyword checks
then run against `scannedArgsSource` instead of the raw `argsSource`. This
means a metadata identifier no longer suppresses detection of a real
credential elsewhere in the same call. Updated the rule's doc comment
("Not flagged (auth-status metadata)" section) to describe the
strip-not-skip behavior.

**Files changed:**
- `lib/src/rules/security/security_auth_storage_rules.dart` — new
  `_argumentAuthStatusContextPatterns` list (boundary-anchored), replaced the
  early-return guard with a strip-and-continue (`scannedArgsSource`) used by
  the `pin`/`token`/`auth`/sensitive-keyword checks, doc comment updates
  (added the auth-status-metadata section, removed a stray blank line that
  split the doc block, fixed a "a booleans/enum" → "a boolean/enum" typo).
- `example/lib/security/require_data_encryption_fixture.dart` — added
  `_ServerContext1010`/`_ctx1010`/`authRequiredMessage1010` fixtures plus:
  two GOOD cases (`_goodAuthStatusFieldsMetadata1010` spreading
  `ctx.authStatusFields` into a `jsonEncode`d payload,
  `_goodAuthRequiredMessageStatic1010` writing a static
  `authRequiredMessage` string — both reproduce the report's reducer, no
  `expect_lint`), and two new BAD cases pinning the strip-not-skip fix:
  `_badAuthStatusFieldPlusPasswordStillTriggers1010` and
  `_badAuthRequiredPlusAccessTokenStillTriggers1010` (`expect_lint:
  require_data_encryption` — metadata field + real credential in the same
  call).
- `test/rules/security/security_auth_storage_fp_test.dart` — added a
  `require_data_encryption` group of 5 **resolved-AST** (`runRuleResolved`/
  `reportedRuleCodes`) tests against the real `RequireDataEncryptionRule`
  (not a copy of the pattern list): the two metadata-only reproducer cases
  from the bug report don't lint; metadata + `password` in the same call
  DOES lint; metadata + `accessToken` in the same call DOES lint; and a bare
  `userAuthScheme` identifier (no recognized metadata match, falls through
  to the generic `auth` keyword) is still flagged, confirming the `\b`
  anchoring doesn't over-exclude.
- `test/rules/security/require_data_encryption_pin_pattern_test.dart` — an
  earlier revision of this fix added a test group here that only mirrored
  the pattern list as a local copy (would pass even if the rule's list
  changed or was deleted); that group and its supporting mirror/helper were
  removed per review, restoring this file to its original 28 tests. Real
  coverage for the fix now lives in `security_auth_storage_fp_test.dart`
  above.

**Tests (run in foreground):**
- `dart test test/rules/security/security_auth_storage_fp_test.dart` → **14
  tests passed** (9 pre-existing `require_token_refresh`/
  `avoid_jwt_decode_client`/`require_biometric_fallback` + 5 new
  `require_data_encryption` resolved-harness tests).
- `dart test test/rules/security/require_data_encryption_pin_pattern_test.dart`
  → **28 tests passed** (unchanged from before this fix).
- `dart analyze` on `lib/src/rules/security/security_auth_storage_rules.dart`,
  `example/lib/security/require_data_encryption_fixture.dart`,
  `test/rules/security/security_auth_storage_fp_test.dart`, and
  `test/rules/security/require_data_encryption_pin_pattern_test.dart` →
  **No issues found!** on all four. Note: intermittent whole-package load
  failures were observed while other agents concurrently edited unrelated
  files (`async_rules.dart`, `windows_rules.dart`,
  `code_quality_avoid_rules.dart`, `security_network_input_rules.dart`); a
  retry once those files stabilized ran clean. None of those files were
  touched by this fix.

**Proposed CHANGELOG bullet:**
- fix: `require_data_encryption` no longer flags auth-status/configuration
  metadata (`authStatusFields`, `authConfigured`, `authScheme`) or static
  `authRequiredMessage` rejection strings as unencrypted credentials, while
  still flagging a real credential (e.g. `password`, `accessToken`) that
  appears alongside such metadata in the same call.

---

## Environment

- saropa_lints version: 16.2.1 (findings produced), 16.3.0 / HEAD (source reviewed; unchanged for this file between the two)
- Dart SDK version: 3.12.2 (stable)
- custom_lint version: n/a (scan via `saropa_lints scan` / VS Code extension)
- Triggering project/file: `saropa_drift_advisor` 4.4.1 — `lib/src/server/generation_handler.dart:138,153,210`, `lib/src/server/auth_handler.dart:107`. Scan report: `saropa_drift_advisor/reports/20260918/20260918_081229_findings.json`.
