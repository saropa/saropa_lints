# BUG: `require_http_status_check` — fires on a send helper that returns the response without reading it

**Status: Fixed**

Created: 2026-11-26
Rule: `require_http_status_check`
File: `lib/src/rules/network/api_network_rules.dart` (line ~95)
Severity: False positive
Rule version: v5 | Since: v0.1.4 | Updated: v4.13.0

---

## Summary

A method that only performs the request and returns `http.Response` is reported for using the body without a status check. It never touches the body; the caller checks the status first.

---

## Attribution Evidence

```bash
grep -rn "'require_http_status_check'" lib/src/rules/
# lib/src/rules/network/api_network_rules.dart:63:    'require_http_status_check',
```

**Emitter registration:** `lib/src/rules/network/api_network_rules.dart:63`
**Rule class:** `RequireHttpStatusCheckRule` — registered in `lib/saropa_lints.dart:881`
**Diagnostic `source` / `owner` as seen in Problems panel:** `saropa_lints`

---

## Reproducer

Derived from reading the rule source. Not executed.

```dart
import 'package:http/http.dart' as http;

class Api {
  Future<http.Response> _send(http.Client client, Uri uri) async { // LINT — but should NOT lint
    return await client.post(uri);
  }

  Future<String?> create(http.Client client, Uri uri) async {
    final http.Response response = await _send(client, uri);
    if (response.statusCode != 200) return null;
    return response.body;
  }
}
```

**Frequency:** Always

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic |
| **Actual** | `[require_http_status_check]` reported on the line marked LINT |

---

## AST Context

```
ClassDeclaration (Api)
  └─ MethodDeclaration (_send)  ← reported
      └─ Block
          └─ ReturnStatement
              └─ AwaitExpression
                  └─ MethodInvocation (client.post)
```

---

## Root Cause

Lines ~101-112 report when the method body text has an HTTP call and no `statusCode`/`isSuccessful`. There is no check that the response body is read, although the message says it is.

---

## Suggested Fix

Report only when the method reads the response (`.body`, `.bodyBytes`, `.data`) or decodes it. Skip when the response is returned as is.

---

## Fixture Gap

1. Helper returning the `Response` — expect NO lint
2. `jsonDecode(response.body)` with no status check — expect LINT

---

## Environment

- saropa_lints version: 17.9.1 (rule source read at this version)
- Dart SDK version: not recorded
- Triggering project/file: a private Flutter app

---

## Finish Report (2026-11-26)

**Fix** (`lib/src/rules/network/api_network_rules.dart`, rule version v6): a private method that returns the HTTP call result as-is is not reported when every reference to it in the file is a direct call from a method. Each caller is then treated as making the HTTP call and must check the status.

**Review fix:** a file that is itself a `part of` another library was accepted although callers can live elsewhere; it now keeps the report, with a regression case.

**Limits:** the local-variable form (`final r = await client.post(uri); return r;`) is still reported. Public helpers, top-level functions and helpers called from constructors are still reported.

Tests: `dart test test/rules/network/require_http_status_check_pass_through_test.dart test/rules/network/api_network_rules_test.dart test/rules/network/api_network_fp_test.dart` - passed.
