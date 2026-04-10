# Migration candidate #056 — `TestWindow` / `TestWidgetsFlutterBinding.window`

**Summary:** Implemented as lint code **`avoid_deprecated_flutter_test_window`** (Recommended, WARNING). Detects SDK `TestWindow` and the deprecated `window` getter on `TestWidgetsFlutterBinding` from `package:flutter_test` using **resolved elements only** (no name-only heuristics). Predicates are shared in `lib/src/rules/config/flutter_test_window_deprecation_utils.dart` with unit tests for the `package:flutter_test` URI boundary.

**Source plan:** `plan/implementable_only_in_plugin_extension/migration-candidate-056-deprecates_testwindow_in.md` (still the canonical checklist; quick fix and `expect_lint` fixture deferred: example packages are Dart-only).

**Flutter:** [PR #122824](https://github.com/flutter/flutter/pull/122824).
