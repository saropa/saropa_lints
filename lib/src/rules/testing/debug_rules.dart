// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import '../../analyzer_compat.dart';
import '../../early_exit_guard_utils.dart';
import '../../mode_constants_utils.dart';
import '../../saropa_lint_rule.dart';
import '../../fixes/debug/replace_with_debug_print_fix.dart';
import '../../fixes/debug/comment_out_sensitive_log_fix.dart';
import '../../fixes/debug/wrap_in_debug_mode_fix.dart';

/// Test-only rule that always reports a lint at the start of the file.
///
/// Since: v4.8.2 | Updated: v4.13.0 | Rule version: v3
///
/// Formerly: `always_fail_test_case`
class AlwaysFailRule extends SaropaLintRule {
  AlwaysFailRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'testing'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<String> get configAliases => const <String>['always_fail_test_case'];

  @override
  String get exampleBad => '// any file — rule always triggers';

  @override
  String get exampleGood => '// disable the rule in analysis_options';

  static const LintCode _code = LintCode(
    'prefer_fail_test_case',
    '[prefer_fail_test_case] This custom lint always fails (test hook). Formerly: always_fail_test_case. Test-only rule that always reports a lint at the start of the file. {v3}',
    correctionMessage:
        'This rule always fails by design — it verifies your lint pipeline is active. Seeing this error confirms saropa_lints is running. Remove prefer_fail_test_case from your enabled rules once verified.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
      final Token firstToken = unit.beginToken;
      reporter.atToken(firstToken);
    });
  }
}

// NOTE: AvoidCommentedOutCodeRule moved to stylistic_rules.dart (v4.2.0)
// The rule now reports at actual comment locations and has a quick fix.

