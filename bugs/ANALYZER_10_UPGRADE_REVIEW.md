# Analyzer 10 upgrade review

**Current:** analyzer ^9.0.0, analysis_server_plugin ^0.3.4, analyzer_plugin ^0.13.11  
**Target:** analyzer ^10.0.0, analysis_server_plugin ^0.3.10+ (supports analyzer 10), analyzer_plugin ^0.14.0

**Release:** This upgrade is **breaking** for consumers (SDK/analyzer constraints and plugin behavior). Ship as **saropa_lints v7** (major version bump from current v6.x).

---

## 1. Dependency changes

| Package                    | Current  | Target                | Notes                                                     |
| -------------------------- | -------- | --------------------- | --------------------------------------------------------- |
| **analyzer**               | ^9.0.0   | ^10.0.0 (or ^10.2.0)  | Breaking API changes below                                |
| **analysis_server_plugin** | ^0.3.4   | ^0.3.10 or ^0.3.11    | 0.3.10+ requires analyzer_plugin 0.14.x and analyzer 10.x |
| **analyzer_plugin**        | ^0.13.11 | ^0.14.0 (e.g. 0.14.4) | 0.14.x requires analyzer 10.0.0                           |

**Action:** In `pubspec.yaml`, set:

- `analyzer: ^10.0.0` (or `^10.2.0` if you align with analysis_server_plugin 0.3.10)
- `analysis_server_plugin: ^0.3.10` (or `^0.3.11`)
- `analyzer_plugin: ^0.14.0` (or `^0.14.4`)

Then run `dart pub get` and fix any resolution conflicts.

---

## 2. Breaking / deprecated API that affects this codebase

### 2.1 Removed (not used here)

- **DiagnosticOrErrorListener** / **RecordingDiagnosticListener** / **BooleanDiagnosticListener**  
  **Status:** Not used in this project. No change.

### 2.2 ClassDeclaration / EnumDeclaration / ExtensionDeclaration / ExtensionTypeDeclaration

In analyzer 10 these nodes use a **body** and (where applicable) **namePart**:

| Old (deprecated)                                        | New (analyzer 10)                                  |
| ------------------------------------------------------- | -------------------------------------------------- |
| `node.members`                                          | `(node.body as BlockClassBody).members`                                |
| `node.leftBracket` / `node.rightBracket`                | `node.body.leftBracket` / `node.body.rightBracket` |
| `node.name`                                             | `node.namePart.typeName`                           |
| `node.typeParameters`                                   | `node.namePart.typeParameters`                     |
| **Enum only:** `node.constants`                         | `node.body.constants`                              |
| **ExtensionType only:** `node.primaryConstructor`, etc. | See analyzer 10 docs for `body` / name parts       |

**API note (analyzer 10.0.0):** `ClassDeclaration.body` is type **ClassBody** (sealed); the implementer **BlockClassBody** has `.members`, `.leftBracket`, `.rightBracket`. For normal class declarations the body is a `BlockClassBody`, so use `(node.body as BlockClassBody).members` (and brackets) unless the shared API exposes them on `ClassBody`. **ClassNamePart** (returned by `namePart`) has **`.typeName`** → **Token**, not `.name`; use `node.namePart.typeName` for `.lexeme` and `reporter.atToken(node.namePart.typeName, ...)`.

**Note:** `ListLiteral`, `SetOrMapLiteral`, `Block`, `FormalParameterList`, etc. are **not** affected; only ClassDeclaration, EnumDeclaration, ExtensionDeclaration, ExtensionTypeDeclaration.

**Impact in this repo:**

