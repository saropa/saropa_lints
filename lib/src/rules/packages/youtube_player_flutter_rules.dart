// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// youtube_player_flutter package lint rules (v10+ iframe rewrite).
///
/// v10.0.0 was an architectural rewrite: the engine moved to webview_flutter and
/// `YoutubePlayerController` is re-exported from `youtube_player_iframe`. These
/// rules cover the v10-specific footguns that no generic rule catches:
/// - the controller's resource method is `close()` (NOT `dispose()`), so the
///   generic `avoid_undisposed_instances` (its fixed disposable-type set excludes
///   `YoutubePlayerController` and it looks for `dispose()`) does not catch a
///   leaked controller — `youtube_player_controller_not_closed` does;
/// - `convertUrlToId` returns a nullable `String?` and is routinely used unchecked;
/// - `YoutubePlayerScaffold` is deprecated and no longer required;
/// - autoplay-with-sound is blocked by browser policy when `mute` is false;
/// - `autoFullScreen` can leave the device stuck in landscape (pedantic, high FP).
///
/// NOTE: `youtube_player_subscription_not_canceled` was intentionally NOT
/// implemented — the StreamSubscription family already covers it
/// (`avoid_stream_subscription_in_field`, `require_timer_cancellation`,
/// `avoid_undisposed_instances`).
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// The controller type whose `close()` is the v10 cleanup method.
const String _controllerType = 'YoutubePlayerController';

Expression? _namedArg(ArgumentList args, String name) {
  for (final Expression arg in args.arguments) {
    if (arg is NamedExpression && arg.name.label.name == name) {
      return arg.expression;
    }
  }
  return null;
}

/// Nearest enclosing class declaration, or null when [node] is top-level.
ClassDeclaration? _enclosingClass(AstNode node) =>
    node.thisOrAncestorOfType<ClassDeclaration>();

/// The `dispose` (or `close`) lifecycle override body in [cls], if any.
FunctionBody? _disposeBody(ClassDeclaration cls) {
  for (final ClassMember member in cls.bodyMembers) {
    if (member is MethodDeclaration) {
      final String name = member.name.lexeme;
      if (name == 'dispose' || name == 'close') return member.body;
    }
  }
  return null;
}

/// True when [body] invokes `<receiver>.<method>()` for any method in [methods].
bool _bodyCallsMethodOn(
  FunctionBody body,
  String receiver,
  Set<String> methods,
) {
  final _MethodCallScan scan = _MethodCallScan(receiver, methods);
  body.accept(scan);
  return scan.matched;
}

class _MethodCallScan extends RecursiveAstVisitor<void> {
  _MethodCallScan(this.receiver, this.methods);
  final String receiver;
  final Set<String> methods;
  bool matched = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final Expression? target = node.target;
    if (target is SimpleIdentifier &&
        target.name == receiver &&
        methods.contains(node.methodName.name)) {
      matched = true;
    }
    super.visitMethodInvocation(node);
  }
}

/// True when [root] references any identifier in [names].
bool _referencesIdentifier(AstNode root, Set<String> names) {
  final _IdScan scan = _IdScan(names);
  root.accept(scan);
  return scan.found;
}

class _IdScan extends GeneralizingAstVisitor<void> {
  _IdScan(this.names);
  final Set<String> names;
  bool found = false;

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (names.contains(node.name)) found = true;
    super.visitSimpleIdentifier(node);
  }
}

bool _isTestFilePath(String path) {
  final String normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('_test.dart') || normalized.contains('/test/');
}

// =============================================================================
// youtube_player_controller_not_closed
// =============================================================================

/// Flags a `YoutubePlayerController` field never `close()`d in dispose().
///
/// Since: v4.16.0 | Rule version: v1
///
/// In v10 the controller's resource-cleanup method is `close()` (a `Future<void>`),
/// NOT `dispose()`: it stops playback, removes the JS channel, and closes the
/// internal stream controllers. A controller stored as a `State`/`ChangeNotifier`
/// field and never `close()`d leaks the underlying `webview_flutter`
/// WebViewController and every open stream controller. The generic
/// `avoid_undisposed_instances` rule does not catch this — its disposable-type set
/// excludes `YoutubePlayerController` and it looks for `dispose()`, not `close()`.
///
/// **BAD:**
/// ```dart
/// class _S extends State<P> {
///   final controller = YoutubePlayerController(); // never closed
///   @override void dispose() { super.dispose(); }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _S extends State<P> {
///   final controller = YoutubePlayerController();
///   @override void dispose() { controller.close(); super.dispose(); }
/// }
/// ```
class YoutubePlayerControllerNotClosedRule extends SaropaLintRule {
  YoutubePlayerControllerNotClosedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{_controllerType};

