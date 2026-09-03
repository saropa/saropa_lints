# PROPOSAL: Clean Architecture Layer-Boundary Enforcement Rule Family

**Status: Open**

Created: 2026-09-02
Type: New rule family (11 rules, one cohesive system)
Related rules: `avoid_business_logic_in_ui`, `avoid_direct_data_access_in_ui`, `avoid_ui_in_domain_layer` (saropa's existing 3 fixed-relationship layer rules — this proposal generalizes the same idea)

---

## Summary

Add a coherent `clean_architecture_kit`-parity rule family that enforces Clean Architecture's layer boundaries and per-layer construction conventions across the `domain`/`data`/`presentation` split: import/type restrictions between layers, naming and file-location conventions per layer, and structural requirements on repositories/use cases/data sources (correct base-class inheritance, correct return types, correct model-to-entity mapping). These 11 rules are one system — they all enforce the same architecture, just at different points in the codebase — so they are proposed together rather than as 11 independent proposals.

**Closes gap:** `clean_architecture_kit` — `disallow_flutter_imports_in_domain`, `disallow_flutter_types_in_domain`, `data_source_purity`, `disallow_use_case_in_presentation`, `enforce_model_to_entity_mapping`, `enforce_abstract_data_source_dependency`, `enforce_file_and_folder_location`, `enforce_naming_conventions`, `enforce_custom_return_type`, `enforce_use_case_inheritance`, `enforce_repository_inheritance`. Implementing this proposal as specified fully closes these 11 gaps (of the package's 13 total gaps — `repository_implementation_purity` and `missing_use_case` are tracked separately, not in this batch) — see `plans/GAP_ANALYSIS.md` "clean_architecture_kit (13 gaps)" section and its expanded "#### Gaps" list.

---

## Motivation

Saropa already enforces three fixed, hardcoded layer relationships (`avoid_business_logic_in_ui`, `avoid_direct_data_access_in_ui`, `avoid_ui_in_domain_layer`) but has no general Clean Architecture enforcement engine — no way to check that a `domain` layer never imports Flutter, that repositories inherit the correct abstract base, that use cases live in the right folder, or that data models map to entities via a defined boundary method. `clean_architecture_kit` is purpose-built prior art for exactly this, and per the gap analysis this is a fully-scoped, real competitive gap rather than three ad hoc rules pretending to be a general system.

---

## Detection / Behavior

All 11 rules share one config surface: the project's layer folder/naming convention (e.g. `lib/features/<feature>/{domain,data,presentation}/`) must be declared so the rules know which files belong to which layer. Below is the behavior per rule.

### `disallow_flutter_imports_in_domain`

Flags any `import 'package:flutter/...'` inside a file classified as `domain` layer.

```dart
// domain/entities/user.dart
import 'package:flutter/material.dart'; // LINT — domain layer must not import Flutter
```

### `disallow_flutter_types_in_domain`

Flags Flutter-framework types (`Color`, `Widget`, `BuildContext`, etc.) used as field/parameter/return types in `domain` layer code, even without a direct Flutter import (e.g. via a re-export).

```dart
// domain/entities/theme_preference.dart
class ThemePreference {
  final Color accent; // LINT — Flutter type Color used in domain entity
}
```

### `data_source_purity`

Flags a `data` layer *data source* class (per the folder/naming convention) that contains business logic (branching decisions beyond raw I/O mapping) rather than pure fetch/persist operations.

```dart
// data/datasources/user_remote_data_source.dart
class UserRemoteDataSource {
  Future<User> fetch(String id) async {
    final response = await api.get(id);
    if (response.age < 18) { // LINT — business rule inside a data source; belongs in domain/use case
      throw AgeRestrictionException();
    }
    return User.fromJson(response.data);
  }
}
```

### `disallow_use_case_in_presentation`

Flags a `presentation` layer file directly instantiating or calling a domain use case's implementation type instead of going through an injected abstraction/provider.

```dart
// presentation/pages/profile_page.dart
final useCase = GetUserUseCaseImpl(repository); // LINT — presentation must not construct use case implementations directly
```

### `enforce_model_to_entity_mapping`

Flags a `data` layer model class (`*Model`/`*Dto`) with no corresponding `toEntity()` (or configured mapping method) that converts it to its `domain` entity counterpart.

```dart
// data/models/user_model.dart
class UserModel { // LINT — UserModel has no toEntity() mapping to a domain entity
  final String id;
}
```

### `enforce_abstract_data_source_dependency`

Flags a repository implementation depending on a concrete data source class instead of an abstract data source interface.

```dart
class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this.dataSource);
  final UserRemoteDataSource dataSource; // LINT — depends on concrete data source; depend on an abstract interface
}
```

### `enforce_file_and_folder_location`

Flags a class whose name/role (per naming convention, e.g. `*UseCase`, `*Repository`, `*Model`) is not located in its expected layer folder.

```dart
// presentation/widgets/get_user_use_case.dart — LINT: UseCase class found outside domain/usecases/
class GetUserUseCase { ... }
```

### `enforce_naming_conventions`

Flags a class violating the configured per-layer naming suffix convention (`*UseCase` in domain, `*RepositoryImpl` in data, `*Page`/`*View` in presentation, etc.).

```dart
// domain/usecases/fetch_user.dart
class FetchUser { ... } // LINT — domain use case class should be named *UseCase (e.g. FetchUserUseCase)
```

### `enforce_custom_return_type`

Flags a use case/repository method returning a raw framework/primitive type instead of the project's configured result wrapper (e.g. `Result<T>`/`Either<Failure, T>`).

```dart
abstract class UserRepository {
  Future<User> getUser(String id); // LINT — should return Future<Result<User>> per project convention
}
```

### `enforce_use_case_inheritance`

Flags a use case class that does not extend/implement the project's configured base `UseCase` class.

```dart
class GetUserUseCase { // LINT — must extend/implement UseCase<Params, ReturnType>
  Future<User> call(String id) async { ... }
}
```

### `enforce_repository_inheritance`

Flags a repository implementation class that does not implement its corresponding abstract domain repository interface.

```dart
class UserRepositoryImpl { // LINT — must implement UserRepository (domain interface)
  Future<User> getUser(String id) async { ... }
}
```

### Should pass (good code, illustrative for the family)

```dart
// domain/entities/user.dart — no Flutter import/types
class User {
  const User({required this.id, required this.name});
  final String id;
  final String name;
}

// domain/repositories/user_repository.dart
abstract class UserRepository {
  Future<Result<User>> getUser(String id); // OK — custom return type
}

// domain/usecases/get_user_use_case.dart
class GetUserUseCase extends UseCase<String, User> { // OK — naming + inheritance
  GetUserUseCase(this._repository);
  final UserRepository _repository;

  @override
  Future<Result<User>> call(String id) => _repository.getUser(id);
}

// data/models/user_model.dart
class UserModel {
  const UserModel({required this.id, required this.name});
  final String id;
  final String name;

  User toEntity() => User(id: id, name: name); // OK — mapping present
}

// data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository { // OK — implements domain interface
  UserRepositoryImpl(this._dataSource);
  final UserDataSource _dataSource; // OK — abstract data source dependency

  @override
  Future<Result<User>> getUser(String id) async {
    final model = await _dataSource.fetch(id);
    return Result.ok(model.toEntity());
  }
}
```

---

## Proposed Tier

Tier: Professional
Justification: this is an opinionated, whole-architecture enforcement system — genuinely valuable for teams that have adopted Clean Architecture, but requires per-project folder/naming configuration and is inapplicable to projects not structured this way, so it belongs above Essential/Recommended (which must work with zero config) but is coherent and correctness-adjacent enough (prevents real layer-boundary violations, not just style) to warrant Professional rather than Comprehensive/Pedantic.

---

## Edge Cases

1. **Project not structured with domain/data/presentation folders at all** — the whole rule family should no-op silently rather than error, since layer classification depends entirely on the configured folder convention.
2. **Shared/core utility code that legitimately sits outside any layer (e.g. `lib/core/`)** — should pass for all 11 rules; layer classification must have a clear "not classified" fallback that skips enforcement rather than defaulting to the strictest layer.
3. **Generated code (`.g.dart`, `.freezed.dart`) for data models** — should pass `enforce_model_to_entity_mapping` and others; standard generated-file suppression applies across the family.
4. **A project using a different Clean Architecture folder convention (e.g. `lib/<layer>/<feature>/` instead of `lib/<feature>/<layer>/`)** — the config schema must support both layouts, or the rules will misclassify every file; this must be resolved during implementation design, not deferred.
5. **Freezed/union-type domain entities that internally reference generated Flutter-adjacent code paths (not actual Flutter types)** — `disallow_flutter_types_in_domain` must check resolved type origin (package `flutter`), not superficial name matching, to avoid false positives on unrelated types that merely share a name (e.g. a domain `Color` enum of its own).

---

## Alternatives Considered

- **Ship as 11 separate proposals** — rejected per the batch instructions; these rules form one coherent enforcement system sharing a single layer-classification config surface, and reviewing/deciding on them independently would fragment a decision that is really "adopt Clean Architecture enforcement, yes or no."
- **Generalize saropa's existing 3 fixed-relationship rules (`avoid_business_logic_in_ui` etc.) into a fully generic N-layer graph the project defines, then re-derive these 11 from that generic engine** — noted in `plans/GAP_ANALYSIS.md` as the more ambitious alternative; deferred because it's a much larger engineering investment (a general dependency-graph DSL) versus implementing the concrete, well-scoped `clean_architecture_kit`-parity rule set first. Revisit the generic-engine approach only if a second architecture-style package's gaps also turn out to need N-layer generality.

---

## Decision

---

## Implementation Notes

- Single shared "layer classifier" module (folder path + naming convention → `domain`/`data`/`presentation` layer tag) should back all 11 rules — do not duplicate classification logic per rule.
- Needs a project-level config block (likely in `analysis_options_custom.yaml`) declaring: layer folder pattern, per-layer naming suffixes, the configured result-wrapper type (for `enforce_custom_return_type`), and the base `UseCase`/`Repository` class names (for the two inheritance rules).
- `repository_implementation_purity` and `missing_use_case` (the other 2 of the package's 13 gaps) are explicitly NOT covered by this proposal — they were not in this batch; file separately if/when picked up, ideally extending the same shared layer classifier.

---

## Commits
