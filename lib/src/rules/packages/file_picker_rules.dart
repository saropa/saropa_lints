// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// file_picker package lint rules (always-on correctness / best-practice).
///
/// Catch the documented file_picker footguns: using a canceled (null) result,
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
  final Expression? value = _namedArgValue(
    node.argumentList,
    'allowedExtensions',
  );
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

      final Expression? ext = _namedArgValue(
        node.argumentList,
        'allowedExtensions',
      );
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

      final Expression? ext = _namedArgValue(
        node.argumentList,
        'allowedExtensions',
      );
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
// file_picker_deprecated_with_data  (version-gated: file_picker >= 12)
// =============================================================================

/// Flags the deprecated `withData:` named argument on FilePicker calls.
///
/// Since: v4.16.0 | Rule version: v1 | Pack: file_picker_12
///
/// `withData` was removed in file_picker v12. Call sites must migrate to
/// `PlatformFile.readAsBytes()` after picking; passing `withData: true` still
/// compiles on older majors but breaks on v12 and above.
///
/// **BAD:**
/// ```dart
/// FilePicker.platform.pickFiles(withData: true);
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = await FilePicker.platform.pickFiles();
/// final bytes = await result!.files.single.readAsBytes();
/// ```
class FilePickerDeprecatedWithDataRule extends SaropaLintRule {
  FilePickerDeprecatedWithDataRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'withData'};

  static const LintCode _code = LintCode(
    'file_picker_deprecated_with_data',
    '[file_picker_deprecated_with_data] The withData: named argument on FilePicker.pickFiles() / pickFile() was deprecated and removed in file_picker v12. Passing withData: true loads the entire file into memory eagerly; the recommended migration is to drop the argument and call await platformFile.readAsBytes() on each PlatformFile after picking, giving you explicit control over when the I/O occurs. Remove this argument to prepare for the v12 upgrade. {v1}',
    correctionMessage:
        'Remove the withData: argument and read file bytes lazily via await platformFile.readAsBytes() after the pick.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_pickerMethods.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.filePicker)) return;

      // Report on the NamedExpression node so the squiggle sits under the
      // deprecated argument, not the whole call.
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'withData') {
          reporter.atNode(arg);
          return;
        }
      }
    });
  }
}

// =============================================================================
// file_picker_deprecated_with_read_stream  (version-gated: file_picker >= 12)
// =============================================================================

/// Flags the deprecated `withReadStream:` named argument on FilePicker calls.
///
/// Since: v4.16.0 | Rule version: v1 | Pack: file_picker_12
///
/// `withReadStream` was removed in file_picker v12. The replacement is
/// `PlatformFile.readAsByteStream()`, which returns a `Stream<List<int>>`
/// with the same semantics but no picker-level argument needed.
///
/// **BAD:**
/// ```dart
/// FilePicker.platform.pickFiles(withReadStream: true);
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = await FilePicker.platform.pickFiles();
/// final stream = result!.files.single.readAsByteStream();
/// ```
class FilePickerDeprecatedWithReadStreamRule extends SaropaLintRule {
  FilePickerDeprecatedWithReadStreamRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'withReadStream'};

  static const LintCode _code = LintCode(
    'file_picker_deprecated_with_read_stream',
    '[file_picker_deprecated_with_read_stream] The withReadStream: named argument on FilePicker.pickFiles() / pickFile() was deprecated and removed in file_picker v12. The v12 replacement is PlatformFile.readAsByteStream(), which returns a Stream<List<int>> with identical streaming semantics but is invoked on the returned PlatformFile rather than as a picker option. Remove this argument and call readAsByteStream() on each PlatformFile after picking to prepare for the v12 upgrade. {v1}',
    correctionMessage:
        'Remove the withReadStream: argument and read each file as a stream via platformFile.readAsByteStream() after the pick.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_pickerMethods.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.filePicker)) return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'withReadStream') {
          reporter.atNode(arg);
          return;
        }
      }
    });
  }
}

// =============================================================================
// file_picker_deprecated_allow_multiple  (version-gated: file_picker >= 12)
// =============================================================================

