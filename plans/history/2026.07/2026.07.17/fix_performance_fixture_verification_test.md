# Fix Performance Fixture Verification Test

The performance rules test's fixture-existence verification loop had two defects: one fixture file was named with a `_desktop` suffix that broke the naming convention (`require_window_close_confirmation_desktop_fixture.dart` vs the expected `require_window_close_confirmation_fixture.dart`), and eight fixture files that existed on disk were missing from the verification list, so their existence was never asserted.

## Finish Report (2026-07-17)

### Changes

- **Fixture rename:** `require_window_close_confirmation_desktop_fixture.dart` → `require_window_close_confirmation_fixture.dart` to match the `{rule_name}_fixture.dart` convention used by all other performance fixtures and enforced by the test loop.
- **8 missing entries added to the fixture verification list:** `avoid_backdrop_filter_in_scrollable`, `avoid_cache_stampede`, `avoid_clip_path_in_animated_builder`, `avoid_image_filter_in_scrollable`, `avoid_opacity_in_animated_builder`, `avoid_opacity_in_scrollable`, `avoid_shader_mask_in_scrollable`, `prefer_static_final_for_session_constant`. All eight files already existed on disk but were never included in the test's fixture list.

### Verification

`dart test test/rules/core/performance_rules_test.dart` — 107 tests passed (0 failures).

## Finish Report — Phase 2 (2026-07-17)

### Problem

The phase-1 fix added the 8 missing fixture names to a hardcoded list, but the list itself was the root vulnerability: every new fixture file required a manual list update, and omissions silently passed (the `for` loop ran zero iterations for missing entries). The same pattern exists in 128 other test files across the project.

Additionally, the handoff reflection flagged a stale `_desktop` suffix on `require_window_close_confirmation_desktop_good.dart` — the rule name `require_window_close_confirmation` has no `_desktop` segment (unlike `require_menu_bar_for_desktop`, which does).

### Changes

- **Auto-discovery replaces hardcoded list:** The 57-entry fixture name list in `performance_rules_test.dart` was replaced with a `Directory.listSync()` scan filtered to `*_fixture.dart`. New fixture files are now verified automatically with no manual maintenance.
- **Guard test added:** A `fixture directory exists and is not empty` test catches a missing or empty `example/lib/performance/` directory before the per-file loop silently passes on zero iterations.
- **Stale good-example rename:** `require_window_close_confirmation_desktop_good.dart` → `require_window_close_confirmation_good.dart`. The cross-reference comment in the fixture file was updated to match.
- **CHANGELOG:** Maintenance entry added.

### Verification

`dart test test/rules/core/performance_rules_test.dart` — 108 tests passed (0 failures). The extra test is the new directory guard.

### ~~Scope limitation~~ Resolved — Phase 3

~~128 other test files use the same hardcoded fixture list pattern and remain vulnerable to the same drift. Converting them is a mechanical but large change (129 files total) and was not requested.~~

## Finish Report — Phase 3 (2026-07-17)

### Problem

The phase-2 conversion left 128 test files still using hardcoded fixture name lists vulnerable to the same drift the performance test had. Every new fixture file required a manual list update across whichever test file owned that category, and omissions silently passed.

### Changes

- **126 test files converted to auto-discovery.** A Python migration script (`d:\tmp\migrate_fixture_tests.py`, one-shot, not committed) replaced every hardcoded fixture list and individual fixture-existence test with the `Directory.listSync()` scan pattern established in phase 2. Each converted file gains a guard test (`fixture directory exists and is not empty`) and a `for` loop that auto-discovers `*_fixture.dart` files.
- **`android_rules_test.dart` handled specially.** The auto-discovery scans `example/lib/android/`, but one fixture (`require_android_manifest_entries`) lives in `example/lib/platform/` because it covers a cross-platform concern. That fixture is verified by a separate explicit test alongside the auto-discovery loop.
- **2 files excluded.** `roadmap_15_rules_test.dart` and `migration_rules_test.dart` have fixture groups with content-validation tests beyond simple existence checks (expect_lint presence, deferred-rule exclusion), so the auto-discovery pattern does not apply.
- **`dart format` applied** to all 127 changed test files (126 converted + 1 reformatted from phase 2).

### Verification

`dart test test/` — 6774 tests passed, 1 skipped, 0 failures.

### Post-review fix

The migration script escaped `$fixture` as `\$fixture` in the Dart `test()` call string, so 125 of the 126 converted files printed the literal `$fixture fixture exists` instead of interpolating the fixture name. Tests still passed (name is cosmetic for pass/fail), but failure attribution in test output was destroyed — a failing fixture would show `$fixture` instead of the actual rule name. Fixed by removing the backslash in all 125 files.

### Remaining

The 2 excluded files (`roadmap_15_rules_test.dart`, `migration_rules_test.dart`) retain manual fixture references. Both have single fixtures at the `example/lib/` root level with no per-category subdirectory, and their tests validate fixture content, not just existence.
