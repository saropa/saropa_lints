# `avoid_url_launcher_simulator_tests` false positive on non-url_launcher tests

## Status: FIXED in v4.14.5

## Summary

The rule fired on any test containing a scheme string (`tel:`, `mailto:`, etc.) regardless of whether `url_launcher` was actually used, causing false positives on pure string/URI parsing tests. Additionally, `group()` matching caused 689-line diagnostic spans.

## Fix (v4.14.5, rule v3)

Three guards added to `AvoidUrlLauncherSimulatorTestsRule`:

1. **Import check**: `fileImportsPackage(node, PackageImports.urlLauncher)` — skips files that don't import `url_launcher`
2. **Launcher API check**: Body must contain `launchUrl`, `canLaunchUrl`, `launch(`, `canLaunch(`, or `url_launcher` — scheme strings alone no longer trigger
3. **Removed `group()` matching**: Only `test()` / `testWidgets()` are matched, preventing massive diagnostic spans

## Files changed

- `lib/src/rules/packages/url_launcher_rules.dart` — rule logic + doc header
- `lib/src/import_utils.dart` — added `PackageImports.urlLauncher`
- `example_packages/lib/packages/avoid_url_launcher_simulator_tests_fixture.dart` — updated fixture
- `test/url_launcher_rules_test.dart` — new test file