/// Warns when `debugPrint()` calls are not guarded by a debug check.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v3
///
/// The project's `debug()` function is production-safe logging infrastructure
/// with its own level filtering and Crashlytics routing — it is NOT flagged.
///
/// `debugPrint()` bypasses all of that and writes directly to the console,
/// so it should be guarded to avoid cluttering production output.
///
/// **Guarded patterns (allowed):**
/// - Inside `if (kDebugMode)` block
/// - Inside `if (DebugType.*.isDebug)` block
/// - Inside `if (MainSettings.isDebugMode)` block
/// - Inside `if (isDebug*)` local variable check
/// - Inside exception handler (catch block)
/// - Inside assert() statement
/// - Inside a method/function named `debug*` or `_debug*` (debug helpers)
///
/// Example of **bad** code:
/// ```dart
/// void someMethod() {
///   debugPrint('Value: $x');  // Unguarded - will print in production
/// }
/// ```
///
/// Example of **good** code:
/// ```dart
/// void someMethod() {
///   if (kDebugMode) {
///     debugPrint('Value: $x');
///   }
///
///   // debug() is always allowed — it's production-safe
///   debug('Missing data');
///   debug('Important warning', level: DebugLevels.Warning);
/// }
/// ```
class AvoidUnguardedDebugRule extends SaropaLintRule {
  AvoidUnguardedDebugRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'testing'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_unguarded_debug',
    '[avoid_unguarded_debug] debugPrint() is not guarded by a debug mode check. {v3}',
    correctionMessage:
        'Wrap in if (kDebugMode) or if (DebugType.*.isDebug). '
        'Consider using debug() instead, which is production-safe.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Pre-compiled patterns for performance - avoid creating RegExp in loops
  static final RegExp _isDebugPattern = RegExp(r'\bisDebug\w*\b');
  static final RegExp _debugSuffixPattern = RegExp(r'\bis\w*Debug\b');
  static final RegExp _kDebugModeRegex = RegExp(r'\bkDebugMode\b');
  static final RegExp _debugTypeDotRegex = RegExp(r'\bDebugType\.');
  static final RegExp _dotIsDebugRegex = RegExp(r'\.isDebug\b');
  static final RegExp _mainSettingsDebugRegex = RegExp(
    r'\bMainSettings\.isDebugMode\b',
  );
  static final RegExp _mainSettingsProfileRegex = RegExp(
    r'\bMainSettings\.isProfileMode\b',
  );
  static final RegExp _userPreferenceDebugRegex = RegExp(
    r'\bUserPreferenceType\.Debug\b',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Only flag debugPrint() — the project's debug() function is
    // production-safe logging infrastructure with its own level filtering.
    // Bare debug() calls are intentional and should not require guards.

    // Check for debugPrint() function calls
    context.addFunctionExpressionInvocation((
      FunctionExpressionInvocation node,
    ) {
      final Expression function = node.function;
      if (function is SimpleIdentifier && function.name == 'debugPrint') {
        if (!_isGuarded(node)) {
          reporter.atNode(node);
        }
      }
    });

    // Check for debugPrint() method invocations
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      if (methodName == 'debugPrint') {
        if (!_isGuarded(node)) {
          reporter.atNode(node);
        }
      }
    });
  }

  /// Check if the node is inside a debug guard.
  ///
  /// Recognizes two patterns:
  /// 1. Direct wrapping: `if (kDebugMode) { debugPrint(...); }`
  /// 2. Early-return guard: `if (!kDebugMode) return;` preceding the call
  ///
  /// Note: the walk crosses closure/function-expression boundaries. This is
  /// correct for compile-time constants like `kDebugMode` (the closure can
  /// only be created inside the guarded zone), but is technically unsound for
  /// runtime-mutable guards (`isDebugActive`, etc.) where the value could
  /// change between closure creation and execution. This is a pre-existing
  /// design trade-off shared with the wrapping-if pattern — all guard
  /// patterns accepted by `_isDebugGuardCondition` are treated identically.
  bool _isGuarded(AstNode node) {
    // Early-return guard: `if (!kDebugMode) return;` dominates all
    // subsequent statements in the same block. kDebugMode is compile-time
    // constant so closures created in the guarded zone are safe to cross.
    if (hasDominatingEarlyExitGuard(
      node,
      predicate: _isNegatedDebugGuardCondition,
      exitTest: endsWithEarlyExit,
      stopAtClosureBoundary: false,
    )) {
      return true;
    }

    // Wrapping guards, debug-named helpers, assert, and catch
    return _hasAncestorGuard(node);
  }

  /// Walk ancestors checking for wrapping debug guards, debug-named
  /// methods/functions, assert statements, and catch clauses.
  bool _hasAncestorGuard(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (_isGuardingAncestor(current, node)) return true;
      current = current.parent;
    }
    return false;
  }

  /// True when [ancestor] is a guard that protects [target] from
  /// needing an explicit debug check.
  bool _isGuardingAncestor(AstNode ancestor, AstNode target) {
    // Wrapping if-statement guard: `if (kDebugMode) { ... }`
    if (ancestor is IfStatement) {
      return _isDebugGuardCondition(ancestor.expression);
    }
    // Enclosing method/function named debug* or _debug*
    if (ancestor is MethodDeclaration || ancestor is FunctionDeclaration) {
      return _isDebugNamedDeclaration(ancestor);
    }
    // Assert statement — debug code by definition
    if (ancestor is AssertStatement) return true;
    // Catch clause — exception handling is allowed
    if (ancestor is CatchClause) return true;
    // Inside a try statement's catch block
    if (ancestor is TryStatement) {
      return ancestor.catchClauses.any(
        (CatchClause c) => _isDescendantOf(target, c),
      );
    }
    return false;
  }

  /// True when [node] is a method or function declaration starting with
  /// `debug` or `_debug` — debug helpers only called from guarded sites.
  bool _isDebugNamedDeclaration(AstNode node) {
    String? lexeme;
    if (node is MethodDeclaration) {
      lexeme = node.name.lexeme;
    } else if (node is FunctionDeclaration) {
      lexeme = node.name.lexeme;
    }
    if (lexeme == null) return false;
    return lexeme.startsWith('debug') || lexeme.startsWith('_debug');
  }

  /// Check if a condition is a debug guard (positive form).
  ///
  /// Matches `kDebugMode`, `DebugType.*.isDebug`, `MainSettings.isDebugMode`,
  /// `isDebug*` local variables, `is*Debug` patterns, and
  /// `UserPreferenceType.Debug*`.
  bool _isDebugGuardCondition(Expression condition) {
    final String source = condition.toSource();

    // kDebugMode
    if (_kDebugModeRegex.hasMatch(source)) {
      return true;
    }

    // DebugType.*.isDebug
    if (_debugTypeDotRegex.hasMatch(source) &&
        _dotIsDebugRegex.hasMatch(source)) {
      return true;
    }

    // MainSettings.isDebugMode or MainSettings.isProfileMode
    if (_mainSettingsDebugRegex.hasMatch(source) ||
        _mainSettingsProfileRegex.hasMatch(source)) {
      return true;
    }

    // isDebug* local variable patterns
    if (_isDebugPattern.hasMatch(source)) {
      return true;
    }

    // is*Debug patterns (isAudioDebug, isWidgetDebug, etc.)
    if (_debugSuffixPattern.hasMatch(source)) {
      return true;
    }

    // UserPreferenceType.Debug* patterns
    if (_userPreferenceDebugRegex.hasMatch(source)) {
      return true;
    }

    // Variable indirection: `final isDebug = kDebugMode;` or chained
    // `final a = kDebugMode; final b = a;` — resolve through up to 3
    // levels of final/const assignment and check each initializer
    final Expression? resolved = _resolveChainedInitializer(condition);
    if (resolved != null) {
      return _isDebugGuardCondition(resolved);
    }

    return false;
  }

  /// Check if a node is a descendant of another node
  bool _isDescendantOf(AstNode node, AstNode potentialAncestor) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current == potentialAncestor) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  /// True when [condition] is the negation of a recognized debug guard,
  /// e.g. `!kDebugMode`, `kDebugMode == false`, `kDebugMode != true`.
  bool _isNegatedDebugGuardCondition(Expression condition) {
    // Prefix negation: `!kDebugMode`
    if (condition is PrefixExpression && condition.operator.lexeme == '!') {
      return _isDebugGuardCondition(condition.operand);
    }

    if (condition is BinaryExpression) {
      // Equality-with-false: `kDebugMode == false` or `false == kDebugMode`
      if (condition.operator.lexeme == '==') {
        if (_isBoolLiteral(condition.rightOperand, false)) {
          return _isDebugGuardCondition(condition.leftOperand);
        }
        if (_isBoolLiteral(condition.leftOperand, false)) {
          return _isDebugGuardCondition(condition.rightOperand);
        }
      }
      // Inequality-with-true: `kDebugMode != true` or `true != kDebugMode`
      if (condition.operator.lexeme == '!=') {
        if (_isBoolLiteral(condition.rightOperand, true)) {
          return _isDebugGuardCondition(condition.leftOperand);
        }
        if (_isBoolLiteral(condition.leftOperand, true)) {
          return _isDebugGuardCondition(condition.rightOperand);
        }
      }
    }
    return false;
  }

  /// True when [expr] is a boolean literal matching [expected].
  bool _isBoolLiteral(Expression expr, bool expected) {
    return expr is BooleanLiteral && expr.value == expected;
  }

  /// Follow a chain of `final`/`const` variable assignments up to
  /// [_maxIndirectionDepth] levels to find the terminal initializer.
  ///
  /// Resolves local variables, top-level constants, and static class
  /// fields — all via pure AST walk (no type resolution). Example:
  /// `final a = kDebugMode; final b = a;` — resolving `b` yields
  /// `kDebugMode` after two hops. Returns `null` if the chain breaks (no
  /// declaration found, mutable var, or depth exceeded). Tracks visited
  /// names to prevent infinite loops on circular references.
  Expression? _resolveChainedInitializer(Expression expr) {
    // Track visited variable names to prevent cycles
    final Set<String> visited = {};
    Expression current = expr;

    for (int depth = 0; depth < _maxIndirectionDepth; depth++) {
      if (current is! SimpleIdentifier) return null;
      final String name = current.name;

      // Cycle detection — a variable referencing itself (impossible in
      // valid Dart, but defensive against malformed AST)
      if (!visited.add(name)) return null;

      // Try local scope first, then fall back to static element resolution
      // for top-level constants and static class fields
      final Expression? initializer =
          _findLocalInitializer(current, name) ??
          _resolveStaticInitializer(current);
      if (initializer == null) return null;

      // If the initializer is itself a simple identifier, follow the chain
      if (initializer is SimpleIdentifier) {
        current = initializer;
        continue;
      }
      // Terminal expression — return it for the caller to test
      return initializer;
    }
    return null;
  }

  /// Find the initializer of a `final`/`const` local variable named [name]
  /// declared in an enclosing block of [expr], BEFORE the usage site.
  ///
  /// Only considers declarations whose offset precedes [expr] — a forward
  /// reference is invalid Dart and would be unsound to trust as a guard.
  Expression? _findLocalInitializer(Expression expr, String name) {
    final int usageOffset = expr.offset;
    AstNode? current = expr.parent;
    while (current != null) {
      if (current is Block) {
        for (final Statement stmt in current.statements) {
          // Only check declarations before the usage site
          if (stmt.offset >= usageOffset) break;
          if (stmt is! VariableDeclarationStatement) continue;
          final VariableDeclarationList declList = stmt.variables;
          // Only trust final/const — mutable vars can be reassigned
          if (!declList.isFinal && !declList.isConst) continue;
          for (final VariableDeclaration decl in declList.variables) {
            if (decl.name.lexeme == name && decl.initializer != null) {
              return decl.initializer;
            }
          }
        }
      }
      // Stop at function/method boundaries — outer scope vars are not
      // guaranteed to be in the same execution context
      if (current is FunctionExpression ||
          current is MethodDeclaration ||
          current is FunctionDeclaration) {
        break;
      }
      current = current.parent;
    }
    return null;
  }

  /// Resolve a [SimpleIdentifier] to the initializer of a top-level or
  /// static class `final`/`const` variable in the same compilation unit.
  ///
  /// Pure AST walk — does NOT use `.element` or type resolution, keeping
  /// this rule in the light lane for fast analysis.
  Expression? _resolveStaticInitializer(SimpleIdentifier identifier) {
    final CompilationUnit? unit = _findCompilationUnit(identifier);
    if (unit == null) return null;

    final String targetName = identifier.name;
    return _findFieldInitializerInUnit(unit, targetName);
  }

  /// Walk a CompilationUnit's top-level and class-level declarations to
  /// find the initializer of a `final`/`const` field matching [targetName].
  Expression? _findFieldInitializerInUnit(
    CompilationUnit unit,
    String targetName,
  ) {
    for (final CompilationUnitMember member in unit.declarations) {
      // Top-level variable declarations
      if (member is TopLevelVariableDeclaration) {
        final Expression? init =
            _matchVariableDecl(member.variables, targetName);
        if (init != null) return init;
      }
      // Static fields inside classes/mixins/extensions
      if (member is ClassDeclaration) {
        final Expression? init =
            _findStaticFieldInClass(member.bodyMembers, targetName);
        if (init != null) return init;
      }
    }
    return null;
  }

  /// Search class/mixin members for a static field matching [name].
  Expression? _findStaticFieldInClass(
    List<ClassMember> members,
    String name,
  ) {
    for (final ClassMember member in members) {
      if (member is! FieldDeclaration || !member.isStatic) continue;
      final Expression? init = _matchVariableDecl(member.fields, name);
      if (init != null) return init;
    }
    return null;
  }

  /// Match a variable declaration list for a final/const [name] with an
  /// initializer.
  Expression? _matchVariableDecl(VariableDeclarationList list, String name) {
    if (!list.isFinal && !list.isConst) return null;
    for (final VariableDeclaration decl in list.variables) {
      if (decl.name.lexeme == name && decl.initializer != null) {
        return decl.initializer;
      }
    }
    return null;
  }

  /// Walk up from [node] to find the enclosing CompilationUnit.
  CompilationUnit? _findCompilationUnit(AstNode node) {
    AstNode? current = node;
    while (current != null) {
      if (current is CompilationUnit) return current;
      current = current.parent;
    }
    return null;
  }

  /// Maximum depth for following variable indirection chains.
  /// Keeps resolution bounded — deeper chains are unlikely in practice.
  static const int _maxIndirectionDepth = 3;
}

