# Migration Candidate #001

**Source:** Flutter SDK 3.41.0
**Category:** Replacement / Migration
**Relevance Score:** 5
**Detected APIs:** Change

---

## Release Note Entry

> [Material] Change default mouse cursor of buttons to basic arrow instead of click (except on web) by @camsim99 in [171796](https://github.com/flutter/flutter/pull/171796)
>
> Context: * Fix drawer Semantics for mismatched platforms by @huycozy in [177095](https://github.com/flutter/flutter/pull/177095)

**PR:** https://github.com/flutter/flutter/pull/171796

## PR Details

**Title:** [Material] Change default mouse cursor of buttons to basic arrow instead of click (except on web)
**Author:** @camsim99
**Status:** merged
**Labels:** a: text input, framework, f: material design, d: api docs, d: examples

### Description

Changes default mouse cursor of Material buttons to basic arrow instead of click as per updated Android guidance.

For each Material button, I did the following:

1. Changed the default mouse cursor to the basic arrow.
2. Added a way to configure the mouse cursor of the button if a method did not exist before.
3. Added a test to ensure that the default mouse cursor is now the basic arrow (or modified an existing one if applicable).
4. Added a test to ensure that the customization of button mouse cursors still works (if currently untested).

The list of Material buttons I modified (supposed to be all of them):

- RawMaterialButton
- DropdownButton
- FloatingActionButton
- ToggleButtons
- ElevatedButton
- IconButton
- FilledButton
- OutlinedButton
- PopupMenuItem
- InkWell
- TextButton
- MaterialButton
- DropdownMenuItem
- DropdownButtonFormField
- BackButton
- CloseButton
- DrawerButton
- EndDrawerButton
- PopupMenuButton
- MenuItemButton
- CheckboxMenuButton
- RadioMenuButton
- MenuBar
- SubmenuButton
- SegmentedButton
- FilterChip
- ChoiceChip
- ActionChip
- InputChip

Fixes https://github.com/flutter/flutter/issues/170296.

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Change`

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
**Generated:** From Flutter SDK v3.41.0 release notes
