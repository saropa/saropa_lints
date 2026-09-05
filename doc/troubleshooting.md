# Troubleshooting

<!--
  Originally an IDE-only deep dive (sections 0-3). Sections 4-10 were merged
  in from README.md's "Troubleshooting" section so all troubleshooting
  content lives in one place instead of being split/duplicated across the
  README and this doc. The README's own Troubleshooting section should link
  here rather than repeat this content.
-->

Deep-dive for the most common reports about saropa_lints: IDE-specific integration issues (sections 0-3), install/config/version problems (sections 4-8), and runtime crashes (sections 9-10). See [doc/faq.md](faq.md) for general questions not tied to a specific error.

## 0. Native analyzer plugin (`saropa_lints` under `analyzer.plugins`)

**Current setups** use VS Code plus the **`saropa_lints`** entry from your project’s **`analysis_options.yaml`** (typically added by **Set Up Project**). You do **not** need separate `plugins: custom_lint` wiring for saropa diagnostics to run in Problems or in `dart analyze` when native plugin bootstrap succeeds.

When things look broken:

1. Run **`dart pub get`** at the workspace root **and** in any Flutter/Dart packages you analyze.
2. Open **Output → Dart Analysis Server** after saving a Dart file — look for **`saropa_lints`** analyzer plugin lifecycle lines (startup errors show here first).
3. **Developer: Reload Window** once after changing **`analysis_options.yaml`** or **`pubspec.yaml`** so the analyzer reconnects cleanly.

Older guides that only mention **`custom_lint`** refer to legacy integration; skip them unless your project intentionally still opts into that runner.

## 1. `custom_lint` is not running (legacy / optional runner)

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

If your rule is in that list, it has no fix to offer — that's not a bug, that's missing coverage. The open list is tracked internally in the project's planning docs (not shipped with the package).

**Fix:**

