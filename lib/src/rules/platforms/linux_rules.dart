// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Linux platform-specific lint rules for Flutter applications.
///
/// These rules help ensure Flutter apps follow Linux platform best practices,
/// handle Linux-specific requirements like XDG directory conventions, font
/// fallbacks, display server compatibility, and privilege handling.
///
/// ## Linux Considerations
///
/// Linux desktop apps have additional considerations:
/// - **XDG Base Directory Spec**: Config, data, and cache should use XDG paths
/// - **Font availability**: System fonts differ across distros
/// - **Display servers**: Both X11 and Wayland must be considered
/// - **Privilege model**: Apps should never assume root access
///
/// ## Related Documentation
///
/// - [XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/latest/)
/// - [Freedesktop.org standards](https://www.freedesktop.org/)
/// - [Flutter Linux Desktop](https://docs.flutter.dev/platform-integration/linux/building)
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart'
    show AnalysisError, DiagnosticSeverity;
import 'package:custom_lint_builder/custom_lint_builder.dart';

import '../../saropa_lint_rule.dart';

// =============================================================================
// avoid_hardcoded_unix_paths
// =============================================================================

/// Detects hardcoded Unix filesystem paths that should use `path_provider`.
///
/// Alias: unix_paths, hardcoded_linux_path
///
/// Hardcoded paths like `/home/`, `/tmp/`, `/etc/` break when the app runs
/// under a different user, in a container, or on a non-standard filesystem
/// layout. Use `path_provider` or `Platform.environment` instead.
///
/// **BAD:**
/// ```dart
/// final configFile = File('/home/user/.config/myapp/settings.json');
/// final tempFile = File('/tmp/myapp_cache.dat');
/// final logFile = File('/var/log/myapp.log');
/// ```
///
/// **GOOD:**
/// ```dart
/// final configDir = await getApplicationSupportDirectory();
/// final configFile = File('${configDir.path}/settings.json');
///
/// final tempDir = await getTemporaryDirectory();
/// final tempFile = File('${tempDir.path}/myapp_cache.dat');
/// ```
class AvoidHardcodedUnixPathsRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidHardcodedUnixPathsRule].
  const AvoidHardcodedUnixPathsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_hardcoded_unix_paths',
    problemMessage:
        '[avoid_hardcoded_unix_paths] Hardcoded Unix path detected. '
        'This breaks under different users, containers, or non-standard layouts.',
    correctionMessage: 'Use path_provider (getApplicationSupportDirectory, '
        'getTemporaryDirectory) or Platform.environment instead.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// Unix path prefixes that indicate hardcoded system paths.
  static const List<String> _unixPathPrefixes = <String>[
    '/home/',
    '/tmp/',
    '/etc/',
    '/usr/',
    '/opt/',
    '/var/',
    '/root/',
  ];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      if (value.isEmpty) return;

      for (final String prefix in _unixPathPrefixes) {
        if (value.startsWith(prefix)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

// =============================================================================
// prefer_xdg_directory_convention
// =============================================================================

/// Detects manual construction of XDG directory paths.
///
/// Alias: xdg_directories, xdg_base_dir
///
/// On Linux, user configuration, data, and cache should follow the XDG Base
/// Directory Specification. Manually building `~/.config/`, `~/.local/share/`,
/// or `~/.cache/` paths bypasses `path_provider` which already handles XDG
/// correctly and provides fallbacks.
///
/// **BAD:**
/// ```dart
/// final home = Platform.environment['HOME'];
/// final configPath = '$home/.config/myapp/settings.json';
/// final dataPath = '$home/.local/share/myapp/data.db';
/// final cachePath = '$home/.cache/myapp/thumbnails';
/// ```
///
/// **GOOD:**
/// ```dart
/// // path_provider respects XDG_CONFIG_HOME, XDG_DATA_HOME, etc.
/// final configDir = await getApplicationSupportDirectory();
/// final cacheDir = await getTemporaryDirectory();
/// ```
class PreferXdgDirectoryConventionRule extends SaropaLintRule {
  /// Creates a new instance of [PreferXdgDirectoryConventionRule].
  const PreferXdgDirectoryConventionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'prefer_xdg_directory_convention',
    problemMessage:
        '[prefer_xdg_directory_convention] Manual XDG directory path '
        'construction detected. This ignores XDG environment overrides.',
    correctionMessage: 'Use path_provider (getApplicationSupportDirectory, '
        'getApplicationCacheDirectory) which respects XDG variables.',
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Patterns that indicate manual XDG directory construction.
  static const List<String> _xdgPatterns = <String>[
    '/.config/',
    '/.local/share/',
    '/.local/state/',
    '/.cache/',
  ];

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      if (value.isEmpty) return;

      for (final String pattern in _xdgPatterns) {
        if (value.contains(pattern)) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }
}

// =============================================================================
// avoid_x11_only_assumptions
// =============================================================================

/// Detects X11-specific code without Wayland fallback considerations.
///
/// Alias: x11_wayland, display_server
///
/// Most major Linux distributions now default to Wayland. Code that directly
/// references X11 APIs, environment variables, or X11-only packages may fail
/// silently or crash on Wayland sessions. Always provide a fallback or use
/// abstraction layers.
///
/// **BAD:**
/// ```dart
/// final display = Platform.environment['DISPLAY'];
/// Process.run('xdotool', ['getactivewindow']);
/// Process.run('xclip', ['-selection', 'clipboard']);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use Flutter's built-in clipboard (works on both X11 and Wayland)
/// final data = await Clipboard.getData('text/plain');
///
/// // Check session type before using display-server-specific code
/// final sessionType = Platform.environment['XDG_SESSION_TYPE'];
/// if (sessionType == 'x11') {
///   // X11-specific code with Wayland fallback
/// }
/// ```
class AvoidX11OnlyAssumptionsRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidX11OnlyAssumptionsRule].
  const AvoidX11OnlyAssumptionsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    name: 'avoid_x11_only_assumptions',
    problemMessage: '[avoid_x11_only_assumptions] X11-specific code detected. '
        'Most Linux distros now default to Wayland.',
    correctionMessage:
        'Use Flutter abstractions or check XDG_SESSION_TYPE before '
        'using display-server-specific APIs.',
    errorSeverity: DiagnosticSeverity.WARNING,
  );

  /// X11-specific tool names commonly invoked via Process.run.
  static const Set<String> _x11Tools = <String>{
    'xdotool',
    'xclip',
    'xsel',
    'xrandr',
    'xdpyinfo',
    'xprop',
    'xwininfo',
    'xinput',
    'xmodmap',
    'xset',
    'xauth',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSimpleStringLiteral((SimpleStringLiteral node) {
      final String value = node.value;
      if (value.isEmpty) return;

      // Detect X11 tool invocations
      if (_x11Tools.contains(value)) {
        reporter.atNode(node, code);
        return;
      }
    });

    // Detect Platform.environment['DISPLAY'] access without session check
    context.registry.addIndexExpression((IndexExpression node) {
      final Expression? target = node.target;
      if (target is! PrefixedIdentifier) return;

      // Check for Platform.environment or similar map access
      final String targetSource = target.toSource();
      if (!targetSource.contains('environment')) return;

      final Expression index = node.index;
      if (index is! SimpleStringLiteral) return;

      if (index.value == 'DISPLAY') {
        // Check if XDG_SESSION_TYPE is also checked in the same function
        AstNode? current = node.parent;
        while (current != null) {
          if (current is FunctionBody) break;
          current = current.parent;
        }

        if (current == null) return;

        final String bodySource = current.toSource();
        if (!bodySource.contains('XDG_SESSION_TYPE')) {
          reporter.atNode(node, code);
        }
      }
    });
  }
}

