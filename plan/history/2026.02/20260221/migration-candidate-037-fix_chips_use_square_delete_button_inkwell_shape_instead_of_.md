# Migration Candidate #037

**Source:** Flutter SDK 3.22.0
**Category:** Replacement / Migration
**Relevance Score:** 6
**Detected APIs:** InkWell, Fix, TahaTesser

---

## Release Note Entry

> Fix chips use square delete button `InkWell` shape instead of circular by @TahaTesser in [144319](https://github.com/flutter/flutter/pull/144319)
>
> Context: * Fix `CalendarDatePicker` day selection shape and overlay by @TahaTesser in [144317](https://github.com/flutter/flutter/pull/144317)

**PR:** https://github.com/flutter/flutter/pull/144319

## PR Details

**Title:** Fix chips use square delete button `InkWell` shape instead of circular
**Author:** @TahaTesser
**Status:** merged
**Labels:** framework, f: material design, will affect goldens, autosubmit

### Description

fixes [Chips delete button hover style is square, not circular](https://github.com/flutter/flutter/issues/141335)

### Code sample

<details>
<summary>expand to view the code sample</summary> 

```dart
import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: RawChip(
            label: const Text('Test'),
            onPressed: null,
            deleteIcon: const Icon(Icons.clear, size: 18),
            onDeleted: () {},
          ),
        ),
      ),
    );
  }
}
```

</details>

### Preview

| Before | After |
| --------------- | --------------- |
| <img src="https://github.com/flutter/flutter/assets/48603081/c5d62c57-97b3-4f94-b83d-df13559ee3a8" /> | <img src="https://github.com/flutter/flutter/assets/48603081/b76edaab-73e0-4aa9-8ca2-127eedd77814"  /> |

## Pre-launch Checklist

- [x] I read the [Contributor Guide] and followed the process outlined there for submitting PRs.
- [x] I read the [Tree Hygiene] wiki page, which explains my responsibilities.
- [x] I read and followed the [Flutter Style Guide], including [Features we expect every widget to implement].
- [x] I signed the [CLA].
- [x] I listed at least one issue that this PR fixes in the description above.
- [ ] I updated/added relevant documentation (doc comments with `///`).

[... truncated]

---

## Migration Analysis

### What Changed

A better pattern or API is now available. The old approach still works but the new one is preferred.

### APIs Involved

- `InkWell`
- `Fix`
- `TahaTesser`

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
**Generated:** From Flutter SDK v3.22.0 release notes
