// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// image_picker package lint rules (new coverage only).
///
/// The repo already ships image_picker rules for null/result handling
/// (`require_image_picker_result_handling`, `require_image_picker_error_handling`),
/// unbounded images (`avoid_image_picker_large_files`,
/// `prefer_image_picker_max_dimensions`), and source choice
/// (`avoid_image_picker_without_source`, `require_image_picker_source_choice`).
/// These rules cover the gaps those do NOT: Android lost-data recovery, the
/// imageQuality 0-100 range, camera-source platform support, LostDataResponse
/// emptiness, and `[index]` access on a multi-pick result.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../fixes/common/replace_node_fix.dart';
import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// All ImagePicker pick entry points.
const Set<String> _pickMethods = <String>{
  'pickImage',
  'pickVideo',
  'pickMedia',
  'pickMultiImage',
  'pickMultipleMedia',
};

/// Multi-pick methods returning `List<XFile>` (cancel → empty list).
const Set<String> _multiMethods = <String>{
  'pickMultiImage',
  'pickMultipleMedia',
};

bool _isTestFilePath(String path) {
  final String normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('_test.dart') || normalized.contains('/test/');
}

Expression? _namedArg(MethodInvocation node, String name) {
  for (final Expression arg in node.argumentList.arguments) {
    if (arg is NamedExpression && arg.name.label.name == name) {
      return arg.expression;
    }
  }
  return null;
}

FunctionBody? _enclosingMemberBody(AstNode node) {
  AstNode? current = node.parent;
  while (current != null) {
    if (current is MethodDeclaration) return current.body;
    if (current is FunctionDeclaration) {
      return current.functionExpression.body;
    }
    if (current is ConstructorDeclaration) return current.body;
    current = current.parent;
  }
  return null;
}

/// Collects the nodes the member-flow rules reason over.
class _MemberScan extends RecursiveAstVisitor<void> {
  final List<IndexExpression> indexExpressions = <IndexExpression>[];
  final List<PrefixedIdentifier> prefixedIds = <PrefixedIdentifier>[];
  final List<PropertyAccess> propertyAccesses = <PropertyAccess>[];
  final List<MethodInvocation> invocations = <MethodInvocation>[];

  @override
  void visitIndexExpression(IndexExpression node) {
    indexExpressions.add(node);
    super.visitIndexExpression(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    prefixedIds.add(node);
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    propertyAccesses.add(node);
    super.visitPropertyAccess(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    invocations.add(node);
    super.visitMethodInvocation(node);
  }

  /// True when `<varName>.<member>` is accessed anywhere.
  bool accessesMember(String varName, Set<String> members) {
    for (final PrefixedIdentifier id in prefixedIds) {
      if (id.prefix.name == varName && members.contains(id.identifier.name)) {
        return true;
      }
    }
    for (final PropertyAccess pa in propertyAccesses) {
      final Expression target = pa.target ?? pa.realTarget;
      if (target is SimpleIdentifier &&
          target.name == varName &&
          members.contains(pa.propertyName.name)) {
        return true;
      }
    }
    return false;
  }

  /// True when an emptiness guard (isEmpty/isNotEmpty/length) is read on [varName].
  bool hasEmptinessGuard(String varName) => accessesMember(
    varName,
    const <String>{'isEmpty', 'isNotEmpty', 'length'},
  );
}

// =============================================================================
// image_picker_missing_retrieve_lost_data
// =============================================================================

/// Flags pick usage in a file with no `retrieveLostData`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// On Android the OS can kill the app mid-pick; the selected media is delivered
/// next launch only via `retrieveLostData()`. File-scoped (the recovery may live
/// in a startup file — a known false positive).
///
/// **BAD:**
/// ```dart
/// await picker.pickImage(source: src); // no retrieveLostData anywhere
/// ```
///
/// **GOOD:**
/// ```dart
/// final lost = await picker.retrieveLostData(); // handled at startup
/// ```
class ImagePickerMissingRetrieveLostDataRule extends SaropaLintRule {
  ImagePickerMissingRetrieveLostDataRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'image_picker_missing_retrieve_lost_data',
    '[image_picker_missing_retrieve_lost_data] This file uses image_picker pick methods but never calls retrieveLostData(). On Android, when the OS kills the app while the picker Intent is active (low-memory process death), the selected media is delivered on the next launch and can only be collected via retrieveLostData(); without it the user\'s selection is silently dropped. File-scoped — the recovery may live in a startup file (a known false positive). {v1}',
    correctionMessage:
        'Call ImagePicker().retrieveLostData() early in app startup and handle the LostDataResponse.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addCompilationUnit((CompilationUnit unit) {
      if (!fileImportsPackage(unit, PackageImports.imagePicker)) return;
      if (_isTestFilePath(context.filePath)) return;

      final _MemberScan scan = _MemberScan();
      unit.accept(scan);

      final List<MethodInvocation> picks = scan.invocations
          .where(
            (MethodInvocation inv) =>
                _pickMethods.contains(inv.methodName.name),
          )
          .toList();
      if (picks.isEmpty) return;

      final bool hasRetrieve = scan.invocations.any(
        (MethodInvocation inv) => inv.methodName.name == 'retrieveLostData',
      );
      if (hasRetrieve) return;

      reporter.atNode(picks.first.methodName);
    });
  }
}

