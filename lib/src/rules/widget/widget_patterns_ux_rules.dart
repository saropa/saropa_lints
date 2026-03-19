// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';

import '../../saropa_lint_rule.dart';
import '../../fixes/widget_patterns/replace_with_void_callback_fix.dart';

class PreferSemanticWidgetNamesRule extends SaropaLintRule {
  PreferSemanticWidgetNamesRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_semantic_widget_names',
    '[prefer_semantic_widget_names] Generic Container widget used where a more specific widget communicates intent. Container combines padding, decoration, alignment, and sizing in one opaque widget, making it unclear which feature is actually needed. Specific widgets like SizedBox, DecoratedBox, Padding, or Align are more readable and more efficient. {v2}',
    correctionMessage:
        'Replace Container with the specific widget that matches the intended use: SizedBox for sizing, Padding for padding, DecoratedBox for decoration, or Align for alignment.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName == 'Container') {
        // Check what properties are used
        final Set<String> usedProps = <String>{};
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression) {
            usedProps.add(arg.name.label.name);
          }
        }

        // Suggest alternatives based on usage
        if (usedProps.length == 1) {
          if (usedProps.contains('decoration')) {
            reporter.atNode(node.constructorName, code);
          } else if (usedProps.contains('width') ||
              usedProps.contains('height')) {
            reporter.atNode(node.constructorName, code);
          } else if (usedProps.contains('padding')) {
            reporter.atNode(node.constructorName, code);
          } else if (usedProps.contains('alignment')) {
            reporter.atNode(node.constructorName, code);
          }
        } else if (usedProps.length == 2 &&
            usedProps.contains('width') &&
            usedProps.contains('height')) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

/// Future rule: avoid-text-scale-factor
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v4
///
/// Warns when using deprecated textScaleFactor instead of textScaler.
///
/// Example of **bad** code:
/// ```dart
/// MediaQuery.textScaleFactorOf(context);
/// MediaQuery.of(context).textScaleFactor;
/// ```
///
/// Example of **good** code:
/// ```dart
/// MediaQuery.textScalerOf(context);
/// MediaQuery.of(context).textScaler;
/// ```
class PreferTextThemeRule extends SaropaLintRule {
  PreferTextThemeRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_text_theme',
    '[prefer_text_theme] Hardcoded TextStyle with inline fontSize, fontWeight, and color values scatters typography decisions throughout the codebase. When the design system changes, every hardcoded style must be found and updated manually. Theme.textTheme centralizes typography so that a single theme change propagates consistently to all text widgets. {v4}',
    correctionMessage:
        'Replace the inline TextStyle with Theme.of(context).textTheme.bodyMedium (or the appropriate text style) and use copyWith for minor overrides.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'TextStyle') return;

      // Check if inside a Text widget's style argument
      AstNode? current = node.parent;
      while (current != null) {
        if (current is NamedExpression && current.name.label.name == 'style') {
          // Check if parent is Text widget
          final AstNode? namedParent = current.parent;
          if (namedParent is ArgumentList) {
            final AstNode? argListParent = namedParent.parent;
            if (argListParent is InstanceCreationExpression) {
              final String parentType =
                  argListParent.constructorName.type.name.lexeme;
              if (parentType == 'Text' || parentType == 'RichText') {
                reporter.atNode(node);
                return;
              }
            }
          }
        }
        current = current.parent;
      }
    });
  }
}

/// Warns when scrollable widgets are nested without NestedScrollView.
///
/// Since: v1.4.2 | Updated: v4.13.0 | Rule version: v5
///
/// Nested scrollables (ListView inside ListView) cause gestures to be
/// ambiguous and can lead to poor scroll performance and UX issues.
///
/// **BAD:**
/// ```dart
/// ListView(
///   children: [
///     ListView.builder(...), // Nested scrollable!
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// NestedScrollView(
///   headerSliverBuilder: (context, innerBoxIsScrolled) => [
///     SliverAppBar(...),
///   ],
///   body: ListView.builder(...),
/// )
/// // Or use shrinkWrap + NeverScrollableScrollPhysics for inner list
/// ```
class PreferColorSchemeFromSeedRule extends SaropaLintRule {
  PreferColorSchemeFromSeedRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_color_scheme_from_seed',
    '[prefer_color_scheme_from_seed] Manually constructing a ColorScheme requires specifying 20+ color roles with correct contrast ratios. Missing or mismatched colors cause poor contrast, invisible text, or WCAG accessibility failures. ColorScheme.fromSeed algorithmically generates all roles from a single seed color with guaranteed accessibility compliance. {v4}',
    correctionMessage:
        'Replace the manual ColorScheme constructor with ColorScheme.fromSeed(seedColor: primaryColor) to generate a complete, accessible palette automatically.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      final String? namedConstructor = node.constructorName.name?.name;

