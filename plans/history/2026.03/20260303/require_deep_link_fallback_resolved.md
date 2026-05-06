# require_deep_link_fallback — false positive / clarification (RESOLVED)

**Rule:** `require_deep_link_fallback`  
**File:** `lib/src/rules/ui/navigation_rules.dart` — `RequireDeepLinkFallbackRule`  
**Status:** Resolved  
**Date:** 2026-03-03

## Resolution summary

1. **Tightened handler detection:** The rule now reports only when the method body contains at least one **navigation** signal (`Navigator`, `GoRouter`, `.go(`, `.push(`, `.goNamed(`, `.pushNamed(`, `.pushReplacement`, `getInitialLink`, `getInitialUri`). Methods that only parse URIs or build link text (e.g. `exportLinkToClipboard`, share helpers) are no longer reported, even if the method name matches deeplink/link/uri/route.

2. **Fallback detection:** Added `!=\s*null` to `_deepLinkFallbackPatterns` so that `if (id != null) { Navigator.push(...) }` is recognized as fallback.

3. **Documentation:** Rule DartDoc now includes "When we report" / "When we don't report", a developer note on pattern-based (heuristic) detection, and the existing BAD/GOOD examples.

4. **Fixture:** `example_widgets/lib/navigation/require_deep_link_fallback_fixture.dart` — added `exportLinkToClipboard` (no navigation, must not trigger) and `_good509_handleRouteByUri` (!= null guard, must not trigger). BAD case unchanged (navigate without fallback still triggers).

## References

- Original bug: `bugs/false_positive_require_deep_link_fallback.md` (deleted after integration)
- Tests: `test/false_positive_fixes_test.dart` (require_deep_link_fallback group), `test/navigation_rules_test.dart`