- **ClassDeclaration:** Many files use `node.members` and/or `node.name` (and a few `node.typeParameters`) in callbacks from `addClassDeclaration`. Switch to `(node.body as BlockClassBody).members` and `node.namePart.typeName` (Token) / `node.namePart.typeParameters`.
- **EnumDeclaration:** At least `lib/src/rules/stylistic/formatting_rules.dart` uses `node.constants` (and possibly `node.members`). Switch to `node.body.constants` and `node.body.members` (enum body type in analyzer 10 may differ from ClassBody; use body as in docs).
- **ExtensionDeclaration / ExtensionTypeDeclaration:** Any use of `.members`, `.name`, `.typeParameters`, `.leftBracket`, `.rightBracket` on these types must use `.body` / `.namePart` as in the table above; for name use `namePart.typeName` (Token) where the type is the same as class.

**Rough count of `.members` on class/enum/extension:** Dozens of call sites across:

- `class_constructor_rules.dart`, `structure_rules.dart`, `stylistic_rules.dart`, `formatting_rules.dart`, `stylistic_whitespace_constructor_rules.dart`
- `bloc_rules.dart`, `equatable_rules.dart`, `riverpod_rules.dart`, `drift_rules.dart`, `freezed_rules.dart`, `package_specific_rules.dart`, `widget_lifecycle_rules.dart`, `code_quality_variables_rules.dart`, `code_quality_avoid_rules.dart`, `disposal_rules.dart`, `lifecycle_rules.dart`, and others

**Strategy options:**

- **A) Direct migration:** Replace every `ClassDeclaration`/`EnumDeclaration`/etc. use of `.members`, `.name`, `.typeParameters`, `.constants`, `.leftBracket`, `.rightBracket` with `.body.*` and `.namePart.*`. Single analyzer version (10 only).
- **B) Compat layer:** Add small helpers (e.g. extensions or static helpers) that return `(node.body as BlockClassBody).members` when `body` is available and fall back to `node.members` otherwise, so the same codebase can compile against both 9 and 10 during transition. After full migration, remove the fallback and use 10 only.

Recommendation: **A** (direct migration to analyzer 10) to avoid long‑term compat branches; optionally use **B** only as a short-lived step if you want to support both versions temporarily.

### 2.3 `isSynthetic` deprecation

- **Element.isSynthetic** and related **isSynthetic** on element types are deprecated in favor of **isOriginXyz** (e.g. `isOriginDeclaration`, `isOriginImplicitDefault`).
- This project uses **isSynthetic** in two places:
  1. **`lib/src/rules/stylistic/stylistic_rules.dart`** (around line 4026): `SimpleStringLiteral.isSynthetic` — AST node, not Element. Need to confirm in analyzer 10 whether this is deprecated and what the replacement is (e.g. another AST property or “synthetic” string detection).
  2. **`lib/src/rules/core/class_constructor_rules.dart`** (around line 1760): `m.factoryKeyword?.isSynthetic` on `ConstructorDeclaration` — this is likely a token/AST property. Check analyzer 10 docs/changelog for Token or FactoryKeyword; replace with the recommended API if deprecated.

**Action:** After upgrading, run the analyzer and tests; fix any deprecation or errors at these two call sites based on the actual analyzer 10 API (and changelog for AST/token `isSynthetic`).

---

## 3. Parent–child relationship changes

Analyzer 10 changelog: *“Code relying on specific parent-child relationships for deprecated nodes in ClassDeclaration, EnumDeclaration, ExtensionDeclaration, and ExtensionTypeDeclaration may break.”*

- If any code assumes the **parent** of `node.members[i]` or similar is exactly `node`, that may no longer hold; the parent may now be `node.body`. Update any such logic to use `(node.body as BlockClassBody).members` and treat the parent as the body node where relevant.
- Search for `.parent is ClassDeclaration` (or Enum/Extension/ExtensionType) near uses of members/name/constants and ensure the new structure (body/namePart) is taken into account.

---

## 4. Files to touch (checklist)

