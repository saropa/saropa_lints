# Bug: Package Vibrancy falsely classifies healthy packages as "End of Life" via known_issues.json, and vibrancy scores diverge wildly from pub.dev quality metrics

**Status:** Resolved
**Date:** 2026-03-23
**Component:** VS Code extension — Package Vibrancy (known_issues.json + vibrancy-calculator.ts)
**Severity:** High — users see "End of Life" warnings for packages that pub.dev rates as healthy, eroding trust in the entire report
**Source:** User report (contacts app); verified against pub.dev score pages on 2026-03-23

---

## Summary

Two related defects in Package Vibrancy produce misleading output:

1. **False EOL via known_issues.json:** 9 packages are hardcoded as `"status": "end_of_life"` in `known_issues.json` with reasons that are factually incorrect or unverifiable. Because `classifyStatus()` applies known_issues as a hard override (line 28 of `status-classifier.ts`), these packages are forced into the "End of Life" category regardless of their actual pub.dev health.

2. **Vibrancy score / pub points disconnect:** The vibrancy formula weights GitHub activity at 90% (Resolution Velocity 50% + Engagement Level 40%) and pub.dev quality at only ~5% effective (half of the 10% Popularity weight). Packages with perfect 160/160 pub points routinely score 0-4/10 on the vibrancy scale. This makes the report's numeric scores unreliable across all categories, not just EOL.

---

## Issue 1: False End of Life Classifications in known_issues.json

### Evidence

All 9 EOL packages were verified against pub.dev on 2026-03-23. The `known_issues.json` entries' own `pubPoints` fields contradict their EOL reasons.

| Package | known_issues Reason | Pub Points (pub.dev) | Pub Points (known_issues) | Contradiction |
|---------|---------------------|---------------------|---------------------------|---------------|
| `timezone` | "Pre-null-safety; blocks Dart 3 compilation entirely." | **160/160** | 160 | Impossible — pub.dev analysis runs on Dart 3.11.1. A package that blocks Dart 3 compilation cannot score 160/160. |
| `local_auth` | "Dead standalone package; lacks modern strong biometric fallback handlers." | **160/160** | 150 | Published by `flutter.dev` (a TRUSTED_PUBLISHER). Last updated 2026-02-25 (26 days ago). Not dead. |
| `font_awesome_flutter` | "(Legacy versions) Icons render as boxes due to missing font maps." | **160/160** | — | Reason explicitly says "Legacy versions" — current v11.0.0 is not legacy. Version-specific issues should not EOL the package. |
| `animations` | "Pre-Material 3 package; page transitions lack predictive back gesture support." | **160/160** | 160 | Missing a feature != End of Life. Package passes all pub.dev quality checks perfectly. |
| `flutter_email_sender` | "File attachment intents crash due to modern FileProvider security rules." | **150/160** | — | Published v8.0.0 six months ago. 50/50 static analysis. If file intents crashed, this would be a known pub.dev issue. |
| `flutter_sticky_header` | "Completely breaks Flutter's modern sliver scroll physics; severe jank." | **150/160** | — | 989 likes, 150/160 points. "Completely breaks" is not substantiated by pub.dev analysis or widespread issue reports. |
| `flutter_rating_bar` | "Gesture math is broken on high-refresh-rate screens (120Hz+)." | **150/160** | — | 423 likes, 150/160 points. A broken gesture system would generate widespread pub.dev reports. |
| `workmanager` | "Dead repo; incompatible with modern Android WorkManager architecture." | **140/160** | — | 50/50 static analysis, 40/40 dependency support. Passes all automated compatibility checks. |
| `flutter_phone_direct_caller` | "Hardcoded to obsolete Java 8 and missing AGP namespaces; native bindings crash on Android Gradle Plugin 8+ and iOS 18." | **135/160** | — | 50/50 static analysis. If native bindings crashed, pub.dev's platform analysis would detect it. |

### Root Cause

`known_issues.json` entries with `"status": "end_of_life"` appear to be authored based on subjective assessments of package architecture or anticipated future breakage, not verified current failures. The reasons describe potential risks ("Pre-Material 3", "lacks modern fallback handlers") rather than confirmed broken states.

The `classifyStatus()` hard override at line 28 (`if (params.knownIssue?.status === 'end_of_life') { return 'end-of-life'; }`) trusts these entries unconditionally, with no validation against pub.dev's own health signals.

### Specific Contradictions

1. **`timezone` claims "blocks Dart 3 compilation entirely"** — yet pub.dev's own analysis ran on Dart 3.11.1 and awarded 160/160. This is provably false.

2. **`local_auth` claims "Dead standalone package"** — yet it's published by `flutter.dev` (in `TRUSTED_PUBLISHERS`), was updated 26 days before this report, and has 160/160 pub points. The hard EOL override bypasses the trusted-publisher promotion that `classifyStatus()` explicitly implements (line 41).

3. **`font_awesome_flutter` reason says "(Legacy versions)"** — the parenthetical acknowledges the issue is version-specific, but the EOL status applies to all versions including current v11.0.0.

4. **`animations` has `pubPoints: 160` in the known_issues.json entry itself** — the data file records perfect health alongside an EOL classification.

### Suggested Fix (Issue 1)

1. **Audit all `"status": "end_of_life"` entries** in `known_issues.json` against current pub.dev scores. Any entry where pub.dev awards >= 140/160 points should be reviewed for factual accuracy.
2. **Require verifiable evidence** for EOL entries: link to a pub.dev discontinuation notice, archived GitHub repo, or reproducible crash report with version/platform.
3. **Consider adding a `"status": "caution"` tier** for packages with legitimate architectural concerns that don't rise to "End of Life" — e.g., "missing predictive back gesture support" is a feature gap, not death.
4. **Add a consistency check** in the scan pipeline: if `known_issues.json` marks a package as EOL but pub.dev reports >= 140 pub points and up-to-date dependencies (40/40), emit a warning that the classification may be stale.

