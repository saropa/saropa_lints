// ignore_for_file: depend_on_referenced_packages

import 'dart:io' show File;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';
import '../../project_context.dart';

/// Regex to find the SDK lower-bound version inside a pubspec.yaml
/// `environment: sdk:` constraint. Tolerates optional whitespace between
/// `environment:` and `sdk:`, optional quotes (single or double) around
/// the constraint string, and optional caret prefixes. Captures the
/// version digits after `>=` so they can be replaced in place.
///
/// Handles both block-style and flow-style YAML:
///   environment:
///     sdk: ">=3.0.0 <4.0.0"
///   environment:
///     sdk: '>=3.0.0 <4.0.0'
///   environment:
///     sdk: >=3.0.0 <4.0.0
final RegExp _sdkLowerBoundPattern = RegExp(
  r"""environment\s*:\s*\n\s*sdk\s*:\s*["']?\^?>=(\d+\.\d+\.\d+)""",
  multiLine: true,
);

/// Quick fix: Raise SDK lower bound in pubspec.yaml to match the syntax
/// feature that triggered the diagnostic.
///
/// Companion fix for [RequireSdkSyntaxMatchRule]. Edits pubspec.yaml
/// rather than the Dart source file — a novel pattern in this codebase
/// using [ChangeBuilder.addGenericFileEdit] instead of `addDartFileEdit`.
///
/// The covering node from the diagnostic determines which SDK version
/// is required. When the rule reports via `reporter.atToken` (e.g. on
/// a class modifier keyword), the covering node is still the parent
/// declaration node (ClassDeclaration), because keywords are tokens,
/// not AST nodes — the `is` checks below handle this correctly.
class RaiseSdkLowerBoundFix extends SaropaFixProducer {
  RaiseSdkLowerBoundFix({required super.context});

  static const _fixKind = FixKind(
    'saropa.fix.raiseSdkLowerBound',
    40,
    'Raise SDK lower bound in pubspec.yaml',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    // Determine which SDK version this node requires.
    final requiredVersion = _resolveRequiredVersion(node);
    if (requiredVersion == null) return;

    // Find pubspec.yaml via the project root.
    final root = ProjectContext.findProjectRoot(file);
    if (root == null) return;

    final pubspecPath = '$root/pubspec.yaml';
    final pubspecFile = File(pubspecPath);
    if (!pubspecFile.existsSync()) return;

    final content = pubspecFile.readAsStringSync();

    // Find the lower-bound version offset in the SDK constraint.
    final match = _sdkLowerBoundPattern.firstMatch(content);
    if (match == null) return;

    // group(1) is the captured version string (e.g. "2.19.0").
    // Compute its absolute offset from the match start.
    final capturedVersion = match.group(1)!;
    final fullMatch = match.group(0)!;
    final relativeOffset = fullMatch.lastIndexOf(capturedVersion);
    if (relativeOffset < 0) return;

    final versionStart = match.start + relativeOffset;
    final versionLength = capturedVersion.length;

    // Replace the lower-bound version with the required version.
    await builder.addGenericFileEdit(pubspecPath, (editBuilder) {
      editBuilder.addSimpleReplacement(
        SourceRange(versionStart, versionLength),
        requiredVersion,
      );
    });
  }

  /// Maps the diagnostic's covering node to the SDK version it requires.
  ///
  /// Uses `is` checks (not runtimeType map lookup) because the analyzer's
  /// concrete classes are private `*Impl` types that would not match
  /// abstract type keys in a `Map<Type, String>`.
  String? _resolveRequiredVersion(AstNode node) {
    // Dart 3.0: records, patterns, class modifiers, switch expressions.
    if (node is RecordTypeAnnotation || node is RecordLiteral) return '3.0.0';
    if (node is SwitchExpression) return '3.0.0';
    if (node is PatternVariableDeclaration || node is PatternAssignment) {
      return '3.0.0';
    }
    if (node is SwitchPatternCase || node is ClassDeclaration) return '3.0.0';
    // Dart 3.3: extension types.
    if (node is ExtensionTypeDeclaration) return '3.3.0';
    // Dart 3.6: digit separators in numeric literals.
    if (node is IntegerLiteral || node is DoubleLiteral) return '3.6.0';
    return null;
  }
}
