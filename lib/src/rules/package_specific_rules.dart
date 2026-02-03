// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Package-specific lint rules for common Flutter/Dart packages.
///
/// These rules ensure proper usage patterns for popular packages like
/// google_sign_in, supabase, webview_flutter, workmanager, and others.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:analyzer/source/source_range.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../saropa_lint_rule.dart';

// =============================================================================
// AUTHENTICATION RULES
// =============================================================================

/// Warns when Google Sign-In calls lack try-catch error handling.
///
/// Alias: google_signin_try_catch, handle_google_signin_errors
///
/// Google Sign-In can fail for various reasons (network, user cancellation,
/// configuration issues). Without error handling, the app may crash.
///
/// **BAD:**
/// ```dart
/// Future<void> signIn() async {
///   final GoogleSignInAccount? account = await _googleSignIn.signIn();
///   // No error handling!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<void> signIn() async {
///   try {
///     final GoogleSignInAccount? account = await _googleSignIn.signIn();
///   } catch (e) {
///     // Handle sign-in failure
///   }
/// }
/// ```
class RequireGoogleSigninErrorHandlingRule extends SaropaLintRule {
  const RequireGoogleSigninErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_google_signin_error_handling',
    problemMessage:
        '[require_google_signin_error_handling] Google Sign-In call without error handling crashes when the user cancels the sign-in flow, the network is unavailable, or Google Play Services are outdated. Users see an unhandled exception crash screen instead of a friendly error message, causing frustration and potential data loss in unsaved work.',
    correctionMessage:
        'Wrap the signIn() call in a try-catch block that handles PlatformException and network errors, and display a user-friendly error message with a retry option.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'signIn' && methodName != 'signInSilently') return;

      // Check if it's likely a GoogleSignIn call
      final String? targetType = node.target?.toSource();
      if (targetType == null) return;

      final bool isGoogleSignIn = targetType.contains('googleSignIn') ||
          targetType.contains('GoogleSignIn') ||
          targetType.contains('_googleSignIn');

      if (!isGoogleSignIn) return;

      // Check if wrapped in try-catch
      AstNode? current = node.parent;
      while (current != null) {
        if (current is TryStatement) return; // Has try-catch, OK
        if (current is FunctionBody) break;
        current = current.parent;
      }

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddTryCatchTodoFix(code)];
}

class _AddTryCatchTodoFix extends DartFix {
  // ignore: avoid_unused_constructor_parameters
  _AddTryCatchTodoFix(LintCode _);

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      // Find the statement containing this method invocation
      AstNode? statementNode = node.parent;
      while (statementNode != null && statementNode is! Statement) {
        statementNode = statementNode.parent;
      }

      if (statementNode == null) return;

      // Get the indentation of the current statement
      final int statementOffset = statementNode.offset;
      final String sourceCode = resolver.source.contents.data;
      int lineStart = statementOffset;
      while (lineStart > 0 && sourceCode[lineStart - 1] != '\n') {
        lineStart--;
      }
      final String leadingWhitespace =
          sourceCode.substring(lineStart, statementOffset);
      final String indent =
          leadingWhitespace.isEmpty ? '  ' : leadingWhitespace;

      final String statementSource = statementNode.toSource();

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Wrap in try-catch',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(statementNode!.offset, statementNode.length),
          'try {\n$indent  $statementSource\n$indent} catch (e) {\n$indent  // Handle error\n$indent  rethrow;\n$indent}',
        );
      });
    });
  }
}

class _AddEnvVarTodoFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK: Use environment variable',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Use environment variable or secure storage instead\n',
        );
      });
    });
  }
}

class _AddDisposeTodoFix extends DartFix {
  _AddDisposeTodoFix(this._methodCall);
  final String _methodCall;

  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addVariableDeclaration((VariableDeclaration node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      // Find the full field declaration (including semicolon)
      AstNode? fieldDecl = node.parent?.parent;
      if (fieldDecl is! FieldDeclaration) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add FIXME reminder for $_methodCall',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        // Find where the semicolon is and insert comment before it
        final String fieldSource = fieldDecl.toSource();
        final int semicolonIndex = fieldSource.lastIndexOf(';');
        if (semicolonIndex == -1) return;

        builder.addSimpleInsertion(
          fieldDecl.offset + semicolonIndex,
          ' // FIXME: Add $_methodCall in dispose()',
        );
      });
    });
  }
}