      // Only flag default constructor, not fromSeed/fromSwatch
      if (constructorName != 'ColorScheme') return;
      if (namedConstructor != null) return; // fromSeed, light, dark, etc.

      // Check if it has many color arguments (indicating manual definition)
      int colorArgs = 0;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name.startsWith('on') ||
              name == 'primary' ||
              name == 'secondary' ||
              name == 'tertiary' ||
              name == 'surface' ||
              name == 'error' ||
              name == 'background' ||
              name == 'outline') {
            colorArgs++;
          }
        }
      }

      // If defining 4+ colors manually, suggest fromSeed
      if (colorArgs >= 4) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when multiple adjacent Text widgets could use Text.rich or RichText.
///
/// Since: v1.6.0 | Updated: v4.13.0 | Rule version: v4
///
/// Multiple Text widgets in a Row or Wrap for styled text is inefficient.
/// Use Text.rich with TextSpan children for mixed styling.
///
/// **BAD:**
/// ```dart
/// Row(
///   children: [
///     Text('Hello ', style: TextStyle(fontWeight: FontWeight.bold)),
///     Text('world', style: TextStyle(color: Colors.blue)),
///     Text('!', style: TextStyle(fontSize: 20)),
///   ],
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Text.rich(
///   TextSpan(
///     children: [
///       TextSpan(text: 'Hello ', style: TextStyle(fontWeight: FontWeight.bold)),
///       TextSpan(text: 'world', style: TextStyle(color: Colors.blue)),
///       TextSpan(text: '!', style: TextStyle(fontSize: 20)),
///     ],
///   ),
/// )
/// ```
class PreferRichTextForComplexRule extends SaropaLintRule {
  PreferRichTextForComplexRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_rich_text_for_complex',
    '[prefer_rich_text_for_complex] Multiple Text widgets in a Row create separate text layout blocks that cannot wrap as a single paragraph. If the combined text exceeds the available width, each Text clips or overflows independently instead of wrapping naturally. Text.rich with multiple TextSpan children lays out as a single text block with proper line wrapping. {v4}',
    correctionMessage:
        'Replace the Row of Text widgets with a single Text.rich(TextSpan(children: [TextSpan(...), TextSpan(...)])) for unified text layout and natural line wrapping.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? typeName = node.constructorName.type.element?.name;
      if (typeName != 'Row' && typeName != 'Wrap') return;

      // Find children argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'children') {
          final Expression childrenExpr = arg.expression;
          if (childrenExpr is ListLiteral) {
            int textWidgetCount = 0;

            for (final CollectionElement element in childrenExpr.elements) {
              if (element is Expression) {
                if (element is InstanceCreationExpression) {
                  final String? childType =
                      element.constructorName.type.element?.name;
                  if (childType == 'Text') {
                    textWidgetCount++;
                  }
                }
              }
            }

            // If 3+ adjacent Text widgets, suggest Text.rich
            if (textWidgetCount >= 3) {
              reporter.atNode(node.constructorName, code);
            }
          }
        }
      }
    });
  }
}

/// Warns when ThemeMode is hardcoded instead of using system default.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v3
///
/// Using ThemeMode.light or ThemeMode.dark ignores user's OS preference.
/// Default to ThemeMode.system to respect user settings, with option to override.
///
/// **BAD:**
/// ```dart
/// MaterialApp(
///   themeMode: ThemeMode.light, // Ignores user's dark mode preference
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// MaterialApp(
///   themeMode: ThemeMode.system, // Respects OS setting
/// )
/// // Or let user choose with setting stored:
/// MaterialApp(
///   themeMode: userThemePreference ?? ThemeMode.system,
/// )
/// ```
class PreferSystemThemeDefaultRule extends SaropaLintRule {
  PreferSystemThemeDefaultRule() : super(code: _code);