If the rule *should* have a fix (it's not in the list above):

1. Confirm your saropa_lints version is recent (`dart pub deps | grep saropa_lints`). Quick-fix coverage grows release-to-release; older versions have fewer fixes.
2. Reload the analyzer (`Developer: Reload Window`). Quick-fix registration happens at analyzer startup.
3. If `dart fix --apply` *does* apply the fix from the terminal but the lightbulb stays empty, the IDE-side caching is stale — delete `.dart_tool/` and reload.

## 4. Can't use saropa_lints v7 in my Flutter project

<!-- v7 was retracted from pub.dev; this is the single most-asked "why won't it install" report, so it gets its own numbered section instead of being buried in the FAQ. -->

**v7 was retracted.** It required **analyzer 10** (and **meta ^1.18.0**); the Flutter SDK pins **meta** to **1.17.0**, so 7.x could not run in Flutter projects. Use **saropa_lints 8.0.0**, which keeps all 7.x rule fixes and stays on **analyzer 9** for Flutter compatibility. See [CHANGELOG](../CHANGELOG.md#800) for context.

## 5. I'm new and completely lost

<!-- Minimal happy-path checklist for a first-time install, kept separate from the deep-dive sections above so a brand-new user isn't handed native-plugin internals before they've even run `dart pub get`. -->

**Start here:**

1. **Install**: Add to your `pubspec.yaml` dev_dependencies:

   ```yaml
   dev_dependencies:
     saropa_lints: ^10.0.0
   ```

2. **Configure**: Add to your `analysis_options.yaml`:

   ```yaml
   include: package:saropa_lints/tiers/recommended.yaml
   ```

3. **Get dependencies**:

   ```bash
   dart pub get
   ```

4. **Reload VS Code**:
   - Press `Ctrl+Shift+P`
   - Type "reload"
   - Click "Developer: Reload Window"

5. **Check**: Look at the PROBLEMS panel (View → Problems), or run `dart analyze`

**Still not working?** See the numbered sections above and below.

## 6. IDE doesn't show lint warnings (quick fix)

<!-- Fast-path steps that resolve the majority of reports before a reader needs the deeper native-plugin / custom_lint diagnostics in sections 0-2 above. -->

**Quick Fix (works 90% of the time):**

1. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
2. Type "reload"
3. Click "Developer: Reload Window"
4. Wait for analysis to complete

**If that doesn't work:**

1. Clear the cache: Delete the `.dart_tool` folder and run `dart pub get`
2. Reload VS Code again (steps above)
3. Check **View → Output → Dart Analysis Server** for errors
4. Verify configuration is correct (see "Configuration not working" below)

**Alternative (command line):**

Run `dart analyze` in your terminal to see all issues immediately.

## 7. Configuration not working (not enough rules loading)

<!-- The "include: package:saropa_lints/tiers/..." shorthand can silently resolve to fewer rules than expected in some analyzer setups; the init CLI sidesteps that by writing every rule explicitly. -->

**Problem:** You only get a few rules instead of the full set for your chosen tier.

**Solution:** Use the CLI tool to generate explicit configuration:

```bash
# Generate config for comprehensive tier
dart run saropa_lints:init --tier comprehensive

# Or for all rules (pedantic tier)
dart run saropa_lints:init --tier pedantic
```

This generates `analysis_options.yaml` with explicit `rule_name: true` for every enabled rule.

**Verify it worked:** Run `dart analyze` and check the output.

## 8. Too many warnings! What do I do?

<!-- First-install shock is expected on any non-trivial codebase; these four options are ordered roughly by effort (smallest change first) so a reader can stop as soon as one works. -->

**This is normal** when first installing. You'll see hundreds or thousands of warnings.

**Option 1: Start smaller** (recommended for existing projects)

```bash
# Start with essential tier (~310 critical rules)
dart run saropa_lints:init --tier essential
```

**Option 2: Use baseline** (for brownfield projects)

Generate a baseline to suppress existing issues and only catch new violations:

```bash
dart run saropa_lints:baseline
```

**Option 3: Disable noisy rules**

Edit your `analysis_options.yaml` and set specific rules to `false`:

```yaml
plugins:
  saropa_lints:
    diagnostics:
      prefer_double_quotes: false # disabled
      prefer_trailing_comma_always: false
      no_magic_number: false
```

**Option 4: Use quick fixes**

Many rules have automatic fixes:

- Hover over the warning
- Click "Quick Fix" or press `Ctrl+.`
- Select "Fix all in file" to fix all instances at once
- Or run `dart fix --apply` from the command line

**Don't stress about fixing everything immediately.** Pick one category (like accessibility or memory leaks) and fix those first.

## 9. Out of Memory errors

<!-- Distinct from the native-crash section below: OOM surfaces as a Dart VM zone allocation error, not a process crash code, and has its own three-step remedy ladder. -->

If you see errors like:

```
../../runtime/vm/zone.cc: 96: error: Out of memory.
```

**Solution 1: Clear the pub cache** (most effective)

```bash
dart pub cache clean
dart pub get
```

**Solution 2: Increase Dart heap size** (PowerShell)

```powershell
$env:DART_VM_OPTIONS="--old_gen_heap_size=4096"
dart analyze
```

**Solution 3: Delete local build artifacts**

```bash
# Windows
rmdir /s /q .dart_tool && dart pub get

# macOS/Linux
rm -rf .dart_tool && dart pub get
```

## 10. Native crashes (Windows)

<!-- Windows-specific analyzer-server crash (distinct exit code) that a plain "reload window" does not fix; requires clearing .dart_tool so the native plugin is rebuilt clean. -->

If you see native crashes with error codes like `ExceptionCode=-1073741819`:

```bash
# Windows
rmdir /s /q .dart_tool && flutter pub get

# macOS/Linux
rm -rf .dart_tool && flutter pub get
```

Then run `dart analyze` again.

## Still stuck

Open an [issue](https://github.com/saropa/saropa_lints/issues/new) with:

- Output of `dart --version` and `flutter --version` (if Flutter).
- Output of `dart pub deps | grep -E "(saropa|custom_lint|analyzer)"`.
- Contents of your `analysis_options.yaml`.
- The Dart Analysis Server log around the relevant save (View → Output).

## Frequently Asked Questions

See [doc/faq.md](faq.md).