/// Warns when Apple Sign-In is used without nonce parameter.
///
/// Alias: apple_signin_nonce, require_apple_nonce
///
/// ## Why This Matters
///
/// The nonce is a critical security layer that prevents **replay attacks**.
/// Without it, an attacker who intercepts a valid Apple ID token could reuse
/// it to authenticate as the victim indefinitely. The nonce ensures each
/// authentication attempt is unique and cannot be replayed.
///
/// ## How It Works
///
/// 1. Generate a cryptographically random nonce (raw nonce)
/// 2. Hash it with SHA-256 and pass the **hash** to Apple
/// 3. Apple embeds the hash in the ID token it returns
/// 4. Pass the **raw nonce** to your backend (e.g., Supabase)
/// 5. Backend hashes the raw nonce and verifies it matches the token
///
/// This two-step process ensures only the original requester can use the token.
///
/// **BAD:**
/// ```dart
/// // INSECURE: No nonce means tokens can be replayed by attackers
/// final credential = await SignInWithApple.getAppleIDCredential(
///   scopes: [AppleIDAuthorizationScopes.email],
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// // Generate nonce using Supabase's built-in method
/// final rawNonce = Supabase.instance.client.auth.generateRawNonce();
/// final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
///
/// final credential = await SignInWithApple.getAppleIDCredential(
///   scopes: [AppleIDAuthorizationScopes.email],
///   nonce: hashedNonce, // Hash goes to Apple
/// );
///
/// // Pass raw nonce to Supabase for verification
/// await Supabase.instance.client.auth.signInWithIdToken(
///   provider: OAuthProvider.apple,
///   idToken: credential.identityToken!,
///   nonce: rawNonce, // Raw nonce goes to Supabase
/// );
/// ```
///
/// See: https://supabase.com/docs/guides/auth/social-login/auth-apple
class RequireAppleSigninNonceRule extends SaropaLintRule {
  const RequireAppleSigninNonceRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_apple_signin_nonce',
    problemMessage:
        '[require_apple_signin_nonce] Omitting a cryptographic nonce when using Apple Sign-In exposes your app to replay attacks. Attackers can intercept a valid authorization token and reuse it to impersonate the user, gaining unauthorized access to their account and sensitive data. Apple’s security documentation strongly recommends using a unique, random nonce for every authentication request to prevent these attacks and ensure user safety.',
    correctionMessage:
        'Always provide a unique, random nonce parameter to getAppleIDCredential() when implementing Apple Sign-In. This binds the authentication request to a single session and prevents replay attacks. Review your authentication flows, update your code to generate and pass a secure nonce, and test thoroughly to ensure the nonce is included in every request.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'getAppleIDCredential') return;

      // Check for nonce parameter
      final ArgumentList args = node.argumentList;
      final bool hasNonce = args.arguments.any((Expression arg) {
        if (arg is NamedExpression) {
          return arg.name.label.name == 'nonce';
        }
        return false;
      });

      if (!hasNonce) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddNonceParameterFix()];
}

class _AddNonceParameterFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK: Add nonce parameter',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Add nonce parameter to prevent replay attacks\n',
        );
      });
    });
  }
}

// =============================================================================
// WEBVIEW RULES
// =============================================================================

/// Warns when WebView lacks SSL error handling callback.
///
/// Alias: webview_ssl_handler, require_ssl_error_callback
///
/// Without SSL error handling, WebView may silently fail on certificate issues
/// or allow insecure connections without user awareness.
///
/// **Note:** This rule supports both the legacy WebView constructor pattern
/// and the modern webview_flutter 4.0+ NavigationDelegate pattern.
///
/// **BAD (Legacy):**
/// ```dart
/// WebView(
///   initialUrl: 'https://example.com',
/// )
/// ```
///
/// **GOOD (Legacy):**
/// ```dart
/// WebView(
///   initialUrl: 'https://example.com',
///   onSslError: (controller, error) {
///     // Handle SSL error appropriately
///   },
/// )
/// ```
///
/// **BAD (Modern webview_flutter 4.0+):**
/// ```dart
/// NavigationDelegate()
/// ```
///
/// **GOOD (Modern webview_flutter 4.0+):**
/// ```dart
/// NavigationDelegate(
///   onSslAuthError: (SslAuthError error) async {
///     // Handle SSL certificate error - call error.cancel() or error.proceed()
///     await error.cancel();
///   },
/// )
/// ```
class RequireWebviewSslErrorHandlingRule extends SaropaLintRule {
  const RequireWebviewSslErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_webview_ssl_error_handling',
    problemMessage:
        '[require_webview_ssl_error_handling] If your WebView does not handle SSL certificate errors, it may silently accept invalid or malicious certificates, exposing users to man-in-the-middle attacks. Users may unknowingly submit sensitive information (such as passwords or payment details) to attackers, resulting in account compromise, data theft, or financial loss. Proper SSL error handling is essential for secure in-app browsing.',
    correctionMessage:
        'Implement an onSslAuthError callback in your WebView’s NavigationDelegate to detect and handle certificate errors. Warn users about invalid certificates, block navigation to untrusted sites, and log incidents for further review. Test your WebView implementation with both valid and invalid certificates to ensure robust SSL error handling.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      // Check for legacy WebView/InAppWebView constructors
      if (typeName == 'WebView' || typeName == 'InAppWebView') {
        final bool hasOnSslError = node.argumentList.arguments.any((arg) {
          if (arg is NamedExpression) {
            final String name = arg.name.label.name;
            return name == 'onSslError' ||
                name == 'onReceivedServerTrustAuthRequest';
          }
          return false;
        });

        if (!hasOnSslError) {
          reporter.atNode(node, code);
        }
        return;
      }

      // Check for modern webview_flutter 4.0+ NavigationDelegate pattern
      // Note: The correct callback is `onSslAuthError` (not `onSslError` which doesn't exist).
      // `onHttpAuthRequest` is for HTTP Basic/Digest auth (401 challenges), NOT SSL errors.
      // See: https://pub.dev/documentation/webview_flutter/latest/webview_flutter/NavigationDelegate-class.html
      if (typeName == 'NavigationDelegate') {
        final bool hasOnSslError = node.argumentList.arguments.any((arg) {
          if (arg is NamedExpression) {
            final String name = arg.name.label.name;
            return name == 'onSslAuthError';
          }
          return false;
        });

        if (!hasOnSslError) {
          reporter.atNode(node, code);
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddSslHandlerTodoFix()];
}

class _AddSslHandlerTodoFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK: Add onSslAuthError handler',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Add onSslAuthError callback to handle SSL certificate issues\n',
        );
      });
    });
  }
}

