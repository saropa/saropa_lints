# Task: `prefer_js_interop_over_dart_js` — Implemented

**Status:** Implemented (rule in tiers).  
**Rule:** `prefer_js_interop_over_dart_js` in `lib/src/rules/platforms/web_rules.dart`.  
**Tier:** Professional. **Severity:** INFO.

## Summary

Use stable `dart:js_interop` (Dart 3.5+) instead of deprecated `dart:js` / `dart:js_util`.  
Detection: exact `Set` match on `ImportDirective.uri` (`dart:js`, `dart:js_util` only). No heuristics.  
Fixture: `example_platforms/lib/web/prefer_js_interop_over_dart_js_fixture.dart`.
