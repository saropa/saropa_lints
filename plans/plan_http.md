# Plan: new `http` lint rules

**Package:** http ^1.6.0 (Saropa Contacts). **saropa_lints coverage:** none (new file).

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `require_http_client_close` | correctness | `http.Client` created locally and never `.close()`d (no try/finally) | report-only | WARNING | skip if client is returned, passed out, or stored in a field/variable that escapes the local function |
> **VALIDATION (2026-06-11) — GUARD NEEDED:** misses await-then-close-without-finally patterns.
| `require_http_timeout` | best-practice | `await client.get/post/…` (or top-level `http.get/…`) with no `.timeout(…)` chained | report-only | WARNING | skip if caller is already inside `.timeout(…)` or a `Future.timeout` |
> **VALIDATION (2026-06-11) — DROP (overlap):** triple-covered by `require_request_timeout` (api_network_rules.dart:601), `prefer_timeout_on_requests` (api_network_rules.dart:3493), `require_future_timeout` (async_rules.dart:2610).
| `avoid_http_top_level_in_loop` | performance | top-level `http.get/post/put/patch/delete/head/read` call inside a `for`/`while`/`do` loop body | report-only | WARNING | skip if loop contains `http.Client()` instantiation (user is already creating a client per-iteration — different smell) |
| `require_http_status_check` | correctness | `response.body` or `jsonDecode(response.body)` accessed with no preceding `if (response.statusCode …)` guard in the same function | report-only | WARNING | only when `response` resolves to `http.Response`; skip if wrapped in a helper that checks status |
> **VALIDATION (2026-06-11) — DROP (name collision):** a rule with this EXACT name already exists (api_network_rules.dart:58). Rename or drop — registration would collide.
| `require_http_body_bytes_for_binary` | correctness | `response.body` accessed on `http.Response` where the content-type header is set to a non-text MIME (image/*, application/octet-stream, audio/*, video/*) — or where the variable is named `image`/`binary`/`bytes`/`download` | report-only | INFO | name-match is heuristic; must also confirm type resolves to `http.Response` |
> **VALIDATION (2026-06-11) — GUARD NEEDED / DEMOTE:** name-substring matching of image/binary/bytes is a high-FP heuristic (cannot read runtime Content-Type); demote or cut.
| `require_http_exception_handling` | correctness | `await http.get/post/…` or `await client.get/post/…` with no enclosing `try`-`catch` that catches `ClientException` or `Exception` | report-only | WARNING | only fire when the enclosing function is `async`; skip if the method signature declares `throws` (Dart doesn't have `throws`, so skip if inside a catch-all or rethrows) |
> **VALIDATION (2026-06-11) — RECONCILE:** overlaps the error-handling family (`require_error_handling_graceful` error_handling_rules.dart:1247); thin ClientException delta.
| `avoid_http_string_url` | migration | `http.get(String)` / `http.post(String)` — passing a `String` literal or variable typed `String` where the 1.x API requires `Uri` | quick-fix: wrap in `Uri.parse(…)` | ERROR | only when argument static type is `String`, not `Uri` |
| `require_http_content_type_on_post` | best-practice | `http.post(…, body: …)` or `client.post(…, body: …)` where `headers` map has no `content-type` key | report-only | WARNING | skip when `body` is a `Map<String, String>` (form-encoded default is correct); only fire when `body` is a `String` or `jsonEncode(…)` |
> **VALIDATION (2026-06-11) — DROP (overlap):** dup of `require_content_type_check` (api_network_rules.dart:1816) + `require_content_type_validation` (api_network_rules.dart:4471).

---

## Rule detail

### `require_http_client_close`

- **What/why:** `http.Client` holds an underlying `dart:io` `HttpClient` which keeps sockets open. If the client is created in a function scope (local variable) and the function exits without calling `.close()`, sockets leak. The official docs say "make sure to close the client when you're done." The leak is real for CLI and server Dart apps; for Flutter apps the OS reclaims on termination, but the underlying `dart:io` `HttpClient` emits a warning if not closed, and long-lived requests can prevent the Dart VM from exiting cleanly in tests.
- **Detection (AST, type-safe):** `addVariableDeclaration` — find `VariableDeclaration` nodes whose initializer is an `InstanceCreationExpression`. Resolve `staticType` of the declared variable; check that `staticType.element.library.identifier == 'package:http/src/client.dart'` (or confirm `staticType.toString() == 'Client'` after verifying `element.librarySource.uri.scheme == 'package'` and path starts with `http/`). Then walk the enclosing `FunctionBody` AST and confirm no `MethodInvocation` with `methodName.name == 'close'` on the same variable exists within a `TryStatement`'s `finallyBlock`. Report if no close found.
- **Fix:** report-only. A mechanical fix would insert `try/finally { client.close(); }` but would require restructuring potentially complex code; too risky for an automated fix.
- **False positives:**
  - Client is returned from the function (`ReturnStatement` returning the variable) — skip.
  - Client is stored to a class field (`AssignmentExpression` where left-hand side resolves to a field) — skip.
  - Client is passed as an argument to another function (could be closed there) — skip.
  - `RetryClient`, `IOClient`, `BrowserClient` subclasses — same library URI check covers them since they all implement `Client`.

---

### `require_http_timeout`

- **What/why:** Mobile networks are unreliable. An `http.get` with no `.timeout(Duration(…))` can hang indefinitely, freezing the UI or stalling server-side Dart processes. The official `http` package README notes that `.timeout()` is the way to add a request-level deadline. The underlying `dart:io` `HttpClient.connectionTimeout` is not exposed through `package:http`; `.timeout()` on the returned `Future` is the only reliable mechanism.
- **Detection (AST, type-safe):** `addMethodInvocation` — match calls to `get`, `post`, `put`, `patch`, `delete`, `head`, `read`, `send` where the target either (a) resolves to the top-level `http` library function (check `element.library.identifier` starts with `package:http/`) or (b) resolves to a method on a type whose `element.library.identifier` starts with `package:http/src/base_client.dart`. Then walk the parent chain: if the `MethodInvocation` is itself the target of another `MethodInvocation` with `methodName.name == 'timeout'`, skip. Also skip if the `awaitExpression.parent` is itself inside a `MethodInvocation` named `timeout`.
- **Fix:** report-only. Timeout duration is context-dependent (connect vs receive, 10 s vs 30 s); inserting the wrong value is worse than leaving it absent.
- **False positives:**
  - Test code — use `ProjectContext.isTestFile(path)` to skip test files (mock clients return instantly).
  - When wrapped in a helper method that chains `.timeout()` inside — AST can't see through function boundaries; this is a known limitation, document it in the rule.

---

### `avoid_http_top_level_in_loop`

- **What/why:** The top-level functions `http.get`, `http.post`, etc. each create a new ephemeral `Client` internally, make one request, then close the client. Inside a loop this spawns a new TCP connection for every iteration, discarding the keep-alive pool. The official README explicitly states: "If you're making multiple requests to the same server, keep open a persistent connection by using a Client rather than making one-off requests." Inside a loop this is a verified performance anti-pattern.
- **Detection (AST, type-safe):** `addMethodInvocation` — match top-level function calls (`get`, `post`, `put`, `patch`, `delete`, `head`, `read`) where `node.target == null` (top-level call, not a method on a receiver) and `element.library.identifier` starts with `package:http/`. Walk ancestor nodes: if any ancestor is a `ForStatement`, `WhileStatement`, or `DoStatement`, report.
- **Fix:** report-only. The fix requires creating a `Client`, refactoring the loop, and closing after — too structural for automation.
- **False positives:**
  - Single-iteration loops (`for (final x in [singleItem])`) — not detectable statically; acceptable FP rate since it's rare and harmless to report.
  - Loops that run at most once in practice — not statically detectable; document as known FP class.

---

### `require_http_status_check`

- **What/why:** `http.Response.body` returns the raw body string regardless of status code. Accessing `response.body` (or passing it to `jsonDecode`) after a 4xx/5xx response will silently process an error payload as if it were data. The official Flutter docs show checking `statusCode == 200` before reading the body; this is a verified correctness requirement.
- **Detection (AST, type-safe):** `addPropertyAccess` or `addPrefixedIdentifier` — find accesses to `.body` on an expression whose `staticType` is `http.Response` (verify `element.library.identifier` starts with `package:http/src/response.dart`). Walk the enclosing `FunctionBody`: check whether any ancestor `IfStatement` condition contains a `PropertyAccess` for `.statusCode` on the same variable. Report if no status check found.
- **Fix:** report-only. The correct check depends on the expected status (200, 201, 2xx range) and the caller's error-handling strategy; inserting a specific value would be presumptuous.
- **False positives:**
  - Helper functions that assert status before passing `Response` through — AST can't see through function boundaries; known limitation.
  - `response.statusCode` checked in a `switch` — walk `SwitchStatement` conditions too, not just `IfStatement`.
  - `response.body` used in a `print` / logging call — still report (logging a 500 body without checking is still a smell, but acceptable to guard against by checking if the parent is a `print` call and downgrading to INFO).

---

### `require_http_body_bytes_for_binary`

- **What/why:** `response.body` decodes the bytes as a UTF-8 string. For binary content (images, files, audio) the decoder will corrupt data where byte sequences are not valid UTF-8. The correct accessor is `response.bodyBytes` (`Uint8List`). The `Response` class documentation explicitly states: "Use `body` for text; use `bodyBytes` for binary content."
- **Detection (AST, type-safe):** `addPropertyAccess` — find `.body` on `http.Response`. Then inspect the surrounding context for binary signals: (a) the variable name contains `image`, `binary`, `bytes`, `file`, `download`, `audio`, `photo`, or `video` (case-insensitive identifier scan on the variable `SimpleIdentifier`); (b) the result of a prior `http.get/post` call where the `Uri` string literal or variable name contains `/image`, `/file`, `/download`, `/binary`. This is a heuristic — severity INFO, not WARNING.
- **Fix:** report-only (heuristic rules should not auto-fix).
- **False positives:** High — name-based heuristic will miss most cases and occasionally fire on coincidental names. Severity INFO keeps the noise acceptable. A lint rule cannot inspect Content-Type header values at runtime; this rule is acknowledged as heuristic and should note that under "Not fully lint-able." The detection note in the plan marks it "(speculative — verify accuracy with fixture tests before shipping)".

---

### `require_http_exception_handling`

- **What/why:** `http.get/post/…` and `client.get/post/…` throw `ClientException` (a subclass of `IOException`) on network errors (DNS failure, connection refused, connection reset) and may throw `SocketException` from the underlying `dart:io` layer. Unhandled, these crash the app or kill a server isolate. The official docs reference `ClientException` as a thrown exception; this is a confirmed API contract.
- **Detection (AST, type-safe):** Same method set as `require_http_timeout`. After matching a call, walk ancestors: if any ancestor `TryStatement` has a `catchClause` that catches `ClientException`, `Exception`, or has a bare `catch (e)` clause — skip. Report if no enclosing try-catch found within the same `FunctionBody`.
- **Fix:** report-only. Inserting an empty catch block would be a no-op fix; the rule name explicitly bars that anti-pattern (`CLAUDE.md` "Quick Fixes" rule).
- **False positives:**
  - The caller propagates the exception intentionally (async function that re-throws) — walking ancestors to the function boundary is sufficient; if no try-catch, report regardless of whether the caller catches it. This is a deliberate design choice: the recommendation is to handle at the call site unless rethrow is deliberate.
  - Test files — skip via `ProjectContext.isTestFile(path)`.

---

### `avoid_http_string_url`

- **What/why:** `http` 1.0.0 removed support for `String` arguments to `get`, `post`, etc.; it requires `Uri`. Code that was valid under `http` ^0.13 will be a **compile error** under ^1.0. This is a verified breaking change confirmed in the CHANGELOG. Any codebase migrating from 0.x still using string arguments needs to wrap them.
- **Detection (AST, type-safe):** `addMethodInvocation` — match top-level `http.*` functions or `client.*` methods (`get`, `post`, `put`, `patch`, `delete`, `head`, `read`). Check the **first argument's `staticType`**: if `staticType.isDartCoreString == true`, report. Never match if `staticType` is `Uri` or dynamic.
- **Fix:** mechanical — wrap the string argument in `Uri.parse(…)`. `ChangeBuilder.addDartFileEdit` → `addSimpleReplacement(arg.sourceRange, 'Uri.parse(${arg.toSource()})')`. This is a safe, mechanical transformation.
- **False positives:** low — the static type check is definitive. A `dynamic` argument is left alone (unknown type at analysis time).

---

### `require_http_content_type_on_post`

- **What/why:** When posting a JSON-encoded string body, omitting `'content-type': 'application/json'` in the headers causes many servers to reject the request (HTTP 415 Unsupported Media Type) or mis-parse it. A common bug in GitHub issues (#167, #357) is sending `jsonEncode(map)` as the body without setting Content-Type. The `http` package defaults to `application/x-www-form-urlencoded` when `body` is a `Map<String, String>`, but that default does NOT apply when `body` is a `String`.
- **Detection (AST, type-safe):** `addMethodInvocation` — match `post` and `put` calls (top-level or on `http.Client`; confirm via library URI). Inspect named argument `body`: if `body` argument's `staticType.isDartCoreString == true` (i.e., the caller is passing a String, strongly suggesting JSON-encoded data), then inspect the `headers` named argument. If `headers` is absent, or is a `MapLiteral` with no key literal matching `'content-type'` or `'Content-Type'`, report.
- **Fix:** report-only. The correct content-type value depends on the API (could be `application/json`, `application/xml`, `text/plain`); inserting `application/json` unconditionally could be wrong.
- **False positives:**
  - `headers` is a variable (not an inline map literal) — cannot inspect keys statically; skip when `headers` is a `SimpleIdentifier` or `PrefixedIdentifier`.
  - Body is a plain string (not JSON) and content-type is intentionally omitted — acceptable FP since posting a plain string without a content-type is also suspicious.

---

## Implementation note

**New file:** `lib/src/rules/packages/http_rules.dart`

**Registration steps (all three required per project MEMORY):**

1. Export from `lib/src/rules/all_rules.dart` — add `export 'packages/http_rules.dart';`
2. Add rule class constructors to `_allRuleFactories` in `lib/saropa_lints.dart` (~line 157)
3. Add rule code strings to a tier in `lib/src/tiers.dart`

**Suggested tier placement:**

- `essentialRules`: `require_http_client_close`, `require_http_exception_handling`, `avoid_http_string_url`
- `essentialRules` (HTTP/Network section, alongside existing `require_dio_timeout`): `require_http_timeout`, `require_http_status_check`
- `recommendedOnlyRules`: `avoid_http_top_level_in_loop`, `require_http_content_type_on_post`
- `comprehensiveOnlyRules`: `require_http_body_bytes_for_binary` (heuristic/INFO)

**Guard pattern:** Every rule must call `fileImportsPackage(node, {'package:http/'})` as the first check in `runWithReporter` to avoid firing on projects that don't use `package:http`. Add `PackageImports.http = {'package:http/'}` to `lib/src/import_utils.dart`.

**Type-safe library URI verification:** For all rules, resolve the `element` of the matched call's `staticType` or the function element, and assert `element.library.identifier.startsWith('package:http/')` before reporting. Never use bare name matching (e.g., `methodName == 'get'` alone would match `dio.get`, `client.get` from other packages).

**Not lint-able (runtime-only):** Checking the actual response Content-Type header at runtime to enforce `bodyBytes` usage — this requires reading `response.headers['content-type']` which is not statically available. The `require_http_body_bytes_for_binary` rule uses a heuristic substitute and should be marked INFO.

---

## Sources

- [pub.dev: http package](https://pub.dev/packages/http)
- [pub.dev: http changelog](https://pub.dev/packages/http/changelog)
- [pub.dev: http Response class](https://pub.dev/documentation/http/latest/http/Response-class.html)
- [dart.dev: Fetch data from the internet](https://dart.dev/server/fetch-data)
- [GitHub dart-lang/http: Client close best practices issue #422](https://github.com/dart-lang/http/issues/422)
- [GitHub dart-lang/http: Timeout issue #21](https://github.com/dart-lang/http/issues/21)
- [GitHub dart-lang/http: Content-type / body fields issue #167](https://github.com/dart-lang/http/issues/167)
- [GitHub dart-lang/http: Content-type POST issue #357](https://github.com/dart-lang/http/issues/357)
- [GitHub dart-lang/http: ClientException not catchable issue #160](https://github.com/dart-lang/http/issues/160)
- [blog.burkharts.net: HttpClients Essential Facts and Tips](https://blog.burkharts.net/everything-you-always-wanted-to-know-about-httpclients)
- [Flutter docs: Fetch data cookbook](https://docs.flutter.dev/cookbook/networking/fetch-data)
