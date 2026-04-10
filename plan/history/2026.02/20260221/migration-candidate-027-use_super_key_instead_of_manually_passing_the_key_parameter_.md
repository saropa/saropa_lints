# Migration Candidate #027

**Source:** Flutter SDK 3.24.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** Use, Key, EchoEllet

---

## Release Note Entry

> Use super.key instead of manually passing the Key parameter to the parent class by @EchoEllet in [147621](https://github.com/flutter/flutter/pull/147621)
>
> Context: * test material text field example by @NobodyForNothing in [147864](https://github.com/flutter/flutter/pull/147864)

**PR:** https://github.com/flutter/flutter/pull/147621

## PR Details

**Title:** Use super.key instead of manually passing the Key parameter to the parent class
**Author:** @EchoEllet
**Status:** merged
**Labels:** framework, d: api docs, d: examples, autosubmit

### Description

*Use `super.key` instead of manually passing the `Key` parameter using super(key: key) in the constructors.*

Since if you create a widget the new default will use `super.key` instead of `Key? key : super(key: key)` this small change is to maintain the consistency, it has no semantic change

also there are some other places that might need to be updated:

![image](https://github.com/flutter/flutter/assets/73608287/898f62f5-10f9-4d76-a46c-6def328177cb)

this file for example generate l10n project and it has all the dart code as String, it might have tests that validate the output somewhere that I might miss, also there are some other places like the `_Segment` class where it require `ValueKey` instead if `Key` so I didn't update them (even though it's possible)

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [ ] I listed at least one issue that this PR fixes in the description above.
- [ ] I updated/added relevant documentation (doc comments with `///`).
- [ ] I added new tests to check the change I am making, or this PR is [test-exempt].
- [ ] I followed the [breaking change policy] and added [Data Driven Fixes] where supported.
- [x] All existing and new tests are pas

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Use`
- `Key`
- `EchoEllet`

---

## Proposed Lint Rule

**Rule Type:** `prefer_replacement`
**Estimated Difficulty:** easy

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
**Generated:** From Flutter SDK v3.24.0 release notes
