# Bug: avoid_renaming_representation_getters and prefer_private_extension_type_field conflict

**Resolution (fixed):** avoid_renaming_representation_getters now allows exactly one public getter when the representation is private (name starts with `_`), so `extension type E(String _sql) { String get sql => _sql; }` no longer triggers. Resolves conflict with prefer_private_extension_type_field.

**Status:** Fixed

**Rules:** `avoid_renaming_representation_getters`, `prefer_private_extension_type_field`  
**Reporter:** saropa_drift_viewer package

---

## Summary

For Dart 3.3+ extension types:

- **prefer_private_extension_type_field** requires the representation to be private: `extension type E(String _repr)`, so the representation parameter must be named with a leading underscore.
- **avoid_renaming_representation_getters** requires that the representation not be exposed via a getter with a **different** name; it prefers the representation name to be used directly or a single public getter name that **matches** the representation.

If the representation is private (`_sql`), we must expose it via a getter with a different name (e.g. `sql`) because the private name is not visible as a public API. That triggered avoid_renaming_representation_getters. If the representation is public (`sql`), we satisfy avoid_renaming but violate prefer_private_extension_type_field. So the two rules were mutually unsatisfiable for extension types that need a public getter with a different name than the private representation.

## Fix applied

avoid_renaming_representation_getters: when the representation is private (name starts with `_`), allow exactly one public getter that exposes it under a different name (e.g. `String get sql => _sql`). Rule doc updated with exception and GOOD example.

## Environment (at report)

- Package: saropa_drift_viewer (Dart VM)
- saropa_lints: 6.2.2
- Dart SDK: >=3.3.0 <4.0.0 (extension types)