  /// Code quality issue. Review when count exceeds 100.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_system_theme_default',
    '[prefer_system_theme_default] Hardcoded ThemeMode ignores user\'s OS dark mode preference. Using ThemeMode.light or ThemeMode.dark ignores user\'s OS preference. Default to ThemeMode.system to respect user settings, with option to override. {v3}',
    correctionMessage:
        'Use ThemeMode.system as default to respect user settings. Verify the change works correctly with existing tests and add coverage for the new behavior.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPrefixedIdentifier((PrefixedIdentifier node) {
      // Only check ThemeMode.light or ThemeMode.dark
      if (node.prefix.name != 'ThemeMode') return;
      if (node.identifier.name != 'light' && node.identifier.name != 'dark') {
        return;
      }

      // Single traversal: find themeMode arg and check for conditionals
      AstNode? current = node.parent;
      bool foundThemeModeArg = false;

      while (current != null) {
        // Skip if inside conditional (user preference logic)
        if (current is ConditionalExpression ||
            current is IfStatement ||
            current is SwitchStatement ||
            current is SwitchExpression) {
          return;
        }

        // Check if directly in themeMode: argument
        if (current is NamedExpression &&
            current.name.label.name == 'themeMode') {
          foundThemeModeArg = true;
          break;
        }

        // Stop at widget boundary
        if (current is InstanceCreationExpression) break;

        current = current.parent;
      }

      if (foundThemeModeArg) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when AbsorbPointer is used (often IgnorePointer is more appropriate).
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v2
///
/// AbsorbPointer blocks ALL touch events including scrolling. IgnorePointer
/// allows events to pass through to widgets behind. AbsorbPointer is rarely
/// the correct choice.
///
/// **BAD:**
/// ```dart
/// AbsorbPointer(
///   absorbing: isLoading,
///   child: Form(...), // Blocks scrolling in parent ListView too!
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// IgnorePointer(
///   ignoring: isLoading,
///   child: Form(...), // Events pass through to parent
/// )
/// // Or use AbsorbPointer only when you specifically need to block events:
/// AbsorbPointer(
///   absorbing: true,
///   // ignore: avoid_absorb_pointer_misuse
///   child: OverlayBlocker(),
/// )
/// ```
class AvoidBrightnessCheckForThemeRule extends SaropaLintRule {
  AvoidBrightnessCheckForThemeRule() : super(code: _code);

