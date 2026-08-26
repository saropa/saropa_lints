/// Standalone SDK compatibility checker for the scan CLI.
///
/// Cross-references the SDK lower bound in pubspec.yaml against Dart syntax
/// features used across all source files. Outputs a summary showing the
/// minimum required SDK version and which files force each version bump.
library;

import 'dart:io' show File, Directory, stderr;

import 'package:analyzer/dart/analysis/utilities.dart' show parseString;
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart' show RecursiveAstVisitor;
import 'package:path/path.dart' as p;

import '../config/pubspec_constraint_parser.dart';
import 'generated_dart_files.dart' show isGeneratedDartPath;

// =========================================================================
// Version-gated feature detection
// =========================================================================

/// A syntax feature detected in a source file that requires a specific
/// minimum SDK version.
class SdkFeatureHit {
  const SdkFeatureHit(this.file, this.line, this.feature, this.requiredVersion);

  /// Path relative to the project root.
  final String file;

  /// 1-based line number where the feature appears.
  final int line;

  /// Human-readable description of the syntax feature.
  final String feature;

  /// Minimum SDK version required (e.g. "3.0.0").
  final String requiredVersion;
}

/// Result of the SDK compatibility check.
class SdkCompatResult {
  const SdkCompatResult({
    required this.declaredLowerBound,
    required this.requiredLowerBound,
    required this.hits,
  });

  /// The SDK lower bound declared in pubspec.yaml (e.g. "3.0.0").
  final String declaredLowerBound;

  /// The minimum SDK version required by the codebase based on syntax
  /// features detected (e.g. "3.6.0"), or the declared bound if no
  /// features require a newer version.
  final String requiredLowerBound;

  /// Individual feature hits, sorted by version (highest first).
  final List<SdkFeatureHit> hits;

  /// True when the codebase uses features that require a newer SDK
  /// than the declared lower bound.
  bool get hasMismatch => requiredLowerBound != declaredLowerBound;
}

/// Runs the SDK compatibility check on [projectPath].
///
/// Returns null when pubspec.yaml is missing or has no parseable SDK
/// lower bound.
SdkCompatResult? checkSdkCompat(String projectPath, {bool quiet = false}) {
  // Read the SDK lower bound from pubspec.yaml.
  final pubspecFile = File(p.join(projectPath, 'pubspec.yaml'));
  if (!pubspecFile.existsSync()) {
    if (!quiet) stderr.writeln('No pubspec.yaml found at $projectPath');
    return null;
  }
  final parsed = parsePubspecConstraints(pubspecFile.readAsStringSync());
  final lower = parsed.sdkConstraint?.lower;
  if (lower == null) {
    if (!quiet) stderr.writeln('No SDK lower bound in pubspec.yaml');
    return null;
  }
  final declaredBound = '${lower.major}.${lower.minor}.${lower.patch}';

  // Collect .dart files under lib/, excluding generated files.
  final libDir = Directory(p.join(projectPath, 'lib'));
  if (!libDir.existsSync()) {
    if (!quiet) stderr.writeln('No lib/ directory found at $projectPath');
    return null;
  }

  final hits = <SdkFeatureHit>[];
  // Track the highest required version across all files.
  var maxRequired = lower;

  // Walk all .dart files in lib/.
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    // Skip generated files (.g.dart, .freezed.dart, etc.).
    if (isGeneratedDartPath(entity.path)) continue;

    final relativePath = p.relative(entity.path, from: projectPath);
    final content = entity.readAsStringSync();

    // Parse the file without resolution — syntax detection only.
    final parseResult = parseString(content: content);
    final unit = parseResult.unit;

    // Visit the AST and collect version-gated features.
    final visitor = _SdkFeatureVisitor(
      filePath: relativePath,
      declaredBound: lower,
    );
    unit.visitChildren(visitor);

    hits.addAll(visitor.hits);
    for (final hit in visitor.hits) {
      final required = SemverParts.tryParse(hit.requiredVersion);
      if (required != null && _isHigher(required, maxRequired)) {
        maxRequired = required;
      }
    }
  }

  final requiredBound =
      '${maxRequired.major}.${maxRequired.minor}.${maxRequired.patch}';

  // Sort hits by version descending, then file, then line.
  hits.sort((a, b) {
    final cmp = b.requiredVersion.compareTo(a.requiredVersion);
    if (cmp != 0) return cmp;
    final fileCmp = a.file.compareTo(b.file);
    if (fileCmp != 0) return fileCmp;
    return a.line.compareTo(b.line);
  });

  return SdkCompatResult(
    declaredLowerBound: declaredBound,
    requiredLowerBound: requiredBound,
    hits: hits,
  );
}

