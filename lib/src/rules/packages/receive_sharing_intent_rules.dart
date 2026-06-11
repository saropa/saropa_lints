// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// receive_sharing_intent package lint rules.
///
/// These rules cover three common error patterns when using the
/// receive_sharing_intent package:
///
///   - Cold-start share events silently dropped because `getInitialMedia()` is
///     never called in a file that subscribes to `getMediaStream()`.
///   - Stale-intent re-delivery on resume because `reset()` is never called
///     anywhere in the class that calls `getInitialMedia()`.
///   - Unfiltered shared-media callbacks that access `SharedMediaFile` fields
///     without ever checking `SharedMediaType`, risking silent type mismatches.
///
/// Dropped rules (overlap with existing coverage):
///   - `rsi_stream_subscription_not_canceled` — subsumed by
///     `require_timer_cancellation` / `avoid_undisposed_instances` /
///     `avoid_stream_subscription_in_field`.
///   - `rsi_unchecked_shared_media_list` — subsumed by
///     `avoid_unsafe_collection_methods` / `prefer_list_first`.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

// =============================================================================
// Internal helpers
// =============================================================================

/// SharedMediaFile payload fields whose unguarded use the unfiltered-type rule
/// detects. These are fields callers read to process the shared content — using
/// them without first checking `.type` (SharedMediaType) risks a silent type
/// mismatch (e.g. passing a video path to an image decoder).
const Set<String> _mediaFileFields = <String>{
  'path',
  'thumbnail',
  'duration',
  'mimeType',
};

