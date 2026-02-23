# Migration Candidate #005

**Source:** Flutter SDK 3.38.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** constant, final, Update, AbdeMohlbi

---

## Release Note Entry

> Update gradle_utils.dart to use `constant` instead of `final` by @AbdeMohlbi in [175443](https://github.com/flutter/flutter/pull/175443)
>
> Context: * Update gradle_errors.dart to use constants defined in gradle_utils.dart by @AbdeMohlbi in [174760](https://github.com/flutter/flutter/pull/174760)

**PR:** https://github.com/flutter/flutter/pull/175443

## PR Details

**Title:** Update gradle_utils.dart to use `constant` instead of `final`
**Author:** @AbdeMohlbi
**Status:** merged
**Labels:** tool, team-android

### Description

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I followed the [breaking change policy] and added [Data Driven Fixes] where supported.
- [ ] All existing and new tests are passing.
- [ ] I listed at least one issue that this PR fixes in the description above.
- [ ] I updated/added relevant documentation (doc comments with `///`).
- [ ] I added new tests to check the change I am making, or this PR is [test-exempt].

If you need help, consider asking for advice on the #hackers-new channel on [Discord].

**Note**: The Flutter team is currently trialing the use of [Gemini Code Assist for GitHub](https://developers.google.com/gemini-code-assist/docs/review-github-code). Comments from the `gemini-code-assist` bot should not be taken as authoritative feedback from the Flutter team. If you find its comments useful you can update your code accordingly, but if you are unsure or disagree with the feedback, please feel free to wait for a Flutter team member's review for guidance on which automated comments should be addressed.

<!-- Links -->
[Contributor Guide]: https://github.com/flutter/flutter/blob/main/docs/contributing/Tree-hygiene.md#overview
[Tree Hygiene]: https://github

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `constant`
- `final`
- `Update`
- `AbdeMohlbi`

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
**Generated:** From Flutter SDK v3.38.0 release notes
