# Tier and Severity Analysis

**Date:** 2026-03-01  
**Scope:** Full tier and severity review against README "The 5 Tiers" and in-code tier comments.  
**Status:** Completed — moved to `bugs/history/`. Changes applied (tiers in `lib/src/tiers.dart`, severity in rule `LintCode`s). See CHANGELOG for entries.

---

## How Tier and Severity Are Chosen

### Preferred tier

A rule's **tier** is determined by the **kind of harm** a single violation causes, not by how often it occurs or how strict the team is:

- **Essential:** One violation can cause **crashes, data loss, security breaches, or memory leaks**. If the app ships with it, something bad will happen (e.g. setState after dispose, SQL injection, missing route handler). Tooling-only or compliance-reminder issues (e.g. pubspec version format, package naming, macOS notarization reminder) are **not** Essential.
- **Recommended:** Real bugs or poor UX that may not immediately crash (e.g. performance, accessibility, error handling, form validation, state immutability best practice). Includes rules moved out of Essential when they are style/tooling/compliance rather than crash/security.
- **Professional / Comprehensive / Pedantic:** Progressively stricter on architecture, testability, optimization, and opinion; severity is mostly INFO so they don't fail analysis by default.

**No orphans:** Every rule belongs in exactly one tier set. "Orphan" rules that were previously "untiered critical/high" are either kept in Essential (crash/security) or moved to Recommended (performance/UX) with a clear comment.

### Preferred severity

**Severity** should match the impact so that `dart analyze --fatal-infos` and CI behavior are consistent with team expectations:

- **ERROR:** Violations must be fixed before release. Used for: crash prevention (e.g. missing route handler, circular redirects, setState after dispose), security (e.g. SQL injection, HTTPS only, route guards), and data loss / integrity. Ensures analysis fails when the rule fires.
- **WARNING:** Should fix; may be waived with justification. Used for memory leaks, poor UX, or correctness issues that don't always crash.
- **INFO:** Consider fixing; optional. Used for style, maintainability, and pedantic rules so they don't block CI by default.

Rules that **crash the app** or **expose data** in their problem message are assigned **ERROR** when in Essential. Security rules in the same family as existing ERROR rules (e.g. `avoid_ignoring_ssl_errors`) are aligned to **ERROR** for consistency.

### Unit tests and false positives

When changing tier or severity:

- **Tier:** No change to rule logic; existing unit tests and fixtures remain valid. Moving a rule to Essential may increase visibility (e.g. more projects enable Essential only).
- **Severity (WARNING → ERROR):** No change to when the rule fires; only diagnostic level. Existing tests that assert the rule reports a lint still pass. CI that uses `--fatal-infos` may now fail on this rule where it previously did not; document in CHANGELOG so teams can fix or suppress.
- **False-positive prevention:** Rule implementations were not modified; detection logic and suppressors (e.g. test files, generated code) are unchanged. If a rule has known false positives, they are unchanged by tier/severity reclassification.

---

## Reference: Tier and Severity Criteria (README § The 5 Tiers)

| Tier | Purpose | Severity expectation |
|------|--------|----------------------|
| **Essential** | Prevents **crashes, data loss, security breaches, memory leaks**. Single violation = real harm. | ERROR for crash/security/data loss; WARNING for memory/UX harm. |
| **Recommended** | Common bugs, performance basics, accessibility. Real problems but may not immediately crash. | WARNING or INFO. |
| **Professional** | Architecture, testability, maintainability, documentation. | Mostly INFO, some WARNING. |
| **Comprehensive** | Stricter patterns, optimization hints, edge cases. | INFO. |
| **Pedantic** | Opinionated, excessive for most teams. | INFO. |

**Severity:** ERROR = must fix; WARNING = should fix; INFO = consider fixing.

---

## 1. Wrong tier: move TO Essential (from Recommended) — APPLIED

These prevented crashes, security breaches, or data loss but were only in **recommendedOnlyRules**. Moved to **essentialRules**.

| Rule | Current tier | Rationale |
|------|--------------|-----------|
| **check_mounted_after_async** | Recommended | README explicitly lists it as an **Essential** example ("check_mounted_after_async (crash)"). Prevents "setState() called after dispose()" crash. Same class of bug as `require_mounted_check` / `require_mounted_check_after_await`, which are already Essential. |
| **avoid_drift_raw_sql_interpolation** | Recommended | SQL injection (OWASP A03:2021-Injection). Implementation is already `DiagnosticSeverity.ERROR`. Single violation can cause data exfiltration/deletion. Security-critical → Essential. |

---

## 2. Wrong tier: move OUT OF Essential (to Recommended or lower) — APPLIED

These are in **essentialRules** but do not match "crashes, data loss, security breaches, memory leaks." They are tooling correctness, compliance reminders, or style.

