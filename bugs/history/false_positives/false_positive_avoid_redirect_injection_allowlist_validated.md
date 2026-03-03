# False positive: `avoid_redirect_injection` — allowlist-validated “destination” parameters

**Rule:** `avoid_redirect_injection`  
**Status:** Resolved  
**Date:** 2026-03-03

---

## Summary

The rule reported redirect-related named arguments (e.g. `exportDestination`) even when the value was allowlist-validated (e.g. `_allowedExportDestinations.contains(x) ? x : null`) and used as metadata, not as a redirect URL. Consumer code used names like `_allowedExportDestinations` and `validatedDestination` but did not contain the literal words `allowlist` or `whitelist`, so the rule did not skip.

## Fix (implemented)

In `AvoidRedirectInjectionRule` (`lib/src/rules/security/security_network_input_rules.dart`), the “Skip if there's validation nearby” block now also skips when the enclosing block source (lowercased) contains the substrings `allowed` or `validated`. This covers patterns like `_allowedExportDestinations`, `validatedDestination`, and similar naming without requiring the literal word “allowlist”.

Fixture: `example_async/lib/security/avoid_redirect_injection_fixture.dart` — added GOOD example `goodAllowlistValidatedDestination` with no `expect_lint`. Tests: `test/security_rules_test.dart` — BAD count (3 expect_lint) and GOOD section without expect_lint.
