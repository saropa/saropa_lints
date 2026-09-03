# PROPOSAL: Require Di Module Separation

**Status: Open**

Created: 2026-09-02

## Summary

Flags a dependency-injection setup where all registrations for a growing app are declared in a single module/file instead of being split into per-feature DI modules.

## Existing Coverage

`lib/src/rules/architecture/dependency_injection_rules.dart` already contains many single-file DI rules (`RequireTypedDiRegistrationRule`, `PreferLazySingletonRegistrationRule`, `RequireDiScopeAwarenessRule`, and others) that check individual registration statements. None of them count or group registrations across the whole DI setup — that project-wide view is what module separation requires.

## Motivation

A monolithic `injection.dart`/`locator.dart` with hundreds of registrations becomes a merge-conflict magnet, obscures which feature owns which dependency, and makes it hard to lazy-load or test a single feature's DI graph in isolation.

## Cross-File Requirement

Cannot be implemented as a per-file analyzer rule — needs the full set of DI registration call sites (e.g. `GetIt` `registerLazySingleton`/`registerFactory` calls, Riverpod provider declarations) across the project to determine that they all live in one file rather than being split per feature; a single file's AST cannot tell how many total registrations exist project-wide or whether a per-feature split already exists elsewhere. Build as a `dart run saropa_lints:cross_file` check rather than a `custom_lint` visitor. See `plans/cross_file_cli_design.md`.

## Detection / Behavior

Fires when the total registration count in one file exceeds a configured threshold (e.g. 20) with no per-feature module files (`*_module.dart`/`*_di.dart` naming pattern) present in the project.

#### BAD:
```dart
// lib/injection.dart — 80 registrations for auth, cart, profile, settings...
void setupLocator() {
  getIt.registerLazySingleton<AuthRepo>(() => AuthRepoImpl());
  getIt.registerLazySingleton<CartRepo>(() => CartRepoImpl());
  // ...78 more
}
```

#### GOOD:
```dart
// lib/features/auth/auth_module.dart
void registerAuthModule(GetIt it) {
  it.registerLazySingleton<AuthRepo>(() => AuthRepoImpl());
}

// lib/injection.dart
void setupLocator() {
  registerAuthModule(getIt);
  registerCartModule(getIt);
}
```

## Quick Fix

None — manual refactor required. Splitting registrations by feature requires human judgment about feature boundaries.

## Alternatives Considered

A purely per-file line-count trigger (without cross-file registration counting) was considered and rejected — a large-but-genuinely-single-feature DI file is legitimate; the project-wide registration count is what actually signals a missing split.
