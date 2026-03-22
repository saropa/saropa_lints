// ignore_for_file: always_specify_types, depend_on_referenced_packages

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/source/source_range.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// Dart SDK 3.0 removed APIs (migration rules)
// =============================================================================
//
// ## Purpose
//
// Dart 3.0.0 removed or deprecated several legacy SDK APIs across **`dart:core`**,
// **`dart:collection`**, **`dart:developer`**, and **`dart:io`** (constructors,
// types, annotations, and a few constants). Consumer code that still references
// removed symbols usually fails analysis with "undefined class" or similar host
// diagnostics; deprecated symbols still resolve but should be migrated. These
// Saropa rules:
//
// * Apply **consistent, searchable** `[rule_name]` diagnostics aligned with
//   other Saropa migration rules (Flutter + Dart).
// * Use **element resolution** when available so user-defined types with the
//   same name (e.g. a project-local `class CastError`) are **not** flagged.
// * Use **`requiredPatterns`** so files that cannot contain a pattern skip the
//   rule early (see CONTRIBUTING.md — performance and file filtering).
// * Provide **quick fixes** only when the replacement is syntactically safe
//   (empty `List()`, `CastError` → `TypeError`, `.expires` → `.message`,
//   removing legacy annotations).
//
// ## Detection notes (false positives)
//
// * [_isDartCoreOrUnresolved]: if resolution fails (`element == null`) but the
//   identifier **exactly** matches the removed SDK name, we report — this targets
//   migration snippets where the host already dropped the declaration. Wrong
//   spellings (`CastErrror`) do not match and are not reported by these rules.
// * Removed **types** are detected via [NamedType] only; they do not recurse
//   into string literals or comments.
//
// ## Tier / impact
//
// Rules live in **Recommended** tier. [LintImpact] is **high** when the pattern
// corresponds to a hard compile failure on modern SDKs (`List()`, `CastError`,
// `NoSuchMethodError()`, `DeferredLibrary`); **medium** for removed error types
// that are usually dead references; **low** for no-op annotations and
// `Deprecated.expires`.
//
// ## Related
//
// * Flutter deprecations: `migration_rules.dart`
// * Plan archive: `bugs/history/20260320/` (migration candidates #098–#107)

bool _isDartCoreLibrary(LibraryElement? lib) {
  if (lib == null) return false;
  return lib.uri.toString() == 'dart:core';
}

/// True when [element] is the dart:core declaration of [expectedLexeme], or
/// [element] is null (unresolved — typical once the SDK removed the API).
///
/// If a user defines their own declaration with the same name, [element] is
/// non-null and its library is not `dart:core`, so this returns false.
bool _isDartCoreOrUnresolved(Element? element, String expectedLexeme) {
  if (element == null) return true;
  if (element.name != expectedLexeme) return false;
  return _isDartCoreLibrary(element.library);
}

bool _isDartCollectionLibrary(LibraryElement? lib) {
  if (lib == null) return false;
  return lib.uri.toString() == 'dart:collection';
}

bool _isDartDeveloperLibrary(LibraryElement? lib) {
  if (lib == null) return false;
  return lib.uri.toString() == 'dart:developer';
}

bool _isDartIoLibrary(LibraryElement? lib) {
  if (lib == null) return false;
  return lib.uri.toString() == 'dart:io';
}

/// True when [element] is the legacy SDK name in dart:developer, or unresolved.
bool _isDartDeveloperOrUnresolved(Element? element, String expectedLexeme) {
  if (element == null) return true;
  if (element.name != expectedLexeme) return false;
  return _isDartDeveloperLibrary(element.library);
}

/// True when [element] is [HasNextIterator] from dart:collection, or unresolved.
bool _isHasNextIteratorOrUnresolved(Element? element) {
  return _isCollectionOrUnresolved(element, 'HasNextIterator');
}

bool _isCollectionOrUnresolved(Element? element, String expectedLexeme) {
  if (element == null) return true;
  if (element.name != expectedLexeme) return false;
  return _isDartCollectionLibrary(element.library);
}

