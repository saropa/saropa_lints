# Plan: Additional rules 11–20 (ROADMAP) — most useful for developers

**Source:** [ROADMAP.md — Additional rules](../../ROADMAP.md#additional-rules).  
**Order:** Sorted by developer usefulness (BLOCKER → MAJOR → MINOR; then Wow ★★★→★★→★; then Effort L→M→H).  
**Legend:** 🟢 L / 🟡 M / 🔴 H effort · ★ / ★★ / ★★★ wow

Plans are implementation guides: target file, AST/visitor, checks, acceptance criteria. Register each rule in `all_rules.dart` and assign a tier in `tiers.dart`; add ROADMAP entry and fixture only after the rule is implemented and the BAD example triggers the lint (see CONTRIBUTING.md and lint-rules skill).

---

## 1. uri_does_not_exist

| Field | Value |
|-------|--------|
| **Kind** | BUG |
| **Severity** | BLOCKER |
| **Effort** | 🔴 H |
| **Wow** | ★ |

**Summary:** Import/export/part URI refers to a non-existent file. Catches broken imports and part directives that break the build.

**Target file:** `lib/src/rules/architecture/structure_rules.dart` or `lib/src/rules/core/` (import/directive rules). May require resolving URIs and checking `ResourceProvider` or analyzer file existence.

**Approach:**
- Use `context.addImportDirective`, `context.addExportDirective`, `context.addPartDirective` (or traverse `CompilationUnit.directives`). For each directive, resolve the URI to a file path and check whether the file exists (via `resolver` or `ResourceProvider`). Report when the target file does not exist.
- Handle relative URIs and package: URIs; respect `package_config` and workspace roots. May overlap with analyzer’s own “uri_does_not_exist”; document relationship and consider tier/severity to avoid duplication.

**Acceptance criteria:**
- [ ] `import 'missing.dart';` and `part 'missing.g.dart';` with non-existent file are reported.
- [ ] Valid imports and parts are not reported.
- [ ] Rule registered, tier, ROADMAP, fixture and test when implemented.

**Quick fix:** None (user must create file or fix path). Optional: suggest correct path if similar file exists.

---

## 2. depend_on_referenced_packages

| Field | Value |
|-------|--------|
| **Kind** | CODE_SMELL |
| **Severity** | MAJOR |
| **Effort** | 🔴 H |
| **Wow** | ★★★ |

**Summary:** Imported package must be listed in pubspec.yaml dependencies. Catches missing dependencies that cause resolution or build failures.

**Target file:** `lib/src/rules/config/config_rules.dart` or a dedicated pubspec/dependency rules file. Requires reading pubspec and matching import URIs to dependency names.

**Approach:**
- Use `ProjectContext` (or pubspec parsing) to get dependency names. For each file, use `context.addImportDirective` and resolve the import URI to a package name; if it’s a package import (package:foo/...) and that package is not in pubspec dependencies, report.
- Handle SDK (dart:) and path/relative imports; only flag package: imports. Consider dev_dependencies and dependency_overrides.

**Acceptance criteria:**
- [ ] `import 'package:foo/bar.dart';` with `foo` not in pubspec is reported.
- [ ] `import 'package:foo/bar.dart';` with `foo` in pubspec is not reported.
- [ ] Rule registered, tier, ROADMAP, fixture and test when implemented.

**Quick fix:** Add dependency to pubspec (e.g. `foo: any`). Optional; may require version resolution.

---

## 3. secure_pubspec_urls

| Field | Value |
|-------|--------|
| **Kind** | CODE_SMELL |
| **Severity** | MAJOR |
| **Effort** | 🔴 H |
| **Wow** | ★★★ |

**Summary:** Use https (not http/git:) in pubspec dependency sources. Improves security and reproducibility.

**Target file:** `lib/src/rules/config/config_rules.dart` or `lib/src/rules/security/`. Requires parsing pubspec.yaml (or using analyzer/existing helpers) and inspecting dependency source URLs.

**Approach:**
- Parse pubspec (e.g. from `ProjectContext` or file read). For each dependency entry that has a `url` or `source` (git, path, etc.), check that HTTP URLs use `https://` and flag `http://` or insecure `git:` usage as configured.
- Document which schemes are allowed (https, path) vs disallowed (http, plain git without commit ref).

**Acceptance criteria:**
- [ ] Dependency with `http://` or insecure `git:` URL is reported.
- [ ] Dependency with `https://` or `path:` is not reported.
- [ ] Rule registered, tier, ROADMAP, fixture and test when implemented.

**Quick fix:** Replace `http://` with `https://` where applicable. Optional.

---

## 4. invalid_visible_outside_template_annotation

| Field | Value |
|-------|--------|
| **Kind** | CODE_SMELL |
| **Severity** | MAJOR |
| **Effort** | 🟡 M |
| **Wow** | ★ |

**Summary:** `@visibleOutsideTemplate` used incorrectly (e.g. on wrong declaration or non-concrete member). AngularDart / template-related.

**Target file:** `lib/src/rules/data/type_rules.dart` or a package-specific rules file if we add AngularDart rules. Use `ProjectContext.usesPackage('angular')` (or equivalent) to run only in relevant projects.

**Approach:**
- Use `context.addAnnotation` or traverse annotated declarations. Detect `@visibleOutsideTemplate` and verify it is applied only where the language allows (e.g. concrete instance members of certain types). Check analyzer/docs for the exact semantics.
- Only run when the project uses Angular/template packages.

**Acceptance criteria:**
- [ ] Incorrect use of `@visibleOutsideTemplate` is reported in Angular/template projects.
- [ ] Correct use and projects without the annotation are not reported.
- [ ] Rule registered, tier, ROADMAP, fixture and test when implemented.

**Quick fix:** Remove or move the annotation. Optional.

---

## 5. prefer_for_elements_to_map_fromIterable

| Field | Value |
|-------|--------|
| **Kind** | CODE_SMELL |
| **Severity** | MAJOR |
| **Effort** | 🟡 M |
| **Wow** | ★★ |

**Summary:** Prefer `Map.fromIterable` (or for-element map literal) over a more verbose pattern. Improves readability and consistency.

**Target file:** `lib/src/rules/data/collection_rules.dart` or `lib/src/rules/stylistic/stylistic_rules.dart`

**Approach:**
- Use `context.addInstanceCreationExpression` or `context.addMethodInvocation`. Detect `Map.fromIterable(...)` and/or the inverse: manual loop building a map that could be written as `Map.fromIterable` or a for-element. Report when a for-loop or repeated put could be replaced by `Map.fromIterable` or `{ for (...) ... }`.
- Define heuristics: e.g. single loop that only adds one entry per iteration with key/value derived from loop variable.

**Acceptance criteria:**
- [ ] Pattern that can be replaced by `Map.fromIterable` or for-element map is reported.
- [ ] Complex map building (multiple keys per iteration, side effects) is not reported.
- [ ] Rule registered, tier, ROADMAP, fixture and test when implemented.

**Quick fix:** Replace with `Map.fromIterable(...)` or for-element. Optional; may need to extract key/value expressions.

---

## 6. missing_code_block_language_in_doc_comment

| Field | Value |
|-------|--------|
| **Kind** | CODE_SMELL |
| **Severity** | MINOR |
| **Effort** | 🟡 M |
| **Wow** | ★★ |

**Summary:** Code block in doc comment should specify a language (e.g. ```dart) for proper highlighting and tooling.

**Target file:** `lib/src/rules/core/docs_rules.dart` or `lib/src/rules/stylistic/stylistic_rules.dart`. Use comment/doc parsing (e.g. `comment_utils.dart` or analyzer doc API).

**Approach:**
- Traverse doc comments (e.g. from `DocumentationComment` or raw comment tokens). Find fenced code blocks (```...```). If a block has no language tag (e.g. ``` with no word after), report.
- Apply to `///` and `/**` doc comments on declarations.

**Acceptance criteria:**
- [ ] ```\ncode\n``` in doc comment is reported.
- [ ] ```dart\ncode\n``` is not reported.
- [ ] Rule registered, tier, ROADMAP, fixture and test when implemented.

**Quick fix:** Add language (e.g. `dart`) to the opening fence. Optional.

---

## 7. unintended_html_in_doc_comment

| Field | Value |
|-------|--------|
| **Kind** | CODE_SMELL |
| **Severity** | MINOR |
| **Effort** | 🟡 M |
| **Wow** | ★★ |

**Summary:** Angle brackets in doc comment are interpreted as HTML; may cause unintended formatting or broken docs.

**Target file:** `lib/src/rules/core/docs_rules.dart` or `lib/src/rules/stylistic/stylistic_rules.dart`

**Approach:**
- Parse doc comment content. Look for `<...>` that is not inside a code block or known safe construct. Report when such content could be interpreted as HTML (e.g. `<type>` for generics mistaken as tags). Consider whitelisting common patterns (e.g. `<T>`, `<int, String>` in code blocks).

**Acceptance criteria:**
- [ ] Doc comment text with ambiguous `<...>` outside code blocks is reported (or only in specific contexts).
- [ ] Code blocks and escaped/safe uses are not reported.
- [ ] Rule registered, tier, ROADMAP, fixture and test when implemented.

**Quick fix:** Escape or move to code block. Optional.

---

## 8. uri_does_not_exist_in_doc_import

| Field | Value |
|-------|--------|
| **Kind** | CODE_SMELL |
| **Severity** | MINOR |
| **Effort** | 🟡 M |
| **Wow** | ★★ |

**Summary:** Doc import URI (e.g. in `@docImport`) refers to a non-existent file.

**Target file:** `lib/src/rules/core/docs_rules.dart`. Requires resolving doc import URIs and checking file existence.

**Approach:**
- Traverse doc comments for doc import directives (e.g. `@docImport` or link syntax). Resolve the URI to a path and check if the file exists. Report when the target does not exist.
- May require analyzer doc API or custom parsing of block tags.

**Acceptance criteria:**
- [ ] Doc import pointing to missing file is reported.
- [ ] Valid doc import is not reported.
- [ ] Rule registered, tier, ROADMAP, fixture and test when implemented.

**Quick fix:** Fix path or remove broken import. Optional.

---

## 9. package_names

| Field | Value |
|-------|--------|
| **Kind** | CODE_SMELL |
| **Severity** | MINOR |
| **Effort** | 🔴 H |
| **Wow** | ★★ |

**Summary:** Package names should be lowercase_with_underscores (pub.dev convention).

**Target file:** `lib/src/rules/config/config_rules.dart`. Requires reading package name from pubspec.yaml.

**Approach:**
- Parse pubspec and get the top-level `name` field. Check it matches `lowercase_with_underscores` (regex or character checks: lowercase, digits, underscores only; no leading/trailing underscore if desired).
- Report when the name does not match convention.

**Acceptance criteria:**
- [ ] `name: MyPackage` or `name: my-package` is reported.
- [ ] `name: my_package` is not reported.
- [ ] Rule registered, tier, ROADMAP, fixture and test when implemented.

**Quick fix:** Suggest corrected name (e.g. replace hyphens with underscores, lower case). Optional; user must edit pubspec.

---

## 10. sort_pub_dependencies

| Field | Value |
|-------|--------|
| **Kind** | CODE_SMELL |
| **Severity** | MINOR |
| **Effort** | 🔴 H |
| **Wow** | ★★ |

**Summary:** Sort pub dependencies A–Z in pubspec (dependencies and dev_dependencies sections).

**Target file:** `lib/src/rules/config/config_rules.dart`. Requires parsing and rewriting or comparing order in pubspec.

**Approach:**
- Parse pubspec (YAML). For `dependencies` and `dev_dependencies`, check that keys are in alphabetical order. Report when a key is out of order.
- Optionally provide a fix that reorders keys (careful with YAML formatting and comments).

**Acceptance criteria:**
- [ ] Out-of-order dependency names are reported.
- [ ] Alphabetically ordered dependencies are not reported.
- [ ] Rule registered, tier, ROADMAP, fixture and test when implemented.

**Quick fix:** Reorder keys alphabetically. Optional; preserve comments if possible.

---

## Implementation order (suggested)

1. **missing_code_block_language** (doc, clear pattern)  
2. **unintended_html_in_doc_comment** (doc)  
3. **uri_does_not_exist_in_doc_import** (doc)  
4. **prefer_for_elements_to_map_fromIterable** (collection)  
5. **invalid_visible_outside_template_annotation** (package-aware)  
6. **package_names** (pubspec parse)  
7. **sort_pub_dependencies** (pubspec parse)  
8. **secure_pubspec_urls** (pubspec + security)  
9. **depend_on_referenced_packages** (pubspec + imports)  
10. **uri_does_not_exist** (resolution + file existence)

---

## Checklist per rule (before marking done)

- [ ] Rule class in correct `*_rules.dart`.
- [ ] Registered in `lib/src/rules/all_rules.dart`.
- [ ] Tier assigned in `lib/src/tiers.dart`.
- [ ] ROADMAP.md table entry added.
- [ ] Fixture in `example/lib/` only after BAD triggers the lint; no stub fixtures.
- [ ] Unit test in `test/`; run `/test`, `/analyze`, `/format`.
- [ ] No quick fix that inserts `// ignore:` (project rule).