/// Warns when WebView has file access enabled.
///
/// Alias: webview_no_file_access, disable_webview_file_access
///
/// Enabling file access in WebView is a security risk as malicious web content
/// could potentially access local files on the device.
///
/// **BAD:**
/// ```dart
/// WebViewController()
///   ..setJavaScriptMode(JavaScriptMode.unrestricted)
///   ..allowFileAccess(true);
/// ```
///
/// **GOOD:**
/// ```dart
/// WebViewController()
///   ..setJavaScriptMode(JavaScriptMode.unrestricted);
/// // File access disabled by default
/// ```
class AvoidWebviewFileAccessRule extends SaropaLintRule {
  const AvoidWebviewFileAccessRule() : super(code: _code);

  // WARNING severity with high impact - security concern but not crash-causing
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_webview_file_access',
    problemMessage:
        '[avoid_webview_file_access] WebView file access enabled (allowFileAccess: true) creates a critical security vulnerability. Malicious web content loaded in the WebView can read local files including user data, cached credentials, and app configuration, then exfiltrate them to attacker-controlled servers without user consent or visible indication.',
    correctionMessage:
        'Remove allowFileAccess: true or explicitly set it to false. If file access is required, restrict it to specific directories and validate all file paths.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for allowFileAccess method call
      if (methodName == 'allowFileAccess' ||
          methodName == 'setAllowFileAccess') {
        final ArgumentList args = node.argumentList;
        if (args.arguments.isNotEmpty) {
          final String argValue = args.arguments.first.toSource();
          if (argValue == 'true') {
            reporter.atNode(node, code);
          }
        }
      }
    });

    // Also check named parameters
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;
      if (!typeName.contains('WebView') && !typeName.contains('Settings')) {
        return;
      }

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'allowFileAccess' ||
              name == 'allowFileAccessFromFileURLs') {
            final String value = arg.expression.toSource();
            if (value == 'true') {
              reporter.atNode(arg, code);
            }
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_RemoveFileAccessFix()];
}

class _RemoveFileAccessFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK: Remove file access',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Remove file access for security\n',
        );
      });
    });

    context.registry.addNamedExpression((NamedExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK: Remove file access',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Remove file access for security\n',
        );
      });
    });
  }
}

// =============================================================================
// CALENDAR/DATETIME RULES
// =============================================================================

/// Warns when device_calendar Event doesn't specify time zone handling.
///
/// Alias: calendar_timezone, device_calendar_timezone
///
/// Calendar events without explicit time zone handling may display at wrong
/// times when users travel or when syncing across devices.
///
/// **Note:** This rule specifically targets device_calendar package Events.
/// It requires both a positional calendarId AND start/end parameters to match,
/// reducing false positives from other Event classes.
///
/// **BAD:**
/// ```dart
/// final event = Event(
///   calendarId,
///   title: 'Meeting',
///   start: TZDateTime.now(local),
///   end: TZDateTime.now(local).add(Duration(hours: 1)),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// final event = Event(
///   calendarId,
///   title: 'Meeting',
///   start: TZDateTime.now(local),
///   end: TZDateTime.now(local).add(Duration(hours: 1)),
///   timeZone: 'America/New_York', // or local.name
/// );
/// ```
class RequireCalendarTimezoneHandlingRule extends SaropaLintRule {
  const RequireCalendarTimezoneHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_calendar_timezone_handling',
    problemMessage:
        '[require_calendar_timezone_handling] device_calendar Event is missing an explicit timeZone. This can cause events to appear at the wrong time for users in different time zones, leading to missed or misaligned appointments.',
    correctionMessage:
        'Add the timeZone parameter to device_calendar Event to ensure events are scheduled and displayed correctly across different time zones. This prevents confusion and missed appointments for users in other regions.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name2.lexeme;
      if (typeName != 'Event') return;

      final ArgumentList args = node.argumentList;

      // device_calendar Event requires a positional calendarId as first arg
      // This helps distinguish it from other Event classes
      final bool hasPositionalArg =
          args.arguments.isNotEmpty && args.arguments.first is! NamedExpression;
      if (!hasPositionalArg) return;

      // Must have both 'start' and 'end' named parameters (device_calendar pattern)
      bool hasStart = false;
      bool hasEnd = false;
      bool hasTimeZone = false;

      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'start') hasStart = true;
          if (name == 'end') hasEnd = true;
          if (name == 'timeZone') hasTimeZone = true;
        }
      }

      // Only flag if it looks like a device_calendar Event (has start AND end)
      if (!hasStart || !hasEnd) return;

      if (!hasTimeZone) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddTimezoneParameterFix()];
}

class _AddTimezoneParameterFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry
        .addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK: Add timeZone parameter',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Add timeZone parameter for cross-timezone support\n',
        );
      });
    });
  }
}

// =============================================================================
// DISPOSE PATTERN RULES
// =============================================================================