/// Warns when `// ignore:` comments don't have a preceding explanatory comment.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Analyzer ignore comments should be documented to explain why the rule is being
/// ignored. This helps future maintainers understand the reasoning.
///
/// Example of **bad** code:
/// ```dart
/// // ignore: avoid_print
/// print('Hello');
/// ```
///
/// Example of **good** code:
/// ```dart
/// // Logging is needed here for debugging during development
/// // ignore: avoid_print
/// print('Hello');
/// ```
class PreferCommentingAnalyzerIgnoresRule extends SaropaLintRule {
  PreferCommentingAnalyzerIgnoresRule() : super(code: _code);

  /// Style/consistency. Large counts acceptable in legacy code.
  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'testing'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_commenting_analyzer_ignores',
    '[prefer_commenting_analyzer_ignores] Analyzer ignore comment must have a preceding explanatory comment. This debug artifact executes in production, potentially exposing internal state or degrading performance. {v5}',
    correctionMessage:
        'Add a comment on the line above explaining why this rule is ignored. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Pre-compiled patterns for performance
  static final RegExp _ignorePattern = RegExp(r'^//\s*ignore:');
  static final RegExp _ignoreForFilePattern = RegExp(r'^//\s*ignore_for_file:');
  static final RegExp _ignoreDirectivePattern = RegExp(
    r'//\s*ignore(?:_for_file)?:\s*\S+',
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit node) {
      final String content = context.fileContent;
      final List<String> lines = content.split('\n');

      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i].trim();

