# PROPOSAL: Enforce the json_serializable Annotation <-> Member Contract

**Status: Open**

Created: 2026-09-02
Type: New rule group (3 rules)
Related rules: `prefer_json_codegen`, `prefer_json_serializable`, `avoid_not_encodable_in_to_json`, `avoid_freezed_json_serializable_conflict` (all existing saropa rules that check the *content/style* of hand-written or generated `fromJson`/`toJson` code — encoding correctness, codegen preference, Freezed interop. This proposal instead checks *existence*: whether an annotation and its corresponding generated-member hookup are both present or both absent. It is a structural contract check, not a style or correctness-of-content check, and is fully complementary to the four rules above.)

---

## Summary

Add three rules that enforce the `json_serializable` package's core contract — "an annotation implies a matching generated-member hookup, and a generated-member hookup implies the annotation":

- **`require_annotation_from_json`** — a class declares `factory X.fromJson(Map<String, dynamic> json)` but carries no `@JsonSerializable()`-family annotation.
- **`require_json_serializable_from_json`** — a class carries `@JsonSerializable()` but declares no `factory X.fromJson(...) => _$XFromJson(json);`.
- **`require_json_serializable_to_json`** — a class carries `@JsonSerializable()` but declares no `Map<String, dynamic> toJson() => _$XToJson(this);`.

**Closes gap:** json_serializable_lints `require_annotation_from_json`, `require_json_serializable_from_json`, `require_json_serializable_to_json` (github.com/leithmail/json_serializable_lints_dart); json_parser_linter's fromJson/toJson existence-pairing concept (github.com/Ragibn5/dart-flutter-packages). Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` theme 6 (json-codegen annotation-contract enforcement).

---

## Motivation

**Package dependency note:** all three rules fire only on classes that carry, or are missing, the `json_serializable` package's `@JsonSerializable()` annotation family (including Freezed's implicit `@JsonSerializable`-equivalent codegen). They have no meaning in a project that does not use `json_serializable`.

`json_serializable` works by pairing a class-level annotation with generated top-level functions (`_$XFromJson`, `_$XToJson`) that the class must explicitly wire up via a `factory` constructor and a `toJson()` method. The generator does not fail loudly when this wiring is missing or stale — it simply produces dead code the annotated class never calls, or leaves a hand-written `fromJson` sitting next to a forgotten (or never-added) annotation. Both failure modes are common in real refactors:

- A developer removes `@JsonSerializable()` during a migration but forgets the now-orphaned `factory X.fromJson(...)` constructor, which either still hand-parses the JSON (silently diverging from what codegen would have produced) or references a `_$XFromJson` function that no longer exists once the build_runner output is deleted.
- A developer adds `@JsonSerializable()` to a class but forgets to add the `factory`/`toJson()` boilerplate — the generated `.g.dart` file compiles fine and defines `_$XFromJson`/`_$XToJson`, but nothing in the class ever calls them, so the class is silently un-serializable at runtime despite looking annotated and "done."

This is exactly the class of bug saropa's `avoid_not_encodable_in_to_json` and `prefer_json_codegen` do NOT catch — those rules assume a `fromJson`/`toJson` exists and check its *content* (encodability, manual-vs-generated style). This proposal is a structural pre-check: annotation presence must imply member presence, and vice versa. It is a straightforward, high-value implement — pure AST presence/absence matching, no type inference required beyond annotation lookup.

---

## Detection / Behavior

### require_annotation_from_json

