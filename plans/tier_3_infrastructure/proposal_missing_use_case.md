# PROPOSAL: Flag Presentation Layer Bypassing the Use-Case/Interactor Layer

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `missing_use_case` to flag a widget, `Bloc`/`Cubit`, or `ViewModel`/controller that calls a repository or data-source method directly instead of going through a project-defined use-case (interactor) class. Clean Architecture's layering exists specifically to keep business logic out of the presentation layer and testable in isolation — a direct repository call from the UI layer is the layering violation the pattern exists to prevent.

**Closes gap:** `clean_architecture_kit` `missing_use_case` (pub.dev). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md`.

---

## Motivation

Once a team adopts Clean Architecture's use-case layer, the value only holds if every access to a repository is routed through a use case; a single direct call from a Bloc or widget reintroduces business logic into the presentation layer and quietly erodes the boundary the rest of the codebase depends on for testability. Because the violation looks identical to a normal method call syntactically, it's easy to miss in review without tooling that understands the project's layer classification.

---

## Detection / Behavior

Requires project-level configuration identifying which classes/directories constitute the "repository" layer and which constitute "presentation" (widgets, Blocs/Cubits, ViewModels) — likely via directory convention (`lib/data/repositories/`, `lib/presentation/`) or a marker interface/annotation, configurable in `analysis_options_custom.yaml`. Flag a method invocation on a repository-layer type from within a presentation-layer class.

### Should flag (bad code)

```dart
// lib/presentation/bloc/profile_bloc.dart
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final UserRepository repository; // repository, not a use case
  ProfileBloc(this.repository) : super(ProfileInitial());

  Future<void> _onLoad(LoadProfile event, Emitter<ProfileState> emit) async {
    final user = await repository.fetchUser(event.id); // LINT — Bloc calls repository directly, bypassing the use-case layer
    emit(ProfileLoaded(user));
  }
}
```

### Should pass (good code)

```dart
// lib/presentation/bloc/profile_bloc.dart
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final GetUserUseCase getUser; // use case, not a raw repository
  ProfileBloc(this.getUser) : super(ProfileInitial());

  Future<void> _onLoad(LoadProfile event, Emitter<ProfileState> emit) async {
    final user = await getUser(event.id); // OK — routed through the use-case layer
    emit(ProfileLoaded(user));
  }
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: Architectural-layering rule requiring project-specific configuration to identify layers; only meaningful for teams that have adopted (and configured) Clean Architecture conventions.

---

## Edge Cases

1. **Project has no configured layer mapping** — rule must be inert (no false positives from guessing directory conventions); require explicit opt-in configuration.
2. **Use-case class itself calling a repository** — should pass; that's the intended, correct call site.
3. **A shared utility/mapper class (neither presentation nor use-case) calling a repository** — needs discussion; likely should pass since it's not presentation-layer code, but the layer boundary needs a clear third bucket to avoid false positives on legitimate infrastructure code.
4. **Repository call wrapped in a presentation-layer extension method that itself just forwards to a use case internally** — should pass at the extension method definition (it's arguably infrastructure), but the extension's own body would still need review if it's actually skipping the use case.

---

## Alternatives Considered

- **Generic "layer dependency direction" rule instead of a Clean-Architecture-specific one** — considered; a broader "layer A must not depend on layer B" config-driven rule could subsume this and other architectural rules, but scoping this proposal to the source package's specific use-case/repository check keeps it implementable without a larger layering-rules framework design.

---

## Decision

---

## Implementation Notes

---

## Commits