        // Check for ignore comments (both // ignore: and // ignore_for_file:)
        if (_isIgnoreComment(line)) {
          // Check if there's a preceding explanatory comment
          if (!_hasPrecedingComment(lines, i)) {
            // Report at the ignore comment location
            final int columnStart = lines[i].indexOf('// ignore');
            if (columnStart >= 0) {
              // Find the actual offset in the file
              int offset = 0;
              for (int j = 0; j < i; j++) {
                offset += lines[j].length + 1; // +1 for newline
              }
              offset += columnStart;

              // Find the end of the ignore directive
              final int length = _getIgnoreCommentLength(lines[i], columnStart);

              reporter.atOffset(offset: offset, length: length);
            }
          }
        }
      }
    });
  }

  /// Check if a line contains an ignore comment
  bool _isIgnoreComment(String line) {
    // Match // ignore: or // ignore_for_file:
    // But not lines that are already explanatory comments followed by ignore
    return _ignorePattern.hasMatch(line) ||
        _ignoreForFilePattern.hasMatch(line);
  }

  /// Check if the line before has an explanatory comment
  bool _hasPrecedingComment(List<String> lines, int currentIndex) {
    if (currentIndex == 0) return false;

    // Look at the previous non-empty line
    for (int i = currentIndex - 1; i >= 0; i--) {
      final String prevLine = lines[i].trim();

      // Skip empty lines
      if (prevLine.isEmpty) continue;

      // Check if it's a comment (but not another ignore comment)
      if (prevLine.startsWith('//')) {
        // Make sure it's not another ignore comment
        if (!_isIgnoreComment(prevLine)) {
          return true;
        }
        // If it's another ignore, keep looking
        continue;
      }

      // If we hit code, there's no preceding comment
      return false;
    }

    return false;
  }

  /// Get the length of the ignore comment for reporting
  int _getIgnoreCommentLength(String line, int start) {
    // Find the ignore comment pattern directly in the full line
    final RegExpMatch? match = _ignoreDirectivePattern.firstMatch(line);
    if (match != null && match.start >= start) {
      return match.end - start;
    }
    return line.length - start;
  }
}

// =============================================================================
// Debug Output Rules
// =============================================================================

/// Suggests using debugPrint instead of print for better output throttling.
///
/// Since: unknown | Updated: v12.3.3 | Rule version: v2
///
/// The print() function can overwhelm the system console and cause message
/// loss when called rapidly. debugPrint() throttles output to avoid this
/// issue and is the recommended way to log debug information.
///
/// **Scope:** Flutter projects only. debugPrint() is defined in
/// `package:flutter/foundation.dart`, so the recommendation is unactionable
/// in a pure Dart package — adopting it would require taking on a full
/// Flutter dependency. The rule returns early when the enclosing project
/// does not declare Flutter in its pubspec (mirrors `avoid_print_in_release`).
///
/// **BAD:**
/// ```dart
/// for (final item in largeList) {
///   print('Processing: $item'); // Can overflow console buffer!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// for (final item in largeList) {
///   debugPrint('Processing: $item'); // Throttled output
/// }
/// ```
///
/// **Note:** In production code, consider using a proper logging framework
/// instead of either print() or debugPrint().
class PreferDebugPrintRule extends SaropaLintRule {
  PreferDebugPrintRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'testing'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceWithDebugPrintFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'prefer_debug_print',
    '[prefer_debug_print] print() should use debugPrint() for throttled console output. {v2}',
    correctionMessage:
        'Replace print() with debugPrint() to prevent console buffer overflow.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // debugPrint() lives in package:flutter/foundation.dart, so recommending
    // it in a pure Dart package is unactionable — the author would have to
    // take on a full Flutter dependency just to silence this lint. Mirror
    // the gate used by AvoidPrintInReleaseRule below.
    final projectInfo = ProjectContext.getProjectInfo(context.filePath);
    if (projectInfo == null || !projectInfo.isFlutterProject) return;

    context.addMethodInvocation((MethodInvocation node) {
      // Only check for print function calls
      if (node.methodName.name != 'print') return;

      // Make sure it's a top-level print call (no target)
      // This avoids matching object.print() methods
      if (node.target != null) return;

      // Skip if inside a test file - print is often acceptable there
      // (handled by testRelevance - default skips test files)

      reporter.atNode(node);
    });

