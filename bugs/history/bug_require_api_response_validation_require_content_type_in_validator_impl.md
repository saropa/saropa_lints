# Bug: require_api_response_validation and require_content_type_validation fire inside validation helper

**Resolution (fixed):** (1) require_content_type_validation: guard detection now accepts then-branches that throw (ExpressionStatement with ThrowExpression, or Block with single ThrowStatement). Nested guards are found via _hasContentTypeGuardInStatement recursion. (2) require_api_response_validation: when the decoded variable is assigned and a subsequent IfStatement in the same block validates it (condition contains variable name and Map/List, then-branch returns or throws), the rule does not report. _variableValidatedByTypeCheck implements this heuristic. Fixtures updated with GOOD cases.

**Status:** Fixed

**Rules:** `require_api_response_validation`, `require_content_type_validation`  
**Reporter:** radiance_vector_game (game/lib/utils/json_validation.dart)

---

## Summary

Both rules reported on `jsonDecode(source)` inside a shared validation helper that checks Content-Type and validates decoded shape (Map/List) and throws otherwise. So the call site was the implementation of the validation; reporting was a false positive.

## Fix applied

- require_content_type_validation: _thenReturnsOrThrows now accepts ExpressionStatement(ThrowExpression) and Block with single ThrowStatement. _hasContentTypeGuardInStatement recurses into if-then blocks to find nested guards (e.g. if (responseHeaders != null) { if (!application/json) throw }).
- require_api_response_validation: _variableValidatedByTypeCheck(block, name, stmt) returns true when a following IfStatement has condition containing the variable name and Map/List and then-branch returns or throws. Rule checks this before reporting.

## Environment (at report)

- saropa_lints: 6.2.2
- Dart SDK: ^3.11.0