  static const LintCode _code = LintCode(
    'youtube_player_controller_not_closed',
    '[youtube_player_controller_not_closed] A YoutubePlayerController is stored as a class field but the enclosing class never calls close() on it. In youtube_player_flutter v10 the controller cleanup method is close() (NOT dispose()): it stops playback, removes the webview JS channel, and closes the internal stream controllers. Without it the underlying webview_flutter controller and every open stream controller leak for the lifetime of the parent object. The generic undisposed-instance rule misses this because the controller uses close(), not dispose(). {v1}',
    correctionMessage:
        'Call controller.close() in the enclosing State/ChangeNotifier dispose() (or ref.onDispose).',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    if (_isTestFilePath(context.filePath)) return;

    context.addFieldDeclaration((FieldDeclaration node) {
      if (!fileImportsPackage(node, PackageImports.youtubePlayerFlutter))
        return;

      // Only the controller type is relevant; check the declared type, and fall
      // back to the initializer constructor name when the field is `final foo = ...`.
      if (!_declaresControllerField(node)) return;

      final ClassDeclaration? cls = _enclosingClass(node);
      if (cls == null) return;
      final FunctionBody? disposeBody = _disposeBody(cls);

      // Collect every controller field name so one dispose() can close several.
      for (final VariableDeclaration v in node.fields.variables) {
        final String fieldName = v.name.lexeme;
        final bool closed =
            disposeBody != null &&
            _bodyCallsMethodOn(disposeBody, fieldName, const <String>{'close'});
        if (!closed) reporter.atNode(v);
      }
    });
  }

  /// True when the field's annotated type is `YoutubePlayerController`, or (when
  /// untyped) its initializer constructs one directly.
  bool _declaresControllerField(FieldDeclaration node) {
    final TypeAnnotation? declared = node.fields.type;
    if (declared is NamedType && declared.name.lexeme == _controllerType) {
      return true;
    }
    for (final VariableDeclaration v in node.fields.variables) {
      final Expression? init = v.initializer;
      if (init is InstanceCreationExpression &&
          init.constructorName.type.name.lexeme == _controllerType) {
        return true;
      }
    }
    return false;
  }
}

// =============================================================================
// youtube_player_convert_url_unchecked
// =============================================================================

/// Flags `YoutubePlayerController.convertUrlToId(...)` used without a null check.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `convertUrlToId(String url)` returns `String?` — null when the input matches no
/// known YouTube URL pattern. Using the result directly (a non-null context, a
/// bare `!`, or passing it straight into another expression) either crashes with a
/// null-check error or feeds `null` as a video id and silently breaks the player.
/// Only the same-expression direct-use form is flagged: an intermediate `String?`
/// variable means the developer acknowledged the nullability.
///
/// **BAD:**
/// ```dart
/// final id = YoutubePlayerController.convertUrlToId(url)!;
/// ```
///
/// **GOOD:**
/// ```dart
/// final id = YoutubePlayerController.convertUrlToId(url);
/// if (id == null) return;
/// ```
class YoutubePlayerConvertUrlUncheckedRule extends SaropaLintRule {
  YoutubePlayerConvertUrlUncheckedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'convertUrlToId'};

  static const LintCode _code = LintCode(
    'youtube_player_convert_url_unchecked',
    '[youtube_player_convert_url_unchecked] The result of YoutubePlayerController.convertUrlToId(...) is used without handling null. convertUrlToId returns String? and yields null whenever the input does not match a known YouTube URL pattern (watch links, youtu.be short links, embed URLs). Force-unwrapping with ! crashes on a non-YouTube string, and passing the raw result onward feeds a null video id that silently fails the player. Assign to a String? and null-check it, or use ?? / ?. instead. {v1}',
    correctionMessage:
        'Assign the result to a String? and guard with if (id == null) return; (or use ?? / ?. instead of !).',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'convertUrlToId') return;
      // Static call: receiver is the controller type name.
      final Expression? target = node.target;
      if (target is! SimpleIdentifier || target.name != _controllerType) return;
      if (!fileImportsPackage(node, PackageImports.youtubePlayerFlutter))
        return;

      final AstNode? parent = node.parent;

      // Acknowledged: stored into a variable (the developer can null-check it
      // downstream; we only flag direct same-expression misuse to stay FP-free).
      if (parent is VariableDeclaration) return;
      // Acknowledged: ?? fallback or ?. chaining handles the null.
      if (parent is BinaryExpression &&
          parent.operator.lexeme == '??' &&
          parent.leftOperand == node) {
        return;
      }

      // Unsafe: force-unwrapped, or passed directly into an argument / non-null
      // context without any null handling.
      final bool forceUnwrapped =
          parent is PostfixExpression && parent.operator.lexeme == '!';
      final bool passedAsArgument = parent is ArgumentList;
      if (forceUnwrapped || passedAsArgument) {
        reporter.atNode(node);
      }
    });
  }
}

