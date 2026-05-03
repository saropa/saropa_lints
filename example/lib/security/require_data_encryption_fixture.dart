// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors
// ignore_for_file: unnecessary_import, unused_import
// ignore_for_file: avoid_unused_constructor_parameters
// ignore_for_file: override_on_non_overriding_member
// ignore_for_file: annotate_overrides, duplicate_ignore
// ignore_for_file: non_abstract_class_inherits_abstract_member
// ignore_for_file: extends_non_class, mixin_of_non_class
// ignore_for_file: field_initializer_outside_constructor
// ignore_for_file: final_not_initialized
// ignore_for_file: super_in_invalid_context
// ignore_for_file: concrete_class_with_abstract_member
// ignore_for_file: type_argument_not_matching_bounds
// ignore_for_file: missing_required_argument
// ignore_for_file: undefined_named_parameter
// ignore_for_file: argument_type_not_assignable
// ignore_for_file: invalid_constructor_name
// ignore_for_file: super_formal_parameter_without_associated_named
// ignore_for_file: undefined_annotation, creation_with_non_type
// ignore_for_file: invalid_factory_name_not_a_class
// ignore_for_file: invalid_reference_to_this
// ignore_for_file: expected_class_member
// ignore_for_file: body_might_complete_normally
// ignore_for_file: not_initialized_non_nullable_instance_field
// ignore_for_file: unchecked_use_of_nullable_value
// ignore_for_file: return_of_invalid_type
// ignore_for_file: use_of_void_result
// ignore_for_file: missing_function_body
// ignore_for_file: extra_positional_arguments
// ignore_for_file: not_enough_positional_arguments
// ignore_for_file: unused_label
// ignore_for_file: unused_element_parameter
// ignore_for_file: non_type_as_type_argument
// ignore_for_file: expected_identifier_but_got_keyword
// ignore_for_file: expected_token, missing_identifier
// ignore_for_file: unexpected_token
// ignore_for_file: duplicate_definition
// ignore_for_file: override_on_non_overriding_member
// ignore_for_file: extends_non_class
// ignore_for_file: no_default_super_constructor
// ignore_for_file: extra_positional_arguments_could_be_named
// ignore_for_file: missing_function_parameters
// ignore_for_file: invalid_annotation, invalid_assignment
// ignore_for_file: expected_executable
// ignore_for_file: named_parameter_outside_group
// ignore_for_file: obsolete_colon_for_default_value
// ignore_for_file: referenced_before_declaration
// ignore_for_file: await_in_wrong_context
// ignore_for_file: non_type_in_catch_clause
// ignore_for_file: could_not_infer
// ignore_for_file: uri_does_not_exist
// ignore_for_file: const_method
// ignore_for_file: redirect_to_non_class
// ignore_for_file: unused_catch_clause
// ignore_for_file: type_test_with_undefined_name
// ignore_for_file: undefined_identifier, undefined_function
// ignore_for_file: undefined_method, undefined_getter
// ignore_for_file: undefined_setter, undefined_class
// ignore_for_file: undefined_super_member
// ignore_for_file: extraneous_modifier
// ignore_for_file: experiment_not_enabled
// ignore_for_file: missing_const_final_var_or_type
// ignore_for_file: undefined_operator, dead_code
// ignore_for_file: invalid_override
// ignore_for_file: not_initialized_non_nullable_variable
// ignore_for_file: list_element_type_not_assignable
// ignore_for_file: assignment_to_final
// ignore_for_file: equal_elements_in_set
// ignore_for_file: prefix_shadowed_by_local_declaration
// ignore_for_file: const_initialized_with_non_constant_value
// ignore_for_file: non_constant_list_element
// ignore_for_file: missing_statement
// ignore_for_file: unnecessary_cast, unnecessary_null_comparison
// ignore_for_file: unnecessary_type_check
// ignore_for_file: invalid_super_formal_parameter_location
// ignore_for_file: assignment_to_type
// ignore_for_file: instance_member_access_from_factory
// ignore_for_file: field_initializer_not_assignable
// ignore_for_file: constant_pattern_with_non_constant_expression
// ignore_for_file: undefined_identifier_await, cast_to_non_type
// ignore_for_file: read_potentially_unassigned_final
// ignore_for_file: mixin_with_non_class_superclass
// ignore_for_file: instantiate_abstract_class
// ignore_for_file: dead_code_on_catch_subtype, unreachable_switch_case
// ignore_for_file: new_with_undefined_constructor
// ignore_for_file: assignment_to_final_local
// ignore_for_file: late_final_local_already_assigned
// ignore_for_file: missing_default_value_for_parameter
// ignore_for_file: non_bool_condition
// ignore_for_file: non_exhaustive_switch_expression
// ignore_for_file: illegal_async_return_type
// ignore_for_file: type_test_with_non_type
// ignore_for_file: invocation_of_non_function_expression
// ignore_for_file: return_of_invalid_type_from_closure
// ignore_for_file: wrong_number_of_type_arguments_constructor
// ignore_for_file: definitely_unassigned_late_local_variable
// ignore_for_file: static_access_to_instance_member
// ignore_for_file: const_with_undefined_constructor
// ignore_for_file: abstract_super_member_reference
// ignore_for_file: equal_keys_in_map, unused_catch_stack
// ignore_for_file: non_constant_default_value, not_a_type
// Test fixture for: require_data_encryption
// Source: lib\src\rules\security_rules.dart

