// ignore_for_file: unused_local_variable, avoid_print, unused_element
// ignore_for_file: depend_on_referenced_packages
// ignore_for_file: prefer_const_constructors, unnecessary_import
// ignore_for_file: unused_import, avoid_unused_constructor_parameters
// ignore_for_file: override_on_non_overriding_member, annotate_overrides
// ignore_for_file: duplicate_ignore, non_abstract_class_inherits_abstract_member
// ignore_for_file: extends_non_class, mixin_of_non_class
// ignore_for_file: field_initializer_outside_constructor, final_not_initialized
// ignore_for_file: super_in_invalid_context, concrete_class_with_abstract_member
// ignore_for_file: type_argument_not_matching_bounds, missing_required_argument
// ignore_for_file: undefined_named_parameter, argument_type_not_assignable
// ignore_for_file: invalid_constructor_name, super_formal_parameter_without_associated_named
// ignore_for_file: undefined_annotation, creation_with_non_type
// ignore_for_file: invalid_factory_name_not_a_class, invalid_reference_to_this
// ignore_for_file: expected_class_member, body_might_complete_normally
// ignore_for_file: not_initialized_non_nullable_instance_field, unchecked_use_of_nullable_value
// ignore_for_file: return_of_invalid_type, use_of_void_result
// ignore_for_file: missing_function_body, extra_positional_arguments
// ignore_for_file: not_enough_positional_arguments, unused_label
// ignore_for_file: unused_element_parameter, non_type_as_type_argument
// ignore_for_file: expected_identifier_but_got_keyword, expected_token
// ignore_for_file: missing_identifier, unexpected_token
// ignore_for_file: duplicate_definition, override_on_non_overriding_member
// ignore_for_file: extends_non_class, no_default_super_constructor
// ignore_for_file: extra_positional_arguments_could_be_named, missing_function_parameters
// ignore_for_file: invalid_annotation, invalid_assignment
// ignore_for_file: expected_executable, named_parameter_outside_group
// ignore_for_file: obsolete_colon_for_default_value, referenced_before_declaration
// ignore_for_file: await_in_wrong_context, non_type_in_catch_clause
// ignore_for_file: could_not_infer, uri_does_not_exist
// ignore_for_file: const_method, redirect_to_non_class
// ignore_for_file: unused_catch_clause, type_test_with_undefined_name
// ignore_for_file: undefined_identifier, undefined_function
// ignore_for_file: undefined_method, undefined_getter
// ignore_for_file: undefined_setter, undefined_class
// ignore_for_file: undefined_super_member, extraneous_modifier
// ignore_for_file: experiment_not_enabled, missing_const_final_var_or_type
// ignore_for_file: undefined_operator, dead_code
// ignore_for_file: invalid_override, not_initialized_non_nullable_variable
// ignore_for_file: list_element_type_not_assignable, assignment_to_final
// ignore_for_file: equal_elements_in_set, prefix_shadowed_by_local_declaration
// ignore_for_file: const_initialized_with_non_constant_value, non_constant_list_element
// ignore_for_file: missing_statement, unnecessary_cast
// ignore_for_file: unnecessary_null_comparison, unnecessary_type_check
// ignore_for_file: invalid_super_formal_parameter_location, assignment_to_type
// ignore_for_file: instance_member_access_from_factory, field_initializer_not_assignable
// ignore_for_file: constant_pattern_with_non_constant_expression, undefined_identifier_await
// ignore_for_file: cast_to_non_type, read_potentially_unassigned_final
// ignore_for_file: mixin_with_non_class_superclass, instantiate_abstract_class
// ignore_for_file: dead_code_on_catch_subtype, unreachable_switch_case
// ignore_for_file: new_with_undefined_constructor, assignment_to_final_local
// ignore_for_file: late_final_local_already_assigned, missing_default_value_for_parameter
// ignore_for_file: non_bool_condition, non_exhaustive_switch_expression
// ignore_for_file: illegal_async_return_type, type_test_with_non_type
// ignore_for_file: invocation_of_non_function_expression, return_of_invalid_type_from_closure
// ignore_for_file: wrong_number_of_type_arguments_constructor, definitely_unassigned_late_local_variable
// ignore_for_file: static_access_to_instance_member, const_with_undefined_constructor
// ignore_for_file: abstract_super_member_reference, equal_keys_in_map
// ignore_for_file: unused_catch_stack, non_constant_default_value
// ignore_for_file: not_a_type

/// Test fixtures for package-specific lint rules.
///
/// Note: Many of these rules require specific package imports (google_sign_in,
/// supabase_flutter, etc.) to fully test. The patterns shown here demonstrate
/// the detection logic using simplified mock types.

// =============================================================================
// Mock types for testing (simulating package APIs)
// =============================================================================

// Mock Google Sign-In
class GoogleSignIn {
  Future<GoogleSignInAccount?> signIn() async => null;
  Future<GoogleSignInAccount?> signInSilently() async => null;
}

