# BUG: `avoid_missing_enum_constant_in_map` — Flags every enum-keyed map literal that omits constants, including lookup maps where absence means no mapping

**Status: Open**

Created: 2026-10-31
Rule: `avoid_missing_enum_constant_in_map`
File: `lib/src/rules/code_quality/code_quality_variables_rules.dart` (line ~178)
Severity: False positive
Rule version: unknown | Since: unknown | Updated: unknown

---

## Summary

Flags every enum-keyed map literal that omits constants, including lookup maps where absence means no mapping. In a downstream app review, 11 of 11 reported sites for this rule were judged false positives.

---

## Attribution Evidence

```bash
grep -rn "'avoid_missing_enum_constant_in_map'" lib/src/rules/
# lib/src/rules/code_quality/code_quality_variables_rules.dart:178:    'avoid_missing_enum_constant_in_map',
```

**Emitter registration:** `lib/src/rules/code_quality/code_quality_variables_rules.dart:178`
**Diagnostic `source` as seen in Problems panel:** `saropa_lints`
Negative sibling-repo grep: not needed, the label is unambiguous.

---

## Reproducer

```dart
const Map<SocialMediaHostTypes, HomeVoiceAction> kMessagingHosts = <SocialMediaHostTypes, HomeVoiceAction>{ // LINT — but should NOT lint
  SocialMediaHostTypes.whatsapp: HomeVoiceAction.whatsApp,
  SocialMediaHostTypes.telegram: HomeVoiceAction.telegram,
};
// Consumer: kMessagingHosts[host] — null means "not a messaging host".
```

**Real sites reviewed (Saropa Contacts app):** lib/utils/speech/contact/home_voice_keywords.dart:15; lib/utils/language/pronunciation/name_pronunciation_latin_registry.dart:20 (language to table registry, Latin script never picks itself); name_pronunciation_pt_table.dart:26; contact_issue_phone_url_predicates.dart:93; voice_lexicon.dart:151.

**Frequency:** Always, for the pattern shown.

---

## Expected vs Actual

| | Behavior |
|---|---|
| **Expected** | No diagnostic: the code is correct |
| **Actual** | `[avoid_missing_enum_constant_in_map]` reported at each site above |

---

## Root Cause

A map typed with an enum key is not a total mapping. When every read uses `map[key]` and handles null (or `?? default`), a partial map is the correct design. The rule has no way to opt out and no signal to detect null-handled reads.

---

## Suggested Fix

Report only when a `map[key]!` bang read or an exhaustive-switch conversion is found for the map, or only for `const` maps named like `*ToLabel`. Optionally accept a `// partial` marker comment.

---

## Fixture Gap

The fixture for `avoid_missing_enum_constant_in_map` should add an expect-NO-lint case for each pattern in the reproducer, plus a near-miss expect-LINT case where the guard is missing.

---

## Environment

- saropa_lints version: current at time of filing (consumer: Saropa Contacts app)
- Dart SDK version: current stable

---

## Info needed to close

Outcome: not fixed. The rule decides from the map literal alone; the reads (`map[key]`, `?? default`, `!`) are in other files, so null-safety of reads is not detectable. This is the third report of the same pattern; the previous two were closed with the `// ignore:` escape hatch documented in the rule's doc comment (see plans/history/2026.06/2026.06.03/ and 2026.06.09/ reports). Missing to proceed:

1. Owner decision on one detectable signal, since read sites cannot be seen. Options: (a) a `// partial` marker comment opt-out (new feature), (b) skip `const` maps (would hide true positives), (c) keep `// ignore:` only. Report suggests (a) but it duplicates `// ignore:`.
2. If a same-file heuristic is wanted: a minimal reproducer where the map and its reads are in the SAME file. The 5 reported sites have reads in other files and cannot be told apart from true positives.
3. Rule version / saropa_lints version in use (reported as "unknown").

## Owner decision

Owner has not yet chosen between ignore comments, a `// partial` marker, or skipping const maps.
Owner asked why a marker is not a duplicate of `// ignore` (a marker the rule honors would differ only if it also documents intent).

## Closed (2026-10-31)

Owner decision: keep `// ignore:` only. A `// partial` marker would behave the same as `// ignore:` (it only documents intent), so no marker and no const-map skip. No code change; consistent with the 2026.06.03 and 2026.06.09 closures. Closed as won't-fix.
