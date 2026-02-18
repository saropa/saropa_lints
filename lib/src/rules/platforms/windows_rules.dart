// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Windows platform-specific lint rules for Flutter applications.
///
/// These rules help ensure Flutter apps follow Windows platform best practices,
/// handle Windows-specific issues like drive letter paths, path separators,
/// case-insensitive filesystems, single-instance behavior, and MAX_PATH limits.
///
/// ## Windows Considerations
///
/// Windows desktop apps have additional considerations:
/// - **Path separators**: Backslash `\` vs forward slash `/`
/// - **Case-insensitive filesystem**: `File.txt` and `file.txt` are the same
/// - **MAX_PATH limit**: 260 characters unless long path support is enabled
/// - **Single instance**: Users expect one window per app
///
/// ## Related Documentation
///
/// - [Flutter Windows Desktop](https://docs.flutter.dev/platform-integration/windows/building)
/// - [Windows App Certification](https://learn.microsoft.com/en-us/windows/apps/publish/)
/// - [Long Path Support](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation)
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';
import '../../fixes/platforms/windows/case_insensitive_path_fix.dart';

// =============================================================================
// Shared constants
// =============================================================================

/// Variable name patterns that suggest a file path value.
///
/// Uses compound words only to avoid false positives from short substrings
/// (e.g. 'dir' matching 'dirty', 'file' matching 'profile'). Each entry
/// is matched case-insensitively via `String.contains`.
const Set<String> _pathVariablePatterns = <String>{
  'path',
  'directory',
  'folder',
  'filepath',
  'dirname',
  'filename',
  'basedir',
  'rootdir',
  'outputdir',
  'inputdir',
  'datadir',
  'cachedir',
  'configdir',
  'logdir',
  'dirpath',
  'fullpath',
  'absolutepath',
  'relativepath',
};

/// Returns true if [source] contains a path-like variable name pattern.
bool _containsPathPattern(String source) {
  final String lower = source.toLowerCase();
  return _pathVariablePatterns.any(lower.contains);
}

// =============================================================================
// avoid_hardcoded_drive_letters
// =============================================================================

/// Detects hardcoded Windows drive letter paths in string literals.
///
/// Since: v4.9.20 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: drive_letter, windows_path
///
/// Hardcoded drive letters like `C:\Users\` break when the app runs on a
/// different drive, different user profile, or non-Windows platform. Use
/// `path_provider` or `Platform.environment['APPDATA']` instead.
///
/// **BAD:**
/// ```dart
/// final configFile = File('C:\\Users\\me\\AppData\\myapp\\config.json');
/// final programDir = Directory('C:\\Program Files\\MyApp');
/// final tempFile = File('D:\\temp\\cache.dat');
/// ```
///
/// **GOOD:**
/// ```dart
/// final appDataDir = await getApplicationSupportDirectory();
/// final configFile = File('${appDataDir.path}\\config.json');
///
/// final appData = Platform.environment['APPDATA'];
/// final configFile = File('$appData\\myapp\\config.json');
/// ```
class AvoidHardcodedDriveLettersRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidHardcodedDriveLettersRule].
  AvoidHardcodedDriveLettersRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_hardcoded_drive_letters',
    '[avoid_hardcoded_drive_letters] Hardcoded Windows drive letter path '
        'detected. This breaks on other drives, users, or platforms. {v3}',
    correctionMessage:
        'Use path_provider (getApplicationSupportDirectory) or '
        "Platform.environment['APPDATA'] instead.",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      if (value.length < 3) return;

      // Match patterns like C:\, D:\, C:/, D:/
      if (_isDriveLetterPath(value)) {
        reporter.atNode(node);
      }
    });
  }

  /// Returns true if [value] starts with a Windows drive letter pattern.
  static bool _isDriveLetterPath(String value) {
    final int firstChar = value.codeUnitAt(0);

    // Check for A-Z or a-z
    final bool isLetter =
        (firstChar >= 0x41 && firstChar <= 0x5A) || // A-Z
        (firstChar >= 0x61 && firstChar <= 0x7A); // a-z

    if (!isLetter) return false;
    if (value.codeUnitAt(1) != 0x3A) return false; // ':'

    // Check for \ or /
    final int thirdChar = value.codeUnitAt(2);
    return thirdChar == 0x5C || thirdChar == 0x2F; // '\' or '/'
  }
}

// =============================================================================
// avoid_forward_slash_path_assumption
// =============================================================================

