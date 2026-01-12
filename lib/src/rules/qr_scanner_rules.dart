import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Warns when QR scan success callback lacks haptic/visual feedback.
///
/// Users need confirmation that their scan was successful. Haptic feedback
/// (vibration) or visual feedback (flash, animation) improves user experience
/// and prevents double-scanning.
///
/// **BAD:**
/// ```dart
/// MobileScanner(
///   onDetect: (capture) {
///     processBarcode(capture.barcodes.first); // No feedback to user
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// MobileScanner(
///   onDetect: (capture) {
///     HapticFeedback.mediumImpact(); // User feels the scan
///     processBarcode(capture.barcodes.first);
///   },
/// )
/// ```
class RequireQrScanFeedbackRule extends SaropaLintRule {
  const RequireQrScanFeedbackRule() : super(code: _code);

  /// UX improvement, not critical.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_qr_scan_feedback',
    problemMessage: 'QR scan callback should provide user feedback.',
    correctionMessage:
        'Add HapticFeedback.mediumImpact() or visual feedback on scan.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _scanCallbacks = <String>{
    'onDetect',
    'onQRViewCreated',
    'onBarcodeDetected',
    'onScan',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedExpression((NamedExpression node) {
      final String paramName = node.name.label.name;
      if (!_scanCallbacks.contains(paramName)) return;

      // Check if the callback contains feedback
      final Expression value = node.expression;
      String callbackSource = '';

      if (value is FunctionExpression) {
        callbackSource = value.body.toSource();
      } else if (value is SimpleIdentifier) {
        // Method reference - harder to check, skip
        return;
      }

      if (callbackSource.isEmpty) return;

      final bool hasFeedback = callbackSource.contains('HapticFeedback') ||
          callbackSource.contains('haptic') ||
          callbackSource.contains('vibrate') ||
          callbackSource.contains('Vibration') ||
          callbackSource.contains('playSound') ||
          callbackSource.contains('AudioPlayer');

      if (!hasFeedback) {
        reporter.atNode(node.name, code);
      }
    });
  }
}

/// Warns when QR scanner lacks lifecycle pause/resume handling.
///
/// Camera for QR scanning drains battery significantly. Without proper
/// lifecycle handling, the camera stays active when the app is backgrounded
/// or the screen is turned off.
///
/// **BAD:**
/// ```dart
/// class _ScannerState extends State<Scanner> {
///   final controller = MobileScannerController();
///   // No lifecycle handling - camera runs in background!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _ScannerState extends State<Scanner> with WidgetsBindingObserver {
///   final controller = MobileScannerController();
///
///   @override
///   void didChangeAppLifecycleState(AppLifecycleState state) {
///     if (state == AppLifecycleState.paused) {
///       controller.stop();
///     } else if (state == AppLifecycleState.resumed) {
///       controller.start();
///     }
///   }
/// }
/// ```
class AvoidQrScannerAlwaysActiveRule extends SaropaLintRule {
  const AvoidQrScannerAlwaysActiveRule() : super(code: _code);

  /// Battery optimization issue.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'avoid_qr_scanner_always_active',
    problemMessage: 'QR scanner should pause when app is backgrounded.',
    correctionMessage:
        'Add WidgetsBindingObserver and pause camera in didChangeAppLifecycleState.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _scannerControllers = <String>{
    'MobileScannerController',
    'QRViewController',
    'CameraController',
    'BarcodeCamera',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addFieldDeclaration((FieldDeclaration node) {
      // Check if field type is a scanner controller
      final String? typeName = node.fields.type?.toSource();
      if (typeName == null) return;

      bool isScannerController = false;
      for (final String controller in _scannerControllers) {
        if (typeName.contains(controller)) {
          isScannerController = true;
          break;
        }
      }

      if (!isScannerController) return;

      // Check if class has lifecycle handling
      AstNode? current = node.parent;
      ClassDeclaration? enclosingClass;

      while (current != null) {
        if (current is ClassDeclaration) {
          enclosingClass = current;
          break;
        }
        current = current.parent;
      }

      if (enclosingClass == null) return;

      final String classSource = enclosingClass.toSource();
      final bool hasLifecycleHandling =
          classSource.contains('WidgetsBindingObserver') &&
              classSource.contains('didChangeAppLifecycleState');

      if (!hasLifecycleHandling) {
        reporter.atNode(node.fields.variables.first, code);
      }
    });
  }
}

