# PROPOSAL: Flag Repository Implementations That Bypass the Abstract DataSource Layer

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: `avoid_ui_in_domain_layer` (flags Flutter/UI types leaking into the domain layer — opposite direction: this rule flags a data-layer class leaking concrete implementation details), `avoid_direct_data_access_in_ui` (flags widgets referencing Repository/DataSource types directly — that rule protects the UI layer's boundary; this rule protects the data layer's own internal boundary between `*RepositoryImpl` and concrete `DataSource` implementations)

---

## Summary

Add `repository_implementation_purity` to flag a class that implements a domain-layer `Repository` interface (conventionally suffixed `RepositoryImpl` and living in the data layer) when that class either (a) imports/constructs a **concrete** (non-abstract) `DataSource` implementation directly instead of depending on the abstract `DataSource` interface, or (b) references any `package:flutter/*` type in its method signatures. A `RepositoryImpl` class is the seam between domain-layer contracts and data-layer mechanics — if it depends on concretions instead of abstractions, or leaks Flutter types, Clean Architecture's dependency-inversion guarantee breaks silently.

**Closes gap:** clean_architecture_kit `repository_implementation_purity` (github.com/puntbyte/clean_architecture_workspace). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` theme 2 (clean_architecture_kit, 13-rule gap group). This proposal scopes only this one rule from that group.

---

## Motivation

**Package dependency note:** this rule targets projects following the Clean Architecture layering convention (`domain`/`data`/`presentation` directories, `Repository` interfaces in domain, `RepositoryImpl` classes in data, `DataSource` abstractions in data) popularized by clean_architecture_kit and similar templates. It has no meaning outside that convention and should never fire in a project without a recognizable layered structure.

Clean Architecture's core promise is that the domain layer defines contracts (`abstract class UserRepository`) and the data layer supplies implementations (`class UserRepositoryImpl implements UserRepository`) that depend only on further abstractions (`abstract class UserDataSource`), never on concretions (`ApiUserDataSourceImpl`, `LocalUserDataSourceImpl`). When a `RepositoryImpl` imports a concrete DataSource directly, dependency injection can no longer swap implementations (e.g. for testing, offline mode, or multi-source aggregation) without editing the repository itself — the entire point of the abstraction is defeated, but nothing in the type system flags it, since Dart happily lets a class construct or reference any concrete type it likes.

A second, related leak is Flutter/UI types appearing in a `RepositoryImpl`'s method signatures (`BuildContext`, `Color`, `Widget`). Data-layer code should be Flutter-independent so it can run in tests, CLI tools, and non-Flutter contexts — the same rationale as saropa's existing `avoid_ui_in_domain_layer`, but applied to the data layer's public surface rather than the domain layer.

Clean architecture_kit ships `repository_implementation_purity` as one of 13 rules covering this layering discipline; saropa currently has zero rules that check the data layer's *internal* purity (its existing architecture rules protect the UI boundary and the domain boundary, but not the data-layer's own dependency direction).

---

## Detection / Behavior

Flag a class declaration that:

1. Is named with the `RepositoryImpl` suffix (configurable convention marker), OR implements/extends a type whose name matches `*Repository` from the domain layer, AND
2. Either:
   - (a) imports or directly instantiates (`ConcreteDataSourceImpl()`) a class whose name matches `*DataSource*Impl` or a similar concrete-implementation naming pattern, when an abstract `*DataSource` interface with the same base name exists in the project, OR
   - (b) declares a field or a public method parameter/return type from `package:flutter/*` (e.g. `BuildContext`, `Color`, `Widget`, `TextStyle`).

### Should flag (bad code)

```dart
// lib/data/repositories/user_repository_impl.dart
import 'package:flutter/material.dart'; // LINT — Flutter type import in data layer
import '../datasources/api_user_data_source_impl.dart'; // concrete DataSource

class UserRepositoryImpl implements UserRepository {
  // LINT — depends on the CONCRETE ApiUserDataSourceImpl instead of the
  // abstract UserDataSource interface; callers cannot substitute a fake
  // or alternate data source without editing this class.
  final ApiUserDataSourceImpl _dataSource = ApiUserDataSourceImpl();

  @override
  Future<User> getUser(String id) => _dataSource.fetchUser(id);

  // LINT — BuildContext has no business appearing in a data-layer method
  // signature; it couples the repository to the Flutter widget tree.
  Future<void> showLoadingIndicator(BuildContext context) async {}
}
```

### Should pass (good code)

```dart
// lib/data/repositories/user_repository_impl.dart
import '../datasources/user_data_source.dart'; // abstract interface only

class UserRepositoryImpl implements UserRepository {
  // OK — depends on the abstract UserDataSource; the concrete
  // implementation is injected by the composition root / DI container.
  UserRepositoryImpl(this._dataSource);

  final UserDataSource _dataSource;

  @override
  Future<User> getUser(String id) => _dataSource.fetchUser(id);
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: This rule is opt-in for projects that follow the Clean Architecture layered-directory convention; it has no meaning and would produce noise in projects without that structure. Package/convention-dependent architecture rules of this shape belong in Comprehensive or Pedantic, never Essential/Recommended.

---

## Edge Cases

1. **Project without a recognizable `domain`/`data` layer split** — should pass entirely (no `RepositoryImpl`-suffixed classes to match, or the abstract/concrete DataSource pairing heuristic finds nothing).
2. **A `RepositoryImpl` that constructs a concrete DataSource only inside a test double / mock file** — should pass; scope detection to `lib/` production code, mirroring saropa's other architecture rules' path-based scoping.
3. **DataSource with no abstract counterpart in the project** (i.e. only one concrete `XxxDataSource` class exists, no `abstract class XxxDataSource`) — should pass; the rule only fires when an abstraction the class *could* have depended on actually exists and was bypassed.
4. **Flutter type used only in a private helper method, not the public interface implementation** — treat as a smell but keep the initial rule scoped to public method signatures and fields to avoid over-flagging internal helpers; note as a possible follow-up if false-negative reports arrive.
5. **Constructor-injected concrete class passed in from outside** (`UserRepositoryImpl(ApiUserDataSourceImpl())` at the call site, but the class itself is typed as `UserDataSource` internally) — should pass; the class's own field/parameter type is what matters, not what a caller happens to pass.

---

## Alternatives Considered

- **Full 13-rule clean_architecture_kit parity in one PR** — rejected; GAP_ANALYSIS groups these as a themed 13-rule set, but each has a distinct AST pattern and failure mode. Landing them one at a time (starting with this one, the highest-value dependency-inversion check) keeps each PR reviewable and testable.
- **Purely name-based heuristic with no abstract/concrete pairing check** (flag any concrete-looking import in a `*RepositoryImpl` file) — rejected; too coarse, would flag legitimate use of concrete utility classes (loggers, formatters) that aren't DataSources at all.

---

## Decision

---

## Implementation Notes

---

## Commits
