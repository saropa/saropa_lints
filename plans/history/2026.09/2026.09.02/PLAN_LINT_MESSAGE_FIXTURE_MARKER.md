# Plan: LINT_MESSAGE Fixture Marker

**Status:** Open
**Created:** 2026-08-30
**Priority:** Low — nice-to-have infrastructure improvement

---

## Problem

The fixture test harness validates that lint rules fire on `// LINT:` markers but does not validate the *message content* of the diagnostic. This allowed the `require_ignore_comment_plugin_prefix` wrong-message bug to ship — the lint fired on the right lines but displayed the wrong message.

Resolved tests (like the 4 added in the bug fix) can pin message content, but they require writing explicit test code for each case. A declarative fixture marker would make message validation frictionless.

## Proposed Feature

Add a `// LINT_MESSAGE: <substring>` marker that the fixture scanner validates against `HarnessDiagnostic.message`. When present on a `// LINT:` line, the harness asserts that the emitted diagnostic's `problemMessage` contains the substring.

### Fixture syntax

```dart
// LINT: require_ignore_comment_plugin_prefix
// LINT_MESSAGE: not a registered
// ignore: saropa_lints/totally_fake_rule
final x = 1;
```

### Implementation steps

1. Extend fixture scanner to recognize `// LINT_MESSAGE:` on lines following `// LINT:`
2. Thread the expected message substring through to the resolved harness assertion
3. Update `runRuleResolved` or a wrapper to compare `HarnessDiagnostic.message` against the marker
4. Migrate existing resolved message tests to use the declarative marker where appropriate

### Scope

- ~113 test files use `testRule()` but only a subset would need message markers
- Backward compatible: existing fixtures without `// LINT_MESSAGE:` continue to work
- The resolved test harness (`test/support/resolved_rule_harness.dart`) already captures `message` in `HarnessDiagnostic`

### Risk

Low — purely additive infrastructure. No rule behavior changes.
