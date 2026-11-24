# sdk-constraint (Package Vibrancy) has no suppression mechanism

**Status: Fixed**

## Summary
The `sdk-constraint` diagnostic (source `Package Vibrancy`) on `pubspec.yaml` `environment.sdk` / `environment.flutter` cannot be silenced. Projects that deliberately pin an old SDK (e.g. to support Android 5.1 / API 22 devices, which Flutter > 3.32 dropped) get a permanent warning.

## Evidence
- `extension/src/vibrancy/providers/sdk-diagnostics.ts` emits the diagnostic with no ignore check.
- `# saropa_lints:ignore <code>` is honored only in `extension/src/pubspec-validation.ts` (`pubspec_validation` diagnostics), not in the vibrancy provider.
- Package-level "Suppress Package" does not apply: the diagnostic range is the `sdk` / `flutter` key, not a package name.

## Reproduction
`jupiter-tablet/pubspec.yaml`:
```yaml
environment:
  sdk: ^3.8.0   # Dart SDK minimum (3.8.0) is behind latest stable
  flutter: ">=3.32.0"   # Flutter minimum (3.32.0) is behind latest stable
```
Adding `# saropa_lints:ignore sdk-constraint` to either line has no effect.

## Requested
1. Honor `# saropa_lints:ignore sdk-constraint` on the same or preceding line in `sdk-diagnostics.ts` (reuse the parser at `pubspec-validation.ts:184-210`).
2. Offer a "Suppress (intentional old SDK)" quick fix next to the existing "raise to >=3.11.0" fix in `code-action-provider.ts`.

## Reporter
jupiter-tablet

## Finish Report (2026-11-24)

The Package Vibrancy `sdk-constraint` diagnostic on `pubspec.yaml` `environment.sdk` / `environment.flutter` had no suppression path, so projects deliberately pinned to an old SDK carried a permanent warning.

Changes:
- `extension/src/pubspec-validation.ts`: `isSuppressed` exported (same-line or preceding-line `# saropa_lints:ignore <code>`).
- `extension/src/vibrancy/providers/sdk-diagnostics.ts`: `buildConstraintDiagnostics` returns no diagnostics when `sdk-constraint` is suppressed for the constraint line.
- `extension/src/vibrancy/providers/code-action-provider.ts`: new "Suppress (intentional old SDK)" quick fix on both `sdk:` and `flutter:` lines. Placement: appended comment when none exists; `, sdk-constraint` appended to an existing comma-separated code list; standalone comment on the line above when the existing directive has trailing prose. Label routed through `l10n('vibrancy.sdkConstraint.suppressOldSdk')`; key added to `en.json`.
- Tests: `sdk-diagnostics.test.ts` (4) and `sdk-suppress-action.test.ts` (5), registered in `tsconfig.test.json`. A first draft of the code-list regex accepted prose as codes; the trailing-prose test caught it and the regex was tightened.

Verification: `tsc --noEmit` and `tsc -p tsconfig.test.json` clean; 9/9 new tests pass. Not rendered in an Extension Development Host. Translated locale catalogs not regenerated (publish-time gate).

Follow-up hardening: `isFileSuppressed` adds a file-wide `# saropa_lints:ignore-file [codes]` directive (applied inside `isSuppressed`, so it covers both pubspec validation and `sdk-constraint`); `endsWithIgnoreCodeList` is exported from `pubspec-validation.ts` so the quick fix and the parser share one grammar; the new tests are added to the `npm test` file list (3 more ignore-file tests).
