# Bug: `avoid_uncaught_future_errors` crashes on enum declarations (Dart 3.11)

**Status:** RESOLVED
**Rule:** `avoid_uncaught_future_errors`
**Severity:** Crash — killed the entire analyzer plugin (exit code 4)
**saropa_lints version:** 8.0.9
**Fixed in:** 8.0.10+

---

## Summary

`_collectFunctionsWithTryCatch` accessed `.body` on declaration nodes. In
Dart SDK 3.11, `EnumDeclarationImpl.body` was gated behind
`useDeclaringConstructorsAst = true`, throwing `UnsupportedError` and
crashing the entire analyzer plugin.

## Root cause

The `MixinDeclaration` branch used `.body.childEntities` and the
`ExtensionDeclaration` branch used `.body`. In SDK 3.11, `EnumDeclaration`
began matching the `is MixinDeclaration` type check via a shared
supertype, so enums hit the mixin branch and called
`EnumDeclarationImpl.body`, which threw.

## Fix applied

- Replaced all `.body` / `.body.childEntities` access with `.members`
  across all declaration types (class, enum, mixin, extension,
  extension type).
- Extracted shared member-scanning logic into `_addMethodsWithTryCatch`
  to eliminate duplication.
- Used a `switch` expression for type dispatch instead of if-else chain.
- Added `ExtensionTypeDeclaration` handling (previously missing).
- Added integration test verifying enums do not crash the analyzer.
