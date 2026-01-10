// ignore_for_file: unused_local_variable, avoid_print, unused_element
// ignore_for_file: depend_on_referenced_packages

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
