# Bug (fixed): require_api_response_validation and require_content_type_validation ignore control flow

**Summary:** Both rules reported on `jsonDecode` even when (1) Content-Type was checked before decode (early return when not `application/json`), or (2) the decoded value was only passed to a `fromJson` validator. Fixed by adding control-flow and usage checks: **require_content_type_validation** skips when a preceding IfStatement in the same/outer block guards on contentType/mimeType and application/json; **require_api_response_validation** skips when `jsonDecode` is the direct argument to `fromJson` or the assigned variable is only passed to `fromJson`.

**Rules:** `require_api_response_validation`, `require_content_type_validation` · **Status:** Fixed · **Reporter:** saropa_drift_viewer

---

## Original report

Both rules flagged `decoded = jsonDecode(body);` despite a prior `if (request.headers.contentType?.mimeType != 'application/json') return ...;` and the only use of `decoded` being `_SqlRequestBody.fromJson(decoded)`.

## Resolution

- **require_content_type_validation:** Uses `_outermostBlockContaining`, `_directChildStatementOf`, and `_isContentTypeGuardStatement` to detect a preceding IfStatement whose condition mentions contentType/mimeType and application/json and whose then branch is a return. No report when such a guard exists.
- **require_api_response_validation:** Skips when (a) `jsonDecode` is the single argument to a `fromJson` call, or (b) the result is assigned to a variable and that variable is only used as the single argument to a `fromJson` call (`_isDirectArgumentToFromJson`, `_variableOnlyPassedToFromJson`). Fixtures: require_api_response_validation_fixture.dart, require_content_type_validation_fixture.dart.
