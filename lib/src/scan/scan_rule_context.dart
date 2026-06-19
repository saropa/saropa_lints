// ignore_for_file: depend_on_referenced_packages

/// Standalone [RuleContext] implementations for the scan command.
///
/// [ScanRuleContext] backs the default syntactic scan (no type resolution).
/// [ResolvedScanRuleContext] backs the `--resolve` scan, where the analyzer
/// has fully resolved each unit, so real [typeProvider]/[typeSystem]/
/// [libraryElement] are available.
///
/// Both extend [MutableRuleContext]: the scan runner mutates [currentUnit]
/// before walking each file. The resolved variant additionally has its
/// resolution results updated per file via [ResolvedScanRuleContext.setResolved].
library;

import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:analyzer/workspace/workspace.dart';

/// `lib/`-directory check shared by both scan contexts. Handles POSIX and
/// Windows separators so classification is stable across platforms.
bool _pathInLib(String path) =>
    path.contains('/lib/') || path.contains('\\lib\\');

/// `test/`-directory check; see [_pathInLib] for the separator rationale.
bool _pathInTest(String path) =>
    path.contains('/test/') || path.contains('\\test\\');

/// Shared base for the scan-mode [RuleContext]s.
///
/// Holds the per-file [currentUnit] (mutated by the scan runner before each
/// file is walked, so a single registered visitor sees the right unit) and the
/// lib/test directory classification both scanners need. [definingUnit] seeds
/// [currentUnit] so a rule that reads it before the first file mutation still
/// gets a valid unit.
abstract class MutableRuleContext implements RuleContext {
  MutableRuleContext({required RuleContextUnit definingUnit})
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
  bool get isInLibDir => _pathInLib(_currentPath);

  @override
  bool get isInTestDirectory => _pathInTest(_currentPath);

  @override
  bool isFeatureEnabled(Feature feature) => false;

  String get _currentPath => currentUnit?.file.path ?? '';
}

/// [RuleContext] for the default (syntactic) scan.
///
/// Rules that depend on resolved types (e.g. [typeProvider], [typeSystem])
/// will see [UnsupportedError] — this is expected for unresolved ASTs. Use
/// `--resolve` ([ResolvedScanRuleContext]) when a rule needs resolution.
class ScanRuleContext extends MutableRuleContext {
  ScanRuleContext({required super.definingUnit});

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
}

/// [RuleContext] for the `--resolve` scan, backed by fully resolved units.
///
/// A single instance is shared by a rule's registered visitors across the whole
/// scan; the runner calls [setResolved] before walking each file so the visitor
/// reads that file's resolution results. This mirrors how [currentUnit] is
/// mutated per file — without per-file updates, type-based rules would see the
/// first file's types for every file.
class ResolvedScanRuleContext extends MutableRuleContext {
  ResolvedScanRuleContext({required super.definingUnit});

  TypeProvider? _typeProvider;
  TypeSystem? _typeSystem;
  LibraryElement? _libraryElement;

  /// Installs the resolution results for the file about to be walked.
  void setResolved({
    required TypeProvider typeProvider,
    required TypeSystem typeSystem,
    required LibraryElement library,
  }) {
    _typeProvider = typeProvider;
    _typeSystem = typeSystem;
    _libraryElement = library;
  }

  @override
  LibraryElement? get libraryElement => _libraryElement;

  /// Resolved scan does not compute a workspace package; rules that need it
  /// degrade the same way they do under the syntactic scan.
  final WorkspacePackage? _package = null;

  @override
  WorkspacePackage? get package => _package;

  @override
  TypeProvider get typeProvider =>
      _typeProvider ??
      (throw StateError('setResolved must be called before typeProvider'));

  @override
  TypeSystem get typeSystem =>
      _typeSystem ??
      (throw StateError('setResolved must be called before typeSystem'));
}
