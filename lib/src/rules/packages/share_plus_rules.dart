// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// share_plus package lint rules.
///
/// Covers the share_plus 11.x migration from the static `Share.*` API to the
/// instance-based `SharePlus.instance.share(ShareParams(...))` API, plus
/// correctness and best-practice rules for the new API.
///
/// Migration rule (version-gated, lives in the `share_plus_11` rule pack):
///   - `prefer_shareplus_instance` — rewrites static Share.share / shareUri /
///     shareXFiles calls to the new API with a mechanical quick fix.
///
/// Correctness rules (import-gated only, base `share_plus` pack):
///   - `share_plus_missing_position_origin` — ShareParams without
///     sharePositionOrigin (iPad crash risk).
///   - `share_plus_unchecked_result` — awaited share result discarded.
///   - `share_plus_empty_share_params` — all content fields statically absent.
///   - `share_plus_uri_and_text_conflict` — uri + text both non-null (runtime
///     ArgumentError).
library;

import 'package:analyzer/dart/ast/ast.dart';

import '../../fixes/common/replace_node_fix.dart';
import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// The import gate for all share_plus rules.
///
/// All rules in this file check this before proceeding to avoid false positives
/// on unrelated code that happens to use the same class/method names.
const Set<String> _sharePlusImport = PackageImports.sharePlus;

// =============================================================================
// prefer_shareplus_instance  (migration rule — version-gated, share_plus_11)
// =============================================================================

/// Flags uses of the deprecated static `Share.*` API and rewrites them to the
/// `SharePlus.instance.share(ShareParams(...))` form introduced in share_plus 11.
///
/// Since: (added with share_plus_11 pack) | Rule version: v1
///
/// share_plus 11.0.0 introduced the instance-based `SharePlus` API and
/// deprecated all static `Share.*` methods. Projects on share_plus ≥ 11 that
/// still call `Share.share`, `Share.shareUri`, or `Share.shareXFiles`
/// (`Share.shareFiles`) accumulate silent migration debt because the deprecated
/// methods still compile but will be removed in a future major.
///
/// **BAD:**
/// ```dart
/// Share.share('Hello world', subject: 'Greeting',
///     sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size);
/// Share.shareUri(Uri.parse('https://example.com'));
/// Share.shareXFiles([XFile(path)], text: 'caption');
/// ```
///
/// **GOOD:**
/// ```dart
/// SharePlus.instance.share(
///   ShareParams(text: 'Hello world', subject: 'Greeting',
///       sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size));
/// SharePlus.instance.share(ShareParams(uri: Uri.parse('https://example.com')));
/// SharePlus.instance.share(ShareParams(files: [XFile(path)], text: 'caption'));
/// ```
class PreferSharePlusInstanceRule extends SaropaLintRule {
  PreferSharePlusInstanceRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_shareplus_instance',
    '[prefer_shareplus_instance] The static Share.share / Share.shareUri / Share.shareXFiles / Share.shareFiles methods were deprecated in share_plus 11.0.0 in favor of the instance-based SharePlus.instance.share(ShareParams(...)). Deprecated static methods will be removed in a future major release. Migrate now to avoid a breaking change and gain access to the richer ShareParams API, including consistent sharePositionOrigin support on all platforms. {v1}',
    correctionMessage:
        'Replace Share.share(text, ...) with SharePlus.instance.share(ShareParams(text: text, ...)), Share.shareUri(uri) with SharePlus.instance.share(ShareParams(uri: uri)), and Share.shareXFiles(files, ...) with SharePlus.instance.share(ShareParams(files: files, ...)). Preserve all named arguments including sharePositionOrigin.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Static methods on `Share` that are deprecated in share_plus 11.
  static const Set<String> _deprecatedMethods = <String>{
    'share',
    'shareUri',
    'shareXFiles',
    'shareFiles',
  };

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _PreferSharePlusInstanceFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Scope to files importing share_plus to avoid false positives on
      // unrelated user-defined Share classes.
      if (!fileImportsPackage(node, _sharePlusImport)) return;