// =============================================================================
// require_linux_font_fallback
// =============================================================================

/// Detects TextStyle with platform-specific fonts without fallback fonts.
///
/// Alias: linux_font, font_fallback
///
/// Linux distributions ship different default fonts than macOS (San Francisco)
/// or Windows (Segoe UI). Using these fonts without `fontFamilyFallback`
/// results in the system falling back to an unpredictable default font,
/// causing inconsistent typography.
///
/// **BAD:**
/// ```dart
/// TextStyle(fontFamily: 'Segoe UI')
/// TextStyle(fontFamily: '.SF Pro Text')
/// TextStyle(fontFamily: 'Helvetica Neue')
/// ```
///
/// **GOOD:**
/// ```dart
/// TextStyle(
///   fontFamily: 'Segoe UI',
///   fontFamilyFallback: ['Roboto', 'Noto Sans', 'Liberation Sans', 'sans-serif'],
/// )
/// ```
///
/// **Quick fix available:** Adds a `fontFamilyFallback` parameter with
/// common cross-platform fonts.
class RequireLinuxFontFallbackRule extends SaropaLintRule {
  /// Creates a new instance of [RequireLinuxFontFallbackRule].
  const RequireLinuxFontFallbackRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    name: 'require_linux_font_fallback',
    problemMessage:
        '[require_linux_font_fallback] Platform-specific font used without '
        'fontFamilyFallback. This font may not exist on Linux.',
    correctionMessage: 'Add fontFamilyFallback with cross-platform fonts like '
        "'Roboto', 'Noto Sans', or 'Liberation Sans'.",
    errorSeverity: DiagnosticSeverity.INFO,
  );

  /// Fonts that are NOT available on standard Linux installations.
  static const Set<String> _nonLinuxFonts = <String>{
    // macOS / iOS
    'San Francisco',
    '.SF Pro Text',
    '.SF Pro Display',
    '.SF Pro Rounded',
    'SF Pro',
    'Helvetica',
    'Helvetica Neue',
    'Apple Color Emoji',
    // Windows
    'Segoe UI',
    'Segoe UI Emoji',
    'Segoe UI Symbol',
    'Consolas',
    'Calibri',
    'Cambria',
    'Verdana',
    'Tahoma',
    'Trebuchet MS',
    'Arial',
    'Times New Roman',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      final String typeName = node.constructorName.type.name2.lexeme;
      if (typeName != 'TextStyle') return;

      final NodeList<Expression> args = node.argumentList.arguments;

      String? fontFamilyValue;
      bool hasFallback = false;

      for (final Expression arg in args) {
        if (arg is! NamedExpression) continue;

        final String name = arg.name.label.name;
        if (name == 'fontFamily') {
          final Expression value = arg.expression;
          if (value is SimpleStringLiteral) {
            fontFamilyValue = value.value;
          }
        } else if (name == 'fontFamilyFallback') {
          hasFallback = true;
        }
      }

      if (fontFamilyValue == null || hasFallback) return;

      // Case-insensitive check against non-Linux fonts
      final String fontLower = fontFamilyValue.toLowerCase();
      for (final String font in _nonLinuxFonts) {
        if (font.toLowerCase() == fontLower) {
          reporter.atNode(node, code);
          return;
        }
      }
    });
  }

  @override
  List<Fix> getFixes() => <Fix>[_AddFontFallbackFix()];
}

