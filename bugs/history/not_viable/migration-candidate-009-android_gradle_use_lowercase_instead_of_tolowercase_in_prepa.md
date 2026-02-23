# Migration Candidate #009

**Source:** Flutter SDK 3.35.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** N/A

---

## Release Note Entry

> Android gradle use lowercase instead of toLowerCase in preparation for removal in v9 by @reidbaker in [171397](https://github.com/flutter/flutter/pull/171397)
>
> Context: * remove `x86` unused codepaths by @AbdeMohlbi in [170191](https://github.com/flutter/flutter/pull/170191)

**PR:** https://github.com/flutter/flutter/pull/171397

## PR Details

**Title:** Android gradle use lowercase instead of toLowerCase in preparation for removal in v9
**Author:** @reidbaker
**Status:** merged
**Labels:** platform-android, tool

### Description

partial resolution for #170791 (lowercase but not filemode) 

This is the first time I have used the experimental api annotation. Most users should have lowercase available without the annotation only the oldest kotlin/agp versions should need the annotation. 

to test with different gradle versions I ran `sed -i '' 's/gradle-.*-bin\.zip/gradle-VERSION-bin.zip/g' gradle/wrapper/gradle-wrapper.properties; JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/ ./gradlew test` 
from packages/flutter_tools/gradle

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I listed at least one issue that this PR fixes in the description above.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [x] I added new tests to check the change I am making, or this PR is [test-exempt].
- [x] I followed the [breaking change policy] and added [Data Driven Fixes] where supported.
- [x] All existing and new tests are passing.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

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
**Generated:** From Flutter SDK v3.35.0 release notes