      final String methodName = node.methodName.name;
      if (!_deprecatedMethods.contains(methodName)) return;

      // The call must be on the `Share` identifier (static class call), not on
      // an instance (e.g. some field named share). Accept either a
      // SimpleIdentifier `Share` or a PrefixedIdentifier `pkg.Share`.
      final Expression? target = node.target;
      if (target == null) return;

      final bool isShareTarget = _isShareClassTarget(target);
      if (!isShareTarget) return;

      reporter.atNode(node);
    });
  }

  /// Returns true when [target] refers to the `Share` class (unresolved-safe).
  ///
  /// Handles both `Share.method(...)` (SimpleIdentifier) and the rare prefixed
  /// form `pkg.Share` (PrefixedIdentifier). Does NOT accept instance vars that
  /// happen to be named `share`.
  static bool _isShareClassTarget(Expression target) {
    if (target is SimpleIdentifier) {
      // `Share` alone — the common case.
      return target.name == 'Share';
    }
    if (target is PrefixedIdentifier) {
      // Handles `share_plus.Share` style if imported with a prefix.
      return target.identifier.name == 'Share';
    }
    return false;
  }
}

/// Quick fix for [PreferSharePlusInstanceRule].
///
/// Mechanically rewrites the whole `Share.xxx(...)` invocation to the new
/// `SharePlus.instance.share(ShareParams(...))` form:
///
///   - `Share.share(text, subject: s, sharePositionOrigin: r)` →
///     `SharePlus.instance.share(ShareParams(text: text, subject: s,
///         sharePositionOrigin: r))`
///   - `Share.shareUri(uri)` → `SharePlus.instance.share(ShareParams(uri: uri))`
///   - `Share.shareXFiles(files, text: t)` →
///     `SharePlus.instance.share(ShareParams(files: files, text: t))`
///   - `Share.shareFiles(files, ...)` → same as shareXFiles
///
/// The fix is suppressed (report-only) when the argument list contains a spread
/// element or an await expression — the rewriter cannot safely reorder
/// evaluation in those cases.
class _PreferSharePlusInstanceFix extends ReplaceNodeFix {
  _PreferSharePlusInstanceFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.preferSharePlusInstance',
    80,
    'Replace with SharePlus.instance.share(ShareParams(...))',
  );

  /// Navigate up from the covering node to the full MethodInvocation.
  @override
  AstNode? findTargetNode(AstNode node) {
    AstNode? current = node;
    while (current != null) {
      if (current is MethodInvocation) return current;
      current = current.parent;
    }
    return null;
  }

  @override
  String computeReplacement(AstNode node) {
    if (node is! MethodInvocation) return node.toSource();

    final String methodName = node.methodName.name;
    final NodeList<Expression> args = node.argumentList.arguments;

    // Suppress the fix when any argument uses a spread or await expression —
    // changing the call shape could alter evaluation order.
    for (final Expression arg in args) {
      final String src = arg.toSource();
      if (arg is SpreadElement) return node.toSource();
      // Detect await by source text since AwaitExpression is not directly
      // yielded as an argument AST node but can appear in a ParenthesizedExpr.
      if (src.trimLeft().startsWith('await ')) return node.toSource();
    }

    // Build the ShareParams argument list.
    final StringBuffer params = StringBuffer();

    if (methodName == 'share') {
      // Share.share(text, subject: s, sharePositionOrigin: r, ...)
      // First positional arg → ShareParams(text: <arg>)
      bool first = true;
      for (final Expression arg in args) {
        if (!first) params.write(', ');
        first = false;
        if (arg is NamedExpression) {
          // Named args (subject, sharePositionOrigin, etc.) pass through.
          params.write(arg.toSource());
        } else {
          // First positional arg → text parameter.
          params.write('text: ${arg.toSource()}');
        }
      }
    } else if (methodName == 'shareUri') {
      // Share.shareUri(uri) → ShareParams(uri: uri)
      // All other named args pass through.
      bool first = true;
      for (final Expression arg in args) {
        if (!first) params.write(', ');
        first = false;
        if (arg is NamedExpression) {
          params.write(arg.toSource());
        } else {
          params.write('uri: ${arg.toSource()}');
        }
      }
    } else {
      // shareXFiles / shareFiles: first positional → files, rest named.
      bool first = true;
      for (final Expression arg in args) {
        if (!first) params.write(', ');
        first = false;
        if (arg is NamedExpression) {
          params.write(arg.toSource());
        } else {
          params.write('files: ${arg.toSource()}');
        }
      }
    }

    return 'SharePlus.instance.share(ShareParams($params))';
  }
}

