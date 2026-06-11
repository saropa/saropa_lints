# Plan: new `quick_actions` lint rules

**Package:** quick_actions ^1.0.8 (Saropa Contacts). **saropa_lints coverage:** none (new file).

**API baseline (v1.0.x, verified against pub.dev docs + source):**

- `QuickActions` constructor: `const QuickActions()` — stateless, safe to construct anywhere.
- `initialize(QuickActionHandler handler) → Future<void>` — registers the cold-start + foreground callback. Must be called **before** `setShortcutItems`; the plugin cannot deliver a cold-start action until the handler is registered.
- `setShortcutItems(List<ShortcutItem> items) → Future<void>` — replaces the OS shortcut list.
- `clearShortcutItems() → Future<void>` — removes all shortcuts.
- `typedef QuickActionHandler = void Function(String type)` — `type` matches `ShortcutItem.type`.
- `ShortcutItem` constructor: `const ShortcutItem({required String type, required String localizedTitle, String? localizedSubtitle, String? icon})`.
- `ShortcutItem.icon` must be a **native** asset name (xcassets on iOS, drawable on Android), NOT a Flutter `assets/` path.
- Android: drawable icons may be tree-shaken in release builds without explicit `keep` rules in `proguard-rules.pro`.

**Primary library URI:** `package:quick_actions/quick_actions.dart`

> **VALIDATION (2026-06-11) — STRONGEST PLAN:** validation found no overlaps, tight literal guards, one valid quick fix — ship as-is. (No other per-rule changes needed.)

**Known footguns (verified):**
1. `setShortcutItems` called before `initialize` — cold-start action is silently lost because the handler channel is not yet open when the OS delivers the launch intent.
2. `setShortcutItems` called without any preceding `initialize` call — the shortcuts appear in the launcher but tapping one from cold-start does nothing.
3. `ShortcutItem.type` string that the `initialize` handler never branches on — a dead shortcut that launches the app but executes no meaningful code.
4. `ShortcutItem.localizedTitle` is blank (empty string) — the OS may suppress or mis-render the shortcut.
5. `ShortcutItem.type` is empty string — the handler callback receives `""`, which virtually no switch/if branch will match, silently ignoring the action.

---

## Proposed rules

| rule_name (snake_case) | type | detects | quick-fix? | severity | FP guard |
|---|---|---|---|---|---|
| `quick_actions_set_before_initialize` | correctness | `setShortcutItems(...)` invoked in the same function body / `initState` before `initialize(...)` is called | report-only | WARNING | only within same enclosing function/method body; skip when `initialize` is await-chained via `.then()` before `setShortcutItems` |
| `quick_actions_missing_initialize` | correctness | `setShortcutItems(...)` called on a `QuickActions` instance with no `initialize(...)` call visible in the same class | report-only | WARNING | scoped to enclosing `ClassDeclaration`; skip if `initialize` appears in any method of the same class |
| `quick_actions_empty_shortcut_type` | correctness | `ShortcutItem(type: '')` — empty-string literal for `type` | mechanical fix: replace with a non-empty placeholder | WARNING | literal string only; skip variables/expressions |
| `quick_actions_empty_localized_title` | correctness | `ShortcutItem(localizedTitle: '')` — empty-string literal for `localizedTitle` | report-only | WARNING | literal string only; skip variables/expressions |
| `quick_actions_flutter_asset_icon` | correctness | `ShortcutItem(icon: 'assets/...')` or `icon` literal starting with `assets/` — Flutter asset path passed where a native resource name is required | report-only | WARNING | literal string starting with `assets/`; skip expressions and variables |

---

## Rule detail

### `quick_actions_set_before_initialize`

- **What/why:** `QuickActions.initialize(handler)` registers the platform channel callback that delivers the cold-start action — i.e., when the OS launches the app directly from a shortcut tap, the plugin fires the `handler` with the matching `type` string. If `setShortcutItems` is called first (or without `initialize` having been awaited), the OS shortcut list is populated but the cold-start handler is not yet registered. The result is a silent no-op: the app opens from the shortcut but takes no navigational or functional action. This is the most common integration mistake shown across Flutter community articles and GitHub issues.
- **Detection (AST, type-safe):** Within a single `FunctionBody` (covering `initState`, `didChangeDependencies`, named methods), find all `MethodInvocation` nodes where:
  1. Method name is `setShortcutItems` AND the receiver's static type is `QuickActions` from `package:quick_actions/quick_actions.dart`.
  2. Method name is `initialize` on the same receiver type.
  Use source-offset ordering: if a `setShortcutItems` invocation has a lower offset than the nearest preceding `initialize` invocation on the same receiver (or there is no preceding `initialize` at all), report the `setShortcutItems` node. For `.then()` chaining (e.g., `initialize(...).then((_) => setShortcutItems(...))`), the `setShortcutItems` call will live inside a `FunctionExpression` argument to `then` on a receiver whose target is the `initialize` call — treat this as the correct order and do NOT flag it.
