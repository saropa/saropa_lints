# IDE Troubleshooting

Deep-dive for the three most common IDE-specific reports about saropa_lints. The broader [README §Troubleshooting](../README.md#troubleshooting) covers installation and configuration; this doc covers the "I installed it correctly but the IDE isn't behaving" cases.

## 1. `custom_lint` is not running

**Symptom:** `dart analyze` shows the saropa rule codes you expect, but VS Code's Problems panel does not — or vice versa.

**Diagnostic:**

```bash
dart run custom_lint
```

Run from your project root (not from `lib/`). The output should list rule codes with the prefix shown in [`pubspec.yaml`](../pubspec.yaml). If the command exits silently or with `Could not find package "custom_lint"`, the analyzer plugin isn't wired in.

**Fix:**

1. Confirm `custom_lint` is in `dev_dependencies` in your project's `pubspec.yaml` (saropa_lints declares it as a regular dependency, but the runner is invoked via the `custom_lint` package directly).
2. Confirm `analysis_options.yaml` includes:

   ```yaml
   analyzer:
     plugins:
       - custom_lint
   ```

3. Run `dart pub get` then **Developer: Reload Window** in VS Code.

## 2. Saropa rules don't appear in the Problems panel

**Symptom:** `dart run custom_lint` from the terminal *does* show saropa rules, but the VS Code Problems panel doesn't.

**Diagnostic:**

Open **View → Output → Dart Analysis Server** (in VS Code), then save any Dart file. Watch the log for:

```text
custom_lint plugin started
```

If you don't see that line, the analyzer didn't pick up the plugin.

**Fix:**

1. Delete `.dart_tool/` and run `dart pub get` again. Stale analyzer cache is the most common cause.
2. If you have multiple analyzer plugins, the `analyzer.plugins` list is order-sensitive in some setups — put `custom_lint` first.
3. Reload the window (`Ctrl+Shift+P` → **Developer: Reload Window**). The analyzer is reset on reload but not on file save.

## 3. Quick fix doesn't appear in the lightbulb

**Symptom:** A saropa rule fires (red squiggle present, listed in Problems panel), but pressing `Ctrl+.` (or `Cmd+.`) does not show the saropa quick fix in the menu.

**Diagnostic:**

The fix producers ship inside saropa_lints itself; if the rule is registered without `fixGenerators` wired up, no lightbulb appears. To check whether a specific rule has any fix at all:

```bash
python scripts/list_rules_without_fixes.py
```

If your rule is in that list, it has no fix to offer — that's not a bug, that's missing coverage. See [`plan/QUICK_FIX_PLAN.md`](../plan/QUICK_FIX_PLAN.md) for the open list.

**Fix:**

If the rule *should* have a fix (it's not in the list above):

1. Confirm your saropa_lints version is recent (`dart pub deps | grep saropa_lints`). Quick-fix coverage grows release-to-release; older versions have fewer fixes.
2. Reload the analyzer (`Developer: Reload Window`). Quick-fix registration happens at analyzer startup.
3. If `dart fix --apply` *does* apply the fix from the terminal but the lightbulb stays empty, the IDE-side caching is stale — delete `.dart_tool/` and reload.

## Still stuck

Open an [issue](https://github.com/saropa/saropa_lints/issues/new) with:

- Output of `dart --version` and `flutter --version` (if Flutter).
- Output of `dart pub deps | grep -E "(saropa|custom_lint|analyzer)"`.
- Contents of your `analysis_options.yaml`.
- The Dart Analysis Server log around the relevant save (View → Output).
