# Migration Candidate #032

**Source:** Flutter SDK 3.24.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** Switch

---

## Release Note Entry

> Switch to triage-* labels for platform package triage by @stuartmorgan in [149614](https://github.com/flutter/flutter/pull/149614)
>
> Context: * Bump github/codeql-action from 3.25.7 to 3.25.8 by @dependabot in [149691](https://github.com/flutter/flutter/pull/149691)

**PR:** https://github.com/flutter/flutter/pull/149614

## PR Details

**Title:** Switch to triage-* labels for platform package triage
**Author:** @stuartmorgan-g
**Status:** merged
**Labels:** autosubmit, d: docs/

### Description

Currently the ecosystem team triages all PRs in the packages repository, but the platform teams also triage all PRs with their platform label. Due to the way PRs in packages work, however, it's relatively common for a PR to not be relevant to all the teams' triages at all times. Common examples:
- One platform team may LGTM a multi-platform PR for their platform's portion, while another platform goes through review for several more weeks.
- A cross-platform PR may not have high-level design approval from the ecosystem owner, at which point platform implementation review is premature.

To avoid PRs showing up repeatedly in a platform team's triage when it's not relevant, this adjusts the triage structure:
- Queries for PRs in platform teams query `triage-<platform name>` rather than `platform-<platform name>`
- Ecosystem triage will add the `triage-<platform name>` label during triage when a PR is ready for that platform team's consideration.
- Platform teams can remove the label when it's not relevant to them (e..g, after it's been LGTM'd for that platform).

This also adds a desktop PR query, since there wasn't one, covering the separate platforms. They are separated to allow for more triage flexibility in the future.

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Switch`

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
**Generated:** From Flutter SDK v3.24.0 release notes
