import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';
import 'package:saropa_lints/src/saropa_lint_rule.dart';

/// Warns when file read operations are used without exists() check or try-catch.
///
/// File operations on non-existent files throw exceptions. Always verify
/// the file exists or wrap in try-catch to handle missing files gracefully.
///
/// **BAD:**
/// ```dart
/// final content = await file.readAsString(); // Crashes if file missing!
/// ```
///
/// **GOOD:**
/// ```dart
/// if (await file.exists()) {
///   final content = await file.readAsString();
/// }
/// // OR
/// try {
///   final content = await file.readAsString();
/// } on FileSystemException {
///   handleMissingFile();
/// }
/// ```
class RequireFileExistsCheckRule extends SaropaLintRule {
  const RequireFileExistsCheckRule() : super(code: _code);

  /// Important for robust file handling.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_file_exists_check',
    problemMessage: 'File read operation should check exists() or use try-catch.',
    correctionMessage: 'Wrap in if (await file.exists()) or try-catch block.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _fileReadMethods = <String>{
    'readAsString',
    'readAsStringSync',
    'readAsBytes',
    'readAsBytesSync',
    'readAsLines',
    'readAsLinesSync',
    'openRead',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_fileReadMethods.contains(methodName)) return;

      // Use type resolution to verify this is a File from dart:io
      final Expression? target = node.target;
      if (target == null) return;

      final String? typeName = target.staticType?.element?.name;
      if (typeName != 'File') return;

      // Check if inside try-catch
      bool insideTryCatch = false;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is TryStatement) {
          insideTryCatch = true;
          break;
        }
        current = current.parent;
      }

      if (insideTryCatch) return;

      // Check if preceded by exists() check in same block
      current = node.parent;
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
        // Simple check for exists() call before the read operation
        final int readPos = bodySource.indexOf(methodName);
        final int existsPos = bodySource.indexOf('.exists()');

        if (existsPos >= 0 && existsPos < readPos) {
          return; // exists() check is before read
        }
      }

      reporter.atNode(node.methodName, code);
    });
  }
}

/// Warns when PDF loading lacks error handling.
///
/// PDF files can be corrupted, password-protected, or use unsupported features.
/// Without error handling, these failures crash the app instead of showing
/// a helpful error message.
///
/// **BAD:**
/// ```dart
/// final doc = await PDFDocument.fromAsset('file.pdf'); // May crash!
/// ```
///
/// **GOOD:**
/// ```dart
/// try {
///   final doc = await PDFDocument.fromAsset('file.pdf');
/// } catch (e) {
///   showError('Could not open PDF: $e');
/// }
/// ```
class RequirePdfErrorHandlingRule extends SaropaLintRule {
  const RequirePdfErrorHandlingRule() : super(code: _code);

  /// Important for robust PDF handling.
  @override
  LintImpact get impact => LintImpact.medium;

  static const LintCode _code = LintCode(
    name: 'require_pdf_error_handling',
    problemMessage: 'PDF loading should have error handling.',
    correctionMessage: 'Wrap PDF loading in try-catch block.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _pdfLoadMethods = <String>{
    'fromAsset',
    'fromFile',
    'fromUrl',
    'fromPath',
    'openDocument',
    'loadDocument',
  };

  static const Set<String> _pdfTypes = <String>{
    'PDFDocument',
    'PdfDocument',
    'PdfController',
    'PDFView',
    'PdfViewer',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_pdfLoadMethods.contains(methodName)) return;

      // Check if target is a PDF-related type
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      bool isPdfOperation = false;
      for (final String pdfType in _pdfTypes) {
        if (targetSource.contains(pdfType)) {
          isPdfOperation = true;
          break;
        }
      }

      if (!isPdfOperation) return;

      // Check if inside try-catch
      bool insideTryCatch = false;
      AstNode? current = node.parent;

      while (current != null) {
        if (current is TryStatement) {
          insideTryCatch = true;
          break;
        }
        current = current.parent;
      }

      if (!insideTryCatch) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when GraphQL response is used without checking for errors.
///
/// GraphQL returns errors in the response body, not via HTTP status codes.
/// Accessing `result.data` without checking `result.hasException` may
/// process null data or miss important error information.
///
/// **BAD:**
/// ```dart
/// final result = await client.query(options);
/// final data = result.data!['users']; // May be null if there's an error!
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = await client.query(options);
/// if (result.hasException) {
///   handleError(result.exception!);
///   return;
/// }
/// final data = result.data!['users'];
/// ```
class RequireGraphqlErrorHandlingRule extends SaropaLintRule {
  const RequireGraphqlErrorHandlingRule() : super(code: _code);

  /// Critical for robust GraphQL apps.
  @override
  LintImpact get impact => LintImpact.high;

  static const LintCode _code = LintCode(
    name: 'require_graphql_error_handling',
    problemMessage: 'GraphQL result should check hasException before accessing data.',
    correctionMessage: 'Add if (result.hasException) check before result.data access.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// GraphQL result type names from graphql_flutter and similar packages.
  static const Set<String> _graphqlResultTypes = <String>{
    'QueryResult',
    'MutationResult',
    'SubscriptionResult',
    'GraphQLResponse',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addPropertyAccess((PropertyAccess node) {
      // Check for .data access
      if (node.propertyName.name != 'data') return;

      // Use type resolution to verify this is a GraphQL result
      final Expression? target = node.target;
      if (target == null) return;

      final String? typeName = target.staticType?.element?.name;
      if (typeName == null || !_graphqlResultTypes.contains(typeName)) {
        return;
      }

      // Check if hasException is checked before this access
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
        final int dataAccessPos = bodySource.indexOf('.data');
        final int hasExceptionPos = bodySource.indexOf('hasException');
        final int errorsPos = bodySource.indexOf('.errors');

        // Check if error handling appears before data access
        if ((hasExceptionPos >= 0 && hasExceptionPos < dataAccessPos) ||
            (errorsPos >= 0 && errorsPos < dataAccessPos)) {
          return; // Error check is before data access
        }

        reporter.atNode(node.propertyName, code);
      }
    });
  }
}
