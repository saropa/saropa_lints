# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> **Looking for older changes?**  \
> See [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md) for versions 0.1.0 through 1.6.0.

## [1.7.7] - 2026-01-09

### Changed
- **Docs**: README now has a Limitations section clarifying Dart-only analysis and dependency_overrides behavior.

## [1.7.6] - 2026-01-09

### Added
- **Quick fix**: avoid_isar_enum_field auto-converts enum fields to string storage.

### Changed
- **Impact tuning**: avoid_isar_enum_field promoted to LintImpact.high.

### Fixed
- Restored NullabilitySuffix-based checks for analyzer compatibility.

## [1.7.5] - 2026-01-09

### Added
- **Opinionated severity**: Added LintImpact.opinionated.
- **New rule**: prefer_future_void_function_over_async_callback.
- **Configuration template**: Added example/analysis_options_template.yaml with 767+ rules.

### Fixed
- Empty block warnings in async callback fixture tests.

### Changed
- **Docs**: Updated counts to reflect 767+ rules.
- **Severity**: Stylistic rules moved to LintImpact.opinionated.

## [1.7.4] - 2026-01-08
- Updated the banner image to show the project name Saropa Lints.

## [1.7.3] - 2026-01-08

### Added
- **New documentation guides**: using_with_flutter_lints.md and migration_from_solid_lints.md.
- Added "Related Packages" section to VGA guide.

### Changed
- **Naming**: Standardized "Saropa Lints" vs saropa_lints across all docs.
- **Migration Guides**: Updated rules (766+), versions (^1.3.0), and tier counts.

## [1.7.2] - 2026-01-08

### Added
- **Impact Classification System**: Categorized rules by critical, high, medium, and low.
- **Impact Report CLI Tool**: dart run saropa_lints:impact_report for prioritized violation reporting.
- **47 New Rules**: Covering Riverpod, GetX, Bloc, Accessibility, Security, and Testing.
- **11 New Quick Fixes**.

## [1.7.1] - 2026-01-08

### Fixed
- Resolved 25 violations for curly_braces_in_flow_control_structures.

## [1.7.0] - 2026-01-08

### Added
- **50 New Rules**: Massive expansion across Riverpod, Build Performance, Testing, Security, and Forms.
- Added support for sealed events in Bloc.

---

## [1.6.0] and Earlier
For details on the initial release and versions 0.1.0 through 1.6.0, please refer to [CHANGELOG_ARCHIVE.md](./CHANGELOG_ARCHIVE.md).
