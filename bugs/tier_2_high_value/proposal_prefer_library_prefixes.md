# PROPOSAL: Flag Non-snake_case Import Prefixes

**Status: Open**

Created: 2026-09-02
Type: New rule
Related rules: none

---

## Summary

Add `prefer_library_prefixes` to flag `import '...' as SomePrefix;` / `as somePrefix;` declarations whose prefix identifier is not `lowercase_with_underscores`, per the Dart style guide's naming convention for import prefixes.

**Closes gap:** pyramid_lint `prefer_library_prefixes`. Implementing this proposal as specified fully closes this competitive gap — see `plans/GAP_ANALYSIS.md` pyramid_lint Gaps section.

---

## Motivation

The Dart Style Guide specifies `snake_case` for library/import prefixes (e.g. `import 'dart:math' as math;`, `import 'package:my_pkg/my_pkg.dart' as my_pkg;`), distinct from `camelCase` for variables/parameters and `PascalCase` for types. A `camelCase` or `PascalCase` prefix (`import '...' as MyLib;`) reads inconsistently against every other prefixed reference in the codebase (`math.pi`, `path.join`) and against the convention every generated/SDK import already follows.

---

## Detection / Behavior

### Should flag (bad code)

```dart
import 'package:my_package/my_package.dart' as MyPackage; // LINT — prefix should be snake_case: my_package

void main() {
  MyPackage.doSomething();
}
```

### Should pass (good code)

```dart
import 'package:my_package/my_package.dart' as my_package; // OK

void main() {
  my_package.doSomething();
}
```

---

## Proposed Tier

Tier: Pedantic
Justification: pure naming-convention style rule, no functional impact — matches saropa's placement for other naming-convention rules (e.g. file-naming, snake_case rules) at the lowest opt-in tier.

---

## Edge Cases

1. **Single-letter or short abbreviation prefixes (`as fb;` for `firebase`)** — should pass as long as the identifier is already lowercase; brevity itself is not a style violation, only casing.
2. **Prefix containing digits (`as v2;`)** — should pass if lowercase-with-underscores rules are otherwise satisfied; digits are allowed in `snake_case` identifiers.
3. **Deferred imports (`import '...' deferred as SomePrefix;`)** — should flag identically; the `deferred` keyword doesn't change the prefix-naming convention.
4. **Prefix that starts with an underscore (`as _internal;`)** — should pass; leading underscore on an import prefix has no special meaning here and doesn't violate snake_case casing itself, though note Dart disallows a leading-underscore prefix from being referenced outside its own library scope regardless.

---

## Alternatives Considered

- **Auto-fix that renames the prefix and every usage site** — include as a quick fix; requires a project-wide rename of the prefix identifier at all `Prefix.member` reference sites within the same file (imports are file-scoped), which is a bounded, safe rewrite.

---

## Decision

---

## Implementation Notes

---

## Commits
