# Migration Candidate #074

**Source:** Flutter SDK 3.3.0
**Category:** Deprecation
**Relevance Score:** 5
**Detected APIs:** Migrate

---

## Release Note Entry

> [tool] Migrate off deprecated coverage parameters by @cbracken in https://github.com/flutter/flutter/pull/104997
>
> Context: * Retry builds when SSL exceptions are thrown by @blasten in https://github.com/flutter/flutter/pull/105078

**PR:** https://github.com/flutter/flutter/pull/104997

## PR Details

**Title:** [tool] Migrate off deprecated coverage parameters
**Author:** @cbracken
**Status:** merged
**Labels:** tool

### Description

In https://github.com/flutter/flutter/pull/103771, we rolled
dependencies in Flutter, which triggered an update of package:coverage
to v1.3.1. The new version includes
https://github.com/dart-lang/coverage/pull/370 in which two deprecations
landed:

* The `Resolver` default constructor was deprecated and replaced with
  the `Resolver.create` static factory method, which unfortunately
  happens to be async.
* The `packagesPath` parameter to `HitMap.parseJson`, which takes the
  path to the `.packages` file of the package for which coverage is to
  be collected, was deprecated. This parameter was replaced with
  `packagePath` in https://github.com/dart-lang/coverage/pull/370 which
  was part of the overall deprecation of the .packages file in Dart
  itself https://github.com/dart-lang/sdk/issues/48272. The overall goal
  being that end-user code shouldn't need to know about implementation
  details such as whether dependency information is stored in a
  .packages file or a package_info.json file, but rather use the
  package_config package to obtain the package metadata and perform
  other functions such as resolving its dependencies to filesystem
  paths. packagesPath was replaced by packagePath, which takes the path
  to the package directory itself. Internally, package:coverage then
  uses package_config to do the rest of the package/script URI
  resolution to filesystem paths.

This migrates off the deprecated `packagesPath` parameter to the
replac

[... truncated]

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `Migrate`

---

## Proposed Lint Rule

**Rule Type:** `deprecation_migration`
**Estimated Difficulty:** easy

### Detection Strategy

Detect usage of the deprecated API via AST method/property invocation nodes

**Relevant AST nodes:**
- `MethodInvocation`
- `PropertyAccess`
- `PrefixedIdentifier`
- `SimpleIdentifier`

### Fix Strategy

Replace with the recommended alternative API

---

## Implementation Checklist

- [ ] Verify the API change in Flutter/Dart SDK source
- [ ] Determine minimum SDK version requirement
- [ ] Write detection logic (AST visitor)
- [ ] Write quick-fix replacement
- [ ] Create test fixture with bad/good examples
- [ ] Add unit tests
- [ ] Register rule in `all_rules.dart`
- [ ] Add to tier in `tiers.dart`
- [ ] Update ROADMAP.md
- [ ] Update CHANGELOG.md

---

**Status:** Not started
**Generated:** From Flutter SDK v3.3.0 release notes
