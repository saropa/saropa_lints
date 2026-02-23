# Migration Candidate #045

**Source:** Flutter SDK 3.19.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** FlutterCompositor, Move

---

## Release Note Entry

> [Windows] Move to `FlutterCompositor` for rendering by @loic-sharma in [48849](https://github.com/flutter/engine/pull/48849)
>
> Context: * [Flutter GPU] Runtime shader import. by @bdero in [48875](https://github.com/flutter/engine/pull/48875)

**PR:** https://github.com/flutter/engine/pull/48849

## PR Details

**Title:** [Windows] Move to `FlutterCompositor` for rendering
**Author:** @loic-sharma
**Status:** merged
**Labels:** affects: desktop, platform-linux, platform-windows, e: impeller, autosubmit

### Description

This migrates the Windows embedder to `FlutterCompositor` so that the engine renders off-screen to a framebuffer instead of directly onto the window's surface. This will allow us to support platform views and multiple views on Windows.

<details>
<summary>Tests...</summary>

* Verify OpenGL compositor's raster time isn't regressed and memory increase is reasonable
* Software compositor's raster time and memory isn't regressed

Test device configurations
* [x] Windows 11 (hardware acceleration enabled/disabled)
* [x] Windows Arm64 (hardware acceleration enabled/disabled)
* [x] Windows 7 (hardware acceleration enabled/disabled, DWM enabled/disabled)

</details>

Addresses https://github.com/flutter/flutter/issues/128904

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide] and the [C++, Objective-C, Java style guides].
- [x] I listed at least one issue that this PR fixes in the description above.
- [x] I added new tests to check the change I am making or feature I am adding, or the PR is [test-exempt]. See [testing the engine] for instructions on writing and running engine tests.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [x] I signed the [CLA].
- [x] All existing and new tests are passing.

If you need help, consider askin

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `FlutterCompositor`
- `Move`

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
**Generated:** From Flutter SDK v3.19.0 release notes
