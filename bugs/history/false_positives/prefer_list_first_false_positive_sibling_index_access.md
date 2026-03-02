# Bug: `prefer_list_first` false positive when sibling index accesses exist

## Status: RESOLVED (v5.0.3)

## Resolution

Fixed in `PreferFirstRule` (v4) and `PreferLastRule` (v3) by adding three suppression checks before reporting:

1. **Assignment target** — `list[0] = value` is skipped (`.first` cannot be used as an lvalue on all List types)
2. **Type check** — `String[0]` and `Map[0]` are skipped (no `.first` getter)
3. **Sibling index access** — `list[0]` alongside `list[1]`, `list[i]`, or `list[0] = ...` in the same function body is skipped (replacing only `[0]` with `.first` creates inconsistent code)

Sibling detection uses a `RecursiveAstVisitor` scoped to the enclosing `FunctionBody`. The visitor matches:
- Non-zero `IntegerLiteral` indices (`[1]`, `[2]`)
- `SimpleIdentifier` variable indices (`[i]` in loops)
- Same-target `[0]` used as an assignment target elsewhere in scope

## Files Changed

- `lib/src/rules/collection_rules.dart` — rule logic + `_hasSiblingIndexAccess` + `_SiblingIndexVisitor`
- `example_core/lib/collection/prefer_list_first_fixture.dart` — 7 new GOOD cases
- `example_core/lib/collection/prefer_list_last_fixture.dart` — 2 new GOOD cases
- `test/collection_rules_test.dart` — 7 new false positive tests
- `CHANGELOG.md` — entries under `[Unreleased] > Fixed`