// =============================================================================
// youtube_player_scaffold_deprecated
// =============================================================================

/// Flags construction of the deprecated `YoutubePlayerScaffold` (v10).
///
/// Since: v4.16.0 | Rule version: v1
///
/// `YoutubePlayerScaffold` was deprecated in v10.0.0; `YoutubePlayer` now handles
/// fullscreen internally via `OverlayPortal`, so no scaffold wrapper is required.
/// Wrapping with it adds unnecessary widget-tree depth and a deprecation warning.
/// Report-only (the builder-callback restructuring cannot be mechanically rewritten).
///
/// **BAD:**
/// ```dart
/// YoutubePlayerScaffold(controller: c, builder: (_, p) => p);
/// ```
///
/// **GOOD:**
/// ```dart
/// Scaffold(body: YoutubePlayer(controller: c));
/// ```
class YoutubePlayerScaffoldDeprecatedRule extends SaropaLintRule {
  YoutubePlayerScaffoldDeprecatedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'YoutubePlayerScaffold'};

  static const LintCode _code = LintCode(
    'youtube_player_scaffold_deprecated',
    '[youtube_player_scaffold_deprecated] YoutubePlayerScaffold is constructed, but it was deprecated in youtube_player_flutter v10.0.0. In v10 the YoutubePlayer widget manages fullscreen internally through OverlayPortal, so the scaffold wrapper is no longer required; keeping it adds an extra layer of widget-tree depth and emits a deprecation warning. Use YoutubePlayer inside a standard Scaffold, wrapping with YoutubePlayerControllerProvider only if controller context propagation is needed. {v1}',
    correctionMessage:
        'Remove YoutubePlayerScaffold and place YoutubePlayer inside a standard Scaffold instead.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.constructorName.type.name.lexeme != 'YoutubePlayerScaffold') {
        return;
      }
      if (!fileImportsPackage(node, PackageImports.youtubePlayerFlutter))
        return;
      reporter.atNode(node.constructorName);
    });
  }
}

// =============================================================================
// youtube_player_mute_not_respected_in_params
// =============================================================================

