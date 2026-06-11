// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// audioplayers package lint rules (new coverage only).
///
/// The repo already covers AudioPlayer/AudioCache disposal in State widgets
/// (`require_media_player_dispose`, disposal_rules.dart), generic StreamSubscription
/// cancellation (`require_stream_subscription_cancel`), and audio-session setup
/// (`prefer_audio_session_config`, media_rules.dart). These rules cover the gaps
/// those do NOT: the AudioPool lifecycle (no existing disposal type lists it), the
/// PlayerMode.lowLatency event/seek dead-code traps, the ReleaseMode.loop +
/// onPlayerComplete dead-listener trap, UrlSource used for a bundled asset path,
/// and an out-of-range setVolume / play(volume:) literal.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../fixes/common/replace_node_fix.dart';
import '../../import_utils.dart';
import '../../saropa_lint_rule.dart';

/// The enclosing function/method/constructor body containing [node].
///
/// The low-latency / loop-mode rules reason only within a single member body:
/// cross-method data flow (a player configured in one method and listened to in
/// another) needs real data-flow analysis, so same-body scope keeps the
/// heuristic tight and the false-positive rate low.
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

/// The receiver variable name of `receiver.method(...)`, or null when the
/// receiver is not a plain identifier (e.g. a chained expression).
///
/// The mode rules match the configuration call and the listen/seek call by the
/// same receiver identifier; a non-identifier receiver can't be matched safely.
String? _receiverName(Expression? target) {
  if (target is SimpleIdentifier) return target.name;
  return null;
}

/// True when `PlayerMode.lowLatency` appears as an argument of [node].
///
/// Matches both `setPlayerMode(PlayerMode.lowLatency)` and the named
/// `play(..., mode: PlayerMode.lowLatency)` form. Resolved structurally
/// (prefix `PlayerMode`, identifier `lowLatency`) rather than by type element
/// so the rule fires without the package being fully resolvable.
bool _argIsLowLatency(Expression arg) {
  Expression value = arg;
  if (value is NamedExpression) value = value.expression;
  return value is PrefixedIdentifier &&
      value.prefix.name == 'PlayerMode' &&
      value.identifier.name == 'lowLatency';
}

/// True when `ReleaseMode.loop` appears as an argument of [node].
bool _argIsReleaseLoop(Expression arg) {
  Expression value = arg;
  if (value is NamedExpression) value = value.expression;
  return value is PrefixedIdentifier &&
      value.prefix.name == 'ReleaseMode' &&
      value.identifier.name == 'loop';
}

/// Scans a member body for the mode-configuration and stream/seek calls the
/// low-latency and loop rules correlate, keyed by receiver identifier.
class _ModeScan extends RecursiveAstVisitor<void> {
  /// Receivers configured with `setPlayerMode(PlayerMode.lowLatency)` or
  /// `play(..., mode: PlayerMode.lowLatency)` in this body.
  final Set<String> lowLatencyReceivers = <String>{};

  /// Receivers configured with `setReleaseMode(ReleaseMode.loop)` in this body.
  final Set<String> loopReceivers = <String>{};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final String name = node.methodName.name;
    final List<Expression> args = node.argumentList.arguments;