/// Quick fix that adds a `fontFamilyFallback` parameter with common
/// cross-platform fonts that are available on Linux.
class _AddFontFallbackFix extends DartFix {
  @override
  void run(
    CustomLintResolver resolver,
    ChangeReporter reporter,
    CustomLintContext context,
    AnalysisError analysisError,
    List<AnalysisError> others,
  ) {
    context.registry.addInstanceCreationExpression((
      InstanceCreationExpression node,
    ) {
      if (!analysisError.sourceRange.intersects(node.sourceRange)) return;

      final NodeList<Expression> args = node.argumentList.arguments;

      // Find the fontFamily argument to insert after it
      for (final Expression arg in args) {
        if (arg is! NamedExpression) continue;
        if (arg.name.label.name != 'fontFamily') continue;

        final changeBuilder = reporter.createChangeBuilder(
          message: 'Add fontFamilyFallback with cross-platform fonts',
          priority: 80,
        );

        changeBuilder.addDartFileEdit((builder) {
          builder.addSimpleInsertion(
            arg.end,
            ",\n      fontFamilyFallback: "
            "const <String>['Roboto', 'Noto Sans', 'Liberation Sans']",
          );
        });
        return;
      }
    });
  }
}

// =============================================================================
// avoid_sudo_shell_commands
// =============================================================================

/// Detects Process.run calls that invoke sudo or assume root privileges.
///
/// Alias: no_sudo, avoid_root
///
/// Desktop applications should never assume root/superuser privileges or
/// invoke `sudo` programmatically. This is a security risk and will fail
/// in sandboxed environments (Flatpak, Snap). Use polkit for privilege
/// escalation or redesign to avoid needing elevated permissions.
///
/// **BAD:**
/// ```dart
/// await Process.run('sudo', ['apt', 'install', 'package']);
/// await Process.run('sudo', ['chmod', '777', '/some/path']);
/// await Process.run('pkexec', ['some-command']);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Use a D-Bus service with polkit authentication
/// // Or use user-space alternatives that don't need root
/// await Process.run('flatpak', ['install', 'com.example.App']);
/// ```
///
/// **OWASP:** `M1:Improper-Platform-Usage`
class AvoidSudoShellCommandsRule extends SaropaLintRule {
  /// Creates a new instance of [AvoidSudoShellCommandsRule].
  const AvoidSudoShellCommandsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  OwaspMapping get owasp => const OwaspMapping(
        mobile: <OwaspMobile>{OwaspMobile.m1},
      );

  static const LintCode _code = LintCode(
    name: 'avoid_sudo_shell_commands',
    problemMessage:
        '[avoid_sudo_shell_commands] Process invocation with elevated '
        'privileges detected. Apps should not assume root access.',
    correctionMessage:
        'Use polkit for privilege escalation, or redesign to avoid '
        'needing elevated permissions. Sandboxed apps cannot use sudo.',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  /// Commands that imply root/elevated privilege usage.
  static const Set<String> _elevatedCommands = <String>{
    'sudo',
    'pkexec',
    'gksudo',
    'kdesudo',
    'su',
  };

  @override
  void runWithReporter(
    CustomLintResolver resolver,
    SaropaDiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check for Process.run or Process.start
      if (methodName != 'run' && methodName != 'start') return;

      final Expression? target = node.target;
      if (target == null) return;

      final String targetSource = target.toSource();
      if (targetSource != 'Process') return;

      final NodeList<Expression> args = node.argumentList.arguments;
      if (args.isEmpty) return;

      final Expression firstArg = args.first;
      if (firstArg is! SimpleStringLiteral) return;

      if (_elevatedCommands.contains(firstArg.value)) {
        reporter.atNode(node, code);
      }
    });
  }
}