// =============================================================================
// image_picker_invalid_image_quality
// =============================================================================

/// Flags an `imageQuality` literal outside 0-100.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `imageQuality` is asserted to be 0-100; an out-of-range literal asserts in
/// debug and crashed on iOS 16+. The fix clamps to the nearest bound.
///
/// **BAD:**
/// ```dart
/// await picker.pickImage(source: src, imageQuality: 150);
/// ```
///
/// **GOOD:**
/// ```dart
/// await picker.pickImage(source: src, imageQuality: 100);
/// ```
class ImagePickerInvalidImageQualityRule extends SaropaLintRule {
  ImagePickerInvalidImageQualityRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'imageQuality'};

  static const LintCode _code = LintCode(
    'image_picker_invalid_image_quality',
    '[image_picker_invalid_image_quality] The imageQuality argument is an integer literal outside the valid 0-100 range. image_picker asserts 0 <= imageQuality <= 100; an out-of-range value triggers an AssertionError in debug and produced a native crash on iOS 16+. Clamp the value into 0-100. {v1}',
    correctionMessage:
        'Use an imageQuality between 0 and 100 (0 = max compression, 100 = none).',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _ClampImageQualityFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_pickMethods.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.imagePicker)) return;

      final Expression? quality = _namedArg(node, 'imageQuality');
      if (quality is! IntegerLiteral) return;
      final int? value = quality.value;
      if (value == null || (value >= 0 && value <= 100)) return;

      reporter.atNode(quality);
    });
  }
}

/// Quick fix: clamp an out-of-range imageQuality literal to 0 or 100.
class _ClampImageQualityFix extends ReplaceNodeFix {
  _ClampImageQualityFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.clampImageQuality',
    80,
    'Clamp imageQuality to 0-100',
  );

  @override
  String computeReplacement(AstNode node) {
    if (node is IntegerLiteral) {
      final int? value = node.value;
      if (value != null && value < 0) return '0';
      if (value != null && value > 100) return '100';
    }
    return node.toSource();
  }
}

// =============================================================================
// image_picker_camera_source_without_support_check
// =============================================================================

