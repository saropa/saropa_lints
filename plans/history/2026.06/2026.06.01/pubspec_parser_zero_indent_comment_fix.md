# Package Dashboard dropped direct deps after zero-indent comments

## Trigger

User compared the saved `20260601_082341pubspec_vibrancy.json` against
`flutter pub outdated` on the saropa contacts project and observed that
~14 direct dependencies — `device_info_plus`, `flutter_contacts`,
`fluttermoji`, `font_awesome_flutter`, `home_widget`, `image`, `latlong2`,
`meta`, `network_info_plus`, `package_info_plus`, `permission_handler`,
`share_plus`, `youtube_player_flutter` — were missing from both the
dashboard table and the exported JSON. User said "the screen is lacking
too" and then "fix".

## Root cause

`extension/src/vibrancy/services/pubspec-parser.ts` used `/^\S/.test(trimmed)`
as the section-exit guard in three call sites:

- `parsePubspecYaml` (line 30)
- `forEachEnvironmentLine` (line 170)
- `parseDependencyOverrides` (line 240)

Because `#` is not whitespace, a zero-indent comment like
`# cspell:ignore bardram` matched the guard, flipped the active section
to `'none'`, and silently dropped every subsequent package until the
parser saw another `dependencies:` / `dev_dependencies:` /
`dependency_overrides:` header. The saropa contacts pubspec has two such
column-zero `# cspell:ignore …` comments at lines 131 and 348 inside
`dependencies:`, which explains the exact pattern of missing packages —
direct deps after line 131 silently dropped, dev deps still picked up
(line 722+), `country_picker` survives because it sits before line 131.

## Fix

Skip blank and `#`-prefixed lines before the `/^\S/` exit check at all
three call sites:

```ts
const isCommentOrBlank = trimmed.length === 0 || trimmed.startsWith('#');
if (!isCommentOrBlank && /^\S/.test(trimmed) && section !== 'none') {
    section = 'none';
}
```

A real top-level key (e.g. `flutter:`, `dev_dependencies:`) still
terminates the section. WHY comments at each fix site name the failure
mode and the saropa/contacts incident.

## Tests

New self-contained file
`extension/src/test/vibrancy/services/pubspec-parser-comments.test.ts`,
wired into `extension/tsconfig.test.json` and the mocha glob in
`extension/package.json`. Four cases:

- `parsePubspecYaml` keeps collecting deps after a zero-indent comment
- `parsePubspecYaml` still treats a real top-level key as a section
  terminator
- `parseDependencyOverrides` keeps collecting overrides after a
  zero-indent comment
- `parseDependencyOverrides` still exits on a real top-level key

`npm test -- --grep "comment.resilience"` → 4 passing.

The pre-existing `pubspec-parser.test.ts` was found to depend on fixture
files (`src/test/fixtures/pubspec.yaml`, `.lock`) that do not exist in
the repo, and was never wired into the test runner. Left alone — that
is a pre-existing condition unrelated to this fix and would expand
scope to repair.

## Files changed

- `extension/src/vibrancy/services/pubspec-parser.ts` — the fix (three
  sites)
- `extension/src/test/vibrancy/services/pubspec-parser-comments.test.ts`
  — new regression tests
- `extension/tsconfig.test.json` — include new test file
- `extension/package.json` — add new test to mocha glob
- `CHANGELOG.md` — entry under `[Unreleased] → Fixed (Extension)`
- `plans/history/2026.06/2026.06.01/pubspec_parser_zero_indent_comment_fix.md`
  — this file

## Scope confirmation

VS Code extension TypeScript only. No Dart lint rule, no
`lib/src/rules/`, no `tiers.dart`, no `LintImpact`, no `ROADMAP.md`. The
LINTER variant's Dart-specific gates do not apply.

## Out of scope

- The pre-existing `cross-file commands` test suite has 10 failures
  observed during the full-suite run. None of those tests reference the
  parser; they live in files I did not touch. Pre-existing condition,
  not introduced by this fix.
- The pre-existing `pubspec-parser.test.ts` references missing fixture
  files and is not wired into the runner. Repairing that would expand
  scope.
- Three other files in the working tree (`extension-activation.ts`,
  `scan-helpers.ts`, `report-exporter.ts`) carry uncommitted changes
  from a separate workstream and are excluded from this commit.

## Verification

On the saropa contacts project, rescan the Package Dashboard. The
previously missing direct deps (`device_info_plus`, `share_plus`,
`youtube_player_flutter`, etc.) now appear in both the table and the
exported `pubspec_vibrancy.json`.