Flag a class declaration containing a `factory X.fromJson(Map<String, dynamic> json)` constructor (any body — hand-written or calling a generated function) when the class has no `@JsonSerializable`-family annotation (`@JsonSerializable()`, `@JsonSerializable(...)`, or Freezed's `@freezed` which implies the same contract).

#### Should flag (bad code)

```dart
// No @JsonSerializable() annotation, but a fromJson factory exists.
class User {
  User({required this.id, required this.name});

  factory User.fromJson(Map<String, dynamic> json) { // LINT
    return User(id: json['id'] as String, name: json['name'] as String);
  }

  final String id;
  final String name;
}
```

#### Should pass (good code)

```dart
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable()
class User {
  User({required this.id, required this.name});

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json); // OK

  final String id;
  final String name;

  Map<String, dynamic> toJson() => _$UserToJson(this);
}
```

### require_json_serializable_from_json

Flag a class declaration carrying `@JsonSerializable()` (or the annotation family) that does NOT declare a `factory X.fromJson(Map<String, dynamic> json)` constructor.

#### Should flag (bad code)

```dart
import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

@JsonSerializable() // LINT — no fromJson factory to call the generated _$UserFromJson
class User {
  User({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => _$UserToJson(this);
}
```

#### Should pass (good code)

```dart
@JsonSerializable()
class User {
  User({required this.id, required this.name});

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json); // OK

  final String id;
  final String name;

  Map<String, dynamic> toJson() => _$UserToJson(this);
}
```

### require_json_serializable_to_json

Flag a class declaration carrying `@JsonSerializable()` (or the annotation family) that does NOT declare a `Map<String, dynamic> toJson()` method.

#### Should flag (bad code)

```dart
@JsonSerializable() // LINT — no toJson() method to call the generated _$UserToJson
class User {
  User({required this.id, required this.name});

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  final String id;
  final String name;
}
```

#### Should pass (good code)

```dart
@JsonSerializable()
class User {
  User({required this.id, required this.name});

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  final String id;
  final String name;

  Map<String, dynamic> toJson() => _$UserToJson(this); // OK
}
```

---

## Proposed Tier

Tier: Comprehensive
Justification: All three rules are gated on the `json_serializable` package's annotation being present or a `fromJson` factory existing — a project-specific dependency, not a universal Dart concern. Niche/opt-in scope matches saropa's existing placement for `prefer_json_serializable` and `avoid_freezed_json_serializable_conflict`. Not Essential/Recommended since projects without `json_serializable` would never trip these rules either way, but projects that DO use it get real value from catching stale/incomplete annotations.

---

## Edge Cases (applies to the group)

1. **Freezed classes** — `@freezed` implies the `json_serializable` contract when combined with `@JsonSerializable()` or `.fromJson`/`toJson` mixins; Freezed generates its own factory/toJson wiring differently (`_$UserFromJson` via the Freezed mixin, not a hand-declared factory in the same shape). All three rules should recognize Freezed's generated pattern as satisfying the contract and not double-flag — cross-reference `avoid_freezed_json_serializable_conflict`'s existing Freezed-detection logic to avoid re-implementing it.
2. **Abstract classes / mixins with `fromJson` as an abstract contract method** (no body) — should pass for `require_annotation_from_json`; an abstract factory declaration with no implementation isn't the pattern this rule targets.
3. **`@JsonSerializable(createFactory: false)`** — should pass for `require_json_serializable_from_json`; the annotation explicitly opts out of factory generation, so no `fromJson` is expected. Same for `@JsonSerializable(createToJson: false)` and `require_json_serializable_to_json`.
4. **Generated files (`.g.dart`)** — should pass; standard generated-file suppression applies to all three rules; only the annotated source file is linted.
5. **`fromJson`/`toJson` present with an entirely hand-written body next to a valid `@JsonSerializable()` annotation** (annotation and member both present, but the member doesn't call `_$XFromJson`/`_$XToJson`) — out of scope for this existence-only proposal; that is `avoid_not_encodable_in_to_json` / `prefer_json_codegen` territory (content check, not existence check). Note the boundary explicitly in rule DartDoc to avoid overlap confusion.

---

## Alternatives Considered

- **Single combined rule instead of three** — rejected; each direction (annotation-without-factory, factory-without-annotation, annotation-without-toJson) has a distinct fix and distinct problem message, and json_serializable_lints ships them separately for the same reason. Splitting also lets teams enable/disable each independently (e.g. a codebase using `createToJson: false` intentionally would disable only the third rule).
- **Requiring exact `_$XFromJson(json)`/`_$XToJson(this)` call-body matching** — rejected for the initial implementation; presence of the factory/method with the correct signature is the existence check this proposal targets. Verifying the body actually delegates to the generated function is a natural follow-up but overlaps with `avoid_not_encodable_in_to_json`'s content-checking territory — flagged as a future extension, not blocking this proposal.

---

## Decision

---

## Implementation Notes

---

## Commits
