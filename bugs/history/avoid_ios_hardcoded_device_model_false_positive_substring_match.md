# Bug Report: `avoid_ios_hardcoded_device_model` — False Positive on Substring Match in Domain Names

## Diagnostic Reference

```json
[{
  "resource": "/D:/src/contacts/lib/data/website/website_host_data.dart",
  "owner": "_generated_diagnostic_collection_name_#2",
  "code": "avoid_ios_hardcoded_device_model",
  "severity": 4,
  "message": "[avoid_ios_hardcoded_device_model] Hardcoded iOS device model detected. Device-specific code breaks when new devices are released. {v2}\nUse platform APIs to detect capabilities instead of device names.",
  "source": "dart",
  "startLineNumber": 333,
  "startColumn": 5,
  "endLineNumber": 333,
  "endColumn": 22,
  "modelVersionId": 1,
  "origin": "extHost1"
}]
```

---

## Summary

The `avoid_ios_hardcoded_device_model` rule flags the string literal `'tripadvisor.com'` as a hardcoded iOS device model. The rule's regex matches the substring `iPad` (case-insensitive) within `tr**ipad**visor`, which is a website domain name — not an iOS device model reference. The regex lacks word boundary assertions, causing false positives on any string that contains `iphone`, `ipad`, or `ipod` as an incidental substring.

---

## The False Positive Scenario

### Triggering Code

`lib/data/website/website_host_data.dart` — a static list of top-level website domains:

```dart
// Lines 325-339 — website domain list (no iOS device references whatsoever)
'my.yahoo.com',
'statista.com',
'clickbank.net',
'smh.com.au',
'cnil.fr',
'playstation.com',
'plos.org',
'lin.ee',
'tripadvisor.com',    // <-- FLAGGED as iOS device model
'oracle.com',
'google.nl',
'thetimes.co.uk',
'dreamstime.com',
'rt.com',
'bing.com',
```

This file is a data table of website hostnames. There is zero iOS device logic anywhere in the file.

---

## Root Cause Analysis