bool _isUserTagClassFromDartDeveloper(Expression? target) {
  if (target is SimpleIdentifier) {
    return target.name == 'UserTag' &&
        _isDartDeveloperLibrary(target.element?.library);
  }
  if (target is PrefixedIdentifier) {
    return target.identifier.name == 'UserTag' &&
        _isDartDeveloperLibrary(target.identifier.element?.library);
  }
  return false;
}

bool _isNetworkInterfaceClassFromDartIo(Expression? target) {
  if (target is SimpleIdentifier) {
    return target.name == 'NetworkInterface' &&
        _isDartIoLibrary(target.element?.library);
  }
  if (target is PrefixedIdentifier) {
    return target.identifier.name == 'NetworkInterface' &&
        _isDartIoLibrary(target.identifier.element?.library);
  }
  return false;
}

SimpleIdentifier? _annotationNameIdentifier(Annotation node) {
  final n = node.name;
  if (n is SimpleIdentifier) return n;
  if (n is PrefixedIdentifier) return n.identifier;
  return null;
}

void _reportRemovedCoreType(
  NamedType node,
  SaropaDiagnosticReporter reporter,
  String typeName,
) {
  if (node.name.lexeme != typeName) return;
  final el = node.element;
  if (!_isDartCoreOrUnresolved(el, typeName)) return;
  reporter.atNode(node);
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_deprecated_list_constructor
// ─────────────────────────────────────────────────────────────────────────────

/// Detects the removed null-unsafe `List()` unnamed constructor (Dart 3.0).
///
/// **Bad:** `List()`, `List<String>()`
/// **Good:** `[]`, `<String>[]`, or `List.filled` / `List.generate` when sizing.
class AvoidDeprecatedListConstructorRule extends SaropaLintRule {
  AvoidDeprecatedListConstructorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'List('};

  static const LintCode _code = LintCode(
    'avoid_deprecated_list_constructor',
    '[avoid_deprecated_list_constructor] The unnamed List() constructor was removed in Dart 3.0.0 (it was not null-safe). Use a list literal ([] or <T>[]) for an empty list, or List.filled / List.generate when you need a length. {v1}',
    correctionMessage:
        'Replace List() with [] or <T>[] when there are no arguments.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _AvoidDeprecatedListConstructorFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final NamedType typeNode = node.constructorName.type;
      final Element? typeEl = typeNode.element;
      if (typeEl?.name != 'List') return;
      if (!_isDartCoreLibrary(typeEl?.library)) return;
      if (node.constructorName.name != null) return;
      reporter.atNode(node);
    });
  }
}

class _AvoidDeprecatedListConstructorFix extends SaropaFixProducer {
  _AvoidDeprecatedListConstructorFix({required super.context});

