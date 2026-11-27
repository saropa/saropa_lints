# require_copy_with_null_handling: false positive when the model clears fields by empty value

**Status:** Closed, by design
**Created:** 2026-11-26
**Rule:** `require_copy_with_null_handling`

## Summary
The rule flags `copyWith` using `param ?? this.param` on nullable parameters. The model `ContactGroupModel` documents clear-by-empty (empty string clears avatar fields, empty list clears chat links/roles). Null means "keep stored value" by contract, and no caller passes null to clear. The hazard (inability to null a field) is intended design, not a defect.

## Attribution Evidence
```
OK    require_copy_with_null_handling: defined at lib/src/rules/packages/equatable_rules.dart:929
```

## Reproducer
```dart
class Group {
  Group({this.avatarUrl, this.chatLinks});
  final String? avatarUrl;
  final List<String>? chatLinks;

  // LINT (reported at method)
  Group copyWith({String? avatarUrl, List<String>? chatLinks}) => Group(
        avatarUrl: avatarUrl ?? this.avatarUrl,
        chatLinks: chatLinks ?? this.chatLinks,
      );
}
// Callers: group.copyWith(avatarUrl: '') clears; group.copyWith(chatLinks: <String>[]) clears. // OK by contract
```

## Expected vs Actual
Expected: no report when the class documents null as "keep" and clears via empty value, or at least a way to express that contract. Actual: reported on every such copyWith.

## AST Context
MethodDeclaration `copyWith`, ExpressionFunctionBody of an InstanceCreationExpression whose arguments are `x ?? this.x`.

## Root Cause
The check only exempts a boolean clear flag guarding `??` (see the FP fix in the rule). It does not recognize clear-by-empty-value semantics, which cannot be detected from the AST.

## Suggested Fix
Consider a documented opt-out (for example a doc comment marker) or lower severity; otherwise consumers keep a reasoned ignore.

## Fixture Gap
No fixture for a model that clears via empty value; add an OK case.

## Environment
Downstream app: contacts, file `lib/models/contact_group/contact_group_model.dart`. saropa_lints per the app's plugins pin.

## Additional cases: no caller ever clears (appended 2026-11-26)
Downstream app: contacts. Every `.copyWith(` caller of each class was grepped in lib/ and test/; none passes null to clear a nullable field, and no feature needs a field reset to null. The hazard cannot occur, and a sentinel would add API surface nothing uses.
- `lib/models/age_group/age_group_model.dart` `AgeGroupModel.copyWith`: only caller (`lib/utils/age_group/age_group_utils.dart`) appends to `contactSaropaUUIDs`.
- `lib/models/authentication/provider_auth_model.dart` `AuthProviderModel.copyWith`: callers refresh `accessToken` and `updatedAt` only (token refresh); tokens are never cleared via copyWith.
- `lib/models/contact/contact_custom_field_item.dart` `CustomFieldItem.copyWith`: only tests set `key` / `value` to non-null values.
Expected: no report, or an opt-out for classes whose callers never clear. Same AST context and root cause as above.

## Additional case: nullable parameters over non-nullable fields (appended 2026-11-26)
`lib/models/audit/activity_filters_notifier.dart` `ActivityFilters.copyWith`: every clearable nullable field was converted to a `FilterValue` parameter (dates, text, tri-state flags, filter lists). The remaining `x ?? this.x` lines (`sortDirection`, `limit`, `hasUniqueContactIds`, `hasUniqueTypes`, `isOnlyMostRecentPerType`, `isIncludeBioLockedContacts`) map to NON-nullable fields, so null can never be a valid stored value. The rule still reports the method. Expected: no report when each `??` target field is non-nullable.

## Finish Report (2026-11-26)

Closed by design. Rule detection is unchanged.

- `ContactGroupModel`, `AgeGroupModel`, `AuthProviderModel` and `CustomFieldItem` are flagged by design: the rule judges the `copyWith` declaration alone, not callers or clear-by-empty conventions.
- `ActivityFilters` was not reproduced: it produced no diagnostic.
- Three resolved behavior tests were added to `test/rules/packages/equatable_rules_test.dart`.
