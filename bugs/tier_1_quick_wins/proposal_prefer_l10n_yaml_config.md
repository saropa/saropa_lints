# PROPOSAL: Prefer L10n Yaml Config

**Status: Open**

Created: 2026-09-02

## Summary

Flags a project that configures Flutter localization inline or ad hoc (hardcoded ARB paths, manual `flutter gen-l10n` command-line flags) instead of through a standard `l10n.yaml` file.

## Motivation

`l10n.yaml` is the standard, tool-recognized configuration surface for Flutter's `gen_l10n`. Putting equivalent settings elsewhere — build scripts, `pubspec.yaml` overrides, hardcoded paths baked into generated-code imports — fragments configuration, breaks IDE/tooling that expects `l10n.yaml` at the project root, and makes it easy for ARB-file or class-name settings to drift from what actually gets generated.

## Detection / Behavior

Fires when the project uses `flutter_localizations`/`intl` code generation (imports of generated `AppLocalizations`/`S` classes, or `.arb` files present) but no `l10n.yaml` exists at the project root, or `gen-l10n` is invoked with command-line flags in a build script instead of reading `l10n.yaml`.

#### BAD:
```yaml
# pubspec.yaml — no l10n.yaml, flags passed ad hoc
flutter:
  generate: true
```
```bash
# scripts/build.sh
flutter gen-l10n --arb-dir=lib/l10n --output-dir=lib/generated
```

#### GOOD:
```yaml
# l10n.yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

## Quick Fix

Generate a starter `l10n.yaml` populated with the arb-dir/output settings detected from the ad-hoc flags or paths; leaves the `pubspec.yaml`/build-script cleanup to the user.

## Alternatives Considered

None — scope kept to presence-of-file detection, since reliably parsing `gen-l10n` CLI flags out of arbitrary shell scripts was judged too fragile for a broader check.
