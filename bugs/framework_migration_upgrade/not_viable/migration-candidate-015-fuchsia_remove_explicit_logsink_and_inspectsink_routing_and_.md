# Migration Candidate #015

**Source:** Flutter SDK 3.32.0
**Category:** Replacement / Migration
**Relevance Score:** 6
**Detected APIs:** Remove, LogSink, InspectSink

---

## Release Note Entry

> [fuchsia] Remove explicit LogSink and InspectSink routing and use dictionaries instead by @gbbosak in [162780](https://github.com/flutter/flutter/pull/162780)
>
> Context: * Public nodes needing paint or layout by @emerssso in [166148](https://github.com/flutter/flutter/pull/166148)

**PR:** https://github.com/flutter/flutter/pull/162780

## PR Details

**Title:** [fuchsia] Remove explicit LogSink and InspectSink routing and use dictionaries instead
**Author:** @gbbosak
**Status:** merged
**Labels:** a: text input, engine, platform-fuchsia

### Description

This is a Fuchsia change to prepare for future changes to the SDK. LogSink and InspectSink will soon be routed through dictionaries, rather than explicitly. For RealmBuilders, we need to route both the dictionary and the protocol (to preserve compatibility). For CML files, we need to use the shards in the SDK instead of using explicit routes. Once the SDK shard is updated, then all SDK consumers should receive new routes. However, not everyone will necessarily be updated at the same time, which is the reason for keeping compatibility routes in RealmBuilder (to prepare for the soft transition).

b/394681733

## Pre-launch Checklist

- [X] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [X] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [X] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [(Google employee)] I signed the [CLA].
- [X] I listed at least one issue that this PR fixes in the description above.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [X (exempt, SDK mechanical change only)] I added new tests to check the change I am making, or this PR is [test-exempt].
- [X] I followed the [breaking change policy] and added [Data Driven Fixes] where supported.
- [X (unable to test on Fuchsia, I believe it has to be merged to be tested)] All existing and new tests are passing.

If you need help, consider as

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Remove`
- `LogSink`
- `InspectSink`

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
**Generated:** From Flutter SDK v3.32.0 release notes