import 'package:saropa_lints_example/flutter_mocks.dart';

dynamic box;
dynamic data;
dynamic file;
final key = 'key';
dynamic prefs;
final secureStorage = FlutterSecureStorage();
dynamic value;
dynamic driftDb;
dynamic plainPrivateKey;
dynamic encryptedPrivateKey;
dynamic cipherText;
dynamic aesEncodedToken;

// BAD: Drift-style `write` with sensitive field name and plaintext value
// expect_lint: require_data_encryption
void _badDriftPlaintextPrivateKey1010() {
  driftDb.write(
    _DriftLikeCompanion(
      privateKey: _DriftValue(plainPrivateKey),
      publicKey: _DriftValue(''),
    ),
  );
}

// BAD: Should trigger require_data_encryption
// expect_lint: require_data_encryption
void _bad1010() async {
  await prefs.setString('credit_card', cardNumber);
  await file.writeAsString(jsonEncode(userProfile));
  box.put('ssn', socialSecurityNumber);
}

// GOOD: Should NOT trigger require_data_encryption
void _good1010() async {
  await secureStorage.write(key: 'credit_card', value: cardNumber);
  await encryptedBox.put('ssn', socialSecurityNumber);
  final encrypted = await encrypter.encrypt(data);
  await file.writeAsBytes(encrypted);
}

// GOOD: Schema field is still `privateKey:` but value is ciphertext by naming
void _goodDriftEncryptedValue1010() {
  driftDb.write(
    _DriftLikeCompanion(
      privateKey: _DriftValue(encryptedPrivateKey),
      publicKey: _DriftValue(''),
    ),
  );
}

// GOOD: `insert` with cipher* / aes* value identifiers
void _goodDriftInsertCipherAndAes1010() {
  driftDb.insert(
    _DriftLikeCompanion(
      token: _DriftValue(cipherText),
      other: 1,
    ),
  );
  driftDb.insert(
    _DriftLikeCompanion(
      token: _DriftValue(aesEncodedToken),
    ),
  );
}

String toFirebaseEncrypted(String? x) => '';

// GOOD: Encryption in method name (…Encrypted(…)) even when args reference key material
void _goodEncryptedMethodCallOnPrivateKey1010() {
  driftDb.write(
    _DriftLikeCompanion(
      privateKey: _DriftValue(toFirebaseEncrypted(plainPrivateKey)),
    ),
  );
}

class _DriftValue {
  _DriftValue(this.x);
  final dynamic x;
}

class _DriftLikeCompanion {
  _DriftLikeCompanion({this.privateKey, this.publicKey, this.token, this.other});
  final dynamic privateKey;
  final dynamic publicKey;
  final dynamic token;
  final dynamic other;
}

/// Regression: type names such as [OwaspMapping] contain the substring `pin`
/// inside `Mapping`; the rule must not flag this call.
class OwaspMappingFixture1010 {}

class FakeViolationExporter1010 {
  static void write({
    required String projectRoot,
    required String sessionId,
    required Object data,
    required Map<String, OwaspMappingFixture1010> owaspLookup,
  }) {}
}

// GOOD: Should NOT trigger require_data_encryption (no `pin` token match)
void _goodOwaspMappingTypeArg1010() {
  FakeViolationExporter1010.write(
    projectRoot: '/',
    sessionId: 's',
    data: Object(),
    owaspLookup: const <String, OwaspMappingFixture1010>{},
  );
}