// =============================================================================
// share_plus_missing_position_origin  (correctness, base share_plus pack)
// =============================================================================

/// Flags `ShareParams(...)` construction without a `sharePositionOrigin` arg.
///
/// Since: (added with share_plus pack) | Rule version: v1
///
/// On iPad, the iOS share sheet is presented as a popover. Without a non-zero
/// `sharePositionOrigin: Rect`, UIKit cannot anchor it and throws a
/// `PlatformException`. The pub.dev README states: "Without it, share_plus will
/// not work on iPads and may cause a crash or leave the UI unresponsive."
///
/// On iOS 26+ (all devices), a zero-sized or absent `Rect` also triggers a
/// crash fixed at the package level in share_plus 12.0.1 for non-iPad, but the
/// iPad requirement is unconditional.
///
/// **BAD:**
/// ```dart
/// SharePlus.instance.share(ShareParams(text: 'Hello')); // no sharePositionOrigin
/// ```
///
/// **GOOD:**
/// ```dart
/// final RenderBox box = context.findRenderObject()! as RenderBox;
/// SharePlus.instance.share(ShareParams(
///   text: 'Hello',
///   sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
/// ));
/// ```
class SharePlusMissingPositionOriginRule extends SaropaLintRule {
  SharePlusMissingPositionOriginRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'share_plus_missing_position_origin',
    '[share_plus_missing_position_origin] ShareParams is constructed without a sharePositionOrigin argument. On iPad, the iOS share sheet is presented as a popover anchored to a Rect; without a non-zero sharePositionOrigin UIKit throws a PlatformException and the share sheet never appears. On iOS 26+ a missing or zero Rect also triggers a crash. Always pass sharePositionOrigin derived from RenderBox.localToGlobal(Offset.zero) & size to ensure safe cross-platform behavior. See https://pub.dev/packages/share_plus. {v1}',
    correctionMessage:
        'Add sharePositionOrigin: (context.findRenderObject()! as RenderBox).localToGlobal(Offset.zero) & (context.findRenderObject()! as RenderBox).size to ShareParams. Store the RenderBox in a local variable to avoid the double lookup.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!fileImportsPackage(node, _sharePlusImport)) return;

      // Match ShareParams constructor only.
      final String ctorName = node.constructorName.type.name.lexeme;
      if (ctorName != 'ShareParams') return;

      // Check for sharePositionOrigin named argument.
      final bool hasOrigin = node.argumentList.arguments.any(
        (arg) =>
            arg is NamedExpression &&
            arg.name.label.name == 'sharePositionOrigin',
      );