| Rule | Current tier | Suggested tier | Rationale |
|------|--------------|----------------|-----------|
| **prefer_semver_version** | Essential | **Recommended** | Enforces major.minor.patch in pubspec. Tooling/publish correctness, not runtime crash or security. Fits "common mistakes" / publish hygiene. |
| **prefer_correct_package_name** | Essential | **Recommended** | Library/package naming (lowercase_with_underscores). "Break pub publish, import resolution, and IDE tooling" — tooling/build, not app crash or data loss. |
| **require_macos_notarization_ready** | Essential | **Recommended** | In-code comment: "INFO - macOS distribution requirement reminder." Distribution/compliance reminder, not crash or security. Fits Recommended. |

---

## 3. Essential "orphan" block: move to Recommended — APPLIED

The **Orphan Rule Assignment (v4.1.0)** block in Essential (around lines 567–605) moved several rules into Essential. Some are performance/UX, not "single violation = crash/security/memory leak":

| Rule | Comment in tiers.dart | Suggested change |
|------|------------------------|------------------|
| **avoid_animation_rebuild_waste** | WARNING - animation performance | Consider **Recommended**. Performance/jank, not memory leak or crash. |
| **require_deep_link_fallback** | WARNING - deep link error handling | Consider **Recommended**. Error handling/UX; blank screen vs crash is borderline. |
| **require_stepper_validation** | WARNING - stepper form validation | Consider **Recommended**. Form validation prevents bad data; not always a crash. |
| **require_immutable_bloc_state** | WARNING - state immutability | Consider **Recommended**. Prevents bugs; immutability is best practice rather than "guaranteed crash." |

Keep in Essential from that block: security (e.g. avoid_deep_link_sensitive_params, avoid_path_traversal, require_data_encryption, require_secure_password_field), platform crash (avoid_platform_channel_on_web), accessibility (avoid_flashing_content), and ref/build (avoid_ref_in_build_body).

---

## 4. Severity: Essential crash rules WARNING → ERROR — APPLIED

These are in Essential and describe **unhandled exception / crash** in their problem message. Severity set to **ERROR** so they fail analysis by default.

| Rule | Current severity | Rationale |
|------|------------------|-----------|
| **require_unknown_route_handler** | WARNING | Message: "app throws an unhandled exception and **crashes**." Fits ERROR for Essential. |
| **avoid_circular_redirects** | WARNING | Message: "**crashes** the app or permanently locking users out." Fits ERROR. |
| **check_mounted_after_async** (if moved to Essential) | WARNING | Same crash as `require_mounted_check` (ERROR). Consider **ERROR** for consistency. |

---

## 5. Severity: Essential rule with INFO → WARNING — N/A (rule moved)

| Rule | Current severity | Rationale |
|------|------------------|-----------|
| **require_macos_notarization_ready** | INFO (per tier comment) | If kept in Essential, distribution requirement should be at least **WARNING** so it's not easily ignored. If moved to Recommended (as above), INFO is fine. |

---

## 6. Severity: Security rules → ERROR — APPLIED

Security rules aligned to **ERROR** for consistency with other OWASP-level rules.

| Rule | Current severity | Rationale |
|------|------------------|-----------|
| **require_https_only** | WARNING | Unencrypted traffic (OWASP M5, A05). Same family as `avoid_ignoring_ssl_errors` (ERROR). Consider **ERROR** for production HTTP. |
| **require_route_guards** | WARNING | Unauthorized access to protected routes. Consider **ERROR** for security-critical routes. |

---

## 7. Duplicate / overlapping semantics (no tier change, for awareness)

- **require_go_router_error_handler** (Recommended) and **require_go_router_fallback_route** (Recommended, INFO) — both address missing error/fallback for unknown routes. Consider documenting as a pair or clarifying difference so users don't enable both redundantly.
- **require_unknown_route_handler** (Essential, MaterialApp) vs **require_go_router_error_handler** / **require_go_router_fallback_route** (GoRouter) — different APIs; tiering is consistent (Essential for Material, Recommended for GoRouter fallback).

---

## 8. Stylistic / Pedantic

- **prefer_fail_test_case** (Stylistic): ERROR by design (test hook). No change.
- No Stylistic or Pedantic rules were found that are clearly crash/security and should move to Essential; the spot-check did not find misplaced ERROR in Pedantic/Stylistic.

---

## 9. Summary (all applied)

| Category | Count | Action taken |
|----------|--------|--------|
| Move to Essential | 2 | check_mounted_after_async, avoid_drift_raw_sql_interpolation |
| Move out of Essential | 3 | prefer_semver_version, prefer_correct_package_name, require_macos_notarization_ready → Recommended |
| Consider moving Essential → Recommended (orphan block) | 4 | avoid_animation_rebuild_waste, require_deep_link_fallback, require_stepper_validation, require_immutable_bloc_state |
| Severity WARNING → ERROR (Essential crash) | 3 | require_unknown_route_handler, avoid_circular_redirects; check_mounted_after_async (if moved to Essential) |
| Severity INFO → WARNING (if keep in Essential) | 1 | require_macos_notarization_ready |
| Severity WARNING → ERROR (security) | 2 | require_https_only, require_route_guards (consider) |

Tier changes in `lib/src/tiers.dart`; severity changes in the rule LintCodes. Rule names and rationale are recorded in CHANGELOG [Unreleased].