---

## Issue 2: Vibrancy Score Does Not Reflect Package Quality

### Evidence

25 packages were checked across all vibrancy categories. The correlation between vibrancy score and pub.dev points is near zero.

#### Packages with PERFECT 160/160 pub points

| Package | Vibrancy Score | Category | Days Since Update |
|---------|---------------|----------|-------------------|
| `animations` | 4/10 | End of Life | 15 |
| `font_awesome_flutter` | 4/10 | End of Life | 1 |
| `local_auth` | 4/10 | End of Life | 3 |
| `timezone` | 6/10 | End of Life | 11 |
| `colored_json` | 0/10 | Stale | 97 |
| `ripple_wave` | 0/10 | Stale | 39 |
| `drift` | 6/10 | Quiet | 0 |
| `flutter_bloc` | 8/10 | Vibrant | 34 |

#### Packages with 150/160 pub points (near-perfect)

| Package | Vibrancy Score | Category |
|---------|---------------|----------|
| `flutter_email_sender` | 3/10 | End of Life |
| `flutter_sticky_header` | 2/10 | End of Life |
| `flutter_rating_bar` | 1/10 | End of Life |
| `auto_size_text` | 1/10 | Stale |
| `decorated_icon` | 0/10 | Stale |
| `fuzzywuzzy` | 0/10 | Stale |
| `gauge_indicator` | 1/10 | Stale |
| `geocoding` | 1/10 | Stale |
| `airplane_mode_checker` | 4/10 | Quiet |
| `flutter_animate` | 3/10 | Legacy |
| `custom_refresh_indicator` | 2/10 | Legacy |
| `like_button` | 2/10 | Legacy |

#### Packages with 140/160 pub points

| Package | Vibrancy Score | Category |
|---------|---------------|----------|
| `workmanager` | 3/10 | End of Life |
| `expandable` | 0/10 | Stale |
| `visibility_detector` | 0/10 | Stale |

#### Package with 135/160 pub points

| Package | Vibrancy Score | Category |
|---------|---------------|----------|
| `flutter_phone_direct_caller` | 1/10 | End of Life |

#### Package with 120/160 pub points (lowest in sample)

| Package | Vibrancy Score | Category |
|---------|---------------|----------|
| `zxcvbn` | 0/10 | Stale |

### Root Cause

The scoring formula in `vibrancy-calculator.ts` (lines 119-140):

```
V_score = (0.5 * ResolutionVelocity) + (0.4 * EngagementLevel) + (0.1 * Popularity) + bonus - penalty
```

- **Resolution Velocity (50%):** closed issues + merged PRs in last 90 days + days since last close
- **Engagement Level (40%):** average comments per issue + recency of last GitHub/pub update
- **Popularity (10%):** pub points (normalized to 150) + GitHub stars (normalized to 5000)

**Effective weight of pub.dev quality = ~5%** (half of the 10% popularity bucket, since it's averaged with star count).

This means:
- A package with 160/160 pub points, 0 GitHub stars, and no recent GitHub activity scores: `0.5 * 0 + 0.4 * 0 + 0.1 * (100/2) = 5/100` → **0.5/10** before penalties
- A publisher penalty (no verified publisher) subtracts another 5 points → **0/10**
- A package with 0 pub points but active GitHub discussions could score higher than a 160/160 package with a quiet repo

The formula measures **maintainer responsiveness on GitHub**, not **package quality or fitness for use**. These are different things. A mature, stable package that "just works" will have low GitHub churn precisely because it doesn't need fixes.

### Suggested Fix (Issue 2)

The score should incorporate pub.dev's quality signal more meaningfully. Options:

**Option A — Increase Popularity weight:**
```
Resolution: 0.35, Engagement: 0.30, Popularity: 0.35
```
And split Popularity into `pubPoints` (normalized to 160) and `stars` with separate sub-weights, so a 160/160 package gets substantial credit even with low stars.

**Option B — Pub points floor:**
Add a minimum score floor based on pub points. E.g., a package with >= 140/160 pub points cannot score below 3/10 (30/100) regardless of GitHub activity. This prevents perfect-quality packages from appearing in the "Stale" category.

**Option C — Maturity signal:**
Detect "stable and complete" packages (high pub points + low issue count + few recent commits) and treat them as a positive signal rather than a negative one. Not every quiet repo is abandoned — some are just done.

---

## Impact

- **User trust:** The report's average score was 4/10 for 132 packages. When 160/160 packages score 0/10, users reasonably question the entire report's validity.
- **False urgency:** 9 healthy packages showing as "End of Life" creates unnecessary migration pressure and wasted engineering effort evaluating replacements.
- **Trusted publisher bypass:** `local_auth` (published by `flutter.dev`) is forced into EOL despite the codebase having explicit trusted-publisher promotion logic designed to prevent exactly this.

---

## Environment

- saropa_lints extension (VS Code)
- Test project: contacts app (`d:\src\contacts`) with 132 dependencies
- Pub.dev scores verified: 2026-03-23
- Pub.dev analysis tool versions: Pana 0.23.11, Flutter 3.41.4, Dart 3.11.1

---

## Related

- `plan/history/20260316/BUG_stale_vs_end_of_life_classification.md` — RESOLVED — added `stale` category, but did not audit `known_issues.json` entries that force EOL via hard override
