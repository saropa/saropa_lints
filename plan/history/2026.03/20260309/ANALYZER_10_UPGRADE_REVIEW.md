# Analyzer 10 Upgrade & Downgrade History

**Archived:** Both migrations complete. Kept for reference (e.g. future analyzer 11 upgrade).

**Timeline:**
- **2025-03:** Upgraded to analyzer 10 &rarr; shipped as **saropa_lints v7.0.0**
- **2025-03:** Downgraded back to analyzer 9 &rarr; shipped as **saropa_lints v8.0.0** (v7.x retracted)

**Why downgrade?** Analyzer 10+ requires `meta ^1.18.0`. The Flutter SDK pins `meta` to `1.17.0`, so the solver never picks analyzer 10+ in Flutter apps/packages. Downgrading to analyzer 9 restored compatibility without losing any v7 content (all rules and quick fixes kept).

**Status:** All analyzer 10 migration phases (0&ndash;7) were completed, then fully reverted. The AST API reference below remains useful for a future upgrade when Flutter unblocks `meta ^1.18.0`.

---

## 1. Dependency versions

| Package                    | Analyzer 9 (current, v8) | Analyzer 10 (v7, retracted) |
| -------------------------- | ------------------------ | --------------------------- |
| **analyzer**               | ^9.0.0                   | ^10.0.0 (or ^10.2.0)       |
| **analysis_server_plugin** | ^0.3.4                   | ^0.3.10                    |
| **analyzer_plugin**        | ^0.13.11                 | ^0.14.0                    |
| **SDK**                    | >=3.6.0 <4.0.0           | >=3.10.0 <4.0.0            |

**Blocker:** `analysis_server_plugin 0.3.11` requires analyzer 11; use `0.3.10` for analyzer 10.

---

## 2. Breaking API changes (analyzer 9 &rarr; 10)

### 2.1 ClassDeclaration / EnumDeclaration / ExtensionDeclaration / ExtensionTypeDeclaration

In analyzer 10 these nodes use a **body** and (where applicable) **namePart**:

| Old (analyzer 9)                                | New (analyzer 10)                                          |
| ----------------------------------------------- | ---------------------------------------------------------- |
| `node.members`                                  | `(node.body as BlockClassBody).members`                    |
| `node.leftBracket` / `node.rightBracket`        | `(node.body as BlockClassBody).leftBracket` / `.rightBracket` |
| `node.name`                                     | `node.namePart.typeName`                                   |
| `node.typeParameters`                            | `node.namePart.typeParameters`                             |
| **Enum only:** `node.constants`                 | `node.body.constants`                                      |
| **Enum only:** `node.members`                   | `node.body.members` (EnumBody, no cast needed)             |

**API notes:**
- **ClassDeclaration:** `body` is `ClassBody` (sealed); implementer `BlockClassBody` has `.members`, `.leftBracket`, `.rightBracket`. Cast required.
- **EnumDeclaration:** `body` is `EnumBody` (has `.constants`, `.members` directly). No cast needed.
- **ClassNamePart:** `namePart.typeName` returns a `Token` (not `.name`). Use for `.lexeme` and `reporter.atToken()`.
- **MixinDeclaration / ExtensionTypeDeclaration:** Still use `node.name` (no `namePart` in analyzer 10 API).

**Not affected:** `ListLiteral`, `SetOrMapLiteral`, `Block`, `FormalParameterList`, `SwitchStatement.members`, `MethodDeclaration.name`, etc.

### 2.2 `isSynthetic` deprecation

`Element.isSynthetic` deprecated in favor of `isOriginXyz` (e.g. `isOriginDeclaration`, `isOriginImplicitDefault`).

Two call sites in this repo:
1. `SimpleStringLiteral.isSynthetic` &rarr; replaced with `node.length == 0`
2. `ConstructorDeclaration.factoryKeyword?.isSynthetic` &rarr; replaced with `(m.factoryKeyword == null || m.factoryKeyword!.length == 0)`

### 2.3 Parent&ndash;child relationship changes

Members' `.parent` may now be the **body** node, not the declaration. Code using `.parent is ClassDeclaration` needs to account for the intermediate body node. Use `thisOrAncestorOfType<ClassDeclaration>()` instead.

---

## 3. Gotchas for future upgrades

### No blind search-replace

Do **not** repo-wide replace `node.members` or `node.name`. Only the **four declaration kinds** (Class, Enum, Extension, ExtensionType) use the new `body`/`namePart` API. `SwitchStatement.members`, `MethodDeclaration.name`, etc. are unchanged.

### `namePart.typeName` is a Token

Use `node.namePart.typeName` for `.lexeme` and `atToken`. There is no `.name` on `ClassNamePart`.

### Fatal infos = no "fix later"

This project runs `dart analyze --fatal-infos`. All deprecations must be fixed in the same upgrade&mdash;cannot leave them for later.

### ExtensionTypeDeclaration has extra deprecated surface

Deprecates `constKeyword`, `representation`, `primaryConstructor` in addition to `members`/`name`/`typeParameters`/brackets. Check the analyzer changelog for the full replacement API.

### Plugin packages may break independently

`analyzer_plugin` (0.13 &rarr; 0.14) and `analysis_server_plugin` (0.3.4 &rarr; 0.3.10) can have their own breaking changes beyond the analyzer AST changes.

---

## 4. Files affected (reference for future upgrade)

**Dozens of call sites** across these files used `.members`/`.name`/`.typeParameters` on Class/Enum/Extension declarations:

- `class_constructor_rules.dart`, `structure_rules.dart`, `stylistic_rules.dart`, `formatting_rules.dart`
- `bloc_rules.dart`, `equatable_rules.dart`, `riverpod_rules.dart`, `drift_rules.dart`, `freezed_rules.dart`
- `widget_lifecycle_rules.dart`, `code_quality_variables_rules.dart`, `code_quality_avoid_rules.dart`
- `disposal_rules.dart`, `lifecycle_rules.dart`, `naming_style_rules.dart`, `performance_rules.dart`
- `type_rules.dart`, `type_safety_rules.dart`, `json_datetime_rules.dart`
- And many others (see git history for v7.0.0 commits for the full list)

---

## 5. Verification checklist (for future upgrade)

1. `dart pub get`
2. `dart analyze --fatal-infos` (zero infos)
3. `dart test` (all pass)
4. Grep for remaining `.members`/`.name`/`.typeParameters`/`.constants` on the four declaration types
5. Check `.parent is ClassDeclaration` patterns

---

## 6. References

- [analyzer package](https://pub.dev/packages/analyzer) (check latest 10.x/11.x)
- [analyzer changelog](https://pub.dev/packages/analyzer/changelog)
- [analysis_server_plugin](https://pub.dev/packages/analysis_server_plugin)
- [analyzer_plugin](https://pub.dev/packages/analyzer_plugin)
- API docs: [ClassDeclaration](https://pub.dev/documentation/analyzer/10.0.0/dart_ast_ast/ClassDeclaration-class.html), [ClassNamePart](https://pub.dev/documentation/analyzer/10.0.0/dart_ast_ast/ClassNamePart-class.html), [BlockClassBody](https://pub.dev/documentation/analyzer/10.0.0/dart_ast_ast/BlockClassBody-class.html), [EnumBody](https://pub.dev/documentation/analyzer/10.0.0/dart_ast_ast/EnumBody-class.html)
