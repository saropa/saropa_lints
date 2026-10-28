# Version sync: Dart package and VS Code extension

## Issue (2026-10-28)
- Dart package: 16.10.0 (tag v16.10.0).
- Extension `extension/package.json`: 16.12.0, set by release commit d86c1d3f (was 16.10.1). Already offered by VS Code.
- The owner never authorized a separate extension version. Both must always match.

## Decision (owner, 2026-10-28)
- Next release is 16.13.0 for both the Dart package and the extension. The Marketplace cannot lower a version, so the Dart package skips to 16.13.0.
- The publish script must set the extension version to the Dart package version, with no independent bump, and fail before publishing if they differ or if the extension would go below the Marketplace version.

## Status
- Publish-script fix: in progress (root cause being traced).
- Version numbers: unchanged until the 16.13.0 release.