  static const FixKind _fixKind = FixKind(
    'saropa.fix.avoidDeprecatedListConstructor',
    80,
    'Replace with list literal',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final creation = node.thisOrAncestorOfType<InstanceCreationExpression>();
    if (creation == null) return;

    final typeNode = creation.constructorName.type;
    final typeEl = typeNode.element;
    if (typeEl?.name != 'List' || !_isDartCoreLibrary(typeEl?.library)) {
      return;
    }
    if (creation.constructorName.name != null) return;
    if (creation.argumentList.arguments.isNotEmpty) return;

    final TypeArgumentList? ta = typeNode.typeArguments;
    final String replacement;
    if (ta == null || ta.arguments.isEmpty) {
      replacement = '[]';
    } else {
      replacement = '${ta.toSource()}[]';
    }

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(creation.offset, creation.length),
        replacement,
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_removed_proxy_annotation
// ─────────────────────────────────────────────────────────────────────────────

/// Detects the removed `@proxy` annotation (Dart 3.0).
class AvoidRemovedProxyAnnotationRule extends SaropaLintRule {
  AvoidRemovedProxyAnnotationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'@proxy'};

  static const LintCode _code = LintCode(
    'avoid_removed_proxy_annotation',
    '[avoid_removed_proxy_annotation] The @proxy annotation was removed in Dart 3.0.0; it had no effect in Dart 2. Remove it. {v1}',
    correctionMessage: 'Delete the @proxy annotation.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _RemoveAnnotationFix(context: context, annotationName: 'proxy'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    context.addAnnotation((Annotation node) {
      final id = _annotationNameIdentifier(node);
      if (id == null || id.name != 'proxy') return;
      if (!_isDartCoreOrUnresolved(id.element, 'proxy')) return;
      reporter.atNode(id);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_removed_provisional_annotation
// ─────────────────────────────────────────────────────────────────────────────

/// Detects the removed `@Provisional` annotation (Dart 3.0).
class AvoidRemovedProvisionalAnnotationRule extends SaropaLintRule {
  AvoidRemovedProvisionalAnnotationRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'Provisional'};

  static const LintCode _code = LintCode(
    'avoid_removed_provisional_annotation',
    '[avoid_removed_provisional_annotation] The @Provisional annotation was removed in Dart 3.0.0. Remove it. {v1}',
    correctionMessage: 'Delete the @Provisional annotation.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _RemoveAnnotationFix(context: context, annotationName: 'Provisional'),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    context.addAnnotation((Annotation node) {
      final id = _annotationNameIdentifier(node);
      if (id == null || id.name != 'Provisional') return;
      if (!_isDartCoreOrUnresolved(id.element, 'Provisional')) return;
      reporter.atNode(id);
    });
  }
}

class _RemoveAnnotationFix extends SaropaFixProducer {
  _RemoveAnnotationFix({required super.context, required this.annotationName});

  final String annotationName;

  // Removes the annotation range plus at most one trailing space/newline and
  // one leading space, to avoid leaving double spaces. Does not strip `///`
  // doc lines or merge adjacent annotations beyond that.

  static const FixKind _fixKind = FixKind(
    'saropa.fix.removeLegacyAnnotation',
    80,
    'Remove legacy annotation',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node == null) return;

    final Annotation? ann = node.thisOrAncestorOfType<Annotation>();
    if (ann == null) return;

    final id = _annotationNameIdentifier(ann);
    if (id == null || id.name != annotationName) return;

    var start = ann.offset;
    var end = ann.end;
    final unit = unitResult.content;
    if (end < unit.length) {
      final next = unit[end];
      if (next == ' ') {
        end++;
      } else if (next == '\n') {
        end++;
      }
    }
    if (start > 0 && unit[start - 1] == ' ') {
      start--;
    }

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(SourceRange(start, end - start), '');
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_deprecated_expires_getter
// ─────────────────────────────────────────────────────────────────────────────

/// Detects use of the removed [Deprecated.expires] getter (Dart 3.0).
class AvoidDeprecatedExpiresGetterRule extends SaropaLintRule {
  AvoidDeprecatedExpiresGetterRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'.expires'};

  static const LintCode _code = LintCode(
    'avoid_deprecated_expires_getter',
    '[avoid_deprecated_expires_getter] Deprecated.expires was removed in Dart 3.0.0. Use Deprecated.message instead. {v1}',
    correctionMessage: "Replace .expires with .message on Deprecated values.",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _AvoidDeprecatedExpiresGetterFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    void checkTarget(Expression? target, SimpleIdentifier prop) {
      if (prop.name != 'expires') return;
      final t = target?.staticType;
      final el = t?.element;
      if (el?.name != 'Deprecated') return;
      if (!_isDartCoreLibrary(el?.library)) return;
      reporter.atNode(prop);
    }

    context.addPropertyAccess((PropertyAccess node) {
      checkTarget(node.realTarget, node.propertyName);
    });

    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      checkTarget(node.prefix, node.identifier);
    });
  }
}

class _AvoidDeprecatedExpiresGetterFix extends SaropaFixProducer {
  _AvoidDeprecatedExpiresGetterFix({required super.context});