/// Formats the SDK compat result as a human-readable summary for stdout.
String formatSdkCompatResult(SdkCompatResult result) {
  final buf = StringBuffer();

  if (!result.hasMismatch) {
    buf.writeln(
      'SDK constraint OK: declared >=${result.declaredLowerBound}, '
      'codebase requires >=${result.requiredLowerBound}.',
    );
    return buf.toString();
  }

  buf.writeln(
    'SDK MISMATCH: pubspec declares >=${result.declaredLowerBound} '
    'but codebase requires >=${result.requiredLowerBound}.',
  );
  buf.writeln();

  // Group hits by required version.
  final grouped = <String, List<SdkFeatureHit>>{};
  for (final hit in result.hits) {
    (grouped[hit.requiredVersion] ??= []).add(hit);
  }

  // Print each version group, highest first.
  final versions = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  for (final version in versions) {
    final versionHits = grouped[version]!;
    buf.writeln('Requires >=$version (${versionHits.length} hits):');
    for (final hit in versionHits) {
      buf.writeln('  ${hit.file}:${hit.line} — ${hit.feature}');
    }
    buf.writeln();
  }

  return buf.toString();
}

// =========================================================================
// Internal helpers
// =========================================================================

/// Returns true when [a] is strictly newer than [b].
bool _isHigher(SemverParts a, SemverParts b) {
  if (a.major != b.major) return a.major > b.major;
  if (a.minor != b.minor) return a.minor > b.minor;
  return a.patch > b.patch;
}

/// AST visitor that detects Dart syntax features requiring a version
/// higher than [declaredBound].
class _SdkFeatureVisitor extends RecursiveAstVisitor<void> {
  _SdkFeatureVisitor({required this.filePath, required this.declaredBound});

  final String filePath;
  final SemverParts declaredBound;
  final List<SdkFeatureHit> hits = [];

  // Version constants for comparison.
  static const _dart30 = SemverParts(3, 0, 0);
  static const _dart33 = SemverParts(3, 3, 0);
  static const _dart36 = SemverParts(3, 6, 0);

  // --- Dart 3.0 features ---

  @override
  void visitRecordTypeAnnotation(RecordTypeAnnotation node) {
    _check(node, _dart30, 'Record type annotation');
    super.visitRecordTypeAnnotation(node);
  }

  @override
  void visitRecordLiteral(RecordLiteral node) {
    _check(node, _dart30, 'Record literal');
    super.visitRecordLiteral(node);
  }

  @override
  void visitSwitchExpression(SwitchExpression node) {
    _check(node, _dart30, 'Switch expression');
    super.visitSwitchExpression(node);
  }

  @override
  void visitPatternVariableDeclaration(PatternVariableDeclaration node) {
    _check(node, _dart30, 'Pattern variable declaration');
    super.visitPatternVariableDeclaration(node);
  }

  @override
  void visitPatternAssignment(PatternAssignment node) {
    _check(node, _dart30, 'Pattern assignment');
    super.visitPatternAssignment(node);
  }

  @override
  void visitSwitchPatternCase(SwitchPatternCase node) {
    _check(node, _dart30, 'Switch pattern case');
    super.visitSwitchPatternCase(node);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Only flag 3.0 class modifiers (sealed, base, interface, final).
    if (node.sealedKeyword != null) {
      _check(node, _dart30, 'sealed class modifier');
    } else if (node.baseKeyword != null) {
      _check(node, _dart30, 'base class modifier');
    } else if (node.interfaceKeyword != null) {
      _check(node, _dart30, 'interface class modifier');
    } else if (node.finalKeyword != null) {
      _check(node, _dart30, 'final class modifier');
    }
    super.visitClassDeclaration(node);
  }

  // --- Dart 3.3: extension types ---

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) {
    _check(node, _dart33, 'Extension type declaration');
    super.visitExtensionTypeDeclaration(node);
  }

  // --- Dart 3.6: digit separators ---

  @override
  void visitIntegerLiteral(IntegerLiteral node) {
    if (node.literal.lexeme.contains('_')) {
      _check(node, _dart36, 'Digit separator in integer literal');
    }
    super.visitIntegerLiteral(node);
  }

  @override
  void visitDoubleLiteral(DoubleLiteral node) {
    if (node.literal.lexeme.contains('_')) {
      _check(node, _dart36, 'Digit separator in double literal');
    }
    super.visitDoubleLiteral(node);
  }

  /// Records a hit if [required] is strictly newer than [declaredBound].
  void _check(AstNode node, SemverParts required, String feature) {
    if (!_isHigher(required, declaredBound)) return;
    final line = node.offset >= 0 ? _lineOf(node) : 0;
    final version = '${required.major}.${required.minor}.${required.patch}';
    hits.add(SdkFeatureHit(filePath, line, feature, version));
  }

  /// Returns the 1-based line number for [node].
  int _lineOf(AstNode node) {
    final root = node.root;
    if (root is CompilationUnit) {
      return root.lineInfo.getLocation(node.offset).lineNumber;
    }
    return 0;
  }
}