- **pubspec.yaml** – bump analyzer, analysis_server_plugin, analyzer_plugin as above.
- **Compat / helpers (optional):** If you use strategy B, add one small file (e.g. under `lib/src/`) that exposes `getClassMembers(ClassDeclaration n)`, `getClassOrEnumName(ClassDeclaration n)`, etc., and use it everywhere instead of direct `.members`/`.name` on class/enum/extension nodes.
- **ClassDeclaration `.members` / `.name` / `.typeParameters`:**
  - Replace with `(node.body as BlockClassBody).members`, `node.namePart.typeName`, `.namePart.typeParameters` in all `addClassDeclaration` (and similar) callbacks. Key files include but are not limited to:
    - `lib/src/rules/stylistic/formatting_rules.dart` (e.g. `node.members`)
    - `lib/src/rules/stylistic/stylistic_rules.dart` (`node.name`, `node.members`)
    - `lib/src/rules/stylistic/stylistic_whitespace_constructor_rules.dart` (`node.members`)
    - `lib/src/rules/architecture/structure_rules.dart` (many `node.members`, `node.name`, `node.typeParameters`)
    - `lib/src/rules/core/class_constructor_rules.dart` (many `node.members`, plus `factoryKeyword?.isSynthetic`)
    - `lib/src/rules/packages/bloc_rules.dart`, `equatable_rules.dart`, `riverpod_rules.dart`, `drift_rules.dart`, `freezed_rules.dart`, `package_specific_rules.dart`
    - `lib/src/rules/widget/widget_lifecycle_rules.dart`, `widget_layout_constraints_rules.dart`, `widget_patterns_avoid_prefer_rules.dart`
    - `lib/src/rules/code_quality/code_quality_variables_rules.dart`, `code_quality_avoid_rules.dart`, `code_quality_prefer_rules.dart`, `code_quality_control_flow_rules.dart`
    - `lib/src/rules/architecture/disposal_rules.dart`, `lifecycle_rules.dart`, `dependency_injection_rules.dart`, `architecture_rules.dart`
    - `lib/src/rules/resources/resource_management_rules.dart`, `file_handling_rules.dart`, `memory_management_rules.dart`
    - `lib/src/rules/core/naming_style_rules.dart`, `async_rules.dart`, `performance_rules.dart`
    - `lib/src/rules/data/json_datetime_rules.dart`, `type_rules.dart`, `type_safety_rules.dart`, `money_rules.dart`
    - `lib/src/rules/config/config_rules.dart`, `media/image_rules.dart`, `network/api_network_rules.dart`, `ui/animation_rules.dart`
    - `lib/src/rules/packages/auto_route_rules.dart`, `provider_rules.dart`, `getx_rules.dart`, `hive_rules.dart`, `firebase_rules.dart`, `isar_rules.dart`, `supabase_rules.dart`, `flutter_hooks_rules.dart`
    - `lib/src/rules/flow/control_flow_rules.dart` (only where the node is ClassDeclaration/EnumDeclaration; SwitchStatement has its own `node.members`, which is unchanged)
- **EnumDeclaration:** `formatting_rules.dart` and any other file using `node.constants` or `node.members` on EnumDeclaration → use `node.body.constants` and `node.body.members`.
- **ExtensionDeclaration / ExtensionTypeDeclaration:** Same idea: `.members`, `.name`, `.typeParameters`, brackets → `.body.*` / `.namePart.*` in:
  - `lib/src/rules/core/class_constructor_rules.dart` (addExtensionTypeDeclaration)
  - `lib/src/rules/data/type_rules.dart`, `lib/src/rules/data/type_safety_rules.dart`
  - `lib/src/rules/architecture/structure_rules.dart`, `lib/src/rules/core/naming_style_rules.dart`
  - `lib/src/rules/code_quality/code_quality_avoid_rules.dart`
- **isSynthetic:** `stylistic_rules.dart` (SimpleStringLiteral), `class_constructor_rules.dart` (factoryKeyword) – adjust per analyzer 10 API/changelog.

---

## 5. Verification after upgrade

