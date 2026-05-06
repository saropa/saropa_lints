# Bug: avoid_renaming_representation_getters and prefer_private_extension_type_field conflict

**History summary:** Filed from saropa_drift_viewer. Two rules conflict: private representation requires a renamed getter. Status: Open.

**Rules:** `avoid_renaming_representation_getters`, `prefer_private_extension_type_field`  
**Status:** Open  
**Reporter:** saropa_drift_viewer package

---

## Summary

For Dart 3.3+ extension types:

- **prefer_private_extension_type_field** requires the representation to be private: `extension type E(String _repr)`, so the representation parameter must be named with a leading underscore.
- **avoid_renaming_representation_getters** requires that the representation not be exposed via a getter with a **different** name; it prefers the representation name to be used directly or a single public getter name that **matches** the representation.

If the representation is private (`_sql`), we must expose it via a getter with a different name (e.g. `sql`) because the private name is not visible as a public API. That triggers avoid_renaming_representation_getters. If the representation is public (`sql`), we satisfy avoid_renaming but violate prefer_private_extension_type_field. So the two rules are mutually unsatisfiable for extension types that need a public getter with a different name than the private representation.

## Expected behavior

- Either one rule should yield when the other is satisfied (e.g. prefer_private_extension_type_field allows a single public getter that “renames” the private representation), or
- avoid_renaming_representation_getters should not report when the representation is private and there is a single public getter that provides the intended API (e.g. `String get sql => _sql`), or
- The rules should be documented as conflicting and one should be disabled when using extension types with a private representation and a friendly public getter name.

## Actual behavior

- Using `extension type _SqlRequestBody(String _sql)` with `String get sql => _sql` satisfies prefer_private_extension_type_field but triggers avoid_renaming_representation_getters ("Extension type should not expose the representation via a getter with a different name").
- Using `extension type _SqlRequestBody(String sql)` satisfies avoid_renaming_representation_getters but triggers prefer_private_extension_type_field ("Extension type representation field must be private").

No single declaration can satisfy both.

## Minimal reproduction

```dart
// Option A: private representation + getter → prefer_private satisfied, avoid_renaming fires
extension type _SqlRequestBody(String _sql) implements Object {
  String get sql => _sql;
}

// Option B: public representation → avoid_renaming satisfied, prefer_private fires
extension type _SqlRequestBody(String sql) implements Object {}
```

## Suggested fix

1. **avoid_renaming_representation_getters:** When the representation is private (name starts with `_`), allow exactly one public getter that exposes it under a different name (e.g. `String get sql => _sql`). Treat “representation name” as the public API name when the representation is intentionally private.
2. **prefer_private_extension_type_field:** In the rule description, mention that a single public getter with a different name is acceptable when the representation is private (and optionally reference avoid_renaming_representation_getters).
3. **Documentation:** In both rules’ docs, state that for extension types with a private representation and a friendly public getter, only one rule can be satisfied unless the above exception is added.

## Environment

- Package: saropa_drift_viewer (Dart VM)
- saropa_lints: 6.2.2
- Dart SDK: >=3.3.0 <4.0.0 (extension types)
