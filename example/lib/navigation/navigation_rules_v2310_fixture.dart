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
