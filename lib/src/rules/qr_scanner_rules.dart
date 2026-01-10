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