/// Warns when KeyboardVisibilityController is not disposed.
///
/// Alias: dispose_keyboard_visibility, keyboard_visibility_leak
///
/// KeyboardVisibilityController listeners must be cancelled to prevent
/// memory leaks and callbacks to disposed widgets.
///
/// **BAD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   late KeyboardVisibilityController _keyboardController;
///
///   @override
///   void initState() {
///     super.initState();
///     _keyboardController = KeyboardVisibilityController();
///     _keyboardController.onChange.listen((visible) {});
///   }
///   // Missing dispose!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyState extends State<MyWidget> {
///   late KeyboardVisibilityController _keyboardController;
///   StreamSubscription? _subscription;
///
///   @override
///   void initState() {
///     super.initState();
///     _keyboardController = KeyboardVisibilityController();
///     _subscription = _keyboardController.onChange.listen((visible) {});
///   }
///
///   @override
///   void dispose() {
///     _subscription?.cancel();
///     super.dispose();
///   }
/// }
/// ```
class RequireKeyboardVisibilityDisposeRule extends SaropaLintRule {
  const RequireKeyboardVisibilityDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_keyboard_visibility_dispose',
    problemMessage:
        '[require_keyboard_visibility_dispose] Uncancelled subscription keeps '
        'firing callbacks after dispose, causing setState errors.',
    correctionMessage: 'Store and cancel the stream subscription in dispose().',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'State') return;

      // Check for KeyboardVisibilityController usage
      final String classSource = node.toSource();
      if (!classSource.contains('KeyboardVisibilityController')) return;

      // Check for proper cleanup patterns
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      // Check for cancel() or dispose() in dispose method
      final bool hasCleanup = disposeBody != null &&
          (disposeBody.contains('.cancel(') ||
              disposeBody.contains('dispose()') ||
              disposeBody.contains('?.cancel('));

      if (!hasCleanup && classSource.contains('.listen(')) {
        // Find the field declaration to report on
        for (final ClassMember member in node.members) {
          if (member is FieldDeclaration) {
            final String fieldSource = member.toSource();
            if (fieldSource.contains('KeyboardVisibilityController')) {
              reporter.atNode(member, code);
              return;
            }
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddDisposeTodoFix('cancel()')];
}

/// Warns when SpeechToText is not stopped in dispose.
///
/// Alias: dispose_speech_to_text, speech_to_text_leak
///
/// SpeechToText must be stopped when the widget is disposed to release
/// microphone resources and stop background processing.
///
/// **BAD:**
/// ```dart
/// class _VoiceState extends State<Voice> {
///   final SpeechToText _speech = SpeechToText();
///
///   void startListening() async {
///     await _speech.listen(onResult: (result) {});
///   }
///   // Missing stop in dispose!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _VoiceState extends State<Voice> {
///   final SpeechToText _speech = SpeechToText();
///
///   void startListening() async {
///     await _speech.listen(onResult: (result) {});
///   }
///
///   @override
///   void dispose() {
///     _speech.stop();
///     super.dispose();
///   }
/// }
/// ```
class RequireSpeechStopOnDisposeRule extends SaropaLintRule {
  const RequireSpeechStopOnDisposeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    name: 'require_speech_stop_on_dispose',
    problemMessage:
        '[require_speech_stop_on_dispose] Unreleased SpeechToText keeps '
        'microphone active, draining battery and blocking other apps.',
    correctionMessage:
        'Add _speech.stop() in dispose() to release microphone resources.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addClassDeclaration((ClassDeclaration node) {
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String superName = extendsClause.superclass.name.lexeme;
      if (superName != 'State') return;

      // Find SpeechToText fields
      final List<String> speechFieldNames = <String>[];
      for (final ClassMember member in node.members) {
        if (member is FieldDeclaration) {
          final String? typeName = member.fields.type?.toSource();
          if (typeName != null && typeName.contains('SpeechToText')) {
            for (final VariableDeclaration variable
                in member.fields.variables) {
              speechFieldNames.add(variable.name.lexeme);
            }
          }
        }
      }

      if (speechFieldNames.isEmpty) return;

      // Find dispose method
      String? disposeBody;
      for (final ClassMember member in node.members) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          disposeBody = member.body.toSource();
          break;
        }
      }

      // Check if speech is stopped
      for (final String name in speechFieldNames) {
        final bool isStopped = disposeBody != null &&
            (disposeBody.contains('$name.stop(') ||
                disposeBody.contains('$name?.stop(') ||
                disposeBody.contains('$name.cancel('));

        if (!isStopped) {
          for (final ClassMember member in node.members) {
            if (member is FieldDeclaration) {
              for (final VariableDeclaration variable
                  in member.fields.variables) {
                if (variable.name.lexeme == name) {
                  reporter.atNode(variable, code);
                }
              }
            }
          }
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddDisposeTodoFix('stop()')];
}

// =============================================================================
// DEEP LINKING RULES
// =============================================================================

// cspell:ignore myapp
/// Warns when deep links contain sensitive parameters in URL.
///
/// Alias: no_tokens_in_deep_links, secure_app_links
///
/// Sensitive data like tokens, passwords, or API keys should never appear
/// in deep link URLs as they may be logged or exposed.
///
/// **BAD:**
/// ```dart
/// final link = 'myapp://auth?token=$accessToken';
/// final link = 'myapp://reset?password=$newPassword';
/// ```
///
/// **GOOD:**
/// ```dart
/// final link = 'myapp://auth?code=$oneTimeCode';
/// // Exchange code for token server-side
/// ```
class AvoidAppLinksSensitiveParamsRule extends SaropaLintRule {
  const AvoidAppLinksSensitiveParamsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_app_links_sensitive_params',
    problemMessage:
        '[avoid_app_links_sensitive_params] Deep link params are logged by '
        'OS and analytics, exposing tokens in crash reports and logs.',
    correctionMessage:
        'Use one-time codes instead of tokens or passwords in URLs.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _sensitiveParams = <String>{
    'token',
    'access_token',
    'accessToken',
    'refresh_token',
    'refreshToken',
    'password',
    'secret',
    'api_key',
    'apiKey',
    'auth_token',
    'authToken',
    'bearer',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addStringInterpolation((StringInterpolation node) {
      final String fullString = node.toSource();

      // Check if it looks like a URL with app scheme
      if (!fullString.contains('://')) return;

      // Check for sensitive parameter names
      for (final String param in _sensitiveParams) {
        if (fullString.contains('$param=') ||
            fullString.contains('$param\$') ||
            fullString.contains('?$param')) {
          reporter.atNode(node, code);
          return;
        }
      }
    });

