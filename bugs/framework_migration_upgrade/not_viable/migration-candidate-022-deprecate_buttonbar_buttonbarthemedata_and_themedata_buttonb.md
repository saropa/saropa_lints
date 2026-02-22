# Migration Candidate #022

**Source:** Flutter SDK 3.24.0
**Category:** Deprecation
**Relevance Score:** 7
**Detected APIs:** ButtonBar, ButtonBarThemeData, ThemeData.buttonBarTheme, Deprecate, TahaTesser

---

## Release Note Entry

> Deprecate `ButtonBar`, `ButtonBarThemeData`, and `ThemeData.buttonBarTheme` by @TahaTesser in [145523](https://github.com/flutter/flutter/pull/145523)
>
> Context: * Fix `MenuItemButton` overflow by @TahaTesser in [143932](https://github.com/flutter/flutter/pull/143932)

**PR:** https://github.com/flutter/flutter/pull/145523

## PR Details

**Title:** Deprecate `ButtonBar`, `ButtonBarThemeData`, and `ThemeData.buttonBarTheme`
**Author:** @TahaTesser
**Status:** merged
**Labels:** framework, f: material design, c: tech-debt, autosubmit

### Description

fixes [Deprecate `ButtonBar`](https://github.com/flutter/flutter/issues/127955)

### Code sample

<details>
<summary>expand to view the code sample</summary> 

```dart
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        buttonBarTheme: const ButtonBarThemeData(
          alignment: MainAxisAlignment.spaceEvenly,
        ),
      ),
      home: Scaffold(
        body: ButtonBar(
          alignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            TextButton(
              onPressed: () {},
              child: const Text('Button 1'),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('Button 2'),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('Button 3'),
            ),
          ],
        ),
      ),
    );
  }
}
```

</details>

## Data driven fix

### Before executing `dart fix --apply`
```dart
  return MaterialApp(
      theme: ThemeData(
        buttonBarTheme: const ButtonBarThemeData(
          alignment: MainAxisAlignment.spaceEvenly,
        ),
      ),
      home: Scaffold(
        body: ButtonBar(
          alignment: MainAxisAlignment.spaceEvenly,
          children: <Widget

[... truncated]

---

## Migration Analysis

### What Changed

An API has been deprecated. Users still using the old API should migrate to the recommended replacement.

### APIs Involved

- `ButtonBar`
- `ButtonBarThemeData`
- `ThemeData.buttonBarTheme`
- `Deprecate`
- `TahaTesser`

---

## Proposed Lint Rule

**Rule Type:** `deprecation_migration`
**Estimated Difficulty:** medium

### Detection Strategy

Detect usage of the deprecated API via AST method/property invocation nodes

**Relevant AST nodes:**
- `MethodInvocation`
- `PropertyAccess`
- `PrefixedIdentifier`
- `SimpleIdentifier`

### Fix Strategy

Replace with the recommended alternative API

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