      if (!hasOrigin) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// share_plus_unchecked_result  (best-practice, base share_plus pack)
// =============================================================================

/// Flags `await SharePlus.instance.share(...)` where the `ShareResult` is
/// discarded (used as an expression statement).
///
/// Since: (added with share_plus pack) | Rule version: v1
///
/// `SharePlus.instance.share()` returns `Future<ShareResult>`. The
/// `ShareResultStatus` enum carries `success`, `dismissed`, and `unavailable`.
/// Apps that show "shared successfully" toasts or trigger analytics without
/// inspecting the result conflate `dismissed` and `success`, producing
/// misleading UX. `unavailable` is returned on platforms (Android, Windows)
/// that cannot identify the user's action — treating it as success silently
/// swallows unknown outcomes.
///
/// This rule flags `await ... share(...)` when the result is not captured.
/// It is distinct from the (removed) unawaited rule: that catches missing
/// `await`; this catches `await` present but result unused.
///
/// **BAD:**
/// ```dart
/// await SharePlus.instance.share(params); // result discarded
/// ```
///
/// **GOOD:**
/// ```dart
/// final result = await SharePlus.instance.share(params);
/// if (result.status == ShareResultStatus.success) { /* ... */ }
/// ```
class SharePlusUncheckedResultRule extends SaropaLintRule {
  SharePlusUncheckedResultRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'share_plus_unchecked_result',
    '[share_plus_unchecked_result] The result of await SharePlus.instance.share(...) is discarded. ShareResult.status carries ShareResultStatus.success, ShareResultStatus.dismissed, and ShareResultStatus.unavailable. Discarding it means the app cannot distinguish a successful share from a user cancellation or a platform that cannot report status. Apps that show a "shared" confirmation toast without checking status can mislead the user. Capture the result and inspect status before reacting. {v1}',
    correctionMessage:
        'Assign the result: final result = await SharePlus.instance.share(params); then inspect result.status before any post-share action.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addExpressionStatement((ExpressionStatement node) {
      if (!fileImportsPackage(node, _sharePlusImport)) return;

      // The expression statement must be an AwaitExpression whose operand is a
      // MethodInvocation targeting SharePlus.instance.share.
      final Expression expr = node.expression;
      if (expr is! AwaitExpression) return;

      final Expression operand = expr.expression;
      if (!_isSharePlusInstanceShareCall(operand)) return;

      reporter.atNode(node);
    });
  }

  /// Returns true when [expr] is a call to `SharePlus.instance.share(...)`.
  ///
  /// Checks syntactically (unresolved-AST-friendly) that:
  ///   - it is a MethodInvocation with method name `share`, and
  ///   - the target is a PropertyAccess `SharePlus.instance` (or an equivalent
  ///     MethodInvocation chain), or simply `instance` when SharePlus is used
  ///     without qualification.
  static bool _isSharePlusInstanceShareCall(Expression expr) {
    if (expr is! MethodInvocation) return false;
    if (expr.methodName.name != 'share') return false;

    final Expression? target = expr.target;
    if (target == null) return false;

    return _isSharePlusInstance(target);
  }

  /// Recognizes `SharePlus.instance` as a PropertyAccess or an identifier.
  static bool _isSharePlusInstance(Expression target) {
    if (target is PropertyAccess) {
      // SharePlus.instance → `SharePlus` is the target of the property access.
      if (target.propertyName.name != 'instance') return false;
      final Expression obj = target.target ?? target.realTarget;
      return obj is SimpleIdentifier && obj.name == 'SharePlus';
    }
    if (target is PrefixedIdentifier) {
      // Handles `SharePlus.instance` parsed as PrefixedIdentifier in some AST
      // contexts (e.g. inside argument lists without assignment).
      return target.prefix.name == 'SharePlus' &&
          target.identifier.name == 'instance';
    }
    return false;
  }
}

// =============================================================================
// share_plus_empty_share_params  (bug, base share_plus pack)
// =============================================================================