    // Also check simple string concatenation
    context.registry.addBinaryExpression((BinaryExpression node) {
      if (node.operator.lexeme != '+') return;

      final String source = node.toSource();
      if (!source.contains('://')) return;

      for (final String param in _sensitiveParams) {
        if (source.contains('$param=')) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddSensitiveUrlTodoFix()];
}

class _AddSensitiveUrlTodoFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addStringInterpolation((StringInterpolation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK: Use one-time code instead',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Use one-time codes instead of sensitive tokens in deep links\n',
        );
      });
    });

    context.registry.addBinaryExpression((BinaryExpression node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK: Use one-time code instead',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Use one-time codes instead of sensitive tokens in deep links\n',
        );
      });
    });
  }
}

// =============================================================================
// ENVIRONMENT/SECRETS RULES
// =============================================================================

/// Warns when Envied annotation lacks obfuscate parameter.
///
/// Alias: envied_obfuscate, require_env_obfuscation
///
/// Environment variables generated by Envied should be obfuscated to prevent
/// easy extraction from compiled binaries.
///
/// **BAD:**
/// ```dart
/// @Envied()
/// abstract class Env {
///   @EnviedField()
///   static const String apiKey = _Env.apiKey;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// @Envied(obfuscate: true)
/// abstract class Env {
///   @EnviedField(obfuscate: true)
///   static const String apiKey = _Env.apiKey;
/// }
/// ```
class RequireEnviedObfuscationRule extends SaropaLintRule {
  const RequireEnviedObfuscationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_envied_obfuscation',
    problemMessage:
        '[require_envied_obfuscation] Envied environment variable generated without obfuscation stores secrets as plaintext string constants in the compiled binary. Attackers can extract API keys, database URLs, and authentication tokens using basic reverse engineering tools, enabling unauthorized access to your backend services and third-party APIs.',
    correctionMessage:
        'Add obfuscate: true to the @Envied annotation or individual @EnviedField annotations to encode secrets at compile time and prevent plaintext extraction.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addAnnotation((Annotation node) {
      final String name = node.name.name;
      if (name != 'Envied' && name != 'EnviedField') return;

      // Check for obfuscate: true
      final ArgumentList? args = node.arguments;
      if (args == null) {
        reporter.atNode(node, code);
        return;
      }

      final bool hasObfuscate = args.arguments.any((Expression arg) {
        if (arg is NamedExpression) {
          if (arg.name.label.name == 'obfuscate') {
            return arg.expression.toSource() == 'true';
          }
        }
        return false;
      });

      if (!hasObfuscate) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddObfuscateTodoFix()];
}

class _AddObfuscateTodoFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addAnnotation((Annotation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK: Add obfuscate: true',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Add obfuscate: true to prevent key extraction from binaries\n',
        );
      });
    });
  }
}

/// Warns when OpenAI API key pattern is found in source code.
///
/// Alias: no_openai_key_in_code, openai_key_security
///
/// OpenAI API keys (sk-...) should never be hardcoded in source files.
/// They should come from environment variables or secure storage.
///
/// **BAD:**
/// ```dart
/// final openAI = OpenAI.instance.build(
///   token: 'sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxx',
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// final openAI = OpenAI.instance.build(
///   token: Env.openAiKey,
/// );
/// ```
class AvoidOpenaiKeyInCodeRule extends SaropaLintRule {
  const AvoidOpenaiKeyInCodeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_openai_key_in_code',
    problemMessage:
        '[avoid_openai_key_in_code] Hardcoded OpenAI keys are extractable '
        'from binaries, enabling API abuse charged to your account.',
    correctionMessage:
        'Use environment variables or secure configuration for API keys.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  // OpenAI keys start with sk- followed by alphanumeric characters
  static final RegExp _openAiKeyPattern = RegExp(r'sk-[a-zA-Z0-9]{20,}');

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      if (_openAiKeyPattern.hasMatch(value)) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddEnvVarTodoFix()];
}

/// Warns when OpenAI API calls (chat_gpt_sdk) lack try-catch error handling.
///
/// Alias: openai_try_catch, handle_openai_errors
///
/// OpenAI API calls can fail due to rate limits, network issues, or invalid
/// requests. Without error handling, the app may crash unexpectedly.
///
/// **Note:** This rule targets the chat_gpt_sdk package's OpenAI class methods.
///
/// **BAD:**
/// ```dart
/// Future<String> chat(String message) async {
///   final response = await openAI.onChatCompletion(request: request);
///   return response!.choices.first.message!.content;
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Future<String?> chat(String message) async {
///   try {
///     final response = await openAI.onChatCompletion(request: request);
///     return response?.choices.first.message?.content;
///   } catch (e) {
///     // Handle API error
///     return null;
///   }
/// }
/// ```
class RequireOpenaiErrorHandlingRule extends SaropaLintRule {
  const RequireOpenaiErrorHandlingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_openai_error_handling',
    problemMessage:
        '[require_openai_error_handling] OpenAI API call without error handling crashes when the service returns rate limit errors (429), the API is temporarily unavailable (503), or the request exceeds token limits. Users see an unhandled exception crash screen instead of graceful fallback behavior, causing lost context and a broken experience.',
    correctionMessage:
        'Wrap OpenAI API calls in a try-catch block that handles rate limits with exponential backoff and service errors with user-friendly fallback messages.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  // chat_gpt_sdk specific method names
  static const Set<String> _openAiMethods = <String>{
    'onChatCompletion',
    'onCompletion',
    'generateImage',
    'onModeration',
    'createEmbeddings',
    'audioTranscription',
    'audioTranslation',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_openAiMethods.contains(methodName)) return;

      // Validate target looks like OpenAI instance
      final Expression? target = node.target;
      if (target != null) {
        final String targetSource = target.toSource().toLowerCase();
        // Should be called on something containing 'openai' or 'gpt'
        if (!targetSource.contains('openai') &&
            !targetSource.contains('gpt') &&
            !targetSource.contains('_ai')) {
          return;
        }
      }

      // Check if wrapped in try-catch
      AstNode? current = node.parent;
      while (current != null) {
        if (current is TryStatement) return;
        if (current is FunctionBody) break;
        current = current.parent;
      }

      reporter.atNode(node, code);
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddTryCatchTodoFix(code)];
}