class GoogleSignInAccount {}

// Mock Supabase
class Supabase {
  static final Supabase instance = Supabase._();
  Supabase._();
  SupabaseClient get client => SupabaseClient();
}

class SupabaseClient {
  SupabaseQueryBuilder from(String table) => SupabaseQueryBuilder();
  RealtimeChannel channel(String name) => RealtimeChannel();
}

class SupabaseQueryBuilder {
  Future<List<dynamic>> select() async => [];
  Future<void> insert(Map<String, dynamic> data) async {}
}

class RealtimeChannel {
  RealtimeChannel subscribe() => this;
  void unsubscribe() {}
}

// Mock WebView
class WebView {
  WebView({String? initialUrl, void Function(dynamic, dynamic)? onSslError});
}

class NavigationDelegate {
  NavigationDelegate({void Function(dynamic, dynamic, dynamic)? onSslError});
}

// Mock WorkManager
class Workmanager {
  void registerPeriodicTask(String id, String name, {dynamic constraints}) {}
  void executeTask(Future<bool> Function(String, Map<String, dynamic>?) task) {}
}

// Mock SpeechToText
class SpeechToText {
  Future<void> listen({void Function(dynamic)? onResult}) async {}
  void stop() {}
}

// Mock SvgPicture
class SvgPicture {
  static Widget asset(String path, {Widget Function(dynamic)? errorBuilder}) =>
      Container();
  static Widget network(String url, {Widget Function(dynamic)? errorBuilder}) =>
      Container();
}

// Mock GoogleFonts
class GoogleFonts {
  static TextStyle roboto({List<String>? fontFamilyFallback}) => TextStyle();
  static TextStyle lato({List<String>? fontFamilyFallback}) => TextStyle();
}

// Mock Flutter types
class Widget {}

class Container extends Widget {}

class TextStyle {}

class State<T> {
  void dispose() {}
}

// Mock Uuid
class Uuid {
  String v1() => '';
  String v4() => '';
}

// =============================================================================
// TEST FIXTURES
// =============================================================================

// -----------------------------------------------------------------------------
// require_google_signin_error_handling
// -----------------------------------------------------------------------------

Future<void> testGoogleSignInWithoutTryCatch() async {
  final googleSignIn = GoogleSignIn();

  // expect_lint: require_google_signin_error_handling
  final account = await googleSignIn.signIn();
}

Future<void> testGoogleSignInWithTryCatch() async {
  final googleSignIn = GoogleSignIn();

  // GOOD: Has try-catch
  try {
    final account = await googleSignIn.signIn();
  } catch (e) {
    print('Error: $e');
  }
}

// -----------------------------------------------------------------------------
// require_supabase_error_handling
// -----------------------------------------------------------------------------

Future<void> testSupabaseWithoutTryCatch() async {
  final supabase = Supabase.instance.client;

  // expect_lint: require_supabase_error_handling
  final data = await supabase.from('users').select();
}

Future<void> testSupabaseWithTryCatch() async {
  final supabase = Supabase.instance.client;

  // GOOD: Has try-catch
  try {
    final data = await supabase.from('users').select();
  } catch (e) {
    print('Error: $e');
  }
}

// -----------------------------------------------------------------------------
// avoid_openai_key_in_code
// -----------------------------------------------------------------------------

void testOpenAiKeyInCode() {
  // expect_lint: avoid_openai_key_in_code
  const key = 'sk-1234567890abcdefghijklmnopqrstuvwxyz';

  // GOOD: Use environment variable
  // const key = String.fromEnvironment('OPENAI_KEY');
}

// -----------------------------------------------------------------------------
// require_webview_ssl_error_handling (Legacy)
// -----------------------------------------------------------------------------

void testWebViewWithoutSslHandler() {
  // expect_lint: require_webview_ssl_error_handling
  final webView = WebView(
    initialUrl: 'https://example.com',
  );
}

void testWebViewWithSslHandler() {
  // GOOD: Has onSslError
  final webView = WebView(
    initialUrl: 'https://example.com',
    onSslError: (controller, error) {},
  );
}

// -----------------------------------------------------------------------------
// require_webview_ssl_error_handling (Modern NavigationDelegate)
// -----------------------------------------------------------------------------

void testNavigationDelegateWithoutSslHandler() {
  // expect_lint: require_webview_ssl_error_handling
  final delegate = NavigationDelegate();
}

void testNavigationDelegateWithSslHandler() {
  // GOOD: Has onSslError
  final delegate = NavigationDelegate(
    onSslError: (controller, error, callback) {},
  );
}

// -----------------------------------------------------------------------------
// require_workmanager_constraints
// -----------------------------------------------------------------------------

void testWorkmanagerWithoutConstraints() {
  final workmanager = Workmanager();

  // expect_lint: require_workmanager_constraints
  workmanager.registerPeriodicTask('sync', 'syncTask');
}

