# Migration Candidate #020

**Source:** Flutter SDK 3.27.0
**Category:** Replacement / Migration
**Relevance Score:** 9
**Detected APIs:** Update, Future.value, SynchronousFuture

---

## Release Note Entry

> Update fake_codec.dart to use Future.value instead of SynchronousFuture by @biggs0125 in [152182](https://github.com/flutter/flutter/pull/152182)
>
> Context: * Add a more typical / concrete example to IntrinsicHeight / IntrinsicWidth by @LongCatIsLooong in [152246](https://github.com/flutter/flutter/pull/152246)

**PR:** https://github.com/flutter/flutter/pull/152182

## PR Details

**Title:** Update fake_codec.dart to use Future.value instead of SynchronousFuture
**Author:** @biggs0125
**Status:** merged
**Labels:** framework, autosubmit

### Description

Upcoming changes to DDC change the async semantics of code produced by the compiler. The changes will bring the semantics more in line with those of dart2js and fix several bugs in the old semantics. However in landing those changes I experienced a test failure in [obscured_animated_image_test](https://github.com/flutter/flutter/blob/master/packages/flutter/test/widgets/obscured_animated_image_test.dart).

Some debugging uncovered that this is due to the use of `SynchronousFuture` in this `FakeCodec`. The old DDC async semantics forced an async gap when that future was [awaited](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/painting/image_stream.dart#L1064). The new async semantics do not create an async gap here. This changes the render ordering of the widget tree created in the test leading to the test failure.

`Future.value` should be a reasonable substitute here and should achieve what the test was trying to achieve while also preserving the correct render ordering given the new DDC semantics.

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Update`
- `Future.value`
- `SynchronousFuture`

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
**Generated:** From Flutter SDK v3.27.0 release notes