// =============================================================================
// UI COMPONENT RULES
// =============================================================================

/// Warns when SvgPicture lacks errorBuilder callback.
///
/// Alias: svg_error_handler, require_svg_error_builder
///
/// SVG loading can fail for various reasons. Without an error builder,
/// the UI may break or show nothing when an SVG fails to load.
///
/// **BAD:**
/// ```dart
/// SvgPicture.asset('assets/icon.svg')
/// SvgPicture.network('https://example.com/icon.svg')
/// ```
///
/// **GOOD:**
/// ```dart
/// SvgPicture.asset(
///   'assets/icon.svg',
///   placeholderBuilder: (context) => CircularProgressIndicator(),
///   errorBuilder: (context, error, stackTrace) => Icon(Icons.error),
/// )
/// ```
class RequireSvgErrorHandlerRule extends SaropaLintRule {
  const RequireSvgErrorHandlerRule() : super(code: _code);

  // Medium impact - UI fallback, not crash-causing
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_svg_error_handler',
    problemMessage:
        '[require_svg_error_handler] SvgPicture without errorBuilder shows blank on invalid SVG.',
    correctionMessage: 'Add errorBuilder to handle SVG loading failures.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for SvgPicture factory constructors
      final String? target = node.target?.toSource();
      if (target != 'SvgPicture') return;

      final String methodName = node.methodName.name;
      if (methodName != 'asset' &&
          methodName != 'network' &&
          methodName != 'file' &&
          methodName != 'memory') {
        return;
      }

      // Check for errorBuilder parameter
      final bool hasErrorBuilder =
          node.argumentList.arguments.any((Expression arg) {
        if (arg is NamedExpression) {
          return arg.name.label.name == 'errorBuilder';
        }
        return false;
      });

      if (!hasErrorBuilder) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddErrorBuilderTodoFix()];
}

class _AddErrorBuilderTodoFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK: Add errorBuilder',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Add errorBuilder callback to handle loading failures\n',
        );
      });
    });
  }
}

// cspell:ignore roboto
/// Warns when GoogleFonts usage lacks fontFamilyFallback.
///
/// Alias: google_fonts_fallback, require_font_fallback
///
/// Google Fonts may fail to load on slow connections or offline. Without a
/// fallback, text may be invisible or use system default unexpectedly.
///
/// **BAD:**
/// ```dart
/// Text(
///   'Hello',
///   style: GoogleFonts.roboto(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(
///   'Hello',
///   style: GoogleFonts.roboto(
///     fontFamilyFallback: ['Arial', 'sans-serif'],
///   ),
/// )
/// ```
class RequireGoogleFontsFallbackRule extends SaropaLintRule {
  const RequireGoogleFontsFallbackRule() : super(code: _code);

  // Medium impact - UI fallback, not crash-causing
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_google_fonts_fallback',
    problemMessage:
        '[require_google_fonts_fallback] GoogleFonts should specify fontFamilyFallback.',
    correctionMessage:
        'Add fontFamilyFallback to handle font loading failures.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      // Check for GoogleFonts calls
      final String? target = node.target?.toSource();
      if (target != 'GoogleFonts') return;

      // Check for fontFamilyFallback parameter
      final bool hasFallback =
          node.argumentList.arguments.any((Expression arg) {
        if (arg is NamedExpression) {
          return arg.name.label.name == 'fontFamilyFallback';
        }
        return false;
      });

      if (!hasFallback) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddFontFallbackTodoFix()];
}

class _AddFontFallbackTodoFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK: Add fontFamilyFallback',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Add fontFamilyFallback for offline/slow network fallback\n',
        );
      });
    });
  }
}

// =============================================================================
// UUID RULES
// =============================================================================

/// Suggests using UUID v4 instead of v1 for better randomness.
///
/// Alias: prefer_uuid_v4_over_v1, use_uuid_v4
///
/// UUID v1 is time-based and includes MAC address, which may leak information.
/// UUID v4 is random and more suitable for most use cases.
///
/// **BAD:**
/// ```dart
/// final id = Uuid().v1();
/// ```
///
/// **GOOD:**
/// ```dart
/// final id = Uuid().v4();
/// ```
class PreferUuidV4Rule extends SaropaLintRule {
  const PreferUuidV4Rule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_uuid_v4',
    problemMessage:
        '[prefer_uuid_v4] Prefer UUID v4 over v1 for better randomness and privacy.',
    correctionMessage: 'Use Uuid().v4() instead of Uuid().v1().',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'v1') return;

      // Check if it's a Uuid call
      final String source = node.toSource();
      if (source.contains('Uuid()') || source.contains('uuid.')) {
        reporter.atNode(node, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_ReplaceV1WithV4Fix()];
}

class _ReplaceV1WithV4Fix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;
      if (node.methodName.name != 'v1') return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Replace v1() with v4()',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleReplacement(
          SourceRange(node.methodName.offset, node.methodName.length),
          'v4',
        );
      });
    });
  }
}

// =============================================================================
// IMAGE PICKER RULES
// =============================================================================

