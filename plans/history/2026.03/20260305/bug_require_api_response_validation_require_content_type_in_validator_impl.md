# Bug: require_api_response_validation and require_content_type_validation fire inside validation helper

**Rules:** `require_api_response_validation`, `require_content_type_validation`  
**Status:** Open  
**Reporter:** radiance_vector_game (game/lib/utils/json_validation.dart)

---

## Summary

Both rules report on `jsonDecode(source)` inside a **shared validation helper** `decodeAndValidateJson` that (1) optionally checks `responseHeaders` for Content-Type `application/json` before parsing, and (2) validates the decoded value is a Map or List and throws FormatException otherwise. So the call site is the implementation of the validation that other code uses to satisfy these rules. Reporting here is a false positive.

## Expected behavior

Do not report when:
- `jsonDecode` is inside a function that (a) when given response headers, checks Content-Type for application/json before calling jsonDecode, and (b) validates the decoded value (e.g. type check for Map/List, or passing to fromJson) and throws or returns safely.

Alternatively, allow a way to mark “this is the validation layer” (e.g. function name pattern or annotation) so the rules skip the implementation.

## Actual behavior

In `decodeAndValidateJson` (game/lib/utils/json_validation.dart):

- **require_content_type_validation** reports at `jsonDecode(source)` even though when `responseHeaders != null` we check `contentType.toLowerCase().contains('application/json')` and throw before calling jsonDecode.
- **require_api_response_validation** reports at the same call even though the next statements validate `decoded is Map<String, dynamic> || decoded is List<dynamic>` and throw FormatException otherwise.

So the rules still treat this as “API response used without validation” and “parsed without Content-Type check” even though this function exists to perform both checks.

## Minimal reproduction

```dart
dynamic decodeAndValidateJson(String source, {Map<String, String>? responseHeaders}) {
  if (responseHeaders != null) {
    final contentType = responseHeaders['content-type'] ?? responseHeaders['Content-Type'];
    if (contentType == null || !contentType.toLowerCase().contains('application/json')) {
      throw FormatException('Unexpected Content-Type');
    }
  }
  final decoded = jsonDecode(source);  // both rules report here
  if (decoded != null && decoded is! Map<String, dynamic> && decoded is! List<dynamic>) {
    throw FormatException('Expected JSON object or array');
  }
  return decoded;
}
```

## Suggested fix

- **require_content_type_validation:** When the `jsonDecode` call is inside a function that has a preceding conditional (in the same or outer block) that (1) uses a variable from `responseHeaders`/headers and (2) checks for application/json and (3) throws or returns before the decode, treat that as satisfying the Content-Type check.
- **require_api_response_validation:** When the decoded variable is only used in a subsequent type check (e.g. `is Map<String, dynamic>` / `is List<dynamic>`) and throw, or is passed to fromJson, treat that as validation and do not report.

## Environment

- saropa_lints: 6.2.2
- Dart SDK: ^3.11.0
