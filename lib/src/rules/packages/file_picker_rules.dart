// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// file_picker package lint rules (always-on correctness / best-practice).
///
/// Catch the documented file_picker footguns: using a cancelled (null) result,
/// the web null-path crash, the FileType.custom / allowedExtensions contract,
/// leading-dot extensions, and the multi-file in-memory hazard.
///
/// The version-gated `withData`/`withReadStream`/`allowMultiple`/`allowCompression`
/// deprecation rules live with the migration-pack workstream, not here.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../fixes/common/replace_node_fix.dart';
import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// The FilePicker entry points that accept the type/extension arguments.
const Set<String> _pickerMethods = <String>{
  'pickFiles',
  'pickFile',
  'saveFile',
  'pickFileAndDirectoryPaths',
};

/// Members of `FilePickerResult` whose use on a still-nullable result is an
/// unchecked dereference.
const Set<String> _resultMembers = <String>{
  'files',
  'paths',
  'xFiles',
  'count',
  'names',
};

Expression? _namedArgValue(ArgumentList args, String name) {
  for (final Expression arg in args.arguments) {
    if (arg is NamedExpression && arg.name.label.name == name) {
      return arg.expression;
    }
  }
  return null;
}

/// True when [expr] is the enum constant `FileType.custom`.
bool _isFileTypeCustom(Expression? expr) =>
    expr is PrefixedIdentifier &&
    expr.prefix.name == 'FileType' &&
    expr.identifier.name == 'custom';

/// True when [expr] is a boolean literal `true`.
bool _isLiteralTrue(Expression? expr) =>
    expr is BooleanLiteral && expr.value == true;

/// The `allowedExtensions:` list literal of a call, or null when absent / not a
/// statically-visible list.
ListLiteral? _allowedExtensionsList(MethodInvocation node) {
  final Expression? value = _namedArgValue(node.argumentList, 'allowedExtensions');
  return value is ListLiteral ? value : null;
}

// =============================================================================
// file_picker_unchecked_null_result
// =============================================================================

/// Flags use of a `FilePickerResult?` member without a null check.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `pickFiles()` returns null when the user cancels; accessing `.files`/`.paths`
/// on the unchecked result is a runtime null dereference. After an
/// `if (result == null) return;` guard the type narrows to non-nullable and the
/// rule does not fire.
///
/// **BAD:**
/// ```dart
/// final r = await FilePicker.platform.pickFiles();
/// use(r.files); // r is FilePickerResult?
/// ```
///
/// **GOOD:**
/// ```dart
/// final r = await FilePicker.platform.pickFiles();
/// if (r == null) return;
/// use(r.files);
/// ```
class FilePickerUncheckedNullResultRule extends SaropaLintRule {
  FilePickerUncheckedNullResultRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'file_picker_unchecked_null_result',
    '[file_picker_unchecked_null_result] A FilePickerResult member (files/paths/xFiles/...) is accessed on a still-nullable result. pickFiles()/pickFile() return null when the user cancels the picker on Android/iOS/desktop, so using the result without a null check is a runtime null dereference. A preceding if (result == null) return; narrows the type and clears this report. {v1}',
    correctionMessage:
        'Null-check the FilePickerResult (if (result == null) return; or result?.files) before using its members.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPropertyAccess((PropertyAccess node) {
      if (!_resultMembers.contains(node.propertyName.name)) return;
      if (!fileImportsPackage(node, PackageImports.filePicker)) return;
      // Resolved nullable FilePickerResult? — flow analysis makes the type
      // non-nullable after a guard, so a guarded access never matches.
      final String? type = node.realTarget.staticType?.getDisplayString();
      if (type != 'FilePickerResult?') return;
      reporter.atNode(node);
    });

    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      if (!_resultMembers.contains(node.identifier.name)) return;
      if (!fileImportsPackage(node, PackageImports.filePicker)) return;
      final String? type = node.prefix.staticType?.getDisplayString();
      if (type != 'FilePickerResult?') return;
      reporter.atNode(node);
    });
  }
}

// =============================================================================
// file_picker_path_on_web
// =============================================================================