The regex in `AvoidIosHardcodedDeviceModelRule` ([ios_rules.dart:3516-3519](lib/src/rules/platforms/ios_rules.dart#L3516-L3519)):

```dart
static final RegExp _deviceModelPattern = RegExp(
  r'iPhone\s*\d+|iPad\s*(Pro|Air|mini)?\s*\d*|iPod\s+touch',
  caseSensitive: false,
);
```

Breaking down the `iPad` branch: `iPad\s*(Pro|Air|mini)?\s*\d*`

- `iPad` — matches the literal characters `i`, `p`, `a`, `d` (case-insensitive)
- `\s*` — zero or more whitespace (matches zero)
- `(Pro|Air|mini)?` — optional suffix (matches nothing)
- `\s*` — zero or more whitespace (matches zero)
- `\d*` — zero or more digits (matches zero)

Since every quantifier after `iPad` allows zero matches, this branch effectively matches the bare substring `ipad` **anywhere** inside a string. With `caseSensitive: false`, it matches inside `tripadvisor`, `tripadvisor.com`, and any other word containing those four consecutive letters.

### The same issue affects `iPhone` and `iPod` branches

- `iPhone\s*\d+` — requires at least one digit after `iPhone`, so it's slightly narrower but still lacks word boundaries. A string like `'myiphone3case'` would match.
- `iPod\s+touch` — requires whitespace + `touch`, so it's less vulnerable but a string like `'myipod touch'` embedded in prose would match.

---

## Additional False Positive Examples

These strings would all be incorrectly flagged by the current regex:

| String | Match | Is It a Device Model? |
|---|---|---|
| `'tripadvisor.com'` | `ipad` in `tripadvisor` | No — website domain |
| `'tripadvisor.co.uk'` | `ipad` in `tripadvisor` | No — website domain |
| `'tripadvisor'` | `ipad` in `tripadvisor` | No — brand name |
| `'The iPad-compatible app'` | `iPad` standalone | **Yes — legitimate match** |
| `'iPad Pro 12.9'` | `iPad Pro 12` | **Yes — legitimate match** |

---

## Suggested Fixes

### Option A: Add Word Boundary Assertions (Recommended)

Add `\b` word boundary assertions to ensure `iPad`, `iPhone`, and `iPod` are matched as whole words, not substrings:

```dart
static final RegExp _deviceModelPattern = RegExp(
  r'\biPhone\s*\d+\b|\biPad\b\s*(Pro|Air|mini)?\s*\d*|\biPod\s+touch\b',
  caseSensitive: false,
);
```

This changes:
- `\biPhone\s*\d+\b` — `iPhone` must start at a word boundary
- `\biPad\b` — `iPad` must be a standalone word (not inside `tripadvisor`)
- `\biPod\s+touch\b` — `iPod` must start at a word boundary

`tripadvisor` would no longer match because `ipad` is not preceded by a word boundary (it's preceded by `tr`).

### Option B: Require Meaningful Suffix for iPad Branch

If word boundaries are too restrictive for some edge cases, require at least one meaningful token after `iPad`:

```dart
// Only match "iPad" when followed by a model indicator or digit
r'iPad\s+(Pro|Air|mini|\d)',
```

This would require `iPad Pro`, `iPad Air`, `iPad mini`, or `iPad 5` etc. — but would miss standalone `'iPad'` references, which may or may not be desirable.

### Option C: Combine Boundary + Suffix

```dart
static final RegExp _deviceModelPattern = RegExp(
  r'\biPhone\s*\d+|\biPad\b(\s+(Pro|Air|mini))?\s*\d*|\biPod\s+touch',
  caseSensitive: false,
);
```

This ensures `iPad` starts at a word boundary and ends at one (via `\b`), while still allowing optional suffixes like `Pro`, `Air`, `mini`, and model numbers.

---

## Missing Test Coverage

The current test fixture ([avoid_ios_hardcoded_device_model_fixture.dart](example_platforms/lib/platforms/avoid_ios_hardcoded_device_model_fixture.dart)) only tests:

- **BAD**: `'iPhone 14'` and `'iPhone 15'` — obvious device model strings
- **GOOD**: Using `MediaQuery` instead

There are **no negative tests** for strings that contain `iPad`/`iPhone`/`iPod` as substrings. Suggested additions:

```dart
// GOOD: Should NOT trigger avoid_ios_hardcoded_device_model
void _goodSubstringDomains() {
  // Website domains containing "ipad" as substring
  const domain1 = 'tripadvisor.com';
  const domain2 = 'tripadvisor.co.uk';

  // Brand names or compound words containing device substrings
  const name1 = 'tripadvisor';
  const name2 = 'notaniphone3case';
}

// BAD: Should trigger avoid_ios_hardcoded_device_model
// expect_lint: avoid_ios_hardcoded_device_model
void _badStandaloneIPad() {
  if (deviceModel.contains('iPad Pro')) {
    // Model-specific handling
  }
}

// expect_lint: avoid_ios_hardcoded_device_model
void _badStandaloneIPad2() {
  if (deviceModel == 'iPad Air 5') {
    // Model-specific handling
  }
}
```

---

## Patterns That Should Be Recognized as Safe

| String | Currently Flagged | Should Be Flagged |
|---|---|---|
| `'tripadvisor.com'` | **Yes** | **No** — domain name |
| `'tripadvisor'` | **Yes** | **No** — brand name |
| `'iPad Pro'` | Yes | Yes — device model |
| `'iPad Air 5'` | Yes | Yes — device model |
| `'iPad mini'` | Yes | Yes — device model |
| `'iPad'` (standalone) | Yes | Yes — device reference |
| `'iPhone 14'` | Yes | Yes — device model |
| `'iPhone 15 Pro Max'` | Yes | Yes — device model |
| `'myiphone3cover'` | **Yes** | **No** — product name |

---

## Current Workaround

Add an ignore comment on the affected line:

```dart
// ignore: avoid_ios_hardcoded_device_model
'tripadvisor.com',
```

This is undesirable because it suppresses a legitimate rule for a string that has nothing to do with iOS devices. It also adds noise to a data file that is just a list of domain names.

---

## Affected Files

| File | Line(s) | What |
|---|---|---|
| `lib/src/rules/platforms/ios_rules.dart` | 3516-3519 | `_deviceModelPattern` regex — missing word boundary `\b` assertions |
| `example_platforms/lib/platforms/avoid_ios_hardcoded_device_model_fixture.dart` | 110-123 | Test fixture — no negative tests for substring matches |

## Priority

**High** — The regex is fundamentally broken for substring containment. `tripadvisor.com` is only one example; any string containing `ipad`, `iphone`, or `ipod` as an incidental substring will be flagged. This is a common pattern in domain lists, URL strings, user agent strings, and brand name data. The fix (adding `\b` word boundary assertions) is trivial and low-risk.