/// Warns when QR scan result is used without URL or content validation.
///
/// QR codes can contain malicious URLs, scripts, or malformed data. Using
/// scanned content directly without validation exposes the app to security
/// risks including phishing, XSS, and injection attacks.
///
/// **BAD:**
/// ```dart
/// MobileScanner(
///   onDetect: (capture) {
///     final barcode = capture.barcodes.first;
///     launchUrl(Uri.parse(barcode.rawValue!)); // Dangerous!
///   },
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// MobileScanner(
///   onDetect: (capture) {
///     final barcode = capture.barcodes.first;
///     final content = barcode.rawValue;
///     if (content == null) return;
///
///     // Validate URL scheme
///     final uri = Uri.tryParse(content);
///     if (uri == null || !['http', 'https'].contains(uri.scheme)) {
///       showError('Invalid QR code');
///       return;
///     }
///
///     // Optional: Check against allowlist of domains
///     if (!_allowedDomains.contains(uri.host)) {
///       showWarning('Unknown domain: ${uri.host}');
///     }
///
///     launchUrl(uri);
///   },
/// )
/// ```
class RequireQrContentValidationRule extends SaropaLintRule {
  const RequireQrContentValidationRule() : super(code: _code);

  /// Security issue - can lead to phishing or malicious redirects.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'require_qr_content_validation',
    problemMessage: 'QR scan result used without validation. Security risk.',
    correctionMessage:
        'Validate URL scheme and optionally domain before using scanned content.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// QR scan callback parameter names.
  static const Set<String> _scanCallbacks = <String>{
    'onDetect',
    'onQRViewCreated',
    'onBarcodeDetected',
    'onScan',
    'onCapture',
  };

  /// Methods that use URLs dangerously.
  static const Set<String> _dangerousMethods = <String>{
    'launchUrl',
    'launch',
    'openUrl',
    'canLaunchUrl',
    'launchUrlString',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addNamedExpression((NamedExpression node) {
      final String paramName = node.name.label.name;
      if (!_scanCallbacks.contains(paramName)) return;

      // Check the callback body
      final Expression value = node.expression;
      String callbackSource = '';

      if (value is FunctionExpression) {
        callbackSource = value.body.toSource();
      } else {
        // Method reference - skip (cannot analyze)
        return;
      }

      if (callbackSource.isEmpty) return;

      // Check if callback uses URL launching without validation
      bool usesUrlLaunching = false;
      for (final String method in _dangerousMethods) {
        if (callbackSource.contains(method)) {
          usesUrlLaunching = true;
          break;
        }
      }

      if (!usesUrlLaunching) return;

      // Check for validation patterns
      // Uri.tryParse is always safe (returns null on failure)
      // Uri.parse is only safe if combined with scheme validation
      final bool hasValidation = callbackSource.contains('Uri.tryParse') ||
          (callbackSource.contains('Uri.parse') &&
              callbackSource.contains('scheme')) ||
          callbackSource.contains('isValidUrl') ||
          callbackSource.contains('validateUrl') ||
          callbackSource.contains('allowedDomains') ||
          callbackSource.contains('allowList') ||
          callbackSource.contains('whitelist') ||
          callbackSource.contains('.host') ||
          callbackSource.contains('startsWith(\'http') ||
          callbackSource.contains('startsWith("http');

      if (!hasValidation) {
        reporter.atNode(node.name, code);
      }
    });

    // Also check for direct usage of barcode rawValue with launchUrl
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_dangerousMethods.contains(methodName)) return;

      // Check if any argument references barcode/rawValue directly
      for (final Expression arg in node.argumentList.arguments) {
        final String argSource = arg.toSource();
        if (argSource.contains('rawValue') ||
            argSource.contains('barcode') ||
            argSource.contains('scanResult') ||
            argSource.contains('qrCode')) {
          // Check if there's validation before this call
          AstNode? current = node.parent;
          BlockFunctionBody? enclosingBody;

          while (current != null) {
            if (current is BlockFunctionBody) {
              enclosingBody = current;
              break;
            }
            current = current.parent;
          }

          if (enclosingBody != null) {
            final String bodySource = enclosingBody.toSource();
            final int launchPos = bodySource.indexOf(methodName);
            final int validatePos = _findValidationPosition(bodySource);

            // If validation appears before launch, it's okay
            if (validatePos >= 0 && validatePos < launchPos) {
              return;
            }
          }

          reporter.atNode(node, code);
          return;
        }
      }
    });
  }

  /// Find the position of URL validation in the source.
  int _findValidationPosition(String source) {
    final List<String> patterns = <String>[
      'Uri.tryParse',
      'isValidUrl',
      'validateUrl',
      '.scheme',
      'allowedDomains',
      'startsWith(\'http',
      'startsWith("http',
    ];

    int earliest = -1;
    for (final String pattern in patterns) {
      final int pos = source.indexOf(pattern);
      if (pos >= 0 && (earliest < 0 || pos < earliest)) {
        earliest = pos;
      }
    }
    return earliest;
  }
}