1. **Resolve:** `dart pub get`
2. **Analyze:** `dart analyze --fatal-infos` (project uses fatal-infos; fix any new errors/infos).
3. **Tests:** `dart test`
4. **Search:** For any remaining direct `.members`, `.name`, `.typeParameters`, `.constants`, `.leftBracket`, `.rightBracket` on ClassDeclaration, EnumDeclaration, ExtensionDeclaration, ExtensionTypeDeclaration and replace with `.body.*` / `.namePart.*` until the analyzer is clean.

---

## 6. Summary

| Area                       | Risk                     | Effort                             |
| -------------------------- | ------------------------ | ---------------------------------- |
| Dependencies               | Low (versions are known) | Bump 3 lines in pubspec.yaml       |
| Class/Enum/Extension AST   | High (many call sites)   | Medium–high (mechanical but broad) |
| isSynthetic (2 call sites) | Low                      | Low (confirm API and replace)      |
| Parent–child assumptions   | Medium                   | Audit only where parent is used    |

**Recommendation:** Upgrade analyzer to 10 and the two plugins to their analyzer-10–compatible versions, then do a single pass replacing deprecated class/enum/extension API with `body` and `namePart`, and fix the two `isSynthetic` usages. Run analyze and tests after each logical chunk to catch regressions early.

---

## 7. Preparatory steps (do before or alongside Phase 0)

These can be done on the **current** codebase (analyzer 9) without breaking anything. They reduce risk and make the migration day simpler.

### 7.1 Baseline and CI

- [ ] **Ensure CI is green** (e.g. main branch passes `dart analyze --fatal-infos` and `dart test`). If not, fix first so we have a clear baseline.
- [ ] **Record current resolved versions:** From `pubspec.lock`, note exact versions of `analyzer`, `analyzer_plugin`, `analysis_server_plugin` (and `_fe_analyzer_shared` if useful). Paste into this doc or a short `bugs/analyzer_10_versions_baseline.txt` so we can compare after upgrade.

### 7.2 Audit and pin the migration surface

- [ ] **List every file that must change:** Run greps and produce a single list of files that contain:
  - `addClassDeclaration` and any of `.members`, `.name`, `.typeParameters` on the callback parameter
  - `addEnumDeclaration` and any of `.constants`, `.members`, `.name`
  - `addExtensionDeclaration` / `addExtensionTypeDeclaration` and any deprecated property access
  Paste the file paths (and optionally line counts) into the doc or a checklist file. Use this as the authoritative “files to touch” list for Phases 3–5.
- [ ] **List every parent/traversal use:** Grep for `.parent is ClassDeclaration`, `.parent is EnumDeclaration`, `.parent is ExtensionDeclaration`, `.parent is ExtensionTypeDeclaration`, and any `node.parent ==` where the node could be a class member. Document file:line so Phase 6.3 is a simple checklist.

### 7.3 Look up analyzer 10 API once

- [x] **Resolve exact types for body/namePart (done):** Before touching code, check analyzer 10 API docs (e.g. pub.dev documentation for analyzer 10): types of `ClassDeclaration.body`, `ClassDeclaration.namePart`, and whether `namePart.name` is `Token` or `Identifier` (and how to get `.lexeme` / use with `atToken`). Add a 2–3 line “API note” in this doc (e.g. under section 2.2) so the migration doesn’t guess.

### 7.4 Optional: introduce a thin accessor layer (strategy B prep)

- [ ] **(Optional)** If you prefer a single switch point: add a small file (e.g. `lib/src/ast_compat.dart`) that **today** exposes helpers like `classMembers(ClassDeclaration n) => n.members`, `classNameToken(ClassDeclaration n) => n.name`, and use them in a few rule files as a trial. Once the pattern works, migrate the rest of the class/enum/extension call sites to use these helpers. When upgrading to analyzer 10, only the helper implementations change to `(n.body as BlockClassBody).members` and `n.namePart.typeName`. This is more prep work but confines the “breaking” edit to one place. Skip if you choose direct migration (strategy A).

### 7.5 Optional: capture “what to fix” without fixing

