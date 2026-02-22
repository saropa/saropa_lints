# Migration Candidate #059

**Source:** Flutter SDK 3.10.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** Use

---

## Release Note Entry

> Use variable instead of multiple accesses through a map by @ueman in [122178](https://github.com/flutter/flutter/pull/122178)
>
> Context: * Improve Dart plugin registration handling by @stuartmorgan in [122046](https://github.com/flutter/flutter/pull/122046)

**PR:** https://github.com/flutter/flutter/pull/122178

## PR Details

**Title:** Use variable instead of multiple accesses through a map
**Author:** @ueman
**Status:** merged
**Labels:** tool, autosubmit

### Description

Instead of accessing the same variable through the map multiple times, use the variable which is also statically checked.

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [ ] I listed at least one issue that this PR fixes in the description above.
- [x] I updated/added relevant documentation (doc comments with `///`).
- [ ] I added new tests to check the change I am making, or this PR is [test-exempt].
- [x] All existing and new tests are passing.

If you need help, consider asking for advice on the #hackers-new channel on [Discord].

<!-- Links -->
[Contributor Guide]: https://github.com/flutter/flutter/wiki/Tree-hygiene#overview
[Tree Hygiene]: https://github.com/flutter/flutter/wiki/Tree-hygiene
[test-exempt]: https://github.com/flutter/flutter/wiki/Tree-hygiene#tests
[Flutter Style Guide]: https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo
[Features we expect every widget to implement]: https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo#features-we-expect-every-widget-to-implement
[CLA]: https://cla.developers.google.com/
[flutter/tests]: https://github.com/flutter/tests
[breaking change policy]: https://github.com/flutter/flut

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Use`

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
**Generated:** From Flutter SDK v3.10.0 release notes