    // Also check for function expression invocations of print
    context.addFunctionExpressionInvocation((
      FunctionExpressionInvocation node,
    ) {
      final Expression function = node.function;
      if (function is SimpleIdentifier && function.name == 'print') {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// v4.1.6 Rules - Logging Best Practices
// =============================================================================

/// Warns when print() is used without kDebugMode check.
///
/// Since: v4.1.6 | Updated: v4.13.0 | Rule version: v3
///
/// print() statements execute in release builds, potentially exposing
/// sensitive information or impacting performance. Always guard print
/// statements with kDebugMode.
///
/// `[CONTEXT]` - Requires understanding surrounding code context.
///
/// **BAD:**
/// ```dart
/// void processUser(User user) {
///   print('Processing user: ${user.email}'); // Runs in release!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void processUser(User user) {
///   if (kDebugMode) {
///     print('Processing user: ${user.email}');
///   }
/// }
/// ```
class AvoidPrintInReleaseRule extends SaropaLintRule {
  AvoidPrintInReleaseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'testing'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_print_in_release',
    '[avoid_print_in_release] Using print() in production exposes debug information to end users, can leak sensitive data, and negatively impacts performance. Print statements are not optimized for release builds and may clutter logs, making it harder to diagnose real issues. This can also violate privacy policies and app store guidelines. {v3}',
    correctionMessage:
        'Wrap print() calls in if (kDebugMode) or use a logging framework with configurable log levels. Remove or refactor print statements before release to ensure only intentional logging is present.',
    // SEV-01 (downgraded from ERROR): debug-hygiene/perf, not a crash/exploit.
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // CLI tools use print() for terminal output — no release/debug distinction
    final projectInfo = ProjectContext.getProjectInfo(context.filePath);
    if (projectInfo == null || !projectInfo.isFlutterProject) return;

    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'print') return;
      if (node.target != null) return; // Skip object.print()

      if (!_isInsideDebugGuard(node)) {
        reporter.atNode(node);
      }
    });

    context.addFunctionExpressionInvocation((
      FunctionExpressionInvocation node,
    ) {
      final Expression function = node.function;
      if (function is SimpleIdentifier && function.name == 'print') {
        if (!_isInsideDebugGuard(node)) {
          reporter.atNode(node);
        }
      }
    });
  }

  bool _isInsideDebugGuard(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement) {
        final String condition = current.expression.toSource();
        if (usesFlutterModeConstants(condition)) {
          return true;
        }
      }
      if (current is AssertStatement) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        WrapInDebugModeFix(context: context),
  ];
}

/// Warns when log calls use string concatenation instead of structured logging.
///
/// Since: v4.1.6 | Updated: v4.13.0 | Rule version: v2
///
/// String concatenation in log messages wastes CPU cycles constructing
/// strings even when logging is disabled. Use structured logging with
/// placeholders or log levels.
///
/// **BAD:**
/// ```dart
/// log('User ' + user.name + ' logged in at ' + timestamp.toString());
/// print('Error: ' + error.message + ' Stack: ' + stackTrace.toString());
/// ```
///
/// **GOOD:**
/// ```dart
/// log('User logged in', data: {'user': user.name, 'time': timestamp});
/// logger.error('Error occurred', error: error, stackTrace: stackTrace);
/// ```
class RequireStructuredLoggingRule extends SaropaLintRule {
  RequireStructuredLoggingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'testing'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_structured_logging',
    '[require_structured_logging] String concatenation in logs wastes CPU building strings even when logging is disabled. String concatenation in log messages wastes CPU cycles constructing strings even when logging is disabled. Use structured logging with placeholders or log levels. {v2}',
    correctionMessage:
        'Use structured logging with named parameters: log("event", data: {"key": value}).',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _logMethods = {
    'log',
    'print',
    'debugPrint',
    'info',
    'warning',
    'error',
    'severe',
    'fine',
    'finer',
    'finest',
    'debug',
    'trace',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_logMethods.contains(methodName)) return;

      // Check if first argument uses string concatenation
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      if (firstArg is NamedExpression) return;

      if (_usesConcatenation(firstArg)) {
        reporter.atNode(firstArg);
      }
    });
  }

  bool _usesConcatenation(Expression expr) {
    if (expr is BinaryExpression && expr.operator.lexeme == '+') {
      // Check if either operand is a string
      if (expr.leftOperand is StringLiteral ||
          expr.rightOperand is StringLiteral) {
        return true;
      }
      // Recursively check for nested concatenation
      return _usesConcatenation(expr.leftOperand) ||
          _usesConcatenation(expr.rightOperand);
    }
    return false;
  }
}

/// Warns when sensitive data is logged.
///
/// Since: v4.1.6 | Updated: v4.13.0 | Rule version: v5
///
/// Alias: avoid_sensitive_data_in_logs
///
/// `[HEURISTIC]` - Uses pattern matching to detect sensitive variable names.
///
/// Logging passwords, tokens, secrets, or other sensitive data is a security
/// risk that can expose credentials and violate compliance requirements
/// (OWASP A09: Security Logging and Monitoring Failures).
///
/// This rule uses AST-based detection to distinguish between:
/// - **Actual data exposure**: `$password`, `${user.token}` → FLAGGED
/// - **Safe descriptive text**: `'Updating token.'`, `'session expired'` → OK
/// - **Safe property access**: `${password.length}`, `${token != null}` → OK
///
/// **BAD:**
/// ```dart
/// print('Login attempt with password: $password');
/// log('Token: ${user.accessToken}');
/// debugPrint('API key: $apiKey, secret: $secretKey');
/// ```
///
/// **GOOD:**
/// ```dart
/// print('Login attempt for user: ${user.email}');
/// log('Token refreshed', data: {'userId': user.id});
/// debugPrint('API call completed');
/// // Safe: just descriptive text, no actual data
/// print('Updating local token.');
/// ```
///
/// **Quick fix available:** Comments out the sensitive log statement for review.
class AvoidSensitiveInLogsRule extends SaropaLintRule {
  AvoidSensitiveInLogsRule() : super(code: _code);