void testWorkmanagerWithConstraints() {
  final workmanager = Workmanager();

  // GOOD: Has constraints
  workmanager.registerPeriodicTask(
    'sync',
    'syncTask',
    constraints: Object(), // Constraints object
  );
}

// -----------------------------------------------------------------------------
// require_workmanager_result_return
// -----------------------------------------------------------------------------

void testWorkmanagerWithoutReturn() {
  final workmanager = Workmanager();

  // expect_lint: require_workmanager_result_return
  workmanager.executeTask((task, inputData) async {
    print('Working...');
    // No return!
  });
}

void testWorkmanagerWithReturn() {
  final workmanager = Workmanager();

  // GOOD: Has return statement
  workmanager.executeTask((task, inputData) async {
    print('Working...');
    return true;
  });
}

// -----------------------------------------------------------------------------
// require_speech_stop_on_dispose
// -----------------------------------------------------------------------------

class _BadSpeechState extends State<Widget> {
  // expect_lint: require_speech_stop_on_dispose
  final SpeechToText _speech = SpeechToText();

  void startListening() async {
    await _speech.listen(onResult: (result) {});
  }

  // Missing _speech.stop() in dispose!
}

class _GoodSpeechState extends State<Widget> {
  final SpeechToText _speech = SpeechToText();

  void startListening() async {
    await _speech.listen(onResult: (result) {});
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}

// -----------------------------------------------------------------------------
// require_svg_error_handler
// -----------------------------------------------------------------------------

void testSvgWithoutErrorBuilder() {
  // expect_lint: require_svg_error_handler
  final svg = SvgPicture.asset('assets/icon.svg');

  // expect_lint: require_svg_error_handler
  final svgNetwork = SvgPicture.network('https://example.com/icon.svg');
}

void testSvgWithErrorBuilder() {
  // GOOD: Has errorBuilder
  final svg = SvgPicture.asset(
    'assets/icon.svg',
    errorBuilder: (error) => Container(),
  );
}

// -----------------------------------------------------------------------------
// require_google_fonts_fallback
// -----------------------------------------------------------------------------

void testGoogleFontsWithoutFallback() {
  // expect_lint: require_google_fonts_fallback
  final style = GoogleFonts.roboto();
}

void testGoogleFontsWithFallback() {
  // GOOD: Has fontFamilyFallback
  final style = GoogleFonts.roboto(
    fontFamilyFallback: ['Arial', 'sans-serif'],
  );
}

// -----------------------------------------------------------------------------
// prefer_uuid_v4
// -----------------------------------------------------------------------------

void testUuidV1() {
  final uuid = Uuid();

  // expect_lint: prefer_uuid_v4
  final id = uuid.v1();
}

void testUuidV4() {
  final uuid = Uuid();

  // GOOD: Uses v4
  final id = uuid.v4();
}

// -----------------------------------------------------------------------------
// avoid_freezed_for_logic_classes (from v4.1.4)
// -----------------------------------------------------------------------------

const freezed = _Freezed();

class _Freezed {
  const _Freezed();
}

// BAD: Freezed on logic class
// expect_lint: avoid_freezed_for_logic_classes
@freezed
class BadUserService {}

// GOOD: Freezed on data class
@freezed
class UserData {}

// -----------------------------------------------------------------------------
// Firebase Rules (from v4.1.5)
// -----------------------------------------------------------------------------

Future<void> testFirebaseWithoutErrorHandling() async {
  // expect_lint: require_firebase_error_handling
  await FirebaseFirestoreDemo.instance.collection('users').get();
}

class FirebaseInBuildWidgetDemo extends StatelessWidgetDemo {
  const FirebaseInBuildWidgetDemo({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_firebase_realtime_in_build
    final stream =
        FirebaseFirestoreDemo.instance.collection('users').snapshots();
    return Container();
  }
}

// GOOD: Firebase with error handling
Future<void> testFirebaseWithErrorHandling() async {
  try {
    await FirebaseFirestoreDemo.instance.collection('users').get();
  } on FirebaseExceptionDemo catch (e) {
    print('Error: $e');
  }
}

// Firebase mocks
class FirebaseFirestoreDemo {
  static final FirebaseFirestoreDemo instance = FirebaseFirestoreDemo._();
  FirebaseFirestoreDemo._();
  CollectionReferenceDemo collection(String path) => CollectionReferenceDemo();
}

class CollectionReferenceDemo {
  Future<Object> get() async => Object();
  Stream<Object> snapshots() => Stream.empty();
}

class FirebaseExceptionDemo implements Exception {
  final String message;
  FirebaseExceptionDemo(this.message);
}

abstract class StatelessWidgetDemo {
  const StatelessWidgetDemo({this.key});
  final Object? key;
  Widget build(BuildContext context);
}

class BuildContext {}
