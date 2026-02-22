# Migration Candidate #004

**Source:** Flutter SDK 3.38.0
**Category:** New Feature / API
**Relevance Score:** 5
**Detected APIs:** Project, gradle-wrapper.properties, Introduce, AbdeMohlbi

---

## Release Note Entry

> Introduce a getter for `Project` to get `gradle-wrapper.properties` directly by @AbdeMohlbi in [175485](https://github.com/flutter/flutter/pull/175485)
>
> Context: * [ Widget Preview ] Fix filter by file on Windows by @bkonyi in [175783](https://github.com/flutter/flutter/pull/175783)

**PR:** https://github.com/flutter/flutter/pull/175485

## PR Details

**Title:** Introduce a getter for `Project` to get `gradle-wrapper.properties` directly  
**Author:** @AbdeMohlbi
**Status:** merged
**Labels:** tool, team-android

### Description

follow up to [this comment](https://github.com/flutter/flutter/pull/174760#discussion_r2353508903)

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I updated/added relevant documentation (doc comments with `///`).
- [x] I followed the [breaking change policy] and added [Data Driven Fixes] where supported.
- [ ] I listed at least one issue that this PR fixes in the description above.
- [ ] I added new tests to check the change I am making, or this PR is [test-exempt].
- [ ] All existing and new tests are passing.

If you need help, consider asking for advice on the #hackers-new channel on [Discord].

**Note**: The Flutter team is currently trialing the use of [Gemini Code Assist for GitHub](https://developers.google.com/gemini-code-assist/docs/review-github-code). Comments from the `gemini-code-assist` bot should not be taken as authoritative feedback from the Flutter team. If you find its comments useful you can update your code accordingly, but if you are unsure or disagree with the feedback, please feel free to wait for a Flutter team member's review for guidance on which automated comments should be addressed.

<!-- Links -->
[Contributor Guide]: https://github.co

[... truncated]

---

## Migration Analysis

### What Changed

A new API has been introduced that simplifies a common pattern. Users can benefit from adopting it.

### APIs Involved

- `Project`
- `gradle-wrapper.properties`
- `Introduce`
- `AbdeMohlbi`

---

## Proposed Lint Rule

**Rule Type:** `prefer_new_api`
**Estimated Difficulty:** medium

### Detection Strategy

Detect verbose/old pattern that could use the new API

**Relevant AST nodes:**
- `MethodInvocation`
- `ExpressionStatement`

### Fix Strategy

Suggest using the new, more concise API

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
