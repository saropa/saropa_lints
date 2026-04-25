// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Repository hygiene checks (gitignore, env files).
library;

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// require_env_file_gitignore
// =============================================================================

/// Ensures `.env` at the project root is listed in `.gitignore` when using dotenv.
///
/// Since: v12.5.0 | Rule version: v1
///
/// Committed secrets are a common incident; this rule only checks the presence
/// of ignore patterns, not whether git actually tracks the file.
class RequireEnvFileGitignoreRule extends SaropaLintRule {
  RequireEnvFileGitignoreRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleType? get ruleType => RuleType.vulnerability;

  @override
  Set<String> get tags => const {'config', 'security'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_env_file_gitignore',
    '[require_env_file_gitignore] A `.env` file exists at the project root but `.gitignore` does not appear to ignore env files while dotenv is used. Secret leakage risk. {v1}',
    correctionMessage:
        'Add `.env` or `.env*` to `.gitignore` and rotate any exposed secrets.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (!ProjectContext.hasDependency(context.filePath, 'flutter_dotenv')) {
      return;
    }
    final root = ProjectContext.findProjectRoot(context.filePath);
    if (root == null) return;

    final envFile = File('$root/.env');
    if (!envFile.existsSync()) return;
    if (_gitignoreIgnoresEnv(root)) return;

    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'load') return;
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != 'dotenv') return;
      reporter.atNode(node);
    });
  }

  static bool _gitignoreIgnoresEnv(String projectRoot) {
    final gitignore = File('$projectRoot/.gitignore');
    if (!gitignore.existsSync()) return false;
    for (final rawLine in gitignore.readAsLinesSync()) {
      var line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      if (line.startsWith('!')) continue;
      if (line == '.env' ||
          line == '.env/' ||
          line.endsWith('.env') ||
          line == '.env*' ||
          line.startsWith('.env')) {
        return true;
      }
    }
    return false;
  }
}