    // play(...) and setPlayerMode(...) can both carry the lowLatency mode.
    if (name == 'setPlayerMode' || name == 'play') {
      final String? receiver = _receiverName(node.realTarget);
      if (receiver != null && args.any(_argIsLowLatency)) {
        lowLatencyReceivers.add(receiver);
      }
    } else if (name == 'setReleaseMode') {
      final String? receiver = _receiverName(node.realTarget);
      if (receiver != null && args.any(_argIsReleaseLoop)) {
        loopReceivers.add(receiver);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// True when [node] is `<receiver>.<stream>.listen(...)`, returning the
/// receiver identifier name and the stream member name when it matches.
({String receiver, String stream})? _streamListen(MethodInvocation node) {
  if (node.methodName.name != 'listen') return null;
  // The listen() target is the stream property access: player.onXxx
  final Expression? target = node.realTarget;
  if (target is PrefixedIdentifier) {
    return (receiver: target.prefix.name, stream: target.identifier.name);
  }
  if (target is PropertyAccess) {
    final Expression inner = target.target ?? target.realTarget;
    if (inner is SimpleIdentifier) {
      return (receiver: inner.name, stream: target.propertyName.name);
    }
  }
  return null;
}

// =============================================================================
// audioplayers_pool_not_disposed
// =============================================================================

/// Flags an `AudioPool` created as a field with no `dispose()` call.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `AudioPool` pre-loads several `AudioPlayer` instances, each holding native
/// resources; `AudioPool.dispose()` releases all of them. A pool stored in a
/// long-lived class without a matching dispose leaks every player it holds.
/// The generic media-disposal rules (`require_media_player_dispose`) list
/// AudioPlayer but NOT AudioPool, and AudioPool is created via the
/// `AudioPool.create` / `createFromAsset` factories, not a field-type the
/// regex rules catch — so this gap is uncovered.
///
/// **BAD:**
/// ```dart
/// class Sfx {
///   late final AudioPool _pool;
///   Future<void> init() async {
///     _pool = await AudioPool.create(source: AssetSource('click.wav'));
///   }
///   // no dispose() that calls _pool.dispose()
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class Sfx {
///   late final AudioPool _pool;
///   void dispose() => _pool.dispose();
/// }
/// ```
class AudioplayersPoolNotDisposedRule extends SaropaLintRule {
  AudioplayersPoolNotDisposedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'AudioPool'};

  static const LintCode _code = LintCode(
    'audioplayers_pool_not_disposed',
    '[audioplayers_pool_not_disposed] An AudioPool is created via AudioPool.create / createFromAsset and stored in a field, but the enclosing class has no dispose() that calls dispose() on it. An AudioPool holds several pre-loaded AudioPlayer instances, each owning native audio resources (Android SoundPool, iOS audio units); without AudioPool.dispose() every pooled player leaks for the lifetime of the owning object. The generic media-disposal rules list AudioPlayer but not AudioPool. {v1}',
    correctionMessage:
        'Add a dispose() to the owning class that calls <pool>.dispose() in the appropriate lifecycle hook (State.dispose, ChangeNotifier.dispose, provider teardown).',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      if (!fileImportsPackage(node, PackageImports.audioplayers)) return;

      // Collect field names whose declared type is AudioPool.
      final Set<String> poolFields = <String>{};
      for (final ClassMember member in node.bodyMembers) {
        if (member is! FieldDeclaration) continue;
        final String? typeName = member.fields.type?.toSource();
        if (typeName == null || !typeName.contains('AudioPool')) continue;
        for (final VariableDeclaration variable in member.fields.variables) {
          poolFields.add(variable.name.lexeme);
        }
      }
      if (poolFields.isEmpty) return;

      // A dispose() that invokes dispose() on each pool field clears the report.
      final _DisposeScan scan = _DisposeScan();
      for (final ClassMember member in node.bodyMembers) {
        if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
          member.body.accept(scan);
        }
      }
      final Set<String> undisposed = poolFields.difference(scan.disposedReceivers);
      if (undisposed.isEmpty) return;

      reporter.atToken(node.nameToken, code);
    });
  }
}

/// Collects receiver identifiers that have `.dispose()` called on them.
class _DisposeScan extends RecursiveAstVisitor<void> {
  final Set<String> disposedReceivers = <String>{};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'dispose') {
      final String? receiver = _receiverName(node.realTarget);
      if (receiver != null) disposedReceivers.add(receiver);
    }
    super.visitMethodInvocation(node);
  }
}

// =============================================================================
// audioplayers_low_latency_with_stream_listen
// =============================================================================