/// Flags the deprecated `allowMultiple:` named argument on FilePicker calls.
///
/// Since: v4.16.0 | Rule version: v1 | Pack: file_picker_12
///
/// `allowMultiple` was deprecated in file_picker v12 in favor of the
/// dedicated `pickFiles()` (multi) vs `pickFile()` (single) API split.
/// `allowMultiple: false` should migrate to a `pickFile()` call (which also
/// returns a non-nullable single `PlatformFile`, avoiding the `.first` dance).
/// `allowMultiple: true` means the existing call was already `pickFiles()`
/// and the argument can simply be removed.
///
/// **BAD:**
/// ```dart
/// FilePicker.platform.pickFiles(allowMultiple: true);
/// FilePicker.platform.pickFiles(allowMultiple: false);
/// ```
///
/// **GOOD:**
/// ```dart
/// FilePicker.platform.pickFiles(); // multiple files — argument removed
/// FilePicker.platform.pickFile();  // single file  — use dedicated method
/// ```
class FilePickerDeprecatedAllowMultipleRule extends SaropaLintRule {
  FilePickerDeprecatedAllowMultipleRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'allowMultiple'};

  static const LintCode _code = LintCode(
    'file_picker_deprecated_allow_multiple',
    '[file_picker_deprecated_allow_multiple] The allowMultiple: named argument on FilePicker.pickFiles() was deprecated in file_picker v12. The v12 API expresses the distinction through dedicated methods instead: pickFiles() for multi-file selection (remove the allowMultiple: true argument) and the new pickFile() for single-file selection (replace allowMultiple: false with pickFile(), which also returns a non-nullable PlatformFile directly). Report-only — removing the argument changes the return type for the false case, so a mechanical replacement is not safe. {v1}',
    correctionMessage:
        'For allowMultiple: true, remove the argument (pickFiles() is multi by default). For allowMultiple: false, migrate the call to pickFile().',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_pickerMethods.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.filePicker)) return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'allowMultiple') {
          reporter.atNode(arg);
          return;
        }
      }
    });
  }
}

// =============================================================================
// file_picker_deprecated_allow_compression  (version-gated: file_picker >= 10)
// =============================================================================

/// Flags the deprecated `allowCompression:` named argument on FilePicker calls.
///
/// Since: v4.16.0 | Rule version: v1 | Pack: file_picker_10
///
/// `allowCompression` was replaced by `compressionQuality` (an `int` 0–100)
/// in file_picker v10. The mechanical mapping is:
///   `allowCompression: true`  → `compressionQuality: 75`
///   `allowCompression: false` → `compressionQuality: 0`
///
/// A quick fix is offered when the value is a boolean literal; when the value
/// is a non-literal expression the fix is report-only (the expression must
/// be manually mapped to a quality value).
///
/// **BAD:**
/// ```dart
/// FilePicker.platform.pickFiles(allowCompression: true);
/// FilePicker.platform.pickFiles(allowCompression: false);
/// ```
///
/// **GOOD:**
/// ```dart
/// FilePicker.platform.pickFiles(compressionQuality: 75);  // was true
/// FilePicker.platform.pickFiles(compressionQuality: 0);   // was false
/// ```
class FilePickerDeprecatedAllowCompressionRule extends SaropaLintRule {
  FilePickerDeprecatedAllowCompressionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'allowCompression'};

  static const LintCode _code = LintCode(
    'file_picker_deprecated_allow_compression',
    '[file_picker_deprecated_allow_compression] The allowCompression: named argument on FilePicker.pickFiles() / pickFile() was deprecated in file_picker v10 and replaced by compressionQuality: (an int 0–100). The boolean-literal migration is mechanical: allowCompression: true becomes compressionQuality: 75 (the documented default quality) and allowCompression: false becomes compressionQuality: 0 (no compression). A quick fix is available when the value is a boolean literal; when it is a non-literal expression the mapping must be done manually. {v1}',
    correctionMessage:
        'Replace allowCompression: true with compressionQuality: 75 and allowCompression: false with compressionQuality: 0.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _AllowCompressionToQualityFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (!_pickerMethods.contains(node.methodName.name)) return;
      if (!fileImportsPackage(node, PackageImports.filePicker)) return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression &&
            arg.name.label.name == 'allowCompression') {
          reporter.atNode(arg);
          return;
        }
      }
    });
  }
}

/// Quick fix: replace `allowCompression: <bool>` with the `compressionQuality:`
/// equivalent when the value is a boolean literal.
///
/// `allowCompression: true`  → `compressionQuality: 75` (documented default)
/// `allowCompression: false` → `compressionQuality: 0`  (disable compression)
///
/// The fix targets the whole NamedExpression so both the label and the value
/// are replaced in one atomic edit. When the value is not a boolean literal the
/// computeReplacement returns the original source unchanged, which means the
/// fix is silently skipped (ReplaceNodeFix contract).
class _AllowCompressionToQualityFix extends ReplaceNodeFix {
  _AllowCompressionToQualityFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.allowCompressionToQuality',
    80,
    'Replace allowCompression: with compressionQuality:',
  );

  @override
  String computeReplacement(AstNode node) {
    if (node is! NamedExpression) return node.toSource();
    final Expression value = node.expression;
    if (value is BooleanLiteral) {
      // true → quality 75 (the documented default equivalent)
      // false → quality 0  (disabled compression)
      final int quality = value.value ? 75 : 0;
      return 'compressionQuality: $quality';
    }
    // Non-literal value: return the original source unchanged so the fix
    // produces no diff and is not offered by the IDE.
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
      if (!_isLiteralTrue(_namedArgValue(node.argumentList, 'withData')))
        return;
      if (!_isLiteralTrue(_namedArgValue(node.argumentList, 'allowMultiple'))) {
        return;
      }

      reporter.atNode(node.methodName);
    });
  }
}
