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
///
/// The bare word 'path' is handled separately via [_hasPathAsWord] because
/// naive substring matching lit up unrelated identifiers and string
/// literals that merely contain "path" as embedded text — e.g.
/// "pathology", "empathy", "warpath", or a CLI flag like
/// '--json-file-path'. The remaining entries are multi-syllable compounds
/// ('directory', 'filepath', ...) that are already specific enough that
/// plain substring matching does not misfire on them.
bool _containsPathPattern(String source) {
  final String lower = source.toLowerCase();
  for (final String pattern in _pathVariablePatterns) {
    if (pattern == 'path') {
      if (_hasPathAsWord(source)) return true;
      continue;
    }
    if (lower.contains(pattern)) return true;
  }
  return false;
}

/// Returns true if [source] contains "path" as a standalone camelCase word
/// component rather than as a substring buried inside an unrelated word.
///
/// A match at `[start, end)` counts as a real word boundary when:
/// - the character before it is missing, not a lowercase letter, or the
///   match itself starts with capital 'P' (a camelCase transition, as in
///   `filePath`) — so a lowercase 'path' glued onto a preceding lowercase
///   letter (as in "empathy", "warpath") is rejected, and
/// - the character after it is missing or not a lowercase letter — so
///   "pathVariable"/"PathValue" count (capital letter follows), but
///   "pathology" does not (lowercase 'o' continues the same word).
bool _hasPathAsWord(String source) {
  for (final RegExpMatch match in _pathOccurrenceRegex.allMatches(source)) {
    final int start = match.start;
    final int end = match.end;
    final bool startsUpperP = source.codeUnitAt(start) == 0x50; // 'P'

    final bool beforeOk =
        start == 0 ||
        !_isLowerAsciiLetter(source.codeUnitAt(start - 1)) ||
        startsUpperP;
    final bool afterOk =
        end == source.length || !_isLowerAsciiLetter(source.codeUnitAt(end));

    if (beforeOk && afterOk) return true;
  }
  return false;
}

/// Matches the literal text "path" case-insensitively, used by
/// [_hasPathAsWord] to locate candidate occurrences before applying the
/// camelCase boundary check.
final RegExp _pathOccurrenceRegex = RegExp('path', caseSensitive: false);

/// Returns true if [codeUnit] is an ASCII lowercase letter ('a'-'z').
bool _isLowerAsciiLetter(int codeUnit) => codeUnit >= 0x61 && codeUnit <= 0x7A;