/// Flags `PlatformFile.path!` force-unwrap (null on web).
///
/// Since: v4.16.0 | Rule version: v1 | Experimental
///
/// `PlatformFile.path` is always null on web; force-unwrapping it throws there.
/// A `kIsWeb` guard around the access suppresses the report. Experimental: the
/// guard detection is a best-effort enclosing-`if` scan.
///
/// **BAD:**
/// ```dart
/// final f = File(platformFile.path!);
/// ```
///
/// **GOOD:**
/// ```dart
/// if (!kIsWeb) { final f = File(platformFile.path!); }
/// // or use platformFile.bytes / readAsBytes() on web
/// ```
class FilePickerPathOnWebRule extends SaropaLintRule {
  FilePickerPathOnWebRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'file_picker_path_on_web',
    '[file_picker_path_on_web] PlatformFile.path is force-unwrapped with ! but is always null on the web platform, so this throws at runtime on web. The browser sandbox exposes no real filesystem path. Use PlatformFile.bytes / readAsBytes() and PlatformFile.name on web, or guard the path access with if (!kIsWeb). This rule is experimental — the kIsWeb-guard detection is a best-effort enclosing-if scan. {v1}',
    correctionMessage:
        'Guard the path use behind if (!kIsWeb), or use bytes / readAsBytes() and name on web where path is null.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPostfixExpression((PostfixExpression node) {
      if (node.operator.lexeme != '!') return;
      if (!fileImportsPackage(node, PackageImports.filePicker)) return;

      final Expression operand = node.operand;
      final Expression? receiver;
      final String property;
      if (operand is PropertyAccess) {
        receiver = operand.realTarget;
        property = operand.propertyName.name;
      } else if (operand is PrefixedIdentifier) {
        receiver = operand.prefix;
        property = operand.identifier.name;
      } else {
        return;
      }
      if (property != 'path') return;

      // Receiver must resolve to PlatformFile (nullable or not).
      final String? type = receiver?.staticType?.getDisplayString();
      if (type != 'PlatformFile' && type != 'PlatformFile?') return;

      // Best-effort: an enclosing `if` whose condition references kIsWeb is a
      // platform guard; suppress. (Experimental — see rule doc.)
      if (_hasEnclosingKIsWebGuard(node)) return;

      reporter.atNode(node);
    });
  }

  bool _hasEnclosingKIsWebGuard(AstNode node) {
    AstNode? current = node.parent;
    while (current != null) {
      if (current is IfStatement && _referencesKIsWeb(current.expression)) {
        return true;
      }
      if (current is FunctionBody) break;
      current = current.parent;
    }
    return false;
  }

  bool _referencesKIsWeb(AstNode condition) {
    bool found = false;
    condition.visitChildren(_KIsWebVisitor(() => found = true));
    if (condition is SimpleIdentifier && condition.name == 'kIsWeb') {
      return true;
    }
    return found;
  }
}

/// Sets a flag when a `kIsWeb` identifier appears in a condition subtree.
class _KIsWebVisitor extends GeneralizingAstVisitor<void> {
  _KIsWebVisitor(this.onFound);
  final void Function() onFound;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == 'kIsWeb') onFound();
    super.visitSimpleIdentifier(node);
  }
}

// =============================================================================
// file_picker_custom_type_missing_extensions
// =============================================================================

