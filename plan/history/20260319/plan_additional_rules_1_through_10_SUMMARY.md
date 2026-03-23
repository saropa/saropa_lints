# Plan: Additional rules 1–10 — complete

**Completed:** 2025-03-19

## Summary

All 10 rules from ROADMAP “Additional rules” (first 10 rows) were implemented or confirmed:

- **1–2 (no_runtimeType_toString, use_truncating_division):** Already implemented in `stylistic_rules.dart`; no code change; kept registration and tier.
- **3. external_with_initializer:** `type_rules.dart` — `addVariableDeclarationList`, first token `external`, report variables with initializer.
- **4. illegal_enum_values:** `structure_rules.dart` — `addEnumDeclaration`, report instance members named `values`.
- **5. wrong_number_of_parameters_for_setter:** `structure_rules.dart` — `addMethodDeclaration` for setters, require exactly one required positional parameter.
- **6. duplicate_ignore:** `stylistic_rules.dart` — `addCompilationUnit`, parse `// ignore:` / `// ignore_for_file:` lines, report duplicate diagnostic names in same comment.
- **7. type_check_with_null:** `type_rules.dart` — `addIsExpression`, report when tested type is Dart `Null` (dart.core).
- **8. unnecessary_library_name:** `structure_rules.dart` — `addLibraryDirective`, report when directive has a name and no URI.
- **9. invalid_runtime_check_with_js_interop_types:** `type_rules.dart` — `addIsExpression`, run only when file/project uses JS interop; report when tested type is from dart.js_interop or package:js.
- **10. argument_must_be_native:** `type_rules.dart` — `addMethodInvocation` for `Native.addressOf`, run only when file uses dart:ffi; report when argument type is not from dart.ffi and not annotated with `@Native`.

All 8 new rules registered in `lib/saropa_lints.dart`, assigned to **comprehensive** tier in `tiers.dart`, and removed from ROADMAP “Additional rules” table. Fixtures and rule-instantiation tests added where applicable.
