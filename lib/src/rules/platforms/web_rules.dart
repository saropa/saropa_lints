// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Web platform-specific lint rules for Flutter applications.
///
/// These rules help ensure Flutter web apps handle browser-specific concerns
/// like CORS, platform channels, URL strategies, web renderers, and
/// deferred loading for optimal performance.
///
/// ## Web Considerations
///
/// Flutter web apps have additional considerations:
/// - **Platform channels**: MethodChannel not available on web
/// - **CORS**: Browser enforces cross-origin restrictions
/// - **URL strategy**: Hash vs path URLs affect SEO
/// - **Web renderers**: HTML and CanvasKit have different capabilities
/// - **Bundle size**: Large imports increase initial load time
///
/// ## Related Documentation
///
/// - [Flutter Web](https://docs.flutter.dev/platform-integration/web/building)
/// - [Web Renderers](https://docs.flutter.dev/platform-integration/web/renderers)
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// avoid_platform_channel_on_web
// =============================================================================

/// Warns when MethodChannel is used without web platform check.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v4
///
/// MethodChannel is not available on web. Using it without a platform check
/// will crash the web build.
///
/// **BAD:**
/// ```dart
/// final platform = MethodChannel('my_channel');
/// final result = await platform.invokeMethod('getData');
/// ```
///
/// **GOOD (if statement):**
/// ```dart
/// if (!kIsWeb) {
///   final platform = MethodChannel('my_channel');
///   final result = await platform.invokeMethod('getData');
/// }
/// ```
///
/// **GOOD (ternary operator):**
/// ```dart
/// static const MethodChannel? _channel = kIsWeb
///     ? null
///     : MethodChannel('my_channel');
/// ```
class AvoidPlatformChannelOnWebRule extends SaropaLintRule {
  AvoidPlatformChannelOnWebRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_platform_channel_on_web',
    '[avoid_platform_channel_on_web] MethodChannel throws '
        'MissingPluginException on web, crashing the application. {v4}',
    correctionMessage: 'Wrap with kIsWeb check or use conditional imports.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'MethodChannel' &&
          typeName != 'EventChannel' &&
          typeName != 'BasicMessageChannel') {
        return;
      }

      // Check if wrapped in platform check
      if (_hasWebPlatformCheck(node)) return;

      reporter.atNode(node.constructorName, code);
    });
  }

  bool _hasWebPlatformCheck(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement) {
        final String condition = current.expression.toSource();
        if (_containsPlatformCheck(condition)) {
          return true;
        }
      }
      // Handle ternary operator: kIsWeb ? null : MethodChannel(...)
      if (current is ConditionalExpression) {
        final String condition = current.condition.toSource();
        if (_containsPlatformCheck(condition)) {
          return true;
        }
      }
      current = current.parent;
    }
    return false;
  }

  bool _containsPlatformCheck(String condition) {
    return condition.contains('kIsWeb') ||
        condition.contains('Platform.') ||
        condition.contains('defaultTargetPlatform');
  }
}

// =============================================================================
// require_cors_handling
// =============================================================================