- [ ] **(Optional)** On a throwaway branch: bump only the three dependencies (and package version to 7.0.0), run `dart pub get` and `dart analyze --fatal-infos` 2>&1. Save the full analyzer output to a file (e.g. `bugs/analyzer_10_first_run.txt`). Use it as the concrete list of errors/deprecations to fix; no code changes beyond pubspec yet.

---

## 8. Detailed task list

Use this as a runbook. Complete in order; run analyze + test after each phase.

### Phase 0: Prep

- [ ] **0.1** Create a branch for the upgrade (e.g. `upgrade/analyzer-10`).
- [ ] **0.2** Run `dart analyze --fatal-infos` and `dart test` and confirm both pass (baseline).
- [ ] **0.3** (Optional) Grep and list every file that contains `addClassDeclaration`, `addEnumDeclaration`, `addExtensionDeclaration`, `addExtensionTypeDeclaration` so you have a scoped file list.

### Phase 1: Dependencies

- [ ] **1.1** In `pubspec.yaml`, bump **package version** to `7.0.0` (breaking release).
- [ ] **1.2** In `pubspec.yaml`, set `analyzer: ^10.2.0` (find latest).
- [ ] **1.3** In `pubspec.yaml`, set `analysis_server_plugin: ^0.3.11` (find latest).
- [ ] **1.4** In `pubspec.yaml`, set `analyzer_plugin: ^0.14.4` (find latest`).
- [ ] **1.5** Run `dart pub get`. Resolve any version conflicts (adjust upper bounds if needed).
- [ ] **1.6** Run `dart analyze --fatal-infos`. Note all new errors and deprecations (do not fix yet—just list them).

### Phase 2: Plugin API (if any)

- [ ] **2.1** If analyze or build fails due to `analysis_server_plugin` or `analyzer_plugin` API changes, read their changelogs and fix imports/call sites. Repeat until `dart analyze` runs (even if analyzer AST deprecations remain).

### Phase 3: ClassDeclaration migration

Only change code where the **receiver** is statically a `ClassDeclaration` (e.g. inside `addClassDeclaration((ClassDeclaration node) { ... })`). Do **not** replace `.members` / `.name` on `SwitchStatement`, `MethodDeclaration`, or other node types.

- [ ] **3.1** In each file that uses `addClassDeclaration`, replace:
  - `node.members` → `(node.body as BlockClassBody).members`
  - `node.name` → `node.namePart.typeName` (if `namePart.name` is a `Token`, keep `.lexeme` / `.offset` etc.; if it’s an `Identifier`, use its getter per API)
  - `node.typeParameters` → `node.namePart.typeParameters`
  - `node.leftBracket` / `node.rightBracket` → `(node.body as BlockClassBody).leftBracket` / `.rightBracket`
- [ ] **3.2** In the same files, replace any `classDecl.members` / `classNode.members` / `cls.members` when the variable is a `ClassDeclaration` with `(classDecl.body as BlockClassBody).members`; same for `.name` → `.namePart.typeName`, `.typeParameters` → `.namePart.typeParameters`.
- [ ] **3.3** Replace `reporter.atToken(node.name, ...)` (and similar) with `reporter.atToken(node.namePart.typeName, ...)` where `node` is `ClassDeclaration`.
- [ ] **3.4** Run `dart analyze --fatal-infos` and fix any type/API issues (e.g. add `BlockClassBody` import from `package:analyzer/dart/ast/ast.dart` if needed).
- [ ] **3.5** Run `dart test` and fix any test failures in rule tests.

**Files to touch (ClassDeclaration):** See section 4 list; prioritize `class_constructor_rules.dart`, `structure_rules.dart`, `stylistic_rules.dart`, `formatting_rules.dart`, `stylistic_whitespace_constructor_rules.dart`, then all other rule files that use `addClassDeclaration` and access `.members`/`.name`/`.typeParameters`.

### Phase 4: EnumDeclaration migration

- [ ] **4.1** In every `addEnumDeclaration` callback, replace:
  - `node.constants` → `node.body.constants`
  - `node.members` → `(node.body as BlockClassBody).members`
  - `node.name` → `node.namePart.typeName` (Token; same as ClassDeclaration)
  - `node.typeParameters` → `node.namePart.typeParameters`
- [ ] **4.2** Run `dart analyze --fatal-infos` and `dart test` for enum-related rules.

**Files to touch (EnumDeclaration):** `lib/src/rules/stylistic/formatting_rules.dart` (and any other file with `addEnumDeclaration`).

### Phase 5: ExtensionDeclaration and ExtensionTypeDeclaration migration

- [ ] **5.1** In every `addExtensionDeclaration` callback, replace `node.members`, `node.name`, `node.typeParameters`, and any bracket access with `node.body.*` and `node.namePart.*` per analyzer 10 API.
- [ ] **5.2** In every `addExtensionTypeDeclaration` callback, replace deprecated members with `body` / `namePart` (and any ExtensionType-specific replacements from the changelog, e.g. `primaryConstructor`).
- [ ] **5.3** Run `dart analyze --fatal-infos` and `dart test`.

**Files to touch:** `lib/src/rules/core/class_constructor_rules.dart`, `lib/src/rules/data/type_rules.dart`, `lib/src/rules/data/type_safety_rules.dart`, `lib/src/rules/architecture/structure_rules.dart`, `lib/src/rules/core/naming_style_rules.dart`, `lib/src/rules/code_quality/code_quality_avoid_rules.dart`, and any other file using `addExtensionDeclaration` / `addExtensionTypeDeclaration`.

### Phase 6: isSynthetic and parent–child

- [ ] **6.1** Fix `SimpleStringLiteral.isSynthetic` in `lib/src/rules/stylistic/stylistic_rules.dart`: check analyzer 10 docs/changelog for the replacement (or remove the check if the API changed).
- [ ] **6.2** Fix `ConstructorDeclaration.factoryKeyword?.isSynthetic` in `lib/src/rules/core/class_constructor_rules.dart`: use the recommended replacement (e.g. token or element API).
- [ ] **6.3** Search for `.parent is ClassDeclaration` (and Enum/Extension/ExtensionType) and any logic that assumes `member.parent == classDecl`. Update to account for `member.parent == classDecl.body` if necessary.
- [ ] **6.4** Run `dart analyze --fatal-infos` and `dart test`.

### Phase 7: Cleanup and verification

- [ ] **7.1** Search the repo for remaining direct use of `.members`, `.name`, `.typeParameters`, `.constants` on the four declaration types (only in `lib/` and `test/`). Replace any stragglers with `body`/`namePart`.
- [ ] **7.2** Run `dart analyze --fatal-infos` (must pass with zero infos).
- [ ] **7.3** Run `dart test` (all tests pass).
- [ ] **7.4** Update **CHANGELOG.md** with a `## 7.0.0` entry and a **Breaking changes** note (analyzer 10, SDK/analyzer constraints, v7 release).
- [ ] **7.5** Run `dart format` and commit with a clear message (e.g. `chore: upgrade to analyzer 10, migrate to body/namePart API (v7 breaking)`).

---

## 9. Gotchas (why it’s not “just a find-replace”)

### 9.1 No blind search-replace

**Do not** repo-wide replace `node.members` with `(node.body as BlockClassBody).members` or `node.name` with `node.namePart.typeName`.

- **SwitchStatement** has `.members` (switch members); that must stay.
- **MethodDeclaration**, **FunctionDeclaration**, etc. have `.name` (method/function name); that is unchanged.
- **ListLiteral**, **SetOrMapLiteral**, **Block** have `.leftBracket`/`.rightBracket`; those are unchanged.

Only the **four declaration kinds** (ClassDeclaration, EnumDeclaration, ExtensionDeclaration, ExtensionTypeDeclaration) use the new `body`/`namePart` API. Replace only where the **static type** of the receiver is one of those four (e.g. inside `addClassDeclaration((ClassDeclaration node) { ... })`). Wrong replacements will cause compile errors or wrong behavior.

### 9.2 namePart.typeName (not .name)

In analyzer 9, `ClassDeclaration.name` is a **Token**. In analyzer 10, `node.namePart.typeName` might be a **Token** or an **Identifier**. If it’s an `Identifier`, it may still have something like `.name` (the simple identifier) or `.lexeme`. Check the analyzer 10 API; every `node.name.lexeme` / `reporter.atToken(node.name, ...)` may need a one-line adjustment if the type differs (e.g. `node.namePart.typeName.lexeme` or `node.namePart.typeName.name`).

### 9.3 Parent–child relationship changes

The changelog says **parent–child relationships** for the deprecated nodes have changed. So:

- **member.parent** might now be the **body** node, not the class/enum/extension declaration. Any code that does `node.parent is ClassDeclaration` or `member.parent == classDecl` may break or need to consider `member.parent == classDecl.body` and then `classDecl.body.parent == classDecl`.
- Visitor or traversal logic that assumes “parent of a class member is the class” will need to account for the intermediate **body** node.

### 9.4 Fatal infos = no “fix later”

This project runs **`dart analyze --fatal-infos`**. So:

- Any **deprecation** reported as an info will **fail** analyze and CI.
- You cannot “upgrade first and fix deprecations later.” All deprecated usages must be fixed in the same upgrade (or in a single follow-up commit that’s part of the same change set).

### 9.5 analyzer_plugin and analysis_server_plugin may break too

“Easy” refers mainly to the **analyzer** AST (body/namePart). The **analyzer_plugin** (0.13 → 0.14) and **analysis_server_plugin** (0.3.4 → 0.3.10+) upgrades can have their own breaking changes (renamed methods, different callback signatures, different types). If after `dart pub get` you see errors in `lib/src/native/` or in code that uses `ChangeBuilder`, `FixKind`, or the plugin registration APIs, you’ll need to read those packages’ changelogs and adapt. That can add non-trivial work.

### 9.6 ExtensionTypeDeclaration has more deprecated surface

ExtensionTypeDeclaration deprecates not only `members`, `name`, `typeParameters`, and brackets, but also **constKeyword**, **representation**, **primaryConstructor**, etc. So ExtensionTypeDeclaration may require more than a simple body/namePart swap; check the analyzer 10 changelog for the full list and the replacement API.

### 9.7 Tests and fixtures

The **test** directory does not (from the earlier grep) use `.members` on class nodes directly, but:

- **Rule tests** that assert on diagnostics or quick fixes might behave differently if the AST shape changes (e.g. different offsets or ranges).
- **Fixtures** in `example/` or `example_*/` are analyzed by the plugin; if the analyzer’s parsing or AST changes slightly, you might see new or different diagnostics. Run the full test suite and fix any failures; a few might need expectation updates.

### 9.8 Summary table

| Gotcha                                      | Impact      | Mitigation                                                                                                                                           |
| ------------------------------------------- | ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| Blind replace breaks SwitchStatement, etc.  | High        | Only replace in addClassDeclaration / addEnumDeclaration / addExtensionDeclaration / addExtensionTypeDeclaration (or where type is one of the four). |
| namePart.name type difference               | Medium      | Check API; adjust .lexeme / atToken call sites.                                                                                                      |
| Parent–child change                         | Medium      | Audit .parent and visitor logic; use body when needed.                                                                                               |
| Fatal infos                                 | High        | Fix all deprecations before CI can pass.                                                                                                             |
| Plugin API breaks                           | Medium–High | Read plugin changelogs; fix registration and fix/assist APIs.                                                                                        |
| ExtensionTypeDeclaration extra deprecations | Low–Medium  | Use full analyzer 10 migration guide for extension types.                                                                                            |
| Test/expectation churn                      | Low         | Run tests; update expectations or fixtures if needed.                                                                                                |