/// Detects path construction using `/` concatenation instead of `path.join()`.
///
/// Since: v4.9.20 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: path_separator, forward_slash_path
///
/// Building file paths with forward slash (`/`) string concatenation produces
/// paths that work on Unix but are not idiomatic on Windows. While Windows
/// accepts `/` in many contexts, some APIs and tools reject it. Always use
/// `path.join()` from the `path` package for cross-platform compatibility.
///
/// **BAD:**
/// ```dart
/// final filePath = directory + '/' + filename;
/// final nested = '$baseDir/$subDir/$file';
/// ```
///
/// **GOOD:**
/// ```dart
/// import 'package:path/path.dart' as p;
/// final filePath = p.join(directory, filename);
/// final nested = p.join(baseDir, subDir, file);
/// ```
class AvoidForwardSlashPathAssumptionRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidForwardSlashPathAssumptionRule].
  AvoidForwardSlashPathAssumptionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_forward_slash_path_assumption',
    '[avoid_forward_slash_path_assumption] Path built with "/" '
        'concatenation. This is not idiomatic on Windows. {v3}',
    correctionMessage:
        "Use path.join() from the 'path' package for cross-platform paths.",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      // Look for string + '/' + string pattern (path concatenation)
      if (node.operator.type.lexeme != '+') return;

      final Expression right = node.rightOperand;
      if (right is! SimpleStringLiteral) return;
      if (right.value != '/') return;

      // Check if left side looks like a path variable
      if (_containsPathPattern(node.leftOperand.toSource())) {
        reporter.atNode(node);
      }
    });

    // Also detect string interpolation: '$dir/$file'
    context.addStringInterpolation((StringInterpolation node) {
      final NodeList<InterpolationElement> elements = node.elements;
      if (elements.length < 3) return;

      for (int i = 1; i < elements.length - 1; i++) {
        final InterpolationElement element = elements[i];
        if (element is! InterpolationString) continue;
        if (element.value != '/') continue;

        // Check surrounding elements for path-like variable names
        final InterpolationElement prev = elements[i - 1];
        if (prev is InterpolationExpression) {
          if (_containsPathPattern(prev.expression.toSource())) {
            reporter.atNode(node);
            return;
          }
        }
      }
    });
  }
}

// =============================================================================
// avoid_case_sensitive_path_comparison
// =============================================================================

/// Detects file path comparisons that don't account for case insensitivity.
///
/// Since: v4.9.20 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: case_path, windows_case
///
/// Windows uses a case-insensitive filesystem (NTFS). Comparing file paths
/// with `==` or `contains` without normalizing case will produce incorrect
/// results: `'C:\Docs\File.txt' == 'C:\docs\file.txt'` is false in Dart
/// but these reference the same file on Windows.
///
/// **BAD:**
/// ```dart
/// if (filePath == expectedPath) { ... }
/// if (filePath.contains('Documents')) { ... }
/// if (paths.contains(targetPath)) { ... }
/// ```
///
/// **GOOD:**
/// ```dart
/// if (filePath.toLowerCase() == expectedPath.toLowerCase()) { ... }
/// if (filePath.toLowerCase().contains('documents')) { ... }
/// import 'package:path/path.dart' as p;
/// if (p.equals(filePath, targetPath)) { ... }
/// ```
///
/// **Quick fix available:** Wraps both operands with `.toLowerCase()`.
class AvoidCaseSensitivePathComparisonRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidCaseSensitivePathComparisonRule].
  AvoidCaseSensitivePathComparisonRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        CaseInsensitivePathFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'avoid_case_sensitive_path_comparison',
    '[avoid_case_sensitive_path_comparison] File path compared without '
        'case normalization. Windows filesystem is case-insensitive. {v3}',
    correctionMessage:
        'Use .toLowerCase() on both sides or path.equals() from the '
        "'path' package for case-insensitive comparison.",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addBinaryExpression((BinaryExpression node) {
      // Only check equality comparisons
      final String op = node.operator.type.lexeme;
      if (op != '==' && op != '!=') return;

      // Check if either side looks like a path variable
      final String leftSource = node.leftOperand.toSource();
      final String rightSource = node.rightOperand.toSource();

      if (!_containsPathPattern(leftSource) &&
          !_containsPathPattern(rightSource)) {
        return;
      }

      // Check if .toLowerCase() is already applied
      if (leftSource.contains('.toLowerCase()') ||
          rightSource.contains('.toLowerCase()') ||
          leftSource.contains('.toUpperCase()') ||
          rightSource.contains('.toUpperCase()')) {
        return;
      }

      reporter.atNode(node);
    });
  }
}

/// Quick fix that wraps both operands of a path comparison with
/// `.toLowerCase()` to make the comparison case-insensitive.

// =============================================================================
// require_windows_single_instance_check
// =============================================================================