/// Flags `fromVideoId(autoPlay: true)` with inline `YoutubePlayerParams(mute: false)`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// Browser autoplay policy (enforced on web and increasingly in iOS WebView) blocks
/// playback with audio when autoplay fires without a user gesture. Constructing
/// `YoutubePlayerController.fromVideoId(autoPlay: true)` with
/// `YoutubePlayerParams(mute: false)` (the default) produces a player that fails to
/// autoplay or shows a policy-blocked error. The safe pairing is autoplay + mute.
/// Detection stays inline-only (the `params:` object built in the same expression)
/// to keep the false-positive rate at zero.
///
/// **BAD:**
/// ```dart
/// YoutubePlayerController.fromVideoId(
///   videoId: id, autoPlay: true, params: YoutubePlayerParams(mute: false));
/// ```
///
/// **GOOD:**
/// ```dart
/// YoutubePlayerController.fromVideoId(
///   videoId: id, autoPlay: true, params: YoutubePlayerParams(mute: true));
/// ```
class YoutubePlayerMuteNotRespectedInParamsRule extends SaropaLintRule {
  YoutubePlayerMuteNotRespectedInParamsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'autoPlay'};

  static const LintCode _code = LintCode(
    'youtube_player_mute_not_respected_in_params',
    '[youtube_player_mute_not_respected_in_params] YoutubePlayerController.fromVideoId is called with autoPlay: true while the inline YoutubePlayerParams has mute: false (or omits mute, whose default is false). Browser autoplay policy on web, and increasingly iOS WebView, blocks unmuted autoplay that lacks a user gesture, so the player either fails to start or surfaces a policy error. Pair autoPlay: true with mute: true, or drop autoPlay and start playback after a user interaction. {v1}',
    correctionMessage:
        'Set mute: true on the YoutubePlayerParams when autoPlay is true, or remove autoPlay and start on user gesture.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      // fromVideoId is a named constructor on YoutubePlayerController.
      if (node.constructorName.type.name.lexeme != _controllerType) return;
      if (node.constructorName.name?.name != 'fromVideoId') return;
      if (!fileImportsPackage(node, PackageImports.youtubePlayerFlutter))
        return;

      final Expression? autoPlay = _namedArg(node.argumentList, 'autoPlay');
      if (autoPlay is! BooleanLiteral || !autoPlay.value) return;

      // Only reason about an inline params construction (cross-variable detection
      // would be unreliable); a separately-built params object is intentionally
      // not flagged to keep this rule false-positive-free.
      final Expression? params = _namedArg(node.argumentList, 'params');
      if (params is! InstanceCreationExpression ||
          params.constructorName.type.name.lexeme != 'YoutubePlayerParams') {
        return;
      }

      final Expression? mute = _namedArg(params.argumentList, 'mute');
      // mute: true is safe; mute absent defaults to false (unsafe); mute: false unsafe.
      if (mute is BooleanLiteral && mute.value) return;

      reporter.atNode(node.constructorName);
    });
  }
}

// =============================================================================
// youtube_player_auto_fullscreen_without_portrait_guard
// =============================================================================

/// Flags `YoutubePlayer` with `autoFullScreen` and no orientation/pop guard.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `YoutubePlayer.autoFullScreen` defaults to true and rotates the device to
/// landscape automatically. If the screen does not restore orientation on pop (via
/// `SystemChrome.setPreferredOrientations` or a `PopScope`/`WillPopScope`), the app
/// can stay stuck in landscape after the player closes — a documented UX bug.
///
/// HIGH false-positive risk: this check is file-scoped and blind to orientation
/// restoration done by a navigation observer or in another file. Pedantic-only;
/// enable only after validating the false-positive rate against real code.
///
/// **BAD:**
/// ```dart
/// // class has no setPreferredOrientations / PopScope
/// YoutubePlayer(controller: c); // autoFullScreen defaults to true
/// ```
///
/// **GOOD:**
/// ```dart
/// YoutubePlayer(controller: c, autoFullScreen: false);
/// ```
class YoutubePlayerAutoFullscreenWithoutPortraitGuardRule
    extends SaropaLintRule {
  YoutubePlayerAutoFullscreenWithoutPortraitGuardRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'YoutubePlayer'};

  static const LintCode _code = LintCode(
    'youtube_player_auto_fullscreen_without_portrait_guard',
    '[youtube_player_auto_fullscreen_without_portrait_guard] A YoutubePlayer is built with autoFullScreen enabled (explicitly true or relying on the true default) and the enclosing class has no SystemChrome.setPreferredOrientations call and no PopScope/WillPopScope. autoFullScreen rotates the device to landscape automatically; without restoring orientation on pop the app can remain stuck in landscape after the player closes. HEURISTIC and file-scoped (high false-positive risk): it cannot see orientation restoration in a navigation observer or another file. {v1}',
    correctionMessage:
        'Set autoFullScreen: false, or restore orientation on pop via SystemChrome.setPreferredOrientations (and/or a PopScope).',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.constructorName.type.name.lexeme != 'YoutubePlayer') return;
      if (!fileImportsPackage(node, PackageImports.youtubePlayerFlutter))
        return;

      // autoFullScreen: false is explicitly safe; absence relies on the true default.
      final Expression? autoFullScreen = _namedArg(
        node.argumentList,
        'autoFullScreen',
      );
      if (autoFullScreen is BooleanLiteral && !autoFullScreen.value) return;

      final ClassDeclaration? cls = _enclosingClass(node);
      if (cls == null) return;

      // Any orientation restoration or pop interception anywhere in the class
      // suppresses the report (conservative — the guard may be cross-file).
      if (_referencesIdentifier(cls, const <String>{
        'setPreferredOrientations',
        'PopScope',
        'WillPopScope',
      })) {
        return;
      }

      reporter.atNode(node.constructorName);
    });
  }
}
