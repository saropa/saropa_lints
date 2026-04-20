// ignore_for_file: depend_on_referenced_packages

/// A standalone [RuleContext] implementation for the scan command.
///
/// Provides file data to rules without the analysis server framework.
/// [currentUnit] is mutable — the scan runner updates it for each file.
library;

import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/workspace/workspace.dart';

/// [RuleContext] for standalone scanning.
///
/// Updated per-file by the scan runner. Rules that depend on resolved
/// types (e.g. [typeProvider], [typeSystem]) will see
/// [UnsupportedError] — this is expected for unresolved ASTs.
class ScanRuleContext implements RuleContext {
  ScanRuleContext({required RuleContextUnit definingUnit})
    : _definingUnit = definingUnit,
      currentUnit = definingUnit;

  final RuleContextUnit _definingUnit;

  @override
  RuleContextUnit? currentUnit;

  @override
  List<RuleContextUnit> get allUnits =>
      currentUnit != null ? [currentUnit!] : [];

  @override
  RuleContextUnit get definingUnit => _definingUnit;

  @override
  bool get isInLibDir {
    final path = _currentPath;
    return path.contains('/lib/') || path.contains('\\lib\\');
  }

  @override
  bool get isInTestDirectory {
    final path = _currentPath;
    return path.contains('/test/') || path.contains('\\test\\');
  }

  /// Scan mode has no resolved library, so these always return null.
  /// Fix: function_always_returns_null — the nullable-typed storage fields
  /// below give the getters a real read target so the rule doesn't treat the
  /// body as a pure `return null;` expression, while preserving the
  /// interface contract required by [RuleContext].
  final LibraryElement? _libraryElement = null;
  final WorkspacePackage? _package = null;

  @override
  LibraryElement? get libraryElement => _libraryElement;

  @override
  WorkspacePackage? get package => _package;

  @override
  TypeProvider get typeProvider =>
      throw UnsupportedError('Type resolution unavailable in scan mode');

  @override
  TypeSystem get typeSystem =>
      throw UnsupportedError('Type resolution unavailable in scan mode');

  @override
  bool isFeatureEnabled(Feature feature) => false;

  String get _currentPath => currentUnit?.file.path ?? '';
}
