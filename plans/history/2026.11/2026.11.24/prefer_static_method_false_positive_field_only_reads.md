# prefer_static_method flags instance methods that read only instance fields

Status: open. Reported from d:/src/contacts lint slice 30 (scanner CLI, `dart run saropa_lints scan . --files ... --format json`).

## Symptom

Instance methods whose body reads only bare instance fields (no `this.`, no instance method call) are reported as "does not reference any instance members". Making them static would not compile.

## Examples (all in d:/src/contacts)

- lib/service/calendar_import_store.dart:97 `bool covers(DateTime? otherStart, DateTime? otherEnd) => _holds(start, otherStart, ...) && _holds(end, ...)` reads fields `start`, `end`.
- lib/service/circle_prompts/circle_prompt_links.dart:93 `of(link)` reads `loadFailed`, `unsafeUuids`, `byLinkUuid`; :101 `excludes(link)` reads `loadFailed`, `unsafeUuids`.
- lib/service/circle_prompts/circle_prompt_triggers.dart:71 `excludes(link)` reads `ownUuid`, `links`.
- lib/service/circle_prompts/circle_prompt_types.dart:164, 195, 209, 262 methods that read `shown`, `categoryShown`, `acted`, `keepDays` and similar final fields.

Each class is `@immutable` with a const constructor and `final` fields.

## Suspected cause

`_ThisUsageFinder.visitSimpleIdentifier` in lib/src/rules/architecture/structure_rules.dart requires `node.element is ExecutableElement`. A bare read of a `final` field with an implicit getter can resolve to a field element or stay unresolved in the CLI scan, so `onFound()` is never called.

## Fix

Treat a resolved `FieldElement` that is non-static (and an unresolved identifier whose name matches a declared instance field of the enclosing class) as instance-state access.