- **Fix:** report-only. Swapping async calls requires understanding the call-site context (whether they are independent statements or chained).
- **False positives:**
  - `initialize` called in a parent class / `super.initState()` and `setShortcutItems` in the subclass — the rule will miss the parent's `initialize`; acceptable conservative over-report.
  - `initialize` called in a provider constructor and `setShortcutItems` in the widget — cross-class patterns not detectable; suppress with `// ignore:`.
  - Calls in unrelated objects that happen to appear in the same function body with interleaved logic — narrow the receiver check to the same local variable name or field name to reduce cross-instance false positives.

---

### `quick_actions_missing_initialize`

- **What/why:** A class that calls `setShortcutItems` but never calls `initialize` has shortcuts that appear in the launcher but deliver no cold-start callback. The OS launches the app on shortcut tap, but because the handler channel was never opened, the launch action is discarded. This is a silent, hard-to-debug failure (the app opens, just to its default screen). The official package documentation states: "initialize the library early in your application's lifecycle by providing a callback."
- **Detection (AST, type-safe):** Within a `ClassDeclaration`, collect all `MethodInvocation` nodes across all methods where method name is `setShortcutItems` and the receiver static type is `QuickActions` from `package:quick_actions/quick_actions.dart`. If any are found, also scan all methods in the same class for an `initialize` invocation on a `QuickActions` receiver. If `setShortcutItems` is present but `initialize` is absent from the entire class, report each `setShortcutItems` call site.
- **Fix:** report-only. The handler body and registration site must be authored by the developer.
- **False positives:**
  - `initialize` delegated to a mixin or base class — not visible to the rule; suppress with `// ignore:`.
  - Top-level functions (not inside a class) — detection is limited to class scope; top-level usage is lower risk (typically one-off setup files) and out of scope for this rule.
  - Test files that call `setShortcutItems` to verify shortcut registration without testing the cold-start path — exclude via `ProjectContext.isTestFile(path)`.

---

### `quick_actions_empty_shortcut_type`

- **What/why:** `ShortcutItem.type` is the identifier delivered to the `QuickActionHandler` callback. An empty string `''` means the callback receives `""`, which virtually no `switch` or `if`-chain will handle, so the cold-start tap silently does nothing. The package documentation states `type` "should be unique within the app" — an empty string trivially satisfies neither uniqueness nor identifiability. This is a programmer error detectable at the construction site.
- **Detection (AST, type-safe):** Match `InstanceCreationExpression` whose constructor element belongs to class `ShortcutItem` from library URI `package:quick_actions/quick_actions.dart`. Inspect the named argument `type:`. If the argument expression is a `StringLiteral` with an empty string value (`''` or `""`), report at the argument node.
- **Fix (mechanical):** Replace the empty `type: ''` with a placeholder `type: 'action_placeholder'` — a trivially safe replacement that makes the problem visible at runtime without breaking compilation. Priority: 80.
- **False positives:** None for literal-only detection. String concatenation, variables, and `const String.fromEnvironment(...)` are not flagged.

---

### `quick_actions_empty_localized_title`

- **What/why:** `ShortcutItem.localizedTitle` is the user-visible label shown by the OS in the app-shortcut menu. An empty string causes a blank label — either the OS suppresses the shortcut or shows an unlabeled entry, both of which are UX defects. This field is `required` in the constructor, so the omission is never a compilation error; the runtime defect is silent.
- **Detection (AST, type-safe):** Match `InstanceCreationExpression` for `ShortcutItem` from `package:quick_actions/quick_actions.dart`. Inspect the named argument `localizedTitle:`. If the expression is a `StringLiteral` with an empty string value, report at the argument node.
- **Fix:** report-only. The correct title depends on the app's feature and localization strategy — no mechanical replacement is safe.
- **False positives:** None for literal-only detection. Dynamic title construction (expressions, variables, l10n getters) is not flagged.