  static const FixKind _fixKind = FixKind(
    'saropa.fix.avoidDeprecatedExpiresGetter',
    80,
    "Replace 'expires' with 'message'",
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node is! SimpleIdentifier || node.name != 'expires') return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(SourceRange(node.offset, node.length), 'message');
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_removed_cast_error
// ─────────────────────────────────────────────────────────────────────────────

/// Detects references to the removed [CastError] type (Dart 3.0).
///
/// Prefer [TypeError]; CastError was subsumed by TypeError.
class AvoidRemovedCastErrorRule extends SaropaLintRule {
  AvoidRemovedCastErrorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'CastError'};

  static const LintCode _code = LintCode(
    'avoid_removed_cast_error',
    '[avoid_removed_cast_error] CastError was removed in Dart 3.0.0. Use TypeError instead (cast failures are TypeErrors). {v1}',
    correctionMessage: 'Replace CastError with TypeError.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) => _ReplaceTypeNameFix(
      context: context,
      from: 'CastError',
      to: 'TypeError',
    ),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    context.addNamedType(
      (NamedType node) => _reportRemovedCoreType(node, reporter, 'CastError'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_removed_fall_through_error
// ─────────────────────────────────────────────────────────────────────────────

/// Detects references to the removed [FallThroughError] (Dart 3.0).
class AvoidRemovedFallThroughErrorRule extends SaropaLintRule {
  AvoidRemovedFallThroughErrorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'FallThroughError'};

  static const LintCode _code = LintCode(
    'avoid_removed_fall_through_error',
    '[avoid_removed_fall_through_error] FallThroughError was removed in Dart 3.0.0; invalid switch fall-through is a compile-time error. Remove dead references to this type. {v1}',
    correctionMessage:
        'Delete the FallThroughError reference or restructure switch code.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    context.addNamedType(
      (NamedType node) =>
          _reportRemovedCoreType(node, reporter, 'FallThroughError'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_removed_abstract_class_instantiation_error
// ─────────────────────────────────────────────────────────────────────────────

/// Detects references to the removed [AbstractClassInstantiationError].
class AvoidRemovedAbstractClassInstantiationErrorRule extends SaropaLintRule {
  AvoidRemovedAbstractClassInstantiationErrorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{
    'AbstractClassInstantiationError',
  };

  static const LintCode _code = LintCode(
    'avoid_removed_abstract_class_instantiation_error',
    '[avoid_removed_abstract_class_instantiation_error] AbstractClassInstantiationError was removed in Dart 3.0.0; instantiating an abstract class is a compile-time error. Remove dead references. {v1}',
    correctionMessage:
        'Remove AbstractClassInstantiationError from catch/types.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    context.addNamedType(
      (NamedType node) => _reportRemovedCoreType(
        node,
        reporter,
        'AbstractClassInstantiationError',
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_removed_cyclic_initialization_error
// ─────────────────────────────────────────────────────────────────────────────

/// Detects references to the removed [CyclicInitializationError].
class AvoidRemovedCyclicInitializationErrorRule extends SaropaLintRule {
  AvoidRemovedCyclicInitializationErrorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{
    'CyclicInitializationError',
  };

  static const LintCode _code = LintCode(
    'avoid_removed_cyclic_initialization_error',
    '[avoid_removed_cyclic_initialization_error] CyclicInitializationError was removed in Dart 3.0.0; cyclic top-level initialization is not detected this way in null-safe code. Remove dead references. {v1}',
    correctionMessage: 'Remove CyclicInitializationError from catch/types.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    context.addNamedType(
      (NamedType node) =>
          _reportRemovedCoreType(node, reporter, 'CyclicInitializationError'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_removed_nosuchmethoderror_default_constructor
// ─────────────────────────────────────────────────────────────────────────────

/// Detects the removed default constructor on [NoSuchMethodError] (Dart 3.0).
///
/// Keep `class … extends` on one line like sibling rules so publish tier
/// audits and `dart format` agree on declaration shape.
class AvoidRemovedNoSuchMethodErrorDefaultConstructorRule
    extends SaropaLintRule {
  AvoidRemovedNoSuchMethodErrorDefaultConstructorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'NoSuchMethodError('};

  static const LintCode _code = LintCode(
    'avoid_removed_nosuchmethoderror_default_constructor',
    '[avoid_removed_nosuchmethoderror_default_constructor] The default NoSuchMethodError() constructor was removed in Dart 3.0.0. Use NoSuchMethodError.withInvocation instead. {v1}',
    correctionMessage:
        'Use NoSuchMethodError.withInvocation with receiver, memberName, and invocation.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final NamedType typeNode = node.constructorName.type;
      final Element? typeEl = typeNode.element;
      if (typeEl?.name != 'NoSuchMethodError') return;
      if (!_isDartCoreLibrary(typeEl?.library)) return;
      if (node.constructorName.name != null) return;
      reporter.atNode(node);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_removed_bidirectional_iterator
// ─────────────────────────────────────────────────────────────────────────────

/// Detects references to the removed [BidirectionalIterator] interface.
class AvoidRemovedBidirectionalIteratorRule extends SaropaLintRule {
  AvoidRemovedBidirectionalIteratorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'BidirectionalIterator'};

  static const LintCode _code = LintCode(
    'avoid_removed_bidirectional_iterator',
    '[avoid_removed_bidirectional_iterator] BidirectionalIterator was removed in Dart 3.0.0. Use Iterator and explicit movePrevious where needed, or track indices manually. {v1}',
    correctionMessage:
        'Replace BidirectionalIterator with Iterator-based APIs.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    context.addNamedType(
      (NamedType node) =>
          _reportRemovedCoreType(node, reporter, 'BidirectionalIterator'),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_removed_deferred_library
// ─────────────────────────────────────────────────────────────────────────────

/// Detects the removed [DeferredLibrary] class / annotation (Dart 3.0).
///
/// Use `import '...' deferred as prefix` instead.
class AvoidRemovedDeferredLibraryRule extends SaropaLintRule {
  AvoidRemovedDeferredLibraryRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-core', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'DeferredLibrary'};

  static const LintCode _code = LintCode(
    'avoid_removed_deferred_library',
    '[avoid_removed_deferred_library] DeferredLibrary was removed in Dart 3.0.0. Use deferred imports: import "lib.dart" deferred as p; then await p.loadLibrary(). {v1}',
    correctionMessage:
        'Replace DeferredLibrary with a deferred import and loadLibrary().',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    context.addAnnotation((Annotation node) {
      final id = _annotationNameIdentifier(node);
      if (id == null || id.name != 'DeferredLibrary') return;
      if (!_isDartCoreOrUnresolved(id.element, 'DeferredLibrary')) {
        return;
      }
      reporter.atNode(id);
    });

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final NamedType typeNode = node.constructorName.type;
      final Element? typeEl = typeNode.element;
      if (typeEl?.name != 'DeferredLibrary') return;
      if (!_isDartCoreOrUnresolved(typeEl, 'DeferredLibrary')) return;
      reporter.atNode(node);
    });

    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'DeferredLibrary') return;
      if (!_isDartCoreOrUnresolved(
        node.methodName.element,
        'DeferredLibrary',
      )) {
        return;
      }
      reporter.atNode(node.methodName);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_deprecated_has_next_iterator
// ─────────────────────────────────────────────────────────────────────────────

/// Flags deprecated [HasNextIterator] from `dart:collection` (Dart 3.0+).
///
/// **Why:** `HasNextIterator` was a legacy adapter around pre–Dart-2 iterator
/// patterns. Modern code should use [Iterator.moveNext] and [Iterator.current].
/// **Detection:** [NamedType] and instance creation only, with library resolution
/// to `dart:collection` (or unresolved migration snippets). **Not detected:**
/// identifiers inside strings/comments. **Quick fix:** none — replacement is
/// context-specific.
///
/// **Bad:** `HasNextIterator(iter)`
/// **Good:** cache `moveNext()` or use language features (`for-in`, collection
/// methods) instead of repeated `hasNext` checks.
class AvoidDeprecatedHasNextIteratorRule extends SaropaLintRule {
  AvoidDeprecatedHasNextIteratorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-collection', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'HasNextIterator'};

  static const LintCode _code = LintCode(
    'avoid_deprecated_has_next_iterator',
    '[avoid_deprecated_has_next_iterator] HasNextIterator is deprecated (Dart 3.0, dart:collection). Use Iterator.moveNext/current instead of this legacy adapter. {v1}',
    correctionMessage:
        'Refactor to Iterator: call moveNext() once and keep the bool if needed.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    context.addNamedType((NamedType node) {
      if (node.name.lexeme != 'HasNextIterator') return;
      final el = node.element;
      if (!_isHasNextIteratorOrUnresolved(el)) return;
      reporter.atNode(node);
    });

    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final NamedType typeNode = node.constructorName.type;
      if (typeNode.name.lexeme != 'HasNextIterator') return;
      final typeEl = typeNode.element;
      if (!_isHasNextIteratorOrUnresolved(typeEl)) return;
      reporter.atNode(node);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_removed_max_user_tags_constant
// ─────────────────────────────────────────────────────────────────────────────

/// Flags the removed `UserTag.MAX_USER_TAGS` constant (Dart 3.0, `dart:developer`).
///
/// **Why:** `MAX_USER_TAGS` was removed; the supported constant is
/// [UserTag.maxUserTags]. **Detection:** [PropertyAccess] with property
/// `MAX_USER_TAGS` and a target that resolves to `UserTag` from `dart:developer`
/// (including `prefix.UserTag` after import). **False-positive guard:** a
/// project-local class named `UserTag` is not the SDK class and is not reported.
/// **Quick fix:** renames `MAX_USER_TAGS` → `maxUserTags` on the identifier.
class AvoidRemovedMaxUserTagsConstantRule extends SaropaLintRule {
  AvoidRemovedMaxUserTagsConstantRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-developer', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'MAX_USER_TAGS'};

  static const LintCode _code = LintCode(
    'avoid_removed_max_user_tags_constant',
    '[avoid_removed_max_user_tags_constant] UserTag.MAX_USER_TAGS was removed in Dart 3.0.0. Use UserTag.maxUserTags instead. {v1}',
    correctionMessage: 'Replace MAX_USER_TAGS with maxUserTags.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _ReplaceMaxUserTagsConstantFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    void reportIfUserTagAccess(SimpleIdentifier prop) {
      if (prop.name != 'MAX_USER_TAGS') return;
      final parent = prop.parent;
      if (parent is! PropertyAccess || parent.propertyName != prop) return;
      if (!_isUserTagClassFromDartDeveloper(parent.realTarget)) return;
      reporter.atNode(prop);
    }

    context.addPropertyAccess((PropertyAccess node) {
      reportIfUserTagAccess(node.propertyName);
    });
  }
}

class _ReplaceMaxUserTagsConstantFix extends SaropaFixProducer {
  _ReplaceMaxUserTagsConstantFix({required super.context});

  static const FixKind _fixKind = FixKind(
    'saropa.fix.replaceMaxUserTagsConstant',
    80,
    'Replace with maxUserTags',
  );

  @override
  FixKind get fixKind => _fixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node is! SimpleIdentifier || node.name != 'MAX_USER_TAGS') return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(node.offset, node.length),
        'maxUserTags',
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_removed_dart_developer_metrics
// ─────────────────────────────────────────────────────────────────────────────

/// Flags removed observability metric types from `dart:developer` (Dart 3.0).
///
/// **Why:** `Metrics`, `Metric`, `Counter`, and `Gauge` were removed; they had
/// been broken since Dart 2.0. There is no in-SDK replacement—drop usage or use
/// another metrics approach. **Detection:** [NamedType] and [InstanceCreationExpression]
/// when the type resolves to `dart:developer` or is unresolved (migration code).
/// **False-positive guard:** types with the same names declared in your package
/// or dependencies resolve to non–`dart:developer` libraries and are ignored.
/// **Quick fix:** none.
class AvoidRemovedDartDeveloperMetricsRule extends SaropaLintRule {
  AvoidRemovedDartDeveloperMetricsRule() : super(code: _code);

  static const Set<String> _removedTypeNames = <String>{
    'Metrics',
    'Metric',
    'Counter',
    'Gauge',
  };

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-developer', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{
    'Metrics',
    'Metric',
    'Counter',
    'Gauge',
  };

  static const LintCode _code = LintCode(
    'avoid_removed_dart_developer_metrics',
    '[avoid_removed_dart_developer_metrics] Metrics, Metric, Counter, and Gauge were removed from dart:developer in Dart 3.0.0 (broken since Dart 2.0). Remove usage or migrate to another metrics approach. {v1}',
    correctionMessage:
        'Delete dart:developer metrics usage; there is no in-SDK replacement.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    void reportNamedType(NamedType node) {
      final name = node.name.lexeme;
      if (!_removedTypeNames.contains(name)) return;
      final el = node.element;
      if (!_isDartDeveloperOrUnresolved(el, name)) return;
      reporter.atNode(node);
    }

    void reportCreation(InstanceCreationExpression node) {
      final NamedType typeNode = node.constructorName.type;
      final name = typeNode.name.lexeme;
      if (!_removedTypeNames.contains(name)) return;
      final typeEl = typeNode.element;
      if (!_isDartDeveloperOrUnresolved(typeEl, name)) return;
      reporter.atNode(node);
    }

    context.addNamedType(reportNamedType);
    context.addInstanceCreationExpression(reportCreation);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// avoid_deprecated_network_interface_list_supported
// ─────────────────────────────────────────────────────────────────────────────

/// Flags deprecated [NetworkInterface.listSupported] (`dart:io`).
///
/// **Why:** The API has always returned true since Dart 2.3; the check adds
/// noise and async work for no benefit. **Detection:** [PropertyAccess] on
/// `listSupported` where the target resolves to SDK `NetworkInterface` from
/// `dart:io`. **False-positive guard:** a user-defined `NetworkInterface` type
/// is not flagged. **Quick fix:** none — call sites may be `await`ed or passed
/// as `Future`; replacements differ.
class AvoidDeprecatedNetworkInterfaceListSupportedRule extends SaropaLintRule {
  AvoidDeprecatedNetworkInterfaceListSupportedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'dart-io', 'config'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'listSupported'};

  static const LintCode _code = LintCode(
    'avoid_deprecated_network_interface_list_supported',
    '[avoid_deprecated_network_interface_list_supported] NetworkInterface.listSupported is deprecated (dart:io). It has always been true since Dart 2.3; remove the check or use true. {v1}',
    correctionMessage:
        'Remove the call or replace with true / Future.value(true) as appropriate.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (context.isLintPluginSource) return;

    context.addPropertyAccess((PropertyAccess node) {
      if (node.propertyName.name != 'listSupported') return;
      if (!_isNetworkInterfaceClassFromDartIo(node.realTarget)) return;
      reporter.atNode(node.propertyName);
    });
  }
}

class _ReplaceTypeNameFix extends SaropaFixProducer {
  _ReplaceTypeNameFix({
    required super.context,
    required this.from,
    required this.to,
  });

  final String from;
  final String to;

  @override
  FixKind get fixKind =>
      FixKind('saropa.fix.replaceTypeName.$from', 80, 'Replace $from with $to');

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final node = coveringNode;
    if (node is NamedType && node.name.lexeme == from) {
      final t = node.name;
      await builder.addDartFileEdit(file, (b) {
        b.addSimpleReplacement(SourceRange(t.offset, t.length), to);
      });
      return;
    }
    if (node is! SimpleIdentifier || node.name != from) return;

    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(SourceRange(node.offset, node.length), to);
    });
  }
}