/// Flags `ShareParams(...)` where all content fields are statically absent,
/// null, or empty-literal — a guaranteed runtime `ArgumentError`.
///
/// Since: (added with share_plus pack) | Rule version: v1
///
/// `SharePlus.instance.share()` enforces at runtime:
///   - at least one of `text`, `files`, or `uri` must be provided,
///   - `text` cannot be empty if provided,
///   - `files` cannot be empty if provided.
/// Violations throw `ArgumentError` synchronously. When ALL three content
/// fields are statically absent, `null`, or empty literal the lint catches the
/// guaranteed throw at analysis time.
///
/// **BAD:**
/// ```dart
/// ShareParams()                        // all absent
/// ShareParams(text: '')                // empty text, files/uri absent
/// ShareParams(text: null, uri: null)   // explicit nulls
/// ```
///
/// **GOOD:**
/// ```dart
/// ShareParams(text: 'Hello world')
/// ShareParams(files: [XFile(path)])
/// ShareParams(uri: Uri.parse('https://example.com'))
/// // dynamic value — runtime determines emptiness; rule stays silent:
/// ShareParams(text: someVar)
/// ```
class SharePlusEmptyShareParamsRule extends SaropaLintRule {
  SharePlusEmptyShareParamsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'share_plus_empty_share_params',
    '[share_plus_empty_share_params] ShareParams is constructed with no content: text, files, and uri are all statically absent, null, or empty literals. SharePlus.instance.share() enforces at runtime that at least one content field is non-empty, throwing ArgumentError immediately if this constraint is violated. This construction is a guaranteed runtime crash detectable at analysis time. Provide at least one non-empty text, a non-empty files list, or a non-null uri. {v1}',
    correctionMessage:
        'Provide at least one content field: ShareParams(text: someText), ShareParams(files: [XFile(path)]), or ShareParams(uri: someUri). Ensure the value is non-null and non-empty at runtime.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!fileImportsPackage(node, _sharePlusImport)) return;

      final String ctorName = node.constructorName.type.name.lexeme;
      if (ctorName != 'ShareParams') return;

      final NodeList<Expression> args = node.argumentList.arguments;

      // Evaluate the three content fields independently.
      // A field is "statically empty" when it is absent, a NullLiteral, an
      // empty StringLiteral, or an empty ListLiteral. Any other expression
      // (variable, conditional, non-empty literal) defeats the rule.
      final bool textEmpty = _fieldIsStaticallyEmpty(args, 'text');
      final bool filesEmpty = _fieldIsStaticallyEmpty(args, 'files');
      final bool uriEmpty = _fieldIsStaticallyEmpty(args, 'uri');

      if (textEmpty && filesEmpty && uriEmpty) {
        reporter.atNode(node);
      }
    });
  }

  /// Returns true when the named argument [fieldName] is absent, null, or an
  /// empty literal value, meaning it carries no content at analysis time.
  ///
  /// Returns false (rule stays silent) if the argument is any non-trivially
  /// empty expression — a variable, method call, conditional, or non-empty
  /// literal — because the runtime value is unknown.
  static bool _fieldIsStaticallyEmpty(
    NodeList<Expression> args,
    String fieldName,
  ) {
    // Find the named argument by label.
    for (final Expression arg in args) {
      if (arg is! NamedExpression) continue;
      if (arg.name.label.name != fieldName) continue;

      final Expression value = arg.expression;

      // Explicit null literal → empty.
      if (value is NullLiteral) return true;

      // Empty string literal → empty (text: '').
      if (fieldName == 'text') {
        if (value is SimpleStringLiteral && value.value.isEmpty) return true;
        if (value is AdjacentStrings) {
          // Adjacent string literals with all-empty segments → empty.
          final bool allEmpty = value.strings.every(
            (s) => s is SimpleStringLiteral && s.value.isEmpty,
          );
          if (allEmpty) return true;
        }
        // Any other expression: value unknown — NOT empty.
        return false;
      }

      // Empty list literal → empty (files: []).
      if (fieldName == 'files') {
        if (value is ListLiteral && value.elements.isEmpty) return true;
        return false;
      }

      // uri: null handled above; any other uri expression is non-null.
      return false;
    }

    // Argument absent entirely → the field has no value.
    return true;
  }
}

// =============================================================================
// share_plus_uri_and_text_conflict  (bug, base share_plus pack)
// =============================================================================