/// Returns true if both sides of [node] resolve to `String` at the type level.
/// Falls back to AST-level null/bool literal exclusion when static types are
/// unavailable (unresolved code, dynamic expressions).
bool _isBothSidesString(BinaryExpression node) {
  final leftType = node.leftOperand.staticType;
  final rightType = node.rightOperand.staticType;

  // When the analyzer has resolved types, use them — catches null, bool, int,
  // enum, and every other non-string operand in one check.
  if (leftType != null && rightType != null) {
    return leftType.isDartCoreString && rightType.isDartCoreString;
  }

  // Fallback: exclude obvious non-string literals when types are unresolved.
  if (node.leftOperand is NullLiteral || node.rightOperand is NullLiteral) {
    return false;
  }
  if (node.leftOperand is BooleanLiteral ||
      node.rightOperand is BooleanLiteral) {
    return false;
  }
  if (node.leftOperand is IntegerLiteral ||
      node.rightOperand is IntegerLiteral) {
    return false;
  }
  if (node.leftOperand is DoubleLiteral || node.rightOperand is DoubleLiteral) {
    return false;
  }

  // Types unresolved and no disqualifying literal — assume string to avoid
  // missing real path comparisons in partially analyzed code.
  return true;
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
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'platform'};

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
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'platform'};

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
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'platform'};

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

      // Case sensitivity only matters for string-to-string comparisons.
      // Skip null checks, boolean guards, integer comparisons, enum matches,
      // and any other non-string operand — none of those are path comparisons.
      if (!_isBothSidesString(node)) return;

      // Check if either side looks like a path variable
      final String leftSource = node.leftOperand.toSource();
      final String rightSource = node.rightOperand.toSource();

      if (!_containsPathPattern(leftSource) &&
          !_containsPathPattern(rightSource)) {
        return;
      }

      // Root-detection idiom: `dir.path == dir.parent.path` — both
      // sides come from the same Directory API call so casing is
      // always consistent; this is a standard Dart filesystem-root test.
      if (_isRootDetectionIdiom(leftSource, rightSource)) return;

      // String literal that doesn't contain a path separator is a CLI
      // flag or label, not a filesystem path. The word "path" in the
      // name (e.g. '--json-file-path') triggered the heuristic wrongly.
      if (_isNonPathStringLiteral(node.leftOperand) ||
          _isNonPathStringLiteral(node.rightOperand)) {
        return;
      }

      // Dart import URIs are case-sensitive by language spec — these
      // are not filesystem path comparisons.
      if (_isDartImportUri(node.leftOperand) ||
          _isDartImportUri(node.rightOperand)) {
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

  /// Detects the standard Dart root-detection idiom where a Directory's
  /// `.path` is compared to its `.parent.path` — both sides come from the
  /// same API so casing is always consistent.
  ///
  /// Verifies that both sides share the same base expression (e.g.
  /// `dir.path == dir.parent.path` is OK, but `a.path == b.parent.path`
  /// is NOT — `a` and `b` are different variables so casing consistency
  /// is not guaranteed).
  bool _isRootDetectionIdiom(String left, String right) {
    // Try both orderings: `dir.path == dir.parent.path` and the reverse.
    return _isRootDetectionPair(left, right) ||
        _isRootDetectionPair(right, left);
  }

  /// Returns true when [simple] is `<base>.path` and [parent] is
  /// `<base>.parent.path` with the SAME `<base>` prefix.
  ///
  /// Without the base-expression check, `a.path == b.parent.path` would
  /// be falsely suppressed — `a` and `b` might be different directories
  /// with different casing (C15).
  bool _isRootDetectionPair(String simple, String parent) {
    // The simple side must end with `.path` but NOT `.parent.path`.
    if (!simple.endsWith('.path')) return false;
    if (simple.endsWith('.parent.path')) return false;

    // The parent side must end with `.parent.path`.
    if (!parent.endsWith('.parent.path')) return false;

    // Extract the base expression from each side and compare.
    // `dir.path`        → base = `dir`
    // `dir.parent.path` → base = `dir`
    final String simpleBase = simple.substring(
      0,
      simple.length - '.path'.length,
    );
    final String parentBase = parent.substring(
      0,
      parent.length - '.parent.path'.length,
    );

    // Both sides must refer to the same variable/expression.
    return simpleBase == parentBase;
  }

  /// Returns true when [expr] is a string literal that does not contain
  /// a filesystem path separator — it's a CLI flag or label name, not
  /// an actual path, even if the variable name contains "path".
  bool _isNonPathStringLiteral(Expression expr) {
    if (expr is! SimpleStringLiteral) return false;
    final String value = expr.value;
    return !value.contains('/') && !value.contains(r'\');
  }

  /// Returns true when [expr]'s own name suggests a Dart import URI
  /// (contains "import" or "uri"), or when [expr] is a for-each loop
  /// variable iterating over an import-like collection — import
  /// specifiers are case-sensitive by language spec and are not
  /// filesystem paths.
  bool _isDartImportUri(Expression expr) {
    if (expr is! SimpleIdentifier) return false;
    final String name = expr.name.toLowerCase();
    // Match 'import' anywhere, but 'uri' only as a camelCase segment —
    // plain `contains('uri')` would match e.g. `fileUri` (a real path
    // variable) and suppress a genuine case-sensitive comparison finding.
    if (name.contains('import') ||
        RegExp(r'(?:^|[^a-z])uri(?:$|[^a-z])').hasMatch(name)) {
      return true;
    }
    return _isLoopVariableOverImportsCollection(expr);
  }

  /// Returns true when [expr] is a for-each loop variable whose iterable
  /// expression looks like an import list — e.g. `for (final imp in
  /// node.imports)`. Loop variables over import collections are commonly
  /// abbreviated ('imp') and don't themselves contain "import"/"uri", so
  /// the direct name check above misses them. This walks up to the
  /// nearest enclosing for-each loop and inspects what it iterates over
  /// instead, matching on the loop variable's own name to make sure
  /// [expr] actually refers to that loop variable and not an unrelated
  /// identifier that merely shares scope with the loop.
  bool _isLoopVariableOverImportsCollection(SimpleIdentifier expr) {
    final ForStatement? forStatement = expr
        .thisOrAncestorOfType<ForStatement>();
    final ForEachParts? parts = forStatement?.forLoopParts is ForEachParts
        ? forStatement!.forLoopParts as ForEachParts
        : null;
    if (parts == null) return false;

    final String? loopVarName = switch (parts) {
      ForEachPartsWithDeclaration d => d.loopVariable.name.lexeme,
      ForEachPartsWithIdentifier i => i.identifier.name,
      _ => null,
    };
    if (loopVarName != expr.name) return false;

    final String iterableSource = parts.iterable.toSource().toLowerCase();
    return iterableSource.contains('import') ||
        iterableSource.contains('uri');
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
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'platform'};

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

  static final RegExp _runAppRegex = RegExp(r'\brunApp\b');
  static final RegExp _singleInstanceRegex = RegExp(r'\bSingleInstance\b');
  static final RegExp _singleInstanceCamelRegex = RegExp(r'\bsingleInstance\b');
  static final RegExp _singleInstanceSnakeRegex = RegExp(
    r'\bsingle_instance\b',
  );
  static final RegExp _mutexRegex = RegExp(r'\bmutex\b');
  static final RegExp _mutexCapRegex = RegExp(r'\bMutex\b');
  static final RegExp _namedPipeRegex = RegExp(r'\bnamedPipe\b');
  static final RegExp _namedPipeCapRegex = RegExp(r'\bNamedPipe\b');
  static final RegExp _ensureSingleInstanceRegex = RegExp(
    r'\bensureSingleInstance\b',
  );
  static final RegExp _isFirstInstanceRegex = RegExp(r'\bisFirstInstance\b');
  static final RegExp _platformIsWindowsRegex = RegExp(
    r'\bPlatform\.isWindows\b',
  );
  static final RegExp _targetPlatformWindowsRegex = RegExp(
    r'\bTargetPlatform\.windows\b',
  );
  static final RegExp _defaultTargetPlatformRegex = RegExp(
    r'\bdefaultTargetPlatform\b',
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
      if (!_runAppRegex.hasMatch(bodySource)) return;

      // Check for single instance patterns
      if (_singleInstanceRegex.hasMatch(bodySource) ||
          _singleInstanceCamelRegex.hasMatch(bodySource) ||
          _singleInstanceSnakeRegex.hasMatch(bodySource) ||
          _mutexRegex.hasMatch(bodySource) ||
          _mutexCapRegex.hasMatch(bodySource) ||
          _namedPipeRegex.hasMatch(bodySource) ||
          _namedPipeCapRegex.hasMatch(bodySource) ||
          _ensureSingleInstanceRegex.hasMatch(bodySource) ||
          _isFirstInstanceRegex.hasMatch(bodySource)) {
        return; // Has single instance handling
      }

      // Check for Windows platform guard
      if (!_platformIsWindowsRegex.hasMatch(bodySource) &&
          !_targetPlatformWindowsRegex.hasMatch(bodySource) &&
          !_defaultTargetPlatformRegex.hasMatch(bodySource)) {
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
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'platform'};

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