/// Warns when ImagePicker.pickImage() is called without maxWidth/maxHeight.
///
/// Alias: image_picker_dimensions, limit_image_size, picker_size_limit
///
/// **Quick fix available:** Adds a reminder comment for manual size limit addition.
///
/// ## Why This Matters
///
/// Modern smartphone cameras capture images at 12-108 megapixels. Loading these
/// full-resolution images into memory can easily exceed available RAM, causing:
/// - Out-of-memory crashes on lower-end devices
/// - UI freezes during image processing
/// - Excessive memory pressure leading to app termination
///
/// ## Detection
///
/// This rule flags `pickImage()` and `pickMultiImage()` calls from the
/// `image_picker` package that don't specify size constraints. Detection is
/// based on the presence of the `source` parameter (unique to image_picker).
///
/// ## Example
///
/// ### BAD:
/// ```dart
/// // A 108MP image = ~12,000 x 9,000 pixels = 432MB uncompressed!
/// final XFile? image = await picker.pickImage(source: ImageSource.gallery);
/// ```
///
/// ### GOOD:
/// ```dart
/// final XFile? image = await picker.pickImage(
///   source: ImageSource.gallery,
///   maxWidth: 1920,  // Full HD is sufficient for most uses
///   maxHeight: 1080,
///   imageQuality: 85, // Optional: compress JPEG quality
/// );
/// ```
///
/// ## Recommended Size Limits
///
/// | Use Case | maxWidth | maxHeight |
/// |----------|----------|-----------|
/// | Profile avatar | 512 | 512 |
/// | List thumbnails | 256 | 256 |
/// | Full-screen display | 1920 | 1080 |
/// | Print quality | 3840 | 2160 |
class PreferImagePickerMaxDimensionsRule extends SaropaLintRule {
  const PreferImagePickerMaxDimensionsRule() : super(code: _code);

  /// High impact - OOM crashes affect user experience significantly.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_image_picker_max_dimensions',
    problemMessage:
        '[prefer_image_picker_max_dimensions] pickImage() called without maxWidth or maxHeight parameters loads full-resolution camera images (12+ megapixels on modern devices). Decoding these large images into memory causes OutOfMemoryError crashes on lower-end devices, excessive memory consumption that triggers OS app kills, and slow image processing.',
    correctionMessage:
        'Add maxWidth and maxHeight parameters (e.g., maxWidth: 1920, maxHeight: 1080) to limit image resolution and prevent out-of-memory crashes on constrained devices.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Only check image_picker methods
      if (methodName != 'pickImage' && methodName != 'pickMultiImage') {
        return;
      }

      // Verify this is likely from ImagePicker (has 'source' parameter)
      bool hasSourceParam = false;
      bool hasMaxWidth = false;
      bool hasMaxHeight = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'source') hasSourceParam = true;
          if (name == 'maxWidth') hasMaxWidth = true;
          if (name == 'maxHeight') hasMaxHeight = true;
        }
      }

      // Only flag if this looks like ImagePicker (has source param)
      // and is missing size constraints
      if (hasSourceParam && !hasMaxWidth && !hasMaxHeight) {
        reporter.atNode(node.methodName, code);
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddImagePickerSizeTodoFix()];
}

class _AddImagePickerSizeTodoFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (!node.sourceRange.intersects(analysisError.sourceRange)) return;

      final ChangeBuilder changeBuilder = reporter.createChangeBuilder(
        message: 'Add HACK: Set maxWidth/maxHeight',
        priority: 1,
      );

      changeBuilder.addDartFileEdit((builder) {
        builder.addSimpleInsertion(
          node.offset,
          '// HACK: Add maxWidth/maxHeight to prevent OOM on high-res cameras\n',
        );
      });
    });
  }
}

// =============================================================================
// URL LAUNCHER RULES
// =============================================================================

/// Warns when launchUrl() is called without specifying LaunchMode.
///
/// Alias: url_launcher_mode, specify_launch_mode, launch_mode_explicit
///
/// ## Why This Matters
///
/// Without explicit LaunchMode, URL launching behavior varies by platform:
/// - **iOS**: Opens in-app Safari View Controller by default
/// - **Android**: Opens external browser by default
/// - **Web**: Opens in same tab by default
///
/// Specifying mode ensures consistent, predictable behavior across all platforms.
///
/// ## Example
///
/// ### BAD:
/// ```dart
/// // Behavior differs between iOS, Android, and web
/// await launchUrl(Uri.parse('https://example.com'));
/// ```
///
/// ### GOOD:
/// ```dart
/// await launchUrl(
///   Uri.parse('https://example.com'),
///   mode: LaunchMode.externalApplication, // Always open external browser
/// );
/// ```
///
/// ## LaunchMode Options
///
/// | Mode | Behavior |
/// |------|----------|
/// | `platformDefault` | Platform decides (inconsistent) |
/// | `inAppWebView` | In-app browser (keeps user in app) |
/// | `inAppBrowserView` | In-app browser with native UI |
/// | `externalApplication` | External browser/app |
/// | `externalNonBrowserApplication` | External app only (not browser) |
class RequireUrlLauncherModeRule extends SaropaLintRule {
  const RequireUrlLauncherModeRule() : super(code: _code);

  /// Medium impact - inconsistent behavior, but not a crash.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_url_launcher_mode',
    problemMessage:
        '[require_url_launcher_mode] launchUrl() without mode parameter has inconsistent behavior across platforms.',
    correctionMessage:
        'Add mode parameter (e.g., LaunchMode.externalApplication) for consistent behavior.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'launchUrl') return;

      // Verify first argument is a Uri (url_launcher signature)
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      // Check if mode is specified
      bool hasMode = false;
      for (final Expression arg in args) {
        if (arg is NamedExpression && arg.name.label.name == 'mode') {
          hasMode = true;
          break;
        }
      }

