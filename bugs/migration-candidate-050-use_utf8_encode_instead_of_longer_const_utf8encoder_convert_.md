# Migration Candidate #050

**Source:** Flutter SDK 3.16.0
**Category:** Replacement / Migration
**Relevance Score:** 7
**Detected APIs:** Use, Utf8Encoder.convert

---

## Release Note Entry

> Use utf8.encode() instead of longer const Utf8Encoder.convert() by @mkustermann in [130567](https://github.com/flutter/flutter/pull/130567)
>
> Context: * Fix material date picker behavior when changing year by @Lexycon in [130486](https://github.com/flutter/flutter/pull/130486)

**PR:** https://github.com/flutter/flutter/pull/130567

## PR Details

**Title:** Use utf8.encode() instead of longer const Utf8Encoder.convert()
**Author:** @mkustermann
**Status:** merged
**Labels:** framework

### Description

The change in [0] has propagated now everywhere, so we can use `utf8.encode()` instead of the longer `const Utf8Encoder.convert()`.

Also it cleans up code like

```
  TypedData bytes;
  bytes.buffer.asByteData();
```

as that is not guaranteed to be correct, the correct version would be

```
  TypedData bytes;
  bytes.buffer.asByteData(bytes.offsetInBytes, bytes.lengthInBytes);
```

a shorter hand for that is:

```
  TypedData bytes;
  ByteData.sublistView(bytes);
```

[0] https://github.com/dart-lang/sdk/issues/52801

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `Use`
- `Utf8Encoder.convert`

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
**Generated:** From Flutter SDK v3.16.0 release notes