/// Flags a position/duration/complete `listen()` on a low-latency player.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `PlayerMode.lowLatency` uses Android SoundPool / iOS low-level APIs that do
/// not emit `onPositionChanged`, `onDurationChanged`, or `onPlayerComplete`.
/// Subscribing to those streams in low-latency mode creates dead listeners that
/// never fire — progress bars and completion callbacks silently break.
/// Heuristic: same member body only (confirmed bluefireteam #1489).
///
/// **BAD:**
/// ```dart
/// player.setPlayerMode(PlayerMode.lowLatency);
/// player.onPositionChanged.listen((p) => update(p)); // never fires
/// ```
///
/// **GOOD:**
/// ```dart
/// player.setPlayerMode(PlayerMode.mediaPlayer);
/// player.onPositionChanged.listen((p) => update(p));
/// ```
class AudioplayersLowLatencyWithStreamListenRule extends SaropaLintRule {
  AudioplayersLowLatencyWithStreamListenRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'lowLatency'};

  /// Stream members that produce no events in low-latency mode.
  static const Set<String> _deadStreams = <String>{
    'onPositionChanged',
    'onDurationChanged',
    'onPlayerComplete',
  };

  static const LintCode _code = LintCode(
    'audioplayers_low_latency_with_stream_listen',
    '[audioplayers_low_latency_with_stream_listen] A player set to PlayerMode.lowLatency subscribes to onPositionChanged, onDurationChanged, or onPlayerComplete in the same scope. Low-latency mode uses Android SoundPool and iOS low-level APIs, which never emit these events, so the listener is dead code and any progress/completion logic depending on it silently never runs. Switch to PlayerMode.mediaPlayer or drop the listener. {v1}',
    correctionMessage:
        'Use PlayerMode.mediaPlayer when you need position / duration / completion events, or remove the unreachable listener.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final ({String receiver, String stream})? listen = _streamListen(node);
      if (listen == null || !_deadStreams.contains(listen.stream)) return;
      if (!fileImportsPackage(node, PackageImports.audioplayers)) return;

      final FunctionBody? body = _enclosingMemberBody(node);
      if (body == null) return;
      final _ModeScan scan = _ModeScan();
      body.accept(scan);

      // Only fire when the SAME receiver was put into low-latency mode here.
      if (!scan.lowLatencyReceivers.contains(listen.receiver)) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// audioplayers_low_latency_with_seek
// =============================================================================

/// Flags `seek()` on a player configured for low-latency mode.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `seek()` is documented as unsupported in `PlayerMode.lowLatency`; the native
/// backend ignores the call silently. It is a no-op, not an error, but signals a
/// misunderstanding of the mode. Heuristic: same member body only.
///
/// **BAD:**
/// ```dart
/// player.setPlayerMode(PlayerMode.lowLatency);
/// await player.seek(const Duration(seconds: 5)); // ignored
/// ```
///
/// **GOOD:**
/// ```dart
/// player.setPlayerMode(PlayerMode.mediaPlayer);
/// await player.seek(const Duration(seconds: 5));
/// ```
class AudioplayersLowLatencyWithSeekRule extends SaropaLintRule {
  AudioplayersLowLatencyWithSeekRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns => const <String>{'lowLatency'};

  static const LintCode _code = LintCode(
    'audioplayers_low_latency_with_seek',
    '[audioplayers_low_latency_with_seek] seek() is called on a player set to PlayerMode.lowLatency in the same scope. Seeking is unsupported in low-latency mode (Android SoundPool / iOS low-level backend), so the call is silently ignored and the playback position does not change. This is a no-op rather than a crash, but it means the seek logic has no effect. Use PlayerMode.mediaPlayer if you need to seek. {v1}',
    correctionMessage:
        'Switch the player to PlayerMode.mediaPlayer to support seek(), or remove the seek() call in low-latency mode.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'seek') return;
      final String? receiver = _receiverName(node.realTarget);
      if (receiver == null) return;
      if (!fileImportsPackage(node, PackageImports.audioplayers)) return;

      final FunctionBody? body = _enclosingMemberBody(node);
      if (body == null) return;
      final _ModeScan scan = _ModeScan();
      body.accept(scan);

      if (!scan.lowLatencyReceivers.contains(receiver)) return;

      reporter.atNode(node.methodName);
    });
  }
}

// =============================================================================
// audioplayers_release_mode_loop_with_complete_listener
// =============================================================================