/// Collects method invocations by name across a subtree.
///
/// Used by the file-level rule (`rsi_missing_initial_media`) and the
/// class-body scan in `rsi_missing_reset_after_initial_media`.
class _MethodNameCollector extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> getMediaStreamCalls = <MethodInvocation>[];
  final List<MethodInvocation> getInitialMediaCalls = <MethodInvocation>[];
  final List<MethodInvocation> resetCalls = <MethodInvocation>[];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    switch (node.methodName.name) {
      case 'getMediaStream':
        getMediaStreamCalls.add(node);
      case 'getInitialMedia':
        getInitialMediaCalls.add(node);
      case 'reset':
        resetCalls.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// Scans a callback body for SharedMediaFile field accesses and any reference
/// to the `SharedMediaType` identifier.
///
/// Fields tracked: `.path`, `.thumbnail`, `.duration`, `.mimeType`.
/// These are the payload fields whose use without a type guard the
/// `rsi_unfiltered_shared_media_type` rule flags.
class _CallbackBodyScanner extends RecursiveAstVisitor<void> {
  /// True when the body reads at least one SharedMediaFile payload field.
  bool accessesMediaFileFields = false;

  /// True when the body contains any reference to the `SharedMediaType`
  /// identifier (e.g. `SharedMediaType.image`, `file.type == SharedMediaType.video`).
  bool referencesSharedMediaType = false;

  @override
  void visitPropertyAccess(PropertyAccess node) {
    // Matches `file.path`, `item.thumbnail`, etc. in chained property access.
    if (_mediaFileFields.contains(node.propertyName.name)) {
      accessesMediaFileFields = true;
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    // Matches simple `file.path` reads the analyzer resolves as
    // PrefixedIdentifier, and `SharedMediaType.image` / `.video` etc.
    if (_mediaFileFields.contains(node.identifier.name)) {
      accessesMediaFileFields = true;
    }
    if (node.prefix.name == 'SharedMediaType') {
      referencesSharedMediaType = true;
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    // Catches a bare `SharedMediaType` reference (e.g. in a switch pattern or
    // `is SharedMediaType` type test).
    if (node.name == 'SharedMediaType') {
      referencesSharedMediaType = true;
    }
    super.visitSimpleIdentifier(node);
  }
}

// =============================================================================
// rsi_missing_initial_media
// =============================================================================

/// Flags a file that calls `getMediaStream()` but never calls
/// `getInitialMedia()`.
///
/// Since: v4.17.0 | Rule version: v1
///
/// `getMediaStream()` handles warm-starts (app already in memory) while
/// `getInitialMedia()` handles cold-starts (app launched *because* of the
/// share). An implementation that only subscribes to `getMediaStream()` silently
/// drops every cold-start share — the user shares a file, the app opens fresh,
/// and nothing is processed. Both paths must be wired in the same file.
///
/// **Known false-positive class:** architectures that split warm-share and
/// cold-start across two different files will trigger this rule on the file that
/// only wires `getMediaStream()`. Use `// ignore: rsi_missing_initial_media`
/// with a comment naming the companion file that handles cold-starts.
///
/// **BAD:**
/// ```dart
/// import 'package:receive_sharing_intent/receive_sharing_intent.dart';
///
/// void initStreams() {
///   ReceiveSharingIntent.instance.getMediaStream().listen(_handleMedia);
///   // getInitialMedia() never called — cold-start shares silently dropped
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// import 'package:receive_sharing_intent/receive_sharing_intent.dart';
///
/// void initStreams() {
///   ReceiveSharingIntent.instance.getMediaStream().listen(_handleMedia);
///   ReceiveSharingIntent.instance.getInitialMedia().then(_handleMedia);
/// }
/// ```
class ReceiveSharingIntentMissingInitialMediaRule extends SaropaLintRule {
  ReceiveSharingIntentMissingInitialMediaRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'getMediaStream'};

  static const LintCode _code = LintCode(
    'rsi_missing_initial_media',
    '[rsi_missing_initial_media] This file calls getMediaStream() but never calls getInitialMedia(). '
        'receive_sharing_intent delivers intents via two paths: getMediaStream() for warm-starts '
        '(app already in memory) and getInitialMedia() for cold-starts (app launched via the share). '
        'Subscribing only to getMediaStream() silently drops every cold-start share — the user shares '
        'a file, the app opens fresh, and nothing is processed. Wire both paths in the same file. {v1}',
    correctionMessage:
        'Add a getInitialMedia().then(...) (or await getInitialMedia()) call alongside '
        'getMediaStream().listen(...) to handle files shared when the app is not already running.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // File-level check: collect ALL method invocations across the compilation
    // unit in a single pass, then decide once per file whether to report.
    context.addCompilationUnit((CompilationUnit unit) {
      // Import guard — only applies to files that import receive_sharing_intent.
      // fileImportsPackage requires an AstNode; the beginToken's parent is the
      // unit itself, so pass the unit directly.
      if (!fileImportsPackage(unit, PackageImports.receiveSharingIntent)) {
        return;
      }

      final _MethodNameCollector collector = _MethodNameCollector();
      unit.accept(collector);

      // No getMediaStream calls — nothing to report.
      if (collector.getMediaStreamCalls.isEmpty) return;

      // Both paths wired — compliant.
      if (collector.getInitialMediaCalls.isNotEmpty) return;

      // Report at the first getMediaStream call site so the diagnostic lands on
      // the call that is "missing its partner" rather than on the file header.
      reporter.atNode(collector.getMediaStreamCalls.first.methodName);
    });
  }
}

// =============================================================================
// rsi_missing_reset_after_initial_media
// =============================================================================

/// Flags a class that calls `getInitialMedia()` but never calls `reset()`
/// anywhere in its body.
///
/// Since: v4.17.0 | Rule version: v1
///
/// The native layer (Android and iOS) caches the initial share intent until
/// `reset()` is invoked. Without it, every subsequent app resume re-delivers the
/// same shared file — the user sees the share handler open again on the next
/// launch even after they already processed the file. The official README
/// example calls `ReceiveSharingIntent.instance.reset()` inside the `.then()`
/// callback of `getInitialMedia()`.
///
/// The check is scoped to the enclosing class declaration in the current
/// compilation unit. A `reset()` call in a base class not visible here will
/// produce a false positive; use `// ignore: rsi_missing_reset_after_initial_media`
/// with a comment naming the base class.
///
/// **BAD:**
/// ```dart
/// class _ShareHandlerState extends State<ShareHandler> {
///   void initState() {
///     ReceiveSharingIntent.instance.getInitialMedia().then((files) {
///       _process(files);
///       // reset() never called — stale intent re-delivered on next resume
///     });
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _ShareHandlerState extends State<ShareHandler> {
///   void initState() {
///     ReceiveSharingIntent.instance.getInitialMedia().then((files) {
///       _process(files);
///       ReceiveSharingIntent.instance.reset();
///     });
///   }
/// }
/// ```
class ReceiveSharingIntentMissingResetRule extends SaropaLintRule {
  ReceiveSharingIntentMissingResetRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'getInitialMedia'};

  static const LintCode _code = LintCode(
    'rsi_missing_reset_after_initial_media',
    '[rsi_missing_reset_after_initial_media] getInitialMedia() is called but reset() is never called '
        'anywhere in the enclosing class. The native layer (Android and iOS) caches the initial share '
        'intent until reset() is invoked. Without it, every subsequent app resume re-delivers the same '
        'shared file — the user sees the share handler open again on the next launch even after processing. '
        'Call ReceiveSharingIntent.instance.reset() after consuming the result of getInitialMedia(). {v1}',
    correctionMessage:
        'Add ReceiveSharingIntent.instance.reset() inside the getInitialMedia().then(...) callback '
        '(or after the await) once the shared data has been consumed.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Scan at the class level: for every class declaration that contains a
    // getInitialMedia() call, check whether reset() is also called anywhere
    // in that class. Report at each getInitialMedia() call that lacks a reset().
    context.addClassDeclaration((ClassDeclaration node) {
      if (!fileImportsPackage(node, PackageImports.receiveSharingIntent)) {
        return;
      }

      final _MethodNameCollector collector = _MethodNameCollector();
      node.accept(collector);

      // No getInitialMedia calls in this class — nothing to check.
      if (collector.getInitialMediaCalls.isEmpty) return;

      // reset() found somewhere in this class — compliant.
      if (collector.resetCalls.isNotEmpty) return;

      // Report at each getInitialMedia() call site — there is typically only
      // one, but report all so no call site is silently missed.
      for (final MethodInvocation call in collector.getInitialMediaCalls) {
        reporter.atNode(call.methodName);
      }
    });
  }
}

// =============================================================================
// rsi_unfiltered_shared_media_type
// =============================================================================

/// Flags a `.listen()` or `.then()` callback on `getMediaStream()` /
/// `getInitialMedia()` that accesses `SharedMediaFile` fields but never
/// references `SharedMediaType`.
///
/// Since: v4.17.0 | Rule version: v1
///
/// The Android intent filter can match multiple MIME types (image/*, video/*,
/// */*). A callback that blindly accesses `.path` without checking `.type`
/// against `SharedMediaType` values risks passing a video or text item to an
/// image decoder, causing silent type errors or crashes. Checking the type
/// before processing is a best practice that prevents these failures.
///
/// **Known false-positive class:** a helper method called from within the
/// callback performs the type filtering — the helper body is not visible from
/// the call-site AST. Use `// ignore: rsi_unfiltered_shared_media_type` with a
/// comment naming the helper.
///
/// **BAD:**
/// ```dart
/// ReceiveSharingIntent.instance.getMediaStream().listen((files) {
///   for (final file in files) {
///     processImage(file.path); // path used, SharedMediaType never checked
///   }
/// });
/// ```
///
/// **GOOD:**
/// ```dart
/// ReceiveSharingIntent.instance.getMediaStream().listen((files) {
///   for (final file in files) {
///     if (file.type == SharedMediaType.image) {
///       processImage(file.path);
///     }
///   }
/// });
/// ```
class ReceiveSharingIntentUnfilteredTypeRule extends SaropaLintRule {
  ReceiveSharingIntentUnfilteredTypeRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{
    'getMediaStream',
    'getInitialMedia',
  };

  static const LintCode _code = LintCode(
    'rsi_unfiltered_shared_media_type',
    '[rsi_unfiltered_shared_media_type] A listen() or then() callback on getMediaStream() / getInitialMedia() '
        'accesses SharedMediaFile fields (.path, .thumbnail, .duration, or .mimeType) without any reference to '
        'SharedMediaType. The Android intent filter can match multiple MIME types (image/*, video/*, */*). '
        'Processing all shared files identically — e.g. passing a video path to an image decoder — causes '
        'silent type errors or crashes at runtime. Check file.type against SharedMediaType values before '
        'processing each file. {v1}',
    correctionMessage:
        'Add a type guard such as (file.type == SharedMediaType.image) before accessing path or other '
        'SharedMediaFile fields so that each MIME type is handled appropriately.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      // Match .listen(...) and .then(...) calls whose receiver is a
      // getMediaStream() or getInitialMedia() call — syntactic name check only.
      // The import guard already confirms the package is in scope, so resolving
      // types is not required.
      final String calledMethod = node.methodName.name;
      if (calledMethod != 'listen' && calledMethod != 'then') return;
      if (!fileImportsPackage(node, PackageImports.receiveSharingIntent))
        return;

      // Verify the immediate receiver is getMediaStream() or getInitialMedia().
      if (!_isRsiDataCall(node.realTarget)) return;

      // Extract the first argument that is an inline function expression
      // (the callback). Named parameters (e.g. onError:) are skipped.
      final FunctionExpression? callback = _firstCallbackArg(node);
      if (callback == null) return;

      final _CallbackBodyScanner scanner = _CallbackBodyScanner();
      callback.body.accept(scanner);

      // Only report when SharedMediaFile fields are accessed but SharedMediaType
      // is never referenced. Accessing neither means the callback ignores file
      // contents entirely — that is outside this rule's concern.
      if (!scanner.accessesMediaFileFields) return;
      if (scanner.referencesSharedMediaType) return;

      reporter.atNode(callback);
    });
  }

  /// True when [expr] is a `getMediaStream()` or `getInitialMedia()` call
  /// (syntactic method-name check only).
  bool _isRsiDataCall(Expression? expr) {
    if (expr is! MethodInvocation) return false;
    final String name = expr.methodName.name;
    return name == 'getMediaStream' || name == 'getInitialMedia';
  }

  /// Returns the first positional or named argument of [node] that is a
  /// [FunctionExpression] (inline callback), or null when none exists.
  FunctionExpression? _firstCallbackArg(MethodInvocation node) {
    for (final Expression arg in node.argumentList.arguments) {
      final Expression value = arg is NamedExpression ? arg.expression : arg;
      if (value is FunctionExpression) return value;
    }
    return null;
  }
}
