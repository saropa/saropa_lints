# Completed (2026-03-23)

**Lint:** `prefer_image_filter_quality_medium` (Comprehensive tier, INFO).

**Implementation:** `lib/src/rules/widget/image_filter_quality_migration_rules.dart` (`PreferImageFilterQualityMediumRule`), shared detection `lib/src/rules/widget/image_filter_quality_detection.dart`, quick fix `lib/src/fixes/widget/prefer_image_filter_quality_medium_fix.dart`.

**Quick fix:** Replaces `FilterQuality.low` → `FilterQuality.medium` (preserves prefix on the enum, e.g. `ui.FilterQuality`).

**Tests:** `test/image_filter_quality_detection_test.dart`. The Dart-only `example/` package uses mock `Image` types (not `package:flutter`), so there is no `// LINT` fixture there; behavior is covered by unit tests.

**Tracking:** `CHANGELOG.md` [Unreleased]; `lib/src/tiers.dart` comprehensive set; `example/analysis_options_template.yaml`.

**Flutter:** Defaults moved in [PR #148799](https://github.com/flutter/flutter/pull/148799) (Flutter 3.24). Rule does not apply to `Texture` (texture defaults were reverted to `low` in the same PR series).

---

# Plan #030

**Source:** Flutter SDK 3.24.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** Switch, FilterQuality.medium

---

## Release Note Entry

> Switch to FilterQuality.medium for images by @goderbauer in [148799](https://github.com/flutter/flutter/pull/148799)
>
> Context: * Fix InputDecorator default hint text style on M3 by @bleroux in [148944](https://github.com/flutter/flutter/pull/148944)

**PR:** https://github.com/flutter/flutter/pull/148799

## PR Details

**Title:** Switch to FilterQuality.medium for images
**Author:** @goderbauer
**Status:** merged
**Labels:** framework, f: material design, f: scrolling, will affect goldens, autosubmit

### Description

https://github.com/flutter/flutter/issues/148253

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Switch`
- `FilterQuality.medium`

---

## Proposed Lint Rule

**Rule Type:** `prefer_replacement`
**Estimated Difficulty:** medium

### Detection Strategy

Detect old pattern and suggest the replacement

**Relevant AST nodes:**
- `MethodInvocation`
- `PropertyAccess`
- `SimpleIdentifier`

### Fix Strategy

Replace old API/pattern with the new recommended approach

---

## Implementation Checklist

- [x] Verify the API change in Flutter/Dart SDK source
- [x] Determine minimum SDK version requirement (Flutter 3.24+; rule is opt-in via tier)
- [x] Write detection logic (AST visitor)
- [x] Write quick-fix replacement
- [x] Create test fixture with bad/good examples (Dart-only `example/` uses mocks — no LINT fixture; tests in `test/image_filter_quality_detection_test.dart`)
- [x] Add unit tests
- [x] Register rule in `all_rules.dart`
- [x] Add to tier in `tiers.dart`
- [x] Update ROADMAP.md (not listed per-rule; see CHANGELOG)
- [x] Update CHANGELOG.md

---

**Status:** Implemented as `prefer_image_filter_quality_medium` (`lib/src/rules/widget/image_filter_quality_migration_rules.dart`, `lib/src/rules/widget/image_filter_quality_detection.dart`, fix `lib/src/fixes/widget/prefer_image_filter_quality_medium_fix.dart`)
**Generated:** From Flutter SDK v3.24.0 release notes