  /// Config alias for backwards compatibility with avoid_sensitive_data_in_logs
  @override
  List<String> get configAliases => const <String>[
    'avoid_sensitive_data_in_logs',
  ];

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'testing'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        CommentOutSensitiveLogFix(context: context),
  ];

  /// OWASP mapping: M6 (Privacy Controls), A09 (Logging Failures)
  @override
  OwaspMapping get owasp => const OwaspMapping(
    mobile: <OwaspMobile>{OwaspMobile.m6},
    web: <OwaspWeb>{OwaspWeb.a09},
  );

  static const LintCode _code = LintCode(
    'avoid_sensitive_in_logs',
    '[avoid_sensitive_in_logs] Logging sensitive data (such as passwords, tokens, or personal information) exposes users to credential theft, privacy violations, and compliance failures (e.g., OWASP A09). Attackers or support staff may access logs and extract secrets, leading to data breaches. {v5}',
    correctionMessage:
        'Never log sensitive information. Remove or redact secrets, credentials, and personal data before logging. Use secure logging practices and review log statements for accidental leaks.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _logMethods = {
    'log',
    'print',
    'debugPrint',
    'info',
    'warning',
    'error',
    'severe',
    'debug',
    'trace',
  };

  // Note: Pattern excludes 'auth' alone as it's too broad (matches 'author',
  // 'authority'). Uses authToken, authKey, authCode instead.
  static final RegExp _sensitivePattern = RegExp(
    r'\b(password|passwd|pwd|secret|token|apiKey|api_key|accessToken|'
    r'access_token|refreshToken|refresh_token|privateKey|private_key|'
    r'secretKey|secret_key|credential|authToken|authKey|authCode|'
    r'bearer|jwt|session|cookie|ssn|creditCard|credit_card|cvv|pin|otp)\b',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      if (!_logMethods.contains(methodName)) return;

      // Check all arguments for sensitive patterns
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (_containsSensitiveData(arg.expression)) {
            reporter.atNode(arg);
          }
        } else if (_containsSensitiveData(arg)) {
          reporter.atNode(arg);
        }
      }
    });
  }

  bool _containsSensitiveData(Expression expr) {
    // For simple string literals with no interpolation, no sensitive data
    // is actually being logged (just descriptive text like "updating token")
    // This MUST be checked first before StringInterpolation.
    if (expr is SimpleStringLiteral) {
      return false;
    }

    // For adjacent strings (multi-line string literals), check each part
    if (expr is AdjacentStrings) {
      for (final StringLiteral part in expr.strings) {
        if (_containsSensitiveData(part)) {
          return true;
        }
      }
      return false;
    }

    // Check string literals for interpolated sensitive variables
    if (expr is StringInterpolation) {
      for (final InterpolationElement element in expr.elements) {
        if (element is InterpolationExpression) {
          // Recursively check the interpolated expression
          if (_containsSensitiveData(element.expression)) {
            return true;
          }
        }
        // Plain string parts (InterpolationString) are ignored - they're just
        // descriptive text, not actual sensitive data being logged
      }
      return false;
    }

    // For concatenation, check if sensitive variables are being concatenated
    if (expr is BinaryExpression && expr.operator.lexeme == '+') {
      return _containsSensitiveData(expr.leftOperand) ||
          _containsSensitiveData(expr.rightOperand);
    }

    // For conditional expressions, check all branches
    if (expr is ConditionalExpression) {
      // Don't check the condition itself - only what gets logged
      return _containsSensitiveData(expr.thenExpression) ||
          _containsSensitiveData(expr.elseExpression);
    }

    // For parenthesized expressions, check inside
    if (expr is ParenthesizedExpression) {
      return _containsSensitiveData(expr.expression);
    }

    // For identifiers (variable references) - check if the name is sensitive
    if (expr is SimpleIdentifier) {
      return _sensitivePattern.hasMatch(expr.name);
    }

    // For property access (e.g., user.token) - check the property name
    if (expr is PrefixedIdentifier) {
      return _sensitivePattern.hasMatch(expr.identifier.name);
    }

    if (expr is PropertyAccess) {
      return _sensitivePattern.hasMatch(expr.propertyName.name);
    }

    // For method calls, don't flag - method results aren't inherently sensitive
    // by name (e.g., getToken() might return masked data)
    if (expr is MethodInvocation) {
      // But do check arguments being passed
      for (final Expression arg in expr.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (_containsSensitiveData(arg.expression)) {
            return true;
          }
        } else if (_containsSensitiveData(arg)) {
          return true;
        }
      }
      return false;
    }

    // For index expressions (e.g., map['token']), check the index
    if (expr is IndexExpression) {
      final Expression index = expr.index;
      if (index is SimpleStringLiteral) {
        return _sensitivePattern.hasMatch(index.value);
      }
      return false;
    }

    // For other expressions (literals, etc.), no sensitive data
    return false;
  }
}