/// Detects Windows desktop apps without single-instance enforcement.
///
/// Since: v4.9.20 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: single_instance, windows_mutex
///
/// Windows users expect desktop applications to be single-instance: launching
/// the app again should bring the existing window to the front rather than
/// opening a second copy. Without this, users accumulate duplicate windows
/// and potentially corrupt shared state.
///
/// **BAD:**
/// ```dart
/// void main() {
///   runApp(const MyApp());
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() {
///   // Using windows_single_instance or similar package
///   final isFirstInstance = await WindowsSingleInstance.ensureSingleInstance(
///     args,
///     'my_app_unique_id',
///   );
///   if (!isFirstInstance) return;
///
///   runApp(const MyApp());
/// }
/// ```
class RequireWindowsSingleInstanceCheckRule extends SaropaLintRule {
  /// Creates a new instance of [RequireWindowsSingleInstanceCheckRule].
  RequireWindowsSingleInstanceCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_windows_single_instance_check',
    '[require_windows_single_instance_check] runApp() called without '
        'single-instance check. Users may open duplicate windows. {v3}',
    correctionMessage:
        'Add single-instance enforcement using windows_single_instance '
        'package or a mutex/named pipe check before runApp().',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addFunctionDeclaration((FunctionDeclaration node) {
      // Only check the main() function
      if (node.name.lexeme != 'main') return;

      final FunctionBody body = node.functionExpression.body;
      final String bodySource = body.toSource();

      // Must contain runApp to be relevant
      if (!bodySource.contains('runApp')) return;

      // Check for single instance patterns
      if (bodySource.contains('SingleInstance') ||
          bodySource.contains('singleInstance') ||
          bodySource.contains('single_instance') ||
          bodySource.contains('mutex') ||
          bodySource.contains('Mutex') ||
          bodySource.contains('namedPipe') ||
          bodySource.contains('NamedPipe') ||
          bodySource.contains('ensureSingleInstance') ||
          bodySource.contains('isFirstInstance')) {
        return; // Has single instance handling
      }

      // Check for Windows platform guard
      if (!bodySource.contains('Platform.isWindows') &&
          !bodySource.contains('TargetPlatform.windows') &&
          !bodySource.contains('defaultTargetPlatform')) {
        return; // Not clearly a Windows-targeted main
      }

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// avoid_max_path_risk
// =============================================================================

/// Detects deeply nested path construction that may exceed Windows MAX_PATH.
///
/// Since: v4.9.20 | Updated: v4.13.0 | Rule version: v3
///
/// Alias: max_path, path_length
///
/// Windows' traditional MAX_PATH limit is 260 characters. While long path
/// support can be enabled, many tools and libraries still enforce this limit.
/// Deeply nested path construction with multiple segments is risky, especially
/// when combined with user home directories or AppData paths.
///
/// **BAD:**
/// ```dart
/// final path = '$appData\\mycompany\\myapp\\data\\cache\\images\\thumbnails\\large\\$id.png';
/// final deep = p.join(base, 'a', 'b', 'c', 'd', 'e', 'f', filename);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use shorter directory structures
/// final path = '$appData\\myapp\\cache\\$id.png';
/// final flat = p.join(base, 'cache', filename);
///
/// // Or enable long path support and document the requirement
/// // Windows Registry: LongPathsEnabled = 1
/// ```
class AvoidMaxPathRiskRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidMaxPathRiskRule].
  AvoidMaxPathRiskRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_max_path_risk',
    '[avoid_max_path_risk] Deeply nested path construction detected. '
        "This may exceed Windows' 260-character MAX_PATH limit. {v3}",
    correctionMessage:
        'Flatten the directory structure or enable long path support '
        '(LongPathsEnabled registry key).',
    severity: DiagnosticSeverity.INFO,
  );

  /// Minimum number of path.join arguments to trigger the warning.
  static const int _maxJoinSegments = 6;

  /// Minimum number of separator characters in a string literal path.
  static const int _maxLiteralSegments = 5;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Detect path.join() with too many segments
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (methodName != 'join') return;

      // Check if target looks like a path package call
      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (targetSource != 'p' &&
          targetSource != 'path' &&
          targetSource != 'Path') {
        return;
      }

      if (node.argumentList.arguments.length >= _maxJoinSegments) {
        reporter.atNode(node);
      }
    });

    // Detect string literals with many path separators
    context.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      if (value.length < 20) return;

      int separatorCount = 0;
      for (int i = 0; i < value.length; i++) {
        final int char = value.codeUnitAt(i);
        if (char == 0x5C || char == 0x2F) separatorCount++; // '\' or '/'
      }

      if (separatorCount >= _maxLiteralSegments) {
        reporter.atNode(node);
      }
    });
  }
}
