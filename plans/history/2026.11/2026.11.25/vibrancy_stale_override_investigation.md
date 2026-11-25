# Vibrancy stale-override false positive (permission_handler_android): investigation and hardening

Package Vibrancy reported `permission_handler_android: 13.0.1` in `dependency_overrides` as stale although the parent `permission_handler` declares `^14.1.0`. The root cause in the reporting project is unconfirmed; this change fixes one confirmed parser hazard that produces the same symptom and adds diagnostics for the remaining hypotheses. The bug report is archived at `plans/history/2026.11/2026.11.25/infra_vibrancy_stale_override_false_positive_permission_handler_android.md`.

## Finish Report (2026-11-25)

### Verified
- The pure analyzer returns `active` (blocker `permission_handler`) for parent range `^14.1.0` and override `13.0.1` (new unit test).
- `parsePubspecYaml` reads `permission_handler_android: ^14.1.0` correctly from the real `permission_handler-13.0.2/pubspec.yaml`.

### Changed
- `pubspec-parser.ts`: trailing YAML comments are stripped from constraint values (including a comment that starts the value); quoted values keep their quotes and a `#` inside quotes is preserved. A constraint with a trailing comment is an invalid semver range, which `satisfiesConstraint` treats as satisfied, so the override read as stale.
- `shared-dep-constraints.ts`: optional `onSkip` callback reports candidates missing from `package_config.json` or with no readable constraints.
- `extension-activation.ts`: skip reasons and a failed dependency graph are written to the scan log.
- Tests added in `override-analyzer.test.ts` and `pubspec-parser.test.ts`.
- `CHANGELOG.md`: new `17.9.1 — Unreleased` section with overview and a Fixed (Extension) entry.

### Added after the reflection gate
- Override status `unknown` (shown as "Unverified") when the dependency graph failed, or when an unreadable parent pubspec depends on the override. The parent gap is scoped per override so an unrelated unreadable package cannot mask a genuinely stale override.
- Skip reasons distinguish unresolved path, read failure and empty pubspec.
- Group tooltip/icon and the scan log count unverified overrides; the tree JSON serializer accepts the new context value.
- Strings routed through `l10n()` with keys under `vibrancyOverride.*` in `en.json`. Translated catalogs are not regenerated; regeneration is a publish-time step.
- Review of the post-gate diff found five issues (serializer context value, global gap scope, missing unknown count, hardcoded strings, quoted-value consumers). The first four were fixed. Quoted constraint values keep their quotes, as before; `satisfiesConstraint` strips them and other consumers were not audited.

### Unconfirmed
- `.dart_tool/package_config.json` of the reporting project was not readable, so hypotheses A (parent path unresolved) and C (parent absent from the dependency graph) remain untested.

### Test results
- `npx tsc --noEmit -p .` and `npx tsc -p tsconfig.test.json`: clean.
- Scoped mocha (override-analyzer, pubspec-parser, pubspec-parser-comments, pubspec-sorter): all pass.
- `test/i18n` has 31 failing locale-parity tests both with and without these changes (count taken at HEAD via stash).
- `pubspec-validation.test.js` has one failing test (`prefer_l10n_yaml_config` "does not flag when l10n.yaml exists alongside pubspec") that also fails with these changes stashed.
- No Extension Development Host run; the Unverified tree row, group tooltip and detail item are unrendered; check both themes.
