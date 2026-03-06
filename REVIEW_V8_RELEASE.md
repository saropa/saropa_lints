# Full review: v8.0.0 release (critical)

This document is a one-time review of the repository state for the v8.0.0 release (analyzer-9 rollback after retracting v7). Use it to validate before publish and to fix any remaining gaps.

---

## 1. Version and dependencies

| Item | Expected | Status |
|------|----------|--------|
| **pubspec.yaml `version`** | `8.0.0` | ✅ Set to `8.0.0` |
| **SDK constraint** | `>=3.6.0 <4.0.0` | ✅ Matches CHANGELOG (Dart 3.6+) |
| **analyzer** | `^9.0.0` | ✅ |
| **analysis_server_plugin** | `^0.3.4` | ✅ |
| **analyzer_plugin** | `^0.13.0` | ✅ |

No analyzer 10 or Dart 3.9-only deps. Flutter-compatible.

---

## 2. CHANGELOG.md

| Item | Status |
|------|--------|
| **First section** | ✅ `## [8.0.0]` — publish script will read this as latest version |
| **8.0.0 content** | ✅ Explains why v8 not v7, requirements (SDK 3.6+, analyzer 9), what’s included from 7.x, upgrade from 6.2.x and from 7.x |
| **7.0.1 / 7.0.0** | ✅ Marked `*(retracted)*` with note to use 8.0.0 |
| **Internal links** | ✅ `[7.0.1](#701)`, `[7.0.0](#700)`, `[8.0.0](#800)` (anchors may vary by renderer) |
| **[Unreleased]** | ✅ Updated: 8.0.0 is current; 7.x retracted; use ^8.0.0 |

**Note:** End of file still has legacy sections `[7.0.3]`, `[7.0.2]`, `[6.2.2]`. They do not affect `get_latest_changelog_version()` (first match is 8.0.0). Optional: remove or consolidate later.

---

## 3. No analyzer-10-only API in lib

Grep results:

- **namePart** — 0 matches in lib ✅  
- **BlockClassBody** — 0 matches in lib ✅  
- **.body.members** (on ClassBody) — 0 matches ✅  

Codebase uses analyzer-9 patterns: `ClassDeclaration.members`, `node.body` where appropriate, mixin/extension via `body.childEntities` in error_handling_rules.

---

## 4. Docs and user-facing text

| File | Change made |
|------|-------------|
| **README.md** | Flutter warning: use 8.0.0; do not use 7.x (retracted). Troubleshooting: v7 retracted; use 8.0.0 (analyzer 9). |
| **doc/guides/upgrading_to_v7.md** | Top note: 7.x retracted; use 8.0.0; same rules/fixes on analyzer 9; guide is reference only. |
| **analysis_options.yaml** | Comment: “6.3.x compatibility” → “analyzer-9 compatibility (8.0.x)”. |
| **CHANGELOG [Unreleased]** | Notice: 8.0.0 is current; 7.x retracted; use ^8.0.0. |
| **bin/init.dart** | Comment that v7 was retracted and v8 skips SDK check; error message for 7.x says “use saropa_lints 8.0.0 for Flutter”. |

---

## 5. bin/init.dart and version logic

- **v7 SDK check** (`_checkV7SdkIfNeeded`): Runs only when `packageVersion.startsWith('7.')`. For 8.0.0 it is never run. Comment added that v7 was retracted and v8 skips this.
- **v7NormalizedCount / “v7 config format”**: Variable names and messages still refer to “v7” for the lowerCaseName-style config format. Behavior is correct for v8 (normalize rule names when reading old configs). No functional change; optional later rename to something like `normalizedRuleNameCount`.

---

## 6. Publish script and version/changelog

- **get_latest_changelog_version()** uses the first `## [X.Y.Z]` in CHANGELOG → **8.0.0** ✅  
- **validate_changelog_version(project_dir, version)** will find `## [8.0.0]` when you publish 8.0.0 ✅  
- No `[Unreleased]` rename is required for this release; the section exists and is updated.

---

## 7. Other references (no change or optional)

- **VIOLATION_EXPORT_API.md** — Example `"version": "4.14.0"` is generic; no update required.  
- **bugs/UNIT_TEST_COVERAGE.md** — “§6.3” is a section number, not package version; no change.  
- **doc/guides (custom_lint, Bloc 8.0, etc.)** — Unrelated to saropa_lints 8.0.0.  
- **example/.dart_tool, example/pubspec.lock** — May still show 6.3.0 until regenerated; run `dart pub get` in example if needed.

---

## 8. Pre-publish checklist

Before running `python scripts/publish.py`:

1. **dart analyze** — Run from project root; must pass (including `--fatal-infos` if that’s your CI gate).  
2. **dart test** — All tests pass.  
3. **dart pub get** — No dependency errors.  
4. **CHANGELOG** — 8.0.0 is the first version section; [Unreleased] notice is correct.  
5. **README / upgrading_to_v7** — Point to 8.0.0 and retracted 7.x.

---

## 9. Summary of fixes applied in this review

1. **README.md** — Flutter warning and Troubleshooting updated for 8.0.0 and retracted 7.x.  
2. **doc/guides/upgrading_to_v7.md** — Top note: use 8.0.0; 7.x retracted; guide reference only.  
3. **analysis_options.yaml** — Comment updated to analyzer-9 / 8.0.x.  
4. **CHANGELOG.md** — [Unreleased] notice updated for 8.0.0 and 7.x retraction.  
5. **bin/init.dart** — Comment and v7 error message updated for retraction and 8.0.0.

No code or API changes; only version wording and docs.

---

*Review completed for v8.0.0 release. Remove or archive this file after publish if desired.*