/// Flags `ShareParams(uri: x, text: y)` where both `uri` and `text` are
/// statically non-null — a guaranteed runtime `ArgumentError`.
///
/// Since: (added with share_plus pack) | Rule version: v1
///
/// `ShareParams` enforces at runtime: "uri and text cannot be provided at the
/// same time." Passing both throws `ArgumentError` synchronously. This
/// constraint cannot be expressed in Dart's type system but IS statically
/// detectable when both are provably non-null at the call site.
///
/// The rule restricts detection to literal or non-nullable-typed operands to
/// avoid false positives on nullable-typed variables guarded by `!= null`
/// upstream (the static type stays `String?` / `Uri?`, but the field IS null at
/// most call sites). This makes the rule near-literal-only but keeps FPs near
/// zero — the trade-off is documented in `plans/plan_migration_share_plus.md`.
///
/// **BAD:**
/// ```dart
/// ShareParams(uri: Uri.parse('https://example.com'), text: 'Check this out')
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use one OR the other, not both:
/// ShareParams(text: 'Check this out')
/// ShareParams(uri: Uri.parse('https://example.com'))
/// ```
class SharePlusUriAndTextConflictRule extends SaropaLintRule {
  SharePlusUriAndTextConflictRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.error;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'share_plus_uri_and_text_conflict',
    '[share_plus_uri_and_text_conflict] ShareParams is constructed with both uri and text set to provably non-null values. share_plus enforces at runtime that uri and text cannot be provided simultaneously, throwing ArgumentError immediately. This is a guaranteed runtime crash when both fields are statically non-null at the call site. Remove either uri or text from the ShareParams constructor. {v1}',
    correctionMessage:
        'Provide either uri or text, not both. If you need to share a URL with a subject line, use ShareParams(uri: theUri, subject: theSubject) and omit text.',
    severity: DiagnosticSeverity.ERROR,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (!fileImportsPackage(node, _sharePlusImport)) return;

      final String ctorName = node.constructorName.type.name.lexeme;
      if (ctorName != 'ShareParams') return;

      final NodeList<Expression> args = node.argumentList.arguments;

      final bool uriProvided = _fieldIsProvablyNonNull(args, 'uri');
      final bool textProvided = _fieldIsProvablyNonNull(args, 'text');

      if (uriProvided && textProvided) {
        reporter.atNode(node);
      }
    });
  }

  /// Returns true when [fieldName] is present in [args] and its expression is
  /// provably non-null: a non-null literal, a non-nullable-typed expression, or
  /// a constructor call (which can never be null).
  ///
  /// Returns false for absent, NullLiteral, and nullable-typed expressions.
  static bool _fieldIsProvablyNonNull(
    NodeList<Expression> args,
    String fieldName,
  ) {
    for (final Expression arg in args) {
      if (arg is! NamedExpression) continue;
      if (arg.name.label.name != fieldName) continue;

      final Expression value = arg.expression;

      // Explicit null → not non-null.
      if (value is NullLiteral) return false;

      // Non-empty string literal → provably non-null.
      if (fieldName == 'text' &&
          value is SimpleStringLiteral &&
          value.value.isNotEmpty) {
        return true;
      }

      // Constructor call (e.g. Uri.parse(...), Uri.https(...)) → provably
      // non-null.
      if (value is MethodInvocation &&
          (value.methodName.name == 'parse' ||
              value.methodName.name == 'https' ||
              value.methodName.name == 'http')) {
        // Only flag when the receiver looks like `Uri` to avoid matching
        // unrelated .parse() calls.
        final Expression? target = value.target;
        if (target is SimpleIdentifier && target.name == 'Uri') return true;
      }
      if (value is InstanceCreationExpression) return true;

      // For variables: check non-nullable static type.
      // NullabilitySuffix.none = non-nullable (String, Uri, etc.).
      // NullabilitySuffix.question = nullable (String?, Uri?).
      final dartType = value.staticType;
      if (dartType != null) {
        // ignore: deprecated_member_use
        final suffix = dartType.nullabilitySuffix;
        // NullabilitySuffix.none means the type is non-nullable.
        if (suffix.name == 'none') return true;
      }

      // Unknown expression — be conservative, don't flag.
      return false;
    }

    // Field absent.
    return false;
  }
}