      if (!hasMode) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when Geolocator location stream doesn't specify distanceFilter.
///
/// Without distanceFilter, the location stream fires on every tiny GPS update,
/// which drains battery and may cause performance issues. Setting a reasonable
/// distanceFilter reduces updates to only meaningful location changes.
///
/// **BAD:**
/// ```dart
/// // Fires constantly, even for 1-meter movements - battery drain!
/// Geolocator.getPositionStream().listen((position) {
///   updateMap(position);
/// });
///
/// Geolocator.getPositionStream(
///   locationSettings: LocationSettings(accuracy: LocationAccuracy.high),
/// ).listen((position) {});
/// ```
///
/// **GOOD:**
/// ```dart
/// // Only fires when user moves 10+ meters
/// Geolocator.getPositionStream(
///   locationSettings: LocationSettings(
///     accuracy: LocationAccuracy.high,
///     distanceFilter: 10, // meters
///   ),
/// ).listen((position) {
///   updateMap(position);
/// });
/// ```
class PreferGeolocatorDistanceFilterRule extends SaropaLintRule {
  const PreferGeolocatorDistanceFilterRule() : super(code: _code);

  /// High impact - affects battery life significantly.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_geolocator_distance_filter',
    problemMessage:
        '[prefer_geolocator_distance_filter] Location stream subscription without a distanceFilter fires continuous GPS updates at the maximum sensor rate regardless of actual movement. This causes excessive battery drain, unnecessary network requests to location services, and high CPU usage from processing redundant position updates that provide no new information.',
    correctionMessage:
        'Add distanceFilter to LocationSettings (e.g., distanceFilter: 10) to receive updates only when the user moves a meaningful distance, reducing battery and CPU usage.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'getPositionStream') return;

      // Check if it's a Geolocator call
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (!targetSource.contains('Geolocator') &&
          targetSource != 'Geolocator') {
        return;
      }

      // Look for locationSettings parameter
      Expression? locationSettingsArg;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'locationSettings') {
          locationSettingsArg = arg.expression;
          break;
        }
      }

      // No locationSettings - definitely missing distanceFilter
      if (locationSettingsArg == null) {
        reporter.atNode(node.methodName, code);
        return;
      }

      // Check if LocationSettings has distanceFilter
      if (locationSettingsArg is InstanceCreationExpression) {
        final bool hasDistanceFilter =
            locationSettingsArg.argumentList.arguments.any((arg) {
          if (arg is NamedExpression) {
            return arg.name.label.name == 'distanceFilter';
          }
          return false;
        });

        if (!hasDistanceFilter) {
          reporter.atNode(locationSettingsArg, code);
        }
      }
    });

    // Also check for direct LocationSettings construction
    context.registry.addInstanceCreationExpression((node) {
      final String typeName = node.constructorName.type.name2.lexeme;

      // Check for various LocationSettings types from geolocator
      if (typeName != 'LocationSettings' &&
          typeName != 'AndroidSettings' &&
          typeName != 'AppleSettings') {
        return;
      }

      // Check if parent context is a getPositionStream call
      AstNode? current = node.parent;
      bool inPositionStream = false;
      while (current != null) {
        if (current is MethodInvocation) {
          if (current.methodName.name == 'getPositionStream') {
            inPositionStream = true;
            break;
          }
        }
        if (current is FunctionBody) break;
        current = current.parent;
      }

      if (!inPositionStream) return;

      // Check for distanceFilter parameter
      final bool hasDistanceFilter = node.argumentList.arguments.any((arg) {
        if (arg is NamedExpression) {
          return arg.name.label.name == 'distanceFilter';
        }
        return false;
      });

      if (!hasDistanceFilter) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

// =============================================================================
// prefer_typed_prefs_wrapper
// =============================================================================

/// Warns when SharedPreferences is used directly without a typed wrapper.
///
/// Alias: typed_prefs, shared_preferences_wrapper
///
/// Direct SharedPreferences access scatters string keys throughout code and
/// lacks type safety. Create a typed wrapper class for maintainability.
///
/// **BAD:**
/// ```dart
/// // Scattered throughout codebase
/// final prefs = await SharedPreferences.getInstance();
/// prefs.setString('user_name', name);  // Typo-prone key
/// prefs.setInt('user-age', age);       // Inconsistent naming
///
/// // Elsewhere...
/// final name = prefs.getString('userName'); // Wrong key, returns null!
/// ```
///
/// **GOOD:**
/// ```dart
/// class UserPreferences {
///   static const _keyName = 'user_name';
///   static const _keyAge = 'user_age';
///
///   final SharedPreferences _prefs;
///   UserPreferences(this._prefs);
///
///   String? get userName => _prefs.getString(_keyName);
///   set userName(String? value) =>
///       value == null ? _prefs.remove(_keyName) : _prefs.setString(_keyName, value);
///
///   int get userAge => _prefs.getInt(_keyAge) ?? 0;
///   set userAge(int value) => _prefs.setInt(_keyAge, value);
/// }
/// ```
class PreferTypedPrefsWrapperRule extends SaropaLintRule {
  const PreferTypedPrefsWrapperRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_typed_prefs_wrapper',
    problemMessage:
        '[prefer_typed_prefs_wrapper] Direct SharedPreferences access with '
        'string literal key. Scattered keys are error-prone.',
    correctionMessage:
        'Create a typed wrapper class with properties for each preference.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for SharedPreferences set/get methods
      if (!methodName.startsWith('set') && !methodName.startsWith('get')) {
        return;
      }

      // Check target for SharedPreferences
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource().toLowerCase();
      if (!targetSource.contains('pref') && !targetSource.contains('shared')) {
        return;
      }

      // Check if key is a string literal (not a constant)
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression keyArg = args.first;
      if (keyArg is SimpleStringLiteral) {
        // Direct string literal - suggests not using a wrapper
        reporter.atNode(node, code);
      }
    });
  }
}
