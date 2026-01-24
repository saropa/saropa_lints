// ignore_for_file: unused_local_variable, unused_element, unused_field
// Test fixture for navigation rules added in v2.3.10

import '../flutter_mocks.dart';

// =========================================================================
// prefer_url_launcher_uri_over_string
// =========================================================================
// Warns when launchUrl is used with string parsing instead of Uri objects.

// BAD: Using Uri.parse() inside launchUrl
Future<void> badLaunchUrlWithParse() async {
  // expect_lint: prefer_url_launcher_uri_over_string
  await launchUrl(Uri.parse('https://example.com'));
}

// BAD: Using Uri.parse() inside canLaunchUrl
Future<void> badCanLaunchWithParse() async {
  // expect_lint: prefer_url_launcher_uri_over_string
  final canLaunch = await canLaunchUrl(Uri.parse('https://example.com'));
}

// GOOD: Using Uri.https() constructor
Future<void> goodLaunchUrlWithConstructor() async {
  final uri = Uri.https('example.com', '/path');
  await launchUrl(uri);
}

// GOOD: Using pre-constructed Uri
Future<void> goodLaunchUrlPreConstructed() async {
  const uri = Uri(scheme: 'https', host: 'example.com');
  await launchUrl(uri);
}

// =========================================================================
// avoid_go_router_push_replacement_confusion
// =========================================================================
// Warns about potential confusion between go() and push() in GoRouter.

// BAD: Using go() for detail route with dynamic ID (probably wants push)
class BadGoRouterGo extends StatelessWidget {
  const BadGoRouterGo({super.key});

  void navigateToDetail(BuildContext context, String id) {
    // expect_lint: avoid_go_router_push_replacement_confusion
    context.go('/details/$id'); // Replaces stack - back button won't work
  }

  void navigateToItem(BuildContext context, String itemId) {
    // expect_lint: avoid_go_router_push_replacement_confusion
    context.go('/item/$itemId'); // Same issue
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Using push() for detail routes
class GoodGoRouterPush extends StatelessWidget {
  const GoodGoRouterPush({super.key});

  void navigateToDetail(BuildContext context, String id) {
    context.push('/details/$id'); // Adds to stack - back button works
  }

  @override
  Widget build(BuildContext context) => Container();
}

// GOOD: Using go() for root routes (intentional stack replacement)
class GoodGoRouterGoRoot extends StatelessWidget {
  const GoodGoRouterGoRoot({super.key});

  void navigateHome(BuildContext context) {
    context.go('/home'); // Root route - stack replacement is intentional
  }

  void navigateToDashboard(BuildContext context) {
    context.go('/dashboard'); // Main section - intentional
  }

  @override
  Widget build(BuildContext context) => Container();
}

// =========================================================================
// Helper mocks
// =========================================================================

Future<bool> launchUrl(Uri url) async => true;
Future<bool> canLaunchUrl(Uri url) async => true;

class Uri {
  const Uri({this.scheme, this.host, this.path});
  final String? scheme;
  final String? host;
  final String? path;

  static Uri parse(String source) => Uri();
  static Uri https(String host, String path) => Uri(
        scheme: 'https',
        host: host,
        path: path,
      );
}

extension GoRouterExtension on BuildContext {
  void go(String path) {}
  void push(String path) {}
  void pushReplacement(String path) {}
}

// =========================================================================
// Navigation Rules (from v4.1.4)
// =========================================================================

void testRouteSettings(BuildContext context) {
  // expect_lint: prefer_route_settings_name
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => Container()),
  );

  // GOOD: With RouteSettings
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Container(),
      settings: const RouteSettings(name: '/details'),
    ),
  );
}

// Mock Navigator
class Navigator {
  static NavigatorState of(BuildContext context) => NavigatorState();
}

class NavigatorState {
  Future<T?> push<T>(Route<T> route) async => null;
}

class Route<T> {}

class MaterialPageRoute<T> extends Route<T> {
  MaterialPageRoute({required this.builder, this.settings});
  final Widget Function(BuildContext) builder;
  final RouteSettings? settings;
}

class RouteSettings {
  const RouteSettings({this.name, this.arguments});
  final String? name;
  final Object? arguments;
}

// =========================================================================
// avoid_navigator_context_issue
// =========================================================================
// Warns when using GlobalKey.currentContext or NavigatorState.context for
// navigation, which can cause navigation failures.

final GlobalKey<State<StatefulWidget>> scaffoldKey = GlobalKey();
final GlobalKey<State<StatefulWidget>> navKey = GlobalKey();

// BAD: Using GlobalKey.currentContext with Navigator.of
void badNavigatorOfWithCurrentContext() {
  // expect_lint: avoid_navigator_context_issue
  Navigator.of(scaffoldKey.currentContext!).push(
    MaterialPageRoute(builder: (_) => Container()),
  );
}

// BAD: Using GlobalKey.currentContext with Navigator static method
void badNavigatorPushWithCurrentContext(BuildContext context) {
  // This pattern is less common but still problematic
  final ctx = navKey.currentContext;
  if (ctx != null) {
    Navigator.of(ctx).push(
      // expect_lint: avoid_navigator_context_issue
      MaterialPageRoute(builder: (_) => Container()),
    );
  }
}

// GOOD: Using direct BuildContext from widget tree
void goodNavigatorOfWithContext(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => Container()),
  );
}

// GOOD: Using context with mounted check
void goodNavigatorWithMountedCheck(BuildContext context) async {
  await Future.delayed(const Duration(seconds: 1));
  if (context.mounted) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => Container()),
    );
  }
}

// GOOD: Scrollable.ensureVisible with currentContext is legitimate
void goodScrollableEnsureVisible() {
  final ctx = navKey.currentContext;
  if (ctx != null) {
    Scrollable.ensureVisible(ctx);
  }
}

// GOOD: Property names containing "context" should not trigger
class ContextMessageWidget extends StatelessWidget {
  const ContextMessageWidget({super.key, required this.contextMessage});
  final String contextMessage;

  @override
  Widget build(BuildContext context) {
    return AlertDialogMessage(message: contextMessage);
  }
}

// Helper mocks
class GlobalKey<T extends State<StatefulWidget>> {
  BuildContext? get currentContext => null;
}

class Scrollable {
  static void ensureVisible(BuildContext context) {}
}

class AlertDialogMessage extends StatelessWidget {
  const AlertDialogMessage({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container();
}