/// Flags `onPlayerComplete.listen()` on a player set to `ReleaseMode.loop`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// In `ReleaseMode.loop` playback restarts automatically at the end, so there is
/// no logical completion and `onPlayerComplete` never fires. A completion
/// listener registered alongside loop mode is dead code. INFO — an
/// analytics/logging-only listener is a mild false positive.
///
/// **BAD:**
/// ```dart
/// player.setReleaseMode(ReleaseMode.loop);
/// player.onPlayerComplete.listen((_) => playNext()); // never fires
/// ```
///
/// **GOOD:**
/// ```dart
/// player.setReleaseMode(ReleaseMode.stop);
/// player.onPlayerComplete.listen((_) => playNext());
/// ```
class AudioplayersReleaseModeLoopWithCompleteListenerRule
    extends SaropaLintRule {
  AudioplayersReleaseModeLoopWithCompleteListenerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.info;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<String>? get requiredPatterns =>
      const <String>{'onPlayerComplete', 'ReleaseMode'};

  static const LintCode _code = LintCode(
    'audioplayers_release_mode_loop_with_complete_listener',
    '[audioplayers_release_mode_loop_with_complete_listener] A player set to ReleaseMode.loop subscribes to onPlayerComplete in the same scope. In loop mode playback restarts automatically at the end, so there is no completion event and onPlayerComplete never fires; any re-play or next-track logic in that listener is dead code. If you want completion callbacks use ReleaseMode.stop or release; if you want looping, remove the listener. Reported at INFO because a logging-only listener is harmless. {v1}',
    correctionMessage:
        'Use ReleaseMode.stop / release if you need onPlayerComplete, or remove the listener when looping is intended.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final ({String receiver, String stream})? listen = _streamListen(node);
      if (listen == null || listen.stream != 'onPlayerComplete') return;
      if (!fileImportsPackage(node, PackageImports.audioplayers)) return;

      final FunctionBody? body = _enclosingMemberBody(node);
      if (body == null) return;
      final _ModeScan scan = _ModeScan();
      body.accept(scan);

      if (!scan.loopReceivers.contains(listen.receiver)) return;

      reporter.atNode(node);
    });
  }
}

// =============================================================================
// audioplayers_url_source_in_asset_context
// =============================================================================

/// Flags `UrlSource('assets/...')` that should be `AssetSource`.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `UrlSource` is for remote HTTP(S) streams. Passing a bundled-asset path like
/// `'assets/click.wav'` makes the player attempt an HTTP request for that literal
/// string instead of loading the bundled asset — a network error or silent
/// failure. The fix swaps to `AssetSource` and strips the default `assets/`
/// prefix (AudioCache.prefix prepends it). Literal strings only.
///
/// **BAD:**
/// ```dart
/// player.play(UrlSource('assets/sounds/click.wav'));
/// ```
///
/// **GOOD:**
/// ```dart
/// player.play(AssetSource('sounds/click.wav'));
/// ```
class AudioplayersUrlSourceInAssetContextRule extends SaropaLintRule {
  AudioplayersUrlSourceInAssetContextRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'UrlSource'};

  static const LintCode _code = LintCode(
    'audioplayers_url_source_in_asset_context',
    '[audioplayers_url_source_in_asset_context] UrlSource is constructed with a literal path that starts with assets/, which is a bundled-asset path, not a URL. UrlSource performs an HTTP(S) request for the given string, so the player tries to fetch the literal "assets/..." over the network and fails or silently plays nothing. Bundled audio must use AssetSource, which loads from the app bundle (the assets/ prefix is AudioCache.prefix and is added automatically). {v1}',
    correctionMessage:
        'Use AssetSource(<path without the assets/ prefix>) for bundled audio; reserve UrlSource for http(s) URLs.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        _SwapToAssetSourceFix(context: context),
  ];

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      if (node.constructorName.type.name.lexeme != 'UrlSource') return;
      if (!fileImportsPackage(node, PackageImports.audioplayers)) return;

      final Expression? arg = node.argumentList.arguments.firstOrNull;
      if (arg is! SimpleStringLiteral) return;
      final String value = arg.value;
      // Bundled-asset paths only — a real URL ("https://.../assets/..") contains
      // a scheme and is excluded so we never flag a CDN path under /assets/.
      if (value.contains('://')) return;
      if (!value.startsWith('assets/') && !value.startsWith('asset/')) return;

      reporter.atNode(node);
    });
  }
}