/// Flags `type: FileType.custom` with no `allowedExtensions`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `FileType.custom` without a non-empty `allowedExtensions` throws at runtime
/// on every platform.
///
/// **BAD:**
/// ```dart
/// FilePicker.platform.pickFiles(type: FileType.custom);
/// ```
///
/// **GOOD:**
/// ```dart
/// FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
/// ```
class FilePickerCustomTypeMissingExtensionsRule extends SaropaLintRule {
  FilePickerCustomTypeMissingExtensionsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'FileType.custom'};

  static const LintCode _code = LintCode(
    'file_picker_custom_type_missing_extensions',
    '[file_picker_custom_type_missing_extensions] A file_picker call uses type: FileType.custom without a non-empty allowedExtensions list. FileType.custom requires the extension filter; the plugin throws at runtime on every platform when allowedExtensions is null or empty while the type is custom. {v1}',
    correctionMessage:
        'Pass allowedExtensions: [\'pdf\', ...] (without leading dots) when using FileType.custom, or change the type.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_pickerMethods.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.filePicker)) return;

      if (!_isFileTypeCustom(_namedArgValue(node.argumentList, 'type'))) return;

      final Expression? ext = _namedArgValue(node.argumentList, 'allowedExtensions');
      final bool missing =
          ext == null || (ext is ListLiteral && ext.elements.isEmpty);
      if (!missing) return;

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// file_picker_extensions_without_custom_type
// =============================================================================

/// Flags `allowedExtensions` passed without `type: FileType.custom`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `allowedExtensions` is only honored with `FileType.custom`; with any other
/// type the plugin ignores it or throws.
///
/// **BAD:**
/// ```dart
/// FilePicker.platform.pickFiles(type: FileType.image, allowedExtensions: ['png']);
/// ```
///
/// **GOOD:**
/// ```dart
/// FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['png']);
/// ```
class FilePickerExtensionsWithoutCustomTypeRule extends SaropaLintRule {
  FilePickerExtensionsWithoutCustomTypeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'allowedExtensions'};

  static const LintCode _code = LintCode(
    'file_picker_extensions_without_custom_type',
    '[file_picker_extensions_without_custom_type] A file_picker call passes allowedExtensions while the type is not FileType.custom (or is absent, defaulting to FileType.any). The extension filter is only honored with FileType.custom; with any other type the plugin ignores the list or throws ("Custom extension filters are only allowed with FileType.custom"). {v1}',
    correctionMessage:
        'Set type: FileType.custom to use allowedExtensions, or remove the allowedExtensions argument.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_pickerMethods.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.filePicker)) return;

      final Expression? ext = _namedArgValue(node.argumentList, 'allowedExtensions');
      // Non-empty extension list present.
      if (ext == null) return;
      if (ext is ListLiteral && ext.elements.isEmpty) return;
      if (ext is NullLiteral) return;

      final Expression? type = _namedArgValue(node.argumentList, 'type');
      // type: FileType.custom is the only valid pairing.
      if (_isFileTypeCustom(type)) return;

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// file_picker_extension_with_dot
// =============================================================================

/// Flags a leading-dot extension in `allowedExtensions` (e.g. `'.pdf'`).
///
/// Since: v4.16.0 | Rule version: v1
///
/// Extensions must omit the dot; `'.pdf'` is silently ignored on Android.
///
/// **BAD:**
/// ```dart
/// allowedExtensions: ['.pdf', '.png']
/// ```
///
/// **GOOD:**
/// ```dart
/// allowedExtensions: ['pdf', 'png']
/// ```
class FilePickerExtensionWithDotRule extends SaropaLintRule {
  FilePickerExtensionWithDotRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'allowedExtensions'};

  static const LintCode _code = LintCode(
    'file_picker_extension_with_dot',
    '[file_picker_extension_with_dot] An allowedExtensions entry starts with a dot (e.g. \'.pdf\'). file_picker expects bare extensions without the leading dot; a dotted entry is silently ignored on Android, so the filter does not match the intended files. {v1}',
    correctionMessage:
        'Remove the leading dot — use \'pdf\' not \'.pdf\' in allowedExtensions.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _StripExtensionDotFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_pickerMethods.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.filePicker)) return;

      final ListLiteral? list = _allowedExtensionsList(node);
      if (list == null) return;

      for (final CollectionElement element in list.elements) {
        if (element is StringLiteral) {
          final String? value = element.stringValue;
          if (value != null && value.startsWith('.')) {
            reporter.atNode(element);
          }
        }
      }
    });
  }
}

/// Quick fix: strip the leading dot from a `'.ext'` literal.
class _StripExtensionDotFix extends ReplaceNodeFix {
  _StripExtensionDotFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.stripExtensionDot',
    80,
    'Remove leading dot from extension',
  );

  @override
  String computeReplacement(AstNode node) {
    if (node is StringLiteral) {
      final String? value = node.stringValue;
      if (value != null && value.startsWith('.')) {
        return "'${value.substring(1)}'";
      }
    }
    return node.toSource();
  }
}

// =============================================================================
// file_picker_with_data_large_files
// =============================================================================

/// Flags `withData: true` together with `allowMultiple: true`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `withData: true` loads each file fully into memory; with `allowMultiple` that
/// is N×file-size RAM and risks OOM. Use a read stream / lazy bytes instead.
///
/// **BAD:**
/// ```dart
/// FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
/// ```
///
/// **GOOD:**
/// ```dart
/// FilePicker.platform.pickFiles(allowMultiple: true); // read each file lazily
/// ```
class FilePickerWithDataLargeFilesRule extends SaropaLintRule {
  FilePickerWithDataLargeFilesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'withData'};

  static const LintCode _code = LintCode(
    'file_picker_with_data_large_files',
    '[file_picker_with_data_large_files] A file_picker call combines withData: true with allowMultiple: true. withData loads each selected file fully into memory as a Uint8List; with multiple files that is N times the file size held at once, which the plugin documentation warns can cause out-of-memory crashes on iOS and Android. Read each file lazily (readAsByteStream / readAsBytes) instead. {v1}',
    correctionMessage:
        'Drop withData: true for multi-file picks and read each PlatformFile lazily via readAsByteStream()/readAsBytes().',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_pickerMethods.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.filePicker)) return;

      // Only explicit boolean true on both flags — variables / expressions are
      // not statically decidable and are not flagged.
      if (!_isLiteralTrue(_namedArgValue(node.argumentList, 'withData'))) return;
      if (!_isLiteralTrue(_namedArgValue(node.argumentList, 'allowMultiple'))) {
        return;
      }

      reporter.atNode(node.methodName);
    });
  }
}
