# Feature: require_method_channel_instrumented

**Status:** Fixed
**Filed:** 2026-07-25
**Source project:** contacts (`d:\src\contacts`)

## Summary

Add a lint rule `require_method_channel_instrumented` that flags any Dart file
calling `MethodChannel.invokeMethod` (or `invokeListMethod`, `invokeMapMethod`)
whose enclosing class lacks a `@MethodChannelInstrumented` annotation.

## Motivation

Method-channel calls cross the Dart↔native boundary via Binder IPC. Slow calls
block the Dart isolate and cause dropped frames. The contacts project added a
`noteIfSlow` debug utility (measures round-trip, logs `[slow-call]` warnings)
and a `@MethodChannelInstrumented` annotation documenting which call sites are
wrapped and which are intentionally unwrapped (trivial/off-main-thread work).

An `agents_rules.yaml` grep-based audit rule (`uninstrumented-invoke-method`)
enforces this today, but a proper analyzer lint would catch violations at
edit-time with IDE squiggles and provide a quick-fix to add the annotation.

## Detection

Flag when ALL of:
1. The file contains a call matching `*.invokeMethod<` or `*.invokeMethod(`
2. The file does NOT contain `@MethodChannelInstrumented` on any class

## Quick fix

Insert `@MethodChannelInstrumented('TODO: document instrumentation rationale')`
above the class declaration and add the import for `note_if_slow.dart`.

## False-positive exclusions

- `invokeMethod` in comments or string literals
- Files under `test/`
- The `note_if_slow.dart` file itself (defines the annotation)

## Annotation location

The annotation class `MethodChannelInstrumented` currently lives in the
contacts project at `lib/utils/_dev/note_if_slow.dart`. For the lint rule to
reference it cross-project, the annotation would need to move to a shared
package (e.g. `saropa_dart_utils`) or the lint rule would need to match by
class name string rather than by type identity.

## Priority

Low — the grep-based audit rule covers this today. The lint rule adds IDE
feedback and quick-fix convenience.

## Finish Report (2026-07-29)

### What changed

New lint rule `require_method_channel_instrumented` added to the Comprehensive tier (INFO severity). The rule registers a `addMethodInvocation` callback, matches `invokeMethod`/`invokeListMethod`/`invokeMapMethod` by exact name, walks up to the enclosing `ClassDeclaration`, and checks `metadata` for an annotation named `MethodChannelInstrumented`. The annotation is matched by class name string (not type identity), making it cross-project compatible without requiring the annotation to live in a shared package.

### Quick fix

`AddMethodChannelInstrumentedFix` inserts `@MethodChannelInstrumented('TODO: document instrumentation rationale')` above the class declaration. The annotation resolves the lint; the string argument prompts the developer to document their instrumentation strategy.

### Pre-filters

- `requiredPatterns: {'invokeMethod'}` — fast string pre-filter skips files without the literal.
- `requiresClassDeclaration: true` — skips files with no class declarations.
- `testRelevance` left at default (`never`) — test files are skipped, matching the feature request's false-positive exclusion.

### Files

- Rule + fix: `lib/src/rules/platforms/method_channel_rules.dart`
- Registration: `lib/saropa_lints.dart` (`_allRuleFactories`), `lib/src/tiers.dart` (`comprehensiveOnlyRules`), `lib/src/rules/all_rules.dart` (export)
- Fixture: `example/lib/platform/require_method_channel_instrumented_fixture.dart`
- Smoke test: `test/scan/fix_application_smoke_test.dart`

### Tests passed

- `test/integrity/saropa_lints_test.dart` — 24/24 (three-way registration validated)
- `test/integrity/anti_pattern_detection_test.dart` — no `.contains()` anti-patterns
- `test/scan/fix_application_smoke_test.dart` — fix class reachable, fixKind constants stable

### Design decision: no import insertion in quick fix

The feature request mentioned adding `import 'note_if_slow.dart'` in the quick fix. This was omitted because the annotation class lives in the contacts project, not in a shared package. The lint rule matches by name string, so any project can define its own `MethodChannelInstrumented` annotation class — inserting a project-specific import path would be wrong for all other consumers.
