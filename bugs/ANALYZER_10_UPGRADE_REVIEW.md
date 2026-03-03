# Analyzer 10 upgrade review

**Current:** analyzer ^9.0.0, analysis_server_plugin ^0.3.4, analyzer_plugin ^0.13.11  
**Target:** analyzer ^10.0.0, analysis_server_plugin ^0.3.10+ (supports analyzer 10), analyzer_plugin ^0.14.0

---

## 1. Dependency changes

| Package | Current | Target | Notes |
|---------|---------|--------|--------|
| **analyzer** | ^9.0.0 | ^10.0.0 (or ^10.2.0) | Breaking API changes below |
| **analysis_server_plugin** | ^0.3.4 | ^0.3.10 or ^0.3.11 | 0.3.10+ requires analyzer_plugin 0.14.x and analyzer 10.x |
| **analyzer_plugin** | ^0.13.11 | ^0.14.0 (e.g. 0.14.4) | 0.14.x requires analyzer 10.0.0 |

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

| Old (deprecated) | New (analyzer 10) |
|------------------|-------------------|
| `node.members` | `node.body.members` |
| `node.leftBracket` / `node.rightBracket` | `node.body.leftBracket` / `node.body.rightBracket` |
| `node.name` | `node.namePart.name` |
| `node.typeParameters` | `node.namePart.typeParameters` |
| **Enum only:** `node.constants` | `node.body.constants` |
| **ExtensionType only:** `node.primaryConstructor`, etc. | See analyzer 10 docs for `body` / name parts |

**Note:** `ListLiteral`, `SetOrMapLiteral`, `Block`, `FormalParameterList`, etc. are **not** affected; only ClassDeclaration, EnumDeclaration, ExtensionDeclaration, ExtensionTypeDeclaration.

**Impact in this repo:**

- **ClassDeclaration:** Many files use `node.members` and/or `node.name` (and a few `node.typeParameters`) in callbacks from `addClassDeclaration`. All of those must switch to `node.body.members` and `node.namePart.name` / `node.namePart.typeParameters`.
- **EnumDeclaration:** At least `lib/src/rules/stylistic/formatting_rules.dart` uses `node.constants` (and possibly `node.members`). Switch to `node.body.constants` and `node.body.members`.
- **ExtensionDeclaration / ExtensionTypeDeclaration:** Any use of `.members`, `.name`, `.typeParameters`, `.leftBracket`, `.rightBracket` on these types must use `.body` / `.namePart` as in the table above.

**Rough count of `.members` on class/enum/extension:** Dozens of call sites across:

- `class_constructor_rules.dart`, `structure_rules.dart`, `stylistic_rules.dart`, `formatting_rules.dart`, `stylistic_whitespace_constructor_rules.dart`
- `bloc_rules.dart`, `equatable_rules.dart`, `riverpod_rules.dart`, `drift_rules.dart`, `freezed_rules.dart`, `package_specific_rules.dart`, `widget_lifecycle_rules.dart`, `code_quality_variables_rules.dart`, `code_quality_avoid_rules.dart`, `disposal_rules.dart`, `lifecycle_rules.dart`, and others

**Strategy options:**

- **A) Direct migration:** Replace every `ClassDeclaration`/`EnumDeclaration`/etc. use of `.members`, `.name`, `.typeParameters`, `.constants`, `.leftBracket`, `.rightBracket` with `.body.*` and `.namePart.*`. Single analyzer version (10 only).
- **B) Compat layer:** Add small helpers (e.g. extensions or static helpers) that return `node.body.members` when `body` is available and fall back to `node.members` otherwise, so the same codebase can compile against both 9 and 10 during transition. After full migration, remove the fallback and use 10 only.

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

- If any code assumes the **parent** of `node.members[i]` or similar is exactly `node`, that may no longer hold; the parent may now be `node.body`. Update any such logic to use `node.body.members` and treat the parent as the body node where relevant.
- Search for `.parent is ClassDeclaration` (or Enum/Extension/ExtensionType) near uses of members/name/constants and ensure the new structure (body/namePart) is taken into account.

---

## 4. Files to touch (checklist)

- **pubspec.yaml** – bump analyzer, analysis_server_plugin, analyzer_plugin as above.
- **Compat / helpers (optional):** If you use strategy B, add one small file (e.g. under `lib/src/`) that exposes `getClassMembers(ClassDeclaration n)`, `getClassOrEnumName(ClassDeclaration n)`, etc., and use it everywhere instead of direct `.members`/`.name` on class/enum/extension nodes.
- **ClassDeclaration `.members` / `.name` / `.typeParameters`:**
  - Replace with `.body.members`, `.namePart.name`, `.namePart.typeParameters` in all `addClassDeclaration` (and similar) callbacks. Key files include but are not limited to:
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

| Area | Risk | Effort |
|------|------|--------|
| Dependencies | Low (versions are known) | Bump 3 lines in pubspec.yaml |
| Class/Enum/Extension AST | High (many call sites) | Medium–high (mechanical but broad) |
| isSynthetic (2 call sites) | Low | Low (confirm API and replace) |
| Parent–child assumptions | Medium | Audit only where parent is used |

**Recommendation:** Upgrade analyzer to 10 and the two plugins to their analyzer-10–compatible versions, then do a single pass replacing deprecated class/enum/extension API with `body` and `namePart`, and fix the two `isSynthetic` usages. Run analyze and tests after each logical chunk to catch regressions early.
