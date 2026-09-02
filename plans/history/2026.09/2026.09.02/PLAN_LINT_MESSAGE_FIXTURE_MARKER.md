# Plan: LINT_MESSAGE Fixture Marker

**Status:** Done (2026-09-02)
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

## Finish Report (2026-09-02)

**Implemented:** Declarative `// LINT_MESSAGE:` and `// LINT_NOT:` fixture markers for the resolved test harness — message-content validation and false-positive guards, respectively.

**New files:**
- `test/support/fixture_marker_parser.dart` — `parseFixtureMarkers()` extracts `// LINT:` + `// LINT_MESSAGE:` pairs, returning `FixtureExpectation` records. `parseFixtureNegations()` extracts `// LINT_NOT:` markers, returning `FixtureNegation` records. CRLF-safe.
- `test/support/fixture_message_harness.dart` — `assertFixtureMarkers()` runs a rule via `runRuleResolved`, validates positive markers (diagnostic must fire, message must match) and negative markers (diagnostic must NOT fire).
- `test/support/fixture_marker_parser_test.dart` — 19 unit tests: positive markers (single/multiple, with/without message, whitespace, non-adjacent rejection, end-of-file, special chars, CRLF, consecutive, adjacent different rules, stacked LINT_MESSAGE), negative markers (single, multiple, empty, CRLF, toString), cross-isolation (LINT_NOT not in parseFixtureMarkers).
- `test/support/fixture_message_harness_test.dart` — 11 integration tests using `require_ignore_comment_plugin_prefix`: positive (bare-name, prefixed-unknown, line-only, multiple), negative (LINT_NOT with registered rule, non-saropa rule, mixed positive+negative), failure modes (wrong substring, no markers, LINT_NOT on firing line), LINT_NOT-only source.

**Modified files:**
- `example/lib/formatting/require_ignore_comment_plugin_prefix_fixture.dart` — added 3 `// LINT_MESSAGE:` markers as proof-of-concept annotations.

**Design decisions:**
- Parser and assertion helper are separate files: parser is pure (no analyzer dependencies), testable independently; helper imports the resolved harness.
- `assertFixtureMarkers` returns the diagnostic list so callers can add extra assertions beyond what markers declare.
- LINT_MESSAGE must immediately follow its LINT marker (no blank line); a gap breaks the pairing — tested and intentional.
- `assertFixtureMarkers` accepts sources with only LINT_NOT markers (no LINT required) — supports pure false-positive-guard fixtures.

**Verification:** 30/30 new tests pass. 55 existing formatting + harness tests pass with no regressions.