// =============================================================================
// require_log_level_for_production
// =============================================================================

/// Warns when verbose logging methods are used without a debug-mode guard.
///
/// Since: v4.14.0 | Updated: v14.5.10 | Rule version: v4
///
/// `[HEURISTIC]` - Detects verbose log calls (log, fine, finer, finest, debug,
/// trace, verbose) outside kDebugMode/kReleaseMode guards or assert blocks.
/// Skipped when the resolved callee already defaults its log-level parameter
/// (`level`/`logLevel`/`severity`/`verbosity`) to a non-verbose value, since
/// demanding an explicit `level:` argument would be a no-op; a callee whose
/// own default is itself verbose is still flagged.
///
/// Verbose logging in production builds exposes internal state, degrades
/// performance, and may leak sensitive information to device logs.
///
/// **BAD:**
/// ```dart
/// void processOrder(Order order) {
///   log('Processing: ${order.toJson()}'); // Leaks data in production!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void processOrder(Order order) {
///   if (kDebugMode) {
///     log('Processing: ${order.toJson()}');
///   }
/// }
/// ```
///
/// GitHub: https://github.com/saropa/saropa_lints/issues/18
class RequireLogLevelForProductionRule extends SaropaLintRule {
  RequireLogLevelForProductionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'testing'};

  // Bumped from RuleCost.low: resolving the callee's element and formal
  // parameters (to check for a safe `level` default) requires cross-library
  // type resolution, which is no longer a single cheap AST node inspection.
  @override
  RuleCost get cost => RuleCost.medium;

  @override
  bool get usesTypeResolution => true;

  static const LintCode _code = LintCode(
    'require_log_level_for_production',
    '[require_log_level_for_production] Verbose log method called without '
        'a debug-mode guard. In production builds, verbose logging exposes '
        'internal application state, degrades performance, and may leak '
        'sensitive information to device logs accessible by other apps. {v4}',
    correctionMessage:
        'Wrap verbose logging in if (kDebugMode) { ... } or use '
        'a log-level-aware logger that suppresses verbose output in release.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Verbose log methods that should be guarded.
  ///
  /// Methods like `fine`, `finer`, `finest` are specific to `dart:developer`
  /// Logger. Generic names like `log` require receiver filtering to avoid
  /// false positives on unrelated APIs (e.g., `math.log()`).
  static const Set<String> _verboseLogMethods = <String>{
    'log',
    'fine',
    'finer',
    'finest',
    'debug',
    'trace',
    'verbose',
  };

  /// Receivers that indicate a logging context (case-insensitive match).
  static final RegExp _loggerTargetPattern = RegExp(
    r'(log|logger|logging|_log|_logger)',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_verboseLogMethods.contains(node.methodName.name)) return;

      // Require a logger-like receiver to avoid false positives on
      // unrelated APIs (e.g., math.log(), myObject.trace()).
      final Expression? target = node.target;
      if (target != null && !_loggerTargetPattern.hasMatch(target.toSource())) {
        return;
      }

      // Skip if already inside a debug guard
      if (_isInsideDebugContext(node)) return;

      // Skip if the resolved callee already defaults its `level` parameter
      // to a safe value (e.g. a project-level `debug()` wrapper) — demanding
      // an explicit `level:` argument would be a no-op.
      if (_hasSafeLevelDefault(node.methodName.element)) return;

      reporter.atNode(node);
    });

    // Bare function calls: log('message'), debug('info'), etc.
    context.addFunctionExpressionInvocation((
      FunctionExpressionInvocation node,
    ) {
      final Expression function = node.function;
      if (function is SimpleIdentifier &&
          _verboseLogMethods.contains(function.name)) {
        if (_isInsideDebugContext(node)) return;
        if (_hasSafeLevelDefault(function.element)) return;
        reporter.atNode(node);
      }
    });
  }

  /// Checks if node is inside kDebugMode/kReleaseMode guard or assert.
  bool _isInsideDebugContext(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement) {
        final String condition = current.expression.toSource();
        if (usesFlutterModeConstants(condition)) return true;
      }
      if (current is AssertStatement) return true;
      current = current.parent;
    }
    return false;
  }

  /// Parameter names (lower-cased, exact match) that signal "this is the
  /// log-level knob" on a logging wrapper. Not just `level` — real-world
  /// wrappers also spell this `logLevel`, `severity`, or `verbosity`; a rule
  /// checking only `level` gives those callees no benefit from this fix and
  /// keeps flagging their already-safe defaults.
  static const Set<String> _levelParameterNames = <String>{
    'level',
    'loglevel',
    'severity',
    'verbosity',
  };

  /// Enum-constant names (lower-cased, exact match — not substring) that
  /// signal the callee's own default is itself a verbose level. A default
  /// of e.g. `Level.trace` means the callee did NOT make a safe choice, so
  /// the diagnostic must still fire for it.
  static const Set<String> _verboseDefaultValueNames = <String>{
    'verbose',
    'trace',
    'finest',
    'finer',
    'fine',
    'debug',
    'all',
  };

  /// True when the resolved callee declares a log-level-shaped parameter
  /// (see [_levelParameterNames]) whose own default value is safe (i.e. not
  /// itself a verbose level), meaning the callee already made the safety
  /// decision (e.g. `void debug(Object? msg, {DebugLevels level =
  /// DebugLevels.Info})`) and an explicit `level:` argument at the call site
  /// would change nothing.
  ///
  /// A default with no qualified enum-constant reference (no `.` in
  /// `defaultValueCode` — e.g. a bare numeric literal `int level = 3`), or
  /// one that is itself a constructor call rather than a bare enum constant
  /// (e.g. `const Level.custom(5)` — contains `(` after the qualifier), is
  /// deliberately treated as UNSAFE rather than safe: there is no reliable
  /// constant name to check against [_verboseDefaultValueNames], and
  /// guessing "unrecognized shape means safe" would silently stop flagging
  /// a genuinely verbose default.
  bool _hasSafeLevelDefault(Element? callee) {
    if (callee is! ExecutableElement) return false;
    for (final FormalParameterElement param in callee.formalParameters) {
      final String? paramName = param.name?.toLowerCase();
      if (!_levelParameterNames.contains(paramName) || !param.hasDefaultValue) {
        continue;
      }
      final String rawCode = param.defaultValueCode ?? '';
      final String code = rawCode.startsWith('const ')
          ? rawCode.substring('const '.length).trimLeft()
          : rawCode;
      if (!code.contains('.') || code.contains('(')) return false;
      final String constantName = code.split('.').last.toLowerCase();
      return !_verboseDefaultValueNames.contains(constantName);
    }
    return false;
  }
}