// Regression: bug `require_data_encryption_false_positive_search_index_tokens`.
// `searchTokens` / `searchIndex` / `lexerTokens` / `parserTokens` /
// `wordTokens` / `nGramTokens` / `routeTokens` / `cspTokens` are NOT
// credentials — they are denormalized search-index / NLP / parser / routing
// material derived from public data.
class _SearchIndexCompanion1010 {
  _SearchIndexCompanion1010({
    this.searchTokens,
    this.searchIndex,
    this.lexerTokens,
    this.parserTokens,
    this.wordTokens,
    this.nGramTokens,
    this.routeTokens,
    this.cspTokens,
  });
  final dynamic searchTokens;
  final dynamic searchIndex;
  final dynamic lexerTokens;
  final dynamic parserTokens;
  final dynamic wordTokens;
  final dynamic nGramTokens;
  final dynamic routeTokens;
  final dynamic cspTokens;
}

// GOOD: Drift-style write of denormalized search-index column. The bare
// `tokens` value variable holds a `|`-separated lowercase search index, NOT
// an auth token. The field name `searchTokens:` disambiguates intent.
void _goodSearchIndexTokens1010() {
  final String tokens = 'foo|bar|baz';
  driftDb.write(
    _SearchIndexCompanion1010(searchTokens: _DriftValue(tokens)),
  );
}

// GOOD: Compiler / NLP / routing token lists. None require encryption.
void _goodCompilerAndNlpTokens1010() {
  driftDb.write(
    _SearchIndexCompanion1010(
      lexerTokens: _DriftValue(<String>['IDENT', 'EQUAL']),
      parserTokens: _DriftValue(<String>['Stmt', 'Expr']),
      wordTokens: _DriftValue(<String>['the', 'quick', 'brown']),
      nGramTokens: _DriftValue(<String>['th', 'he', 'qu']),
      routeTokens: _DriftValue(<String>['users', 'profile']),
      cspTokens: _DriftValue(<String>["'self'", 'https:']),
    ),
  );
}

// GOOD: shared-prefs key written for a search-index lookup.
void _goodSharedPrefsSearchIndex1010() async {
  await prefs.setString('searchTokens', 'a|b|c');
}

// Regression: `auth` substring match flagged `authorship` / `authority` /
// `authored` / `authoring` — publishing & governance terms with no auth
// meaning. The bug-report's downstream cases include attribution metadata
// columns and governmental-jurisdiction lookups.
class _AuthorshipCompanion1010 {
  _AuthorshipCompanion1010({
    this.authorshipMetadata,
    this.authorPrefix,
    this.authority,
    this.authoredAt,
    this.authoringTool,
  });
  final dynamic authorshipMetadata;
  final dynamic authorPrefix;
  final dynamic authority; // governmental jurisdiction
  final dynamic authoredAt;
  final dynamic authoringTool;
}

// GOOD: Authorship / authority columns are NOT credentials.
void _goodAuthorshipMetadata1010() {
  driftDb.write(
    _AuthorshipCompanion1010(
      authorshipMetadata: _DriftValue('cc-by-sa'),
      authorPrefix: _DriftValue('Dr.'),
      authority: _DriftValue('NSW'),
      authoredAt: _DriftValue(DateTime.now()),
      authoringTool: _DriftValue('claude-code'),
    ),
  );
}

// BAD: Real credential identifiers must STILL trigger after the FP fix.
// Each of these uses a credential-context prefix (auth, api, access, refresh,
// bearer, jwt, csrf, session, oauth, id, authorize, authentication) that the
// regex deliberately preserves.
// expect_lint: require_data_encryption
void _badCredentialTokensStillTrigger1010() async {
  await prefs.setString('authToken', 'abc.def.ghi');
}

// expect_lint: require_data_encryption
void _badApiTokenStillTriggers1010() async {
  await prefs.setString('apiToken', 'sk_live_xxx');
}

// expect_lint: require_data_encryption
void _badAccessTokenStillTriggers1010() async {
  await prefs.setString('accessToken', 'eyJhbGciOi');
}

// expect_lint: require_data_encryption
void _badAuthorizeStillTriggers1010() async {
  // `authorize` matches _authKeywordPattern via the `or(?!iz)` lookahead
  // exception. No other sensitive keyword in the call.
  await prefs.setString('authorize_endpoint', 'value');
}

// expect_lint: require_data_encryption
void _badAuthenticationStillTriggers1010() async {
  // `authentication` matches _authKeywordPattern (no `or` follows `auth`).
  // No other sensitive keyword in the call.
  await prefs.setString('authentication_state', 'value');
}