/// Quick fix: rewrite `UrlSource('assets/foo')` to `AssetSource('foo')`.
class _SwapToAssetSourceFix extends ReplaceNodeFix {
  _SwapToAssetSourceFix({required super.context});

  @override
  FixKind get fixKind => FixKind(
    'saropa.fix.swapUrlSourceToAssetSource',
    80,
    'Replace UrlSource with AssetSource',
  );

  @override
  String computeReplacement(AstNode node) {
    if (node is! InstanceCreationExpression) return node.toSource();
    final Expression? arg = node.argumentList.arguments.firstOrNull;
    if (arg is! SimpleStringLiteral) return node.toSource();

    // Strip the leading assets/ (or asset/) — AudioCache.prefix re-adds it.
    String path = arg.value;
    if (path.startsWith('assets/')) {
      path = path.substring('assets/'.length);
    } else if (path.startsWith('asset/')) {
      path = path.substring('asset/'.length);
    }
    return "AssetSource('$path')";
  }
}

// =============================================================================
// audioplayers_hardcoded_volume_above_one
// =============================================================================

/// Flags a `setVolume` / `play(volume:)` literal greater than 1.0.
///
/// Since: v4.16.0 | Rule version: v1
///
/// `setVolume(double)` and the `play(..., volume:)` parameter expect 0.0-1.0.
/// A literal like `setVolume(100)` (percentage-scale thinking) is silently
/// clamped to 1.0 by the backend with no feedback, so the bug compiles and runs
/// while sounding wrong. Clamping is not guaranteed stable across platforms.
/// Literals only.
///
/// **BAD:**
/// ```dart
/// player.setVolume(100);
/// ```
///
/// **GOOD:**
/// ```dart
/// player.setVolume(1.0);
/// ```
class AudioplayersHardcodedVolumeAboveOneRule extends SaropaLintRule {
  AudioplayersHardcodedVolumeAboveOneRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.warning;

  @override
  RuleType? get ruleType => RuleType.bug;

  @override
  Set<String> get tags => const {'packages'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<String>? get requiredPatterns => const <String>{'olume'};

  static const LintCode _code = LintCode(
    'audioplayers_hardcoded_volume_above_one',
    '[audioplayers_hardcoded_volume_above_one] A volume value passed to setVolume() or play(volume:) is a numeric literal greater than 1.0. The audioplayers volume range is 0.0-1.0; the native backend silently clamps anything above 1.0 down to 1.0, so a value like 100 (a common percentage-scale mistake) compiles and runs at full volume with no error or warning. The clamping is not guaranteed stable across platforms. {v1}',
    correctionMessage:
        'Pass a volume in 0.0-1.0 (divide a percentage by 100, e.g. 100 becomes 1.0).',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((MethodInvocation node) {
      final String method = node.methodName.name;
      if (method != 'setVolume' && method != 'play') return;
      if (!fileImportsPackage(node, PackageImports.audioplayers)) return;

      final Expression? value = method == 'setVolume'
          ? node.argumentList.arguments.firstOrNull
          : _namedArg(node, 'volume');
      if (value == null) return;

      final num? literal = _numericLiteral(value);
      if (literal == null || literal <= 1.0) return;

      reporter.atNode(value);
    });
  }

  /// The first named argument [name] of [node], or null.
  Expression? _namedArg(MethodInvocation node, String name) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression && arg.name.label.name == name) {
        return arg.expression;
      }
    }
    return null;
  }

  /// The numeric value of [expr] when it is an int or double literal, else null.
  /// Only literals are flagged — a variable could hold a clamped/valid value.
  num? _numericLiteral(Expression expr) {
    if (expr is IntegerLiteral) return expr.value;
    if (expr is DoubleLiteral) return expr.value;
    return null;
  }
}