/// Warns when HTTP calls on web lack CORS handling.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v3
///
/// Web browsers enforce CORS restrictions. HTTP calls may fail without
/// proper CORS headers from the server or proxy configuration.
///
/// **BAD:**
/// ```dart
/// final response = await http.get(Uri.parse('https://api.example.com/data'));
/// ```
///
/// **GOOD:**
/// ```dart
/// // Either configure server CORS headers, or:
/// final response = await http.get(
///   Uri.parse('https://api.example.com/data'),
///   headers: {'Access-Control-Allow-Origin': '*'},
/// );
/// // Or use a CORS proxy in development
/// ```
class RequireCorsHandlingRule extends SaropaLintRule {
  RequireCorsHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_cors_handling',
    '[require_cors_handling] HTTP calls from a Flutter web app fail silently without proper CORS headers from the server. The browser blocks cross-origin requests by default, causing network errors that prevent data loading, authentication, and API communication. Users see blank screens or broken functionality with no clear error message. {v3}',
    correctionMessage:
        'Configure the server to return Access-Control-Allow-Origin headers for your app domain, or route requests through a CORS proxy during development.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // This is a web-specific concern - check file path or conditionally run
    final String path = context.filePath;

    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for HTTP method calls
      if (methodName != 'get' &&
          methodName != 'post' &&
          methodName != 'put' &&
          methodName != 'delete' &&
          methodName != 'patch') {
        return;
      }

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('http') && !targetSource.contains('Http')) {
        return;
      }

      // Check if inside web-specific code or has CORS consideration
      if (path.contains('_web.dart') || path.contains('/web/')) {
        // Web-specific file, check for CORS handling
        final String source = node.toSource();
        if (!source.contains('cors') &&
            !source.contains('CORS') &&
            !source.contains('Access-Control')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

// =============================================================================
// prefer_deferred_loading_web
// =============================================================================

/// Warns when large imports are not deferred on web.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v4
///
/// Web apps should defer loading large libraries to improve initial load time.
/// Use deferred loading for heavy packages.
///
/// **BAD:**
/// ```dart
/// import 'package:heavy_charts/charts.dart';
/// ```
///
/// **GOOD:**
/// ```dart
/// import 'package:heavy_charts/charts.dart' deferred as charts;
///
/// // Then load when needed:
/// await charts.loadLibrary();
/// charts.LineChart(...)
/// ```
class PreferDeferredLoadingWebRule extends SaropaLintRule {
  PreferDeferredLoadingWebRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_deferred_loading_web',
    '[prefer_deferred_loading_web] Large package imported eagerly increases initial bundle size. Web apps should defer loading large libraries to improve initial load time. Use deferred loading for heavy packages. {v4}',
    correctionMessage:
        'Use "deferred as" import to reduce initial load time. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  // Packages that are typically large and should be deferred on web
  static const Set<String> _heavyPackages = <String>{
    'fl_chart',
    'syncfusion',
    'charts',
    'flutter_map',
    'google_maps',
    'video_player',
    'camera',
    'pdf',
    'printing',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addImportDirective((ImportDirective node) {
      final String? uri = node.uri.stringValue;
      if (uri == null) return;

      // Check if importing a heavy package
      bool isHeavy = false;
      for (final String pkg in _heavyPackages) {
        if (uri.contains(pkg)) {
          isHeavy = true;
          break;
        }
      }

      if (!isHeavy) return;

      // Check if deferred
      if (node.deferredKeyword == null) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// avoid_web_only_dependencies
// =============================================================================

/// Warns when web-only packages are imported in non-web code.
///
/// Since: v4.1.6 | Updated: v4.13.0 | Rule version: v3
///
/// dart:html and related web APIs don't exist on mobile/desktop.
/// Use conditional imports for cross-platform code.
///
/// **BAD:**
/// ```dart
/// import 'dart:html'; // Crashes on mobile!
///
/// void main() {
///   document.body?.append(DivElement());
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use conditional imports
/// import 'stub_html.dart'
///   if (dart.library.html) 'dart:html';
/// ```
class AvoidWebOnlyDependenciesRule extends SaropaLintRule {
  AvoidWebOnlyDependenciesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_web_only_dependencies',
    '[avoid_web_only_dependencies] Importing web-only libraries such as dart:html, dart:js, or dart:indexed_db in a Flutter or Dart app that targets mobile or desktop platforms will cause the app to crash with UnsupportedError at startup. This makes the app completely unusable for non-web users and can result in poor user experience, negative reviews, and lost users. Web-only dependencies must be isolated to web-specific code. {v3}',
    correctionMessage:
        'Use conditional imports or platform-agnostic alternatives to ensure your app runs on all supported platforms. Refactor code to isolate web-only dependencies behind platform checks or abstractions, and test your app on all target platforms to catch unsupported imports before release.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _webOnlyImports = {
    'dart:html',
    'dart:indexed_db',
    'dart:js',
    'dart:js_util',
    'dart:svg',
    'dart:web_audio',
    'dart:web_gl',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addImportDirective((ImportDirective node) {
      final String? uri = node.uri.stringValue;
      if (uri == null) return;

      if (_webOnlyImports.contains(uri)) {
        // Check if it's a conditional import
        if (node.configurations.isNotEmpty) {
          return; // Conditional import is fine
        }
        reporter.atNode(node);
      }
    });
  }
}

// cspell:ignore myapp
// =============================================================================
// prefer_url_strategy_for_web
// =============================================================================

/// Warns when web apps don't use path URL strategy.
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v2
///
/// Hash URLs (/#/page) look ugly and hurt SEO. Use PathUrlStrategy for
/// clean URLs in production web apps.
///
/// **BAD:**
/// ```dart
/// // URLs like: myapp.com/#/home, myapp.com/#/settings
/// void main() {
///   runApp(MyApp()); // Uses hash URLs by default
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// // URLs like: myapp.com/home, myapp.com/settings
/// void main() {
///   usePathUrlStrategy(); // Call before runApp
///   runApp(MyApp());
/// }
/// ```
class PreferUrlStrategyForWebRule extends SaropaLintRule {
  PreferUrlStrategyForWebRule() : super(code: _code);

  /// Hash URLs hurt SEO and look unprofessional.
  /// App works but may rank lower in search results.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_url_strategy_for_web',
    '[prefer_url_strategy_for_web] Flutter web defaults to hash-based URLs (e.g. /#/page) which are unfriendly to search engines, break social media link previews, and look unprofessional. Path-based URLs (/page) enable proper SEO indexing, shareable deep links, and server-side routing support. {v2}',
    correctionMessage:
        'Call usePathUrlStrategy() before runApp() in main(), or configure url_strategy in your router package to produce clean path-based URLs.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String path = context.filePath;

    // Only check web-related files or main.dart
    if (!path.endsWith('main.dart') &&
        !path.contains('/web/') &&
        !path.contains(r'\web\')) {
      return;
    }

    context.addFunctionDeclaration((FunctionDeclaration node) {
      if (node.name.lexeme != 'main') return;

      final String mainSource = node.toSource();

      // Check if has runApp but no URL strategy
      if (mainSource.contains('runApp') &&
          !mainSource.contains('usePathUrlStrategy') &&
          !mainSource.contains('setPathUrlStrategy') &&
          !mainSource.contains('UrlStrategy')) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

// =============================================================================
// require_web_renderer_awareness
// =============================================================================

/// Warns when kIsWeb is used without considering renderer type.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
///
/// Flutter web has different renderers (HTML, CanvasKit, Skia) with
/// different capabilities. Code assuming one renderer may fail on others.
///
/// **BAD:**
/// ```dart
/// if (kIsWeb) {
///   // Assumes HTML renderer capabilities
///   html.window.localStorage['key'] = value;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// if (kIsWeb) {
///   // Check renderer if using renderer-specific features
///   if (isCanvasKit) {
///     // CanvasKit-specific code
///   } else {
///     // HTML renderer code
///   }
/// }
/// ```
///
/// **Note:** This is an INFO-level reminder. Not all web code is
/// renderer-dependent.
class RequireWebRendererAwarenessRule extends SaropaLintRule {
  RequireWebRendererAwarenessRule() : super(code: _code);

  /// Platform compatibility issue.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_web_renderer_awareness',
    '[require_web_renderer_awareness] kIsWeb check without renderer consideration. Behavior may vary. Flutter web has different renderers (HTML, CanvasKit, Skia) with different capabilities. Code assuming one renderer may fail on others. {v3}',
    correctionMessage:
        'Check if the web-specific code depends on HTML DOM access (HTML renderer only) or canvas features (CanvasKit only). Use dart:js_interop or conditional imports for renderer-specific behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addIfStatement((node) {
      // Check if condition uses kIsWeb
      final conditionSource = node.expression.toSource();
      if (!conditionSource.contains('kIsWeb')) {
        return;
      }

      // Check if body uses renderer-specific APIs
      final bodySource = node.thenStatement.toSource().toLowerCase();

      // cspell:ignore sessionstorage
      // HTML-specific patterns
      final htmlPatterns = [
        'html.',
        'dart:html',
        'window.',
        'document.',
        'localstorage',
        'sessionstorage',
      ];

      final usesHtmlApis = htmlPatterns.any((p) => bodySource.contains(p));

      if (!usesHtmlApis) {
        return;
      }

      // Check if there's renderer awareness
      final blockSource = node.toSource().toLowerCase();
      if (blockSource.contains('canvaskit') ||
          blockSource.contains('renderer') ||
          blockSource.contains('skwasm')) {
        return;
      }

      reporter.atNode(node.expression, code);
    });
  }
}