  static const LintCode _code = LintCode(
    'avoid_brightness_check_for_theme',
    '[avoid_brightness_check_for_theme] Manually checking Theme.of(context).brightness to pick light/dark colors bypasses the colorScheme system, which already provides semantically correct colors for each theme mode. Brightness checks are fragile, miss high-contrast mode, and scatter color logic throughout the codebase instead of centralizing it in the theme. {v2}',
    correctionMessage:
        'Replace brightness-conditional colors with colorScheme properties (e.g. colorScheme.onSurface, colorScheme.surface) that automatically adapt to light, dark, and high-contrast modes.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Detect Theme.of(context).brightness pattern
    context.addPropertyAccess((PropertyAccess node) {
      if (node.propertyName.name != 'brightness') return;

      final Expression? target = node.target;
      if (target is! MethodInvocation) return;
      if (target.methodName.name != 'of') return;

      final Expression? methodTarget = target.target;
      if (methodTarget is SimpleIdentifier && methodTarget.name == 'Theme') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when Scaffold body doesn't handle safe areas.
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v2
///
/// Notches, home indicators, and rounded corners clip content. Scaffold
/// body should use SafeArea or handle MediaQuery.padding appropriately.
///
/// **BAD:**
/// ```dart
/// Scaffold(
///   body: Column(
///     children: [...], // May be clipped by notch!
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Scaffold(
///   body: SafeArea(
///     child: Column(
///       children: [...],
///     ),
///   ),
/// )
/// // Or handle manually:
/// Scaffold(
///   body: Padding(
///     padding: MediaQuery.of(context).padding,
///     child: Column(...),
///   ),
/// )
/// ```
class PreferCupertinoForIosFeelRule extends SaropaLintRule {
  PreferCupertinoForIosFeelRule() : super(code: _code);

  /// Design preference for native iOS feel.
  /// App works but may feel less native to iOS users.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_cupertino_for_ios_feel',
    '[prefer_cupertino_for_ios_feel] Material widget has Cupertino equivalent for native iOS feel. Material widgets look foreign on iOS. Use Cupertino equivalents or adaptive widgets for native iOS feel. {v2}',
    correctionMessage:
        'Use the Cupertino equivalent (e.g. CupertinoAlertDialog, CupertinoButton) or an adaptive widget (.adaptive constructor) to provide native iOS look and feel.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Map<String, String> _materialToCupertino = <String, String>{
    'AlertDialog': 'CupertinoAlertDialog',
    'CircularProgressIndicator': 'CupertinoActivityIndicator',
    'Switch': 'CupertinoSwitch',
    'Slider': 'CupertinoSlider',
    'TextField': 'CupertinoTextField',
    'DatePicker': 'CupertinoDatePicker',
    'TimePicker': 'CupertinoTimerPicker',
    'BottomNavigationBar': 'CupertinoTabBar',
    'TabBar': 'CupertinoSlidingSegmentedControl',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (_materialToCupertino.containsKey(typeName)) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when desktop apps don't set window size constraints.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// Desktop apps need minimum window size to prevent unusable layouts.
/// Set constraints in main() or platform runner.
///
/// **BAD:**
/// ```dart
/// void main() {
///   runApp(MyDesktopApp()); // No size constraints - can resize to 1x1!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await windowManager.ensureInitialized();
///   await windowManager.setMinimumSize(Size(800, 600));
///   runApp(MyDesktopApp());
/// }
/// ```
class PreferKeyboardShortcutsRule extends SaropaLintRule {
  PreferKeyboardShortcutsRule() : super(code: _code);

  /// Desktop users expect keyboard shortcuts for efficiency.
  /// App works but power users may find it less productive.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_keyboard_shortcuts',
    '[prefer_keyboard_shortcuts] Desktop app should implement keyboard shortcuts for common actions. Desktop users expect Ctrl+S, Ctrl+Z, etc. Implement Shortcuts and Actions for standard keyboard interactions. {v2}',
    correctionMessage:
        'Add Shortcuts and Actions widgets for standard keyboard shortcuts (Ctrl+S save, Ctrl+Z undo, Ctrl+C copy, etc.) to match desktop user expectations.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    final String path = context.filePath;

    // Only check files that might be desktop entry points
    if (!path.endsWith('main.dart') && !path.contains('app.dart')) return;

    context.addClassDeclaration((ClassDeclaration node) {
      // Check if extends StatelessWidget/StatefulWidget
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String? superName = extendsClause.superclass.element?.name;
      if (superName != 'StatelessWidget' && superName != 'StatefulWidget') {
        return;
      }

      // Check if class name suggests it's the main app
      final String className = node.name.lexeme;
      if (!className.contains('App') && !className.contains('Main')) return;

      // Check if build method has Shortcuts
      final String classSource = node.toSource();
      if (classSource.contains('MaterialApp') ||
          classSource.contains('CupertinoApp')) {
        if (!classSource.contains('Shortcuts') &&
            !classSource.contains('CallbackShortcuts')) {
          reporter.atToken(node.name, code);
        }
      }
    });
  }
}

/// Warns when methods return nullable Widget? types.
///
/// Since: v2.3.3 | Updated: v4.13.0 | Rule version: v2
///
/// Methods returning `Widget?` are often better implemented as:
/// - Returning an empty SizedBox or Container when nothing should render
/// - Using conditional rendering in the parent widget
/// - Extracting to a separate widget class
///
/// Nullable widget methods can lead to null checks scattered throughout
/// the widget tree and make the rendering logic harder to follow.
///
/// **BAD:**
/// ```dart
/// Widget? _buildOptionalHeader() {
///   if (!showHeader) return null;
///   return Text('Header');
/// }
///
/// @override
/// Widget build(BuildContext context) {
///   return Column(
///     children: [
///       if (_buildOptionalHeader() != null) _buildOptionalHeader()!,
///       // or
///       _buildOptionalHeader() ?? SizedBox.shrink(),
///     ],
///   );
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// Widget _buildHeader() {
///   if (!showHeader) return const SizedBox.shrink();
///   return Text('Header');
/// }
///
/// // Or use conditional rendering directly:
/// @override
/// Widget build(BuildContext context) {
///   return Column(
///     children: [
///       if (showHeader) const Text('Header'),
///     ],
///   );
/// }
/// ```
class PreferActionButtonTooltipRule extends SaropaLintRule {
  PreferActionButtonTooltipRule() : super(code: _code);

  /// Accessibility improvement.
  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_action_button_tooltip',
    '[prefer_action_button_tooltip] IconButton without a tooltip is inaccessible to screen reader users who cannot see the icon and have no text description of the button action. Tooltips also appear on long-press (mobile) and hover (desktop), providing discoverability for all users, not just those using assistive technology. {v2}',
    correctionMessage:
        'Add tooltip: \"Description of action\" to the IconButton so screen readers can announce the button purpose and hover/long-press shows a label.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Buttons that should have tooltips
  static const Set<String> _buttonTypes = <String>{
    'IconButton',
    'FloatingActionButton',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_buttonTypes.contains(typeName)) return;

      final ArgumentList args = node.argumentList;

      bool hasTooltip = false;
      for (final Expression arg in args.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'tooltip') {
          hasTooltip = true;
          break;
        }
      }

      if (!hasTooltip) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when void Function() is used instead of VoidCallback typedef.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// Using VoidCallback typedef is cleaner and more conventional in Flutter.
///
/// ### Example
///
/// #### BAD:
/// ```dart
/// final void Function() onPressed;
/// void doSomething(void Function() callback) {}
/// ```
///
/// #### GOOD:
/// ```dart
/// final VoidCallback onPressed;
/// void doSomething(VoidCallback callback) {}
/// ```
class PreferVoidCallbackRule extends SaropaLintRule {
  PreferVoidCallbackRule() : super(code: _code);

  /// Style improvement.
  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleType? get ruleType => RuleType.codeSmell;

  @override
  Set<String> get tags => const {'flutter', 'ui'};

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        ReplaceWithVoidCallbackFix(context: context),
  ];

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  /// Alias: prefer_void_callback_type
  static const LintCode _code = LintCode(
    'prefer_void_callback',
    '[prefer_void_callback] Use VoidCallback instead of void Function(). Using VoidCallback typedef is cleaner and more conventional in Flutter. {v2}',
    correctionMessage:
        'Replace void Function() with VoidCallback for consistency. Use ValueChanged<T> for void Function(T) and ValueGetter<T> for T Function().',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addGenericFunctionType((GenericFunctionType node) {
      // Check for void Function()
      final TypeAnnotation? returnType = node.returnType;
      if (returnType == null) return;

      // Return type should be void
      final String returnTypeName = returnType.toSource();
      if (returnTypeName != 'void') return;

      // Should have no parameters
      final FormalParameterList? params = node.parameters;
      if (params == null || params.parameters.isNotEmpty) return;

      // Should have no type parameters
      if (node.typeParameters != null) return;

      reporter.atNode(node);
    });
  }
}

/// Warns when InheritedWidget doesn't override updateShouldNotify.
///
/// Since: v2.1.0 | Updated: v4.13.0 | Rule version: v3
///
/// Without updateShouldNotify, dependent widgets rebuild on every
/// ancestor rebuild, even when the inherited data hasn't changed.
///
/// **BAD:**
/// ```dart
/// class MyInherited extends InheritedWidget {
///   final String data;
///   const MyInherited({required this.data, required Widget child})
///       : super(child: child);
///   // Missing updateShouldNotify!
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class MyInherited extends InheritedWidget {
///   final String data;
///   const MyInherited({required this.data, required Widget child})
///       : super(child: child);
///
///   @override
///   bool updateShouldNotify(MyInherited oldWidget) {
///     return data != oldWidget.data;
///   }
/// }
/// ```