// =============================================================================
// prefer_conditional_logging
// =============================================================================

/// Prefer conditional logging so expensive message construction is not done when log level is disabled.
///
/// **Bad:**
/// ```dart
/// log.info('User: $user'); // always builds string
/// ```
///
/// **Good:**
/// ```dart
/// if (logLevelEnabled) log.info('User: $user');
/// ```
class PreferConditionalLoggingRule extends SaropaLintRule {
  PreferConditionalLoggingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'testing'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_conditional_logging',
    '[prefer_conditional_logging] Log call with interpolated or expensive '
        'message is always evaluated. Wrap in a log-level check to avoid '
        'unnecessary string construction when the level is disabled.',
    correctionMessage:
        'Guard with a log-level check, e.g. if (Logger.level <= Level.info) log.info(...).',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _logMethods = <String>{
    'info',
    'warning',
    'severe',
    'fine',
    'finer',
    'finest',
    'shout',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final targetNode = node.target;
      if (targetNode is! SimpleIdentifier) return;
      if (targetNode.name != 'log') return;
      if (!_logMethods.contains(node.methodName.name)) return;
      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;
      final firstArg = args.first;
      final Expression first = firstArg is NamedExpression
          ? firstArg.expression
          : firstArg;
      if (first is! StringInterpolation && first is! AdjacentStrings) return;
      reporter.atNode(node.methodName, code);
    });
  }
}

// =============================================================================
// prefer_log_levels
// =============================================================================

/// Suggests using multiple log levels appropriately.
///
/// Using only one log level (e.g. only info) makes filtering and diagnostics
/// harder. Prefer debug/info/warning/error as appropriate.
///
/// **Bad:** File only uses log.info(...).
///
/// **Good:** Use log.debug, log.info, log.warning, log.severe as appropriate.
class PreferLogLevelsRule extends SaropaLintRule {
  PreferLogLevelsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'testing'};

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_log_levels',
    '[prefer_log_levels] Only one log level used in this file. '
        'Use multiple levels (debug, info, warning, severe) for better filtering.',
    correctionMessage:
        'Use log.debug(), log.info(), log.warning(), log.severe() as appropriate.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _levels = <String>{
    'debug',
    'info',
    'warning',
    'severe',
    'fine',
    'finer',
    'finest',
    'shout',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
      final Set<String> usedLevels = <String>{};
      MethodInvocation? firstLog;
      unit.visitChildren(
        _LogLevelVisitor(usedLevels, (MethodInvocation n) {
          firstLog ??= n;
        }),
      );
      if (usedLevels.length <= 1 && firstLog != null) {
        reporter.atNode(firstLog!);
      }
    });
  }
}

class _LogLevelVisitor extends RecursiveAstVisitor<void> {
  _LogLevelVisitor(this._usedLevels, this._onLog);

  final Set<String> _usedLevels;
  final void Function(MethodInvocation node) _onLog;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final Expression? target = node.target;
    if (target is SimpleIdentifier && target.name == 'log') {
      final String level = node.methodName.name;
      if (PreferLogLevelsRule._levels.contains(level)) {
        _usedLevels.add(level);
        _onLog(node);
      }
    }
    super.visitMethodInvocation(node);
  }
}

// =============================================================================
// prefer_log_timestamp
// =============================================================================

/// Suggests including timestamps in log output.
///
/// Logs without time information are harder to correlate with events.
///
/// **Bad:** log.info('Event'); with no time in message or formatter.
///
/// **Good:** Use a logger with timestamp formatter or include time in messages.
class PreferLogTimestampRule extends SaropaLintRule {
  PreferLogTimestampRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'testing'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_log_timestamp',
    '[prefer_log_timestamp] Log calls without timestamp context. '
        'Consider including timestamps for easier diagnostics.',
    correctionMessage:
        'Use a logger with timestamp formatter or add time to log messages.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _logMethods = <String>{
    'info',
    'warning',
    'severe',
    'debug',
    'fine',
    'finer',
    'finest',
    'shout',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String content = context.fileContent;
    if (RegExp(r'\btimestamp\b').hasMatch(content)) return;
    if (RegExp(r'DateTime\.now\s*\(').hasMatch(content)) return;

    context.addMethodInvocation((MethodInvocation node) {
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'log') return;
      if (!_logMethods.contains(node.methodName.name)) return;
      reporter.atNode(node);
    });
  }
}
