# Migration Candidate #053

**Source:** Flutter SDK 3.13.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** flutter channel, Give, Hixie

---

## Release Note Entry

> Give channel descriptions in `flutter channel`, use branch instead of upstream for channel name by @Hixie in [126936](https://github.com/flutter/flutter/pull/126936)
>
> Context: * Revert "Replace rsync when unzipping artifacts on a Mac (#126703)" by @vashworth in [127430](https://github.com/flutter/flutter/pull/127430)

**PR:** https://github.com/flutter/flutter/pull/126936

## PR Details

**Title:** Give channel descriptions in `flutter channel`, use branch instead of upstream for channel name
**Author:** @Hixie
**Status:** merged
**Labels:** tool, autosubmit

### Description

## How we determine the channel name

Historically, we used the current branch's upstream to figure out the current channel name. I have no idea why. I traced it back to https://github.com/flutter/flutter/pull/446/files where @abarth implement this and I reviewed that PR and left no comment on it at the time.

I think this is confusing. You can be on a branch and it tells you that your channel is different. That seems weird.

This PR changes the logic to uses the current branch as the channel name.

## How we display channels

The main reason this PR exists is to add channel descriptions to the `flutter channel` list:

```
ianh@burmese:~/dev/flutter/packages/flutter_tools$ flutter channel
Flutter channels:
  master (tip of tree, for contributors)
  main (tip of tree, follows master channel)
  beta (updated monthly, recommended for experienced users)
  stable (updated quarterly, for new users and for production app releases)
* foo_bar

Currently not on an official channel.
ianh@burmese:~/dev/flutter/packages/flutter_tools$
```

## Other changes

I made a few other changes while I was at it:

* If you're not on an official channel, we used to imply `--show-all`, but now we don't, we just show the official channels plus yours. This avoids flooding the screen in the case the user is on a weird channel and just wants to know what channel they're on.
* I made the tool more consistent about how it handles unofficial branches. Now it's always `[user bran

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `flutter channel`
- `Give`
- `Hixie`

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
**Generated:** From Flutter SDK v3.13.0 release notes