---

### `quick_actions_flutter_asset_icon`

- **What/why:** `ShortcutItem.icon` expects a **native** asset name: an entry from `Assets.xcassets` on iOS, or a `drawable` resource name on Android. Passing a Flutter asset path (e.g., `'assets/icons/search.png'`) does not work at runtime — the OS's native shortcut renderer has no access to the Flutter asset bundle. The shortcut will display with no icon or may fail silently. The pub.dev documentation states explicitly: "Name of native resource (xcassets etc; NOT a Flutter asset)." This confusion is common for developers new to quick_actions.
- **Detection (AST, type-safe):** Match `InstanceCreationExpression` for `ShortcutItem` from `package:quick_actions/quick_actions.dart`. Inspect the named argument `icon:`. If the expression is a `StringLiteral` whose value starts with `'assets/'` (case-sensitive), report at the argument node.
- **Fix:** report-only. The correct native resource name depends on the project's native asset setup (Xcode xcassets name, Android drawable name).
- **False positives:** None for literal-only detection with the `assets/` prefix guard. Paths like `'my_icon'` (native resource names) will not match.

---

## Not lint-able (static analysis boundary)

- **Dead type string (handler never branches on a registered `type`):** Verifying that every `ShortcutItem.type` string is handled in the `initialize` callback requires cross-call-site string matching — the `type` value at the `ShortcutItem` construction site must be compared against the set of string literals in the `handler`'s `switch`/`if` branches. This is a cross-expression data-flow problem, not a local AST pattern. It would require constant-folding and branch-coverage analysis, which is outside the scope of a single-pass lint visitor. Mark as not lint-able; the correct fix is a code-review or test contract.
- **Duplicate `type` across `ShortcutItem`s in the same `setShortcutItems` call:** Detecting duplicate string literals within a list literal is cross-element and requires collecting all `type:` argument values for a single invocation. Technically feasible within a single `MethodInvocation` node but high FP risk when types are constructed from variables or constants. Deferred as speculative.
- **`initialize` not called in `initState` / called too late (e.g., after first frame):** The "early lifecycle" requirement is a runtime ordering constraint across Flutter's widget lifecycle. Statically detecting whether `initialize` is called "early enough" (before the first frame, or at least at widget mount time) requires understanding the widget lifecycle order, which is not representable as a local AST pattern.

---

## Implementation note

New file `lib/src/rules/packages/quick_actions_rules.dart`. Register all five rule classes in the `_allRuleFactories` list in `lib/saropa_lints.dart` under a `// QuickActions rules (quick_actions_rules.dart)` comment. Add all five rule names to `professionalOnlyRules` (or `comprehensiveOnlyRules`) in `lib/src/tiers.dart` — rationale: these rules are only relevant when the package is in use and require developer awareness of the plugin's initialization contract; they are not broad-correctness rules appropriate for essential/recommended tiers.

Add `static const Set<String> quickActions = {'package:quick_actions/'};` to `PackageImports` in `lib/src/import_utils.dart`. Use `fileImportsPackage(node, PackageImports.quickActions)` as the early-exit guard in every rule's `runWithReporter`.

All five rules use `SaropaLintRule` base class with:
- `impact`: `LintImpact.warning` (WARNING rules) or `LintImpact.info` (INFO rules)
- `ruleType`: `RuleType.correctness`
- `tags`: `const {'packages'}`
- `cost`: `RuleCost.low`

`quick_actions_empty_shortcut_type` is the only rule with a quick fix; implement via `SaropaFixGenerator` / `DartFix` pattern replacing the empty `type:` argument literal.

---

## Sources

- [quick_actions pub.dev](https://pub.dev/packages/quick_actions)
- [QuickActions class API docs](https://pub.dev/documentation/quick_actions/latest/quick_actions/QuickActions-class.html)
- [ShortcutItem class API docs](https://pub.dev/documentation/quick_actions/latest/quick_actions/ShortcutItem-class.html)
- [QuickActionHandler typedef](https://pub.dev/documentation/quick_actions/latest/quick_actions/QuickActionHandler.html)
- [quick_actions official example (flutter/plugins)](https://github.com/flutter/plugins/blob/main/packages/quick_actions/quick_actions/example/lib/main.dart)
- [iOS cold-start fix PR #3811](https://github.com/flutter/plugins/pull/3811)
- [iOS cold-start issue #130243](https://github.com/flutter/flutter/issues/130243)
