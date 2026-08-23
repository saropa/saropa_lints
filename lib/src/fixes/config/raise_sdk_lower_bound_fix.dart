// ignore_for_file: depend_on_referenced_packages

import 'dart:io' show File;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';

import '../../native/saropa_fix.dart';
import '../../project_context.dart';

// Maps AST node types flagged by require_sdk_syntax_match to the minimum
// SDK version that introduced them. Order doesn't matter — the covering
// node's runtime type selects the version.
const Map<Type, String> _nodeTypeToSdkVersion = {
  // Dart 3.0: records, patterns, class modifiers, switch expressions.
  RecordTypeAnnotation: '3.0.0',
  RecordLiteral: '3.0.0',
  SwitchExpression: '3.0.0',
  PatternVariableDeclaration: '3.0.0',
  PatternAssignment: '3.0.0',
  SwitchPatternCase: '3.0.0',
  ClassDeclaration: '3.0.0',
  // Dart 3.3: extension types.
  ExtensionTypeDeclaration: '3.3.0',
  // Dart 3.6: digit separators (IntegerLiteral / DoubleLiteral with _).
  IntegerLiteral: '3.6.0',
  DoubleLiteral: '3.6.0',
};

/// Regex to find the SDK lower-bound version inside a pubspec.yaml
/// `environment: sdk:` constraint. Matches `>=X.Y.Z` and captures the
/// offset of the version digits so they can be replaced in place.
/// The character class matches optional quote chars around the constraint.
final RegExp _sdkLowerBoundPattern = RegExp(
  r"""environment\s*:\s*\n\s*sdk\s*:\s*["']?>=(\d+\.\d+\.\d+)""",
  multiLine: true,
);

/// Quick fix: Raise SDK lower bound in pubspec.yaml to match the syntax
/// feature that triggered the diagnostic.
///
/// This is a companion fix for [RequireSdkSyntaxMatchRule]. It edits
/// pubspec.yaml rather than the Dart source file, which is a novel pattern
/// in this codebase (all other fixes edit .dart files).
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
    final versionStart = match.start + match.group(0)!.indexOf(match.group(1)!);
    final versionLength = match.group(1)!.length;

    // Replace the lower-bound version with the required version.
    await builder.addGenericFileEdit(pubspecPath, (editBuilder) {
      editBuilder.addSimpleReplacement(
        SourceRange(versionStart, versionLength),
        requiredVersion,
      );
    });
  }

  /// Maps the diagnostic's covering node to the SDK version it requires.
  /// Returns null if the node type is unrecognised (defensive — should not
  /// happen because the fix is only registered for require_sdk_syntax_match).
  String? _resolveRequiredVersion(AstNode node) {
    // Direct lookup by runtime type.
    final version = _nodeTypeToSdkVersion[node.runtimeType];
    if (version != null) return version;

    // The node's concrete class may be a private impl (e.g. ClassDeclarationImpl).
    // Walk supertypes via is-checks for the mapped abstract types.
    if (node is RecordTypeAnnotation || node is RecordLiteral) return '3.0.0';
    if (node is SwitchExpression) return '3.0.0';
    if (node is PatternVariableDeclaration || node is PatternAssignment) {
      return '3.0.0';
    }
    if (node is SwitchPatternCase || node is ClassDeclaration) return '3.0.0';
    if (node is ExtensionTypeDeclaration) return '3.3.0';
    if (node is IntegerLiteral || node is DoubleLiteral) return '3.6.0';
    return null;
  }
}