/// Flags `source: ImageSource.camera` with no `supportsImageSource` guard.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `ImageSource.camera` is unsupported on web/desktop and throws there. Heuristic:
/// looks for a `supportsImageSource` or `Platform` guard in the member; a
/// helper-wrapped guard is a known false positive. (Distinct from the existing
/// `avoid_image_picker_without_source`, which flags a missing source entirely.)
///
/// **BAD:**
/// ```dart
/// await picker.pickImage(source: ImageSource.camera);
/// ```
///
/// **GOOD:**
/// ```dart
/// if (picker.supportsImageSource(ImageSource.camera)) {
///   await picker.pickImage(source: ImageSource.camera);
/// }
/// ```
class ImagePickerCameraSourceWithoutSupportCheckRule extends SaropaLintRule {
  ImagePickerCameraSourceWithoutSupportCheckRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'ImageSource.camera'};

  static const LintCode _code = LintCode(
    'image_picker_camera_source_without_support_check',
    '[image_picker_camera_source_without_support_check] pickImage / pickVideo is called with source: ImageSource.camera but the member has no supportsImageSource or platform guard. ImageSource.camera is unsupported on web (it opens the gallery) and throws UnimplementedError on Windows/Linux. Heuristic — a guard wrapped in a helper method is a known false positive. {v1}',
    correctionMessage:
        'Gate the camera pick on picker.supportsImageSource(ImageSource.camera) (or a platform check) and fall back to gallery.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String method = node.methodName.name;
      if (method != 'pickImage' && method != 'pickVideo') return;
      if (!fileImportsPackage(node, PackageImports.imagePicker)) return;

      final Expression? source = _namedArg(node, 'source');
      if (source is! PrefixedIdentifier ||
          source.prefix.name != 'ImageSource' ||
          source.identifier.name != 'camera') {
        return;
      }

      final FunctionBody? body = _enclosingMemberBody(node);
      if (body == null) return;
      final _MemberScan scan = _MemberScan();
      body.accept(scan);

      final bool hasSupportCheck = scan.invocations.any(
        (MethodInvocation inv) => inv.methodName.name == 'supportsImageSource',
      );
      if (hasSupportCheck) return;

      // A Platform.* reference in the member counts as a platform guard.
      if (scan.prefixedIds.any(
        (PrefixedIdentifier id) => id.prefix.name == 'Platform',
      )) {
        return;
      }

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// image_picker_lost_data_empty_check_missing
// =============================================================================

/// Flags `LostDataResponse.files`/`.exception` read with no `isEmpty` check.
///
/// Since: v4.16.0 | Rule version: v1
///
/// The recommended pattern guards with `if (response.isEmpty) return;` before
/// reading the response.
///
/// **BAD:**
/// ```dart
/// final r = await picker.retrieveLostData();
/// useFiles(r.files); // no isEmpty check
/// ```
///
/// **GOOD:**
/// ```dart
/// final r = await picker.retrieveLostData();
/// if (r.isEmpty) return;
/// useFiles(r.files);
/// ```
class ImagePickerLostDataEmptyCheckMissingRule extends SaropaLintRule {
  ImagePickerLostDataEmptyCheckMissingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'retrieveLostData'};

  static const LintCode _code = LintCode(
    'image_picker_lost_data_empty_check_missing',
    '[image_picker_lost_data_empty_check_missing] A LostDataResponse from retrieveLostData() has its files or exception read without first checking isEmpty. LostDataResponse.isEmpty is true when there is no recovered data; reading .files / .exception on an empty response yields null or throws. The documented pattern guards with if (response.isEmpty) return; before any access. {v1}',
    correctionMessage:
        'Guard with if (response.isEmpty) return; before reading response.files or response.exception.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'retrieveLostData') return;
      if (!fileImportsPackage(node, PackageImports.imagePicker)) return;

      final AstNode? awaitNode = node.parent;
      if (awaitNode is! AwaitExpression) return;
      final AstNode? decl = awaitNode.parent;
      if (decl is! VariableDeclaration) return;
      final String varName = decl.name.lexeme;

      final FunctionBody? body = _enclosingMemberBody(node);
      if (body == null) return;
      final _MemberScan scan = _MemberScan();
      body.accept(scan);

      if (!scan.accessesMember(varName, const <String>{'files', 'exception'})) {
        return;
      }
      if (scan.accessesMember(varName, const <String>{
        'isEmpty',
        'isNotEmpty',
      })) {
        return;
      }

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// image_picker_multi_result_unchecked_empty
// =============================================================================

/// Flags `[index]` access on a multi-pick result with no emptiness guard.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `pickMultiImage`/`pickMultipleMedia` return an empty list on cancel; `files[0]`
/// then throws RangeError. (The `.first`/`.last` form is covered by the generic
/// `avoid_unsafe_collection_methods`; this rule adds the `[index]` case.)
///
/// **BAD:**
/// ```dart
/// final files = await picker.pickMultiImage();
/// final f = files[0];
/// ```
///
/// **GOOD:**
/// ```dart
/// final files = await picker.pickMultiImage();
/// if (files.isNotEmpty) { final f = files[0]; }
/// ```
class ImagePickerMultiResultUncheckedEmptyRule extends SaropaLintRule {
  ImagePickerMultiResultUncheckedEmptyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{
    'pickMultiImage',
    'pickMultipleMedia',
  };

  static const LintCode _code = LintCode(
    'image_picker_multi_result_unchecked_empty',
    '[image_picker_multi_result_unchecked_empty] A multi-pick result list is indexed (e.g. files[0]) with no emptiness guard. pickMultiImage / pickMultipleMedia return an EMPTY list when the user cancels (not null), so indexing it throws RangeError: Index out of range. Guard with isNotEmpty first. The .first/.last form is handled by the generic unsafe-collection rule; this covers the [index] access. {v1}',
    correctionMessage:
        'Guard the index access with if (files.isNotEmpty) { ... } (or use elementAtOrNull).',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_multiMethods.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.imagePicker)) return;

      final AstNode? awaitNode = node.parent;
      if (awaitNode is! AwaitExpression) return;
      final AstNode? decl = awaitNode.parent;
      if (decl is! VariableDeclaration) return;
      final String varName = decl.name.lexeme;

      final FunctionBody? body = _enclosingMemberBody(node);
      if (body == null) return;
      final _MemberScan scan = _MemberScan();
      body.accept(scan);

      // No emptiness guard anywhere on the var → unsafe.
      if (scan.hasEmptinessGuard(varName)) return;

      for (final IndexExpression index in scan.indexExpressions) {
        final Expression target = index.realTarget;
        if (target is SimpleIdentifier && target.name == varName) {
          reporter.atNode(index);
        }
      }
    });
  }
}
