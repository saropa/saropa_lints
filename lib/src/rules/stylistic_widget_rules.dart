// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

import 'package:analyzer/dart/ast/ast.dart';

import '../saropa_lint_rule.dart';

// ============================================================================
// STYLISTIC WIDGET & UI RULES - Batch 1
// ============================================================================
//
// These rules are NOT included in any tier by default. They represent team
// preferences for widget construction patterns where there is no objectively
// "correct" answer.
// ============================================================================

/// Warns when Container is used for simple width/height spacing.
///
/// Since: v4.9.5 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of SizedBox:**
/// - More lightweight - SizedBox is const by default
/// - Clearer intent - explicit that it's just for sizing
/// - Better performance - less widget overhead
///
/// **Cons (why some teams prefer Container):**
/// - Container is more versatile for future changes
/// - Familiar from other frameworks
/// - Single widget for all box needs
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Container(width: 16, height: 16)
/// Container(width: 100)
/// ```
///
/// #### GOOD:
/// ```dart
/// SizedBox(width: 16, height: 16)
/// SizedBox(width: 100)
/// ```
class PreferSizedBoxOverContainerRule extends SaropaLintRule {
  PreferSizedBoxOverContainerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_sizedbox_over_container',
    '[prefer_sizedbox_over_container] A Container is used only for width/height sizing, which adds unnecessary decoration and padding layers. Use SizedBox instead for a lighter widget with clearer intent. {v3}',
    correctionMessage:
        'Replace Container with SizedBox when you only need width and height \u2014 SizedBox skips the decoration/padding layers.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'Container') return;

      // Check if Container only has width, height, and/or child
      final args = node.argumentList.arguments;
      final argNames = <String>{};

      for (final arg in args) {
        if (arg is NamedExpression) {
          argNames.add(arg.name.label.name);
        }
      }

      // Only flag if ONLY using width/height/child (no decoration, color, etc.)
      final allowedArgs = {'width', 'height', 'child', 'key'};
      if (argNames.isNotEmpty && argNames.every(allowedArgs.contains)) {
        // Must have at least width or height to be a sizing container
        if (argNames.contains('width') || argNames.contains('height')) {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when SizedBox is used instead of Container (opposite rule).
///
/// Since: v4.9.5 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of Container:**
/// - More versatile for future changes (add decoration, color easily)
/// - Consistent API across the codebase
/// - Single widget type for all box needs
///
/// **Cons (why some teams prefer SizedBox):**
/// - SizedBox is more lightweight
/// - Clearer intent for sizing-only
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// SizedBox(width: 16, height: 16)
/// ```
///
/// #### GOOD:
/// ```dart
/// Container(width: 16, height: 16)
/// ```
class PreferContainerOverSizedBoxRule extends SaropaLintRule {
  PreferContainerOverSizedBoxRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_container_over_sizedbox',
    '[prefer_container_over_sizedbox] A SizedBox was used where a Container would provide better consistency and easier future extension. Replace it with a Container to allow adding decoration, padding, or alignment without a widget swap. {v3}',
    correctionMessage:
        'Replace SizedBox with Container so decoration, padding, or alignment can be added later without a widget swap.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'SizedBox') return;

      // Skip SizedBox.shrink() and SizedBox.expand()
      final namedConstructor = node.constructorName.name?.name;
      if (namedConstructor == 'shrink' || namedConstructor == 'expand') return;

      reporter.atNode(node);
    });
  }
}

/// Warns when RichText is used instead of Text.rich().
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of Text.rich():**
/// - Inherits DefaultTextStyle automatically
/// - Simpler API for common cases
/// - Consistent with other Text constructors
///
/// **Cons (why some teams prefer RichText):**
/// - RichText offers more control
/// - Explicit about not inheriting styles
/// - Familiar from other frameworks
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// RichText(
///   text: TextSpan(text: 'Hello', children: [...]),
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// Text.rich(
///   TextSpan(text: 'Hello', children: [...]),
/// )
/// ```
class PreferTextRichOverRichTextRule extends SaropaLintRule {
  PreferTextRichOverRichTextRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_text_rich_over_richtext',
    '[prefer_text_rich_over_richtext] RichText widget does not inherit DefaultTextStyle, requiring manual base style setup. Text.rich() inherits the theme automatically and produces less boilerplate. {v3}',
    correctionMessage:
        'Replace RichText with Text.rich() to inherit the DefaultTextStyle and avoid manually setting the base style.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName == 'RichText') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when Text.rich() is used instead of RichText (opposite rule).
///
/// Since: v2.7.0 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of RichText:**
/// - Explicit control over text styling
/// - No implicit style inheritance
/// - More predictable behavior
///
/// **Cons (why some teams prefer Text.rich()):**
/// - Text.rich() inherits DefaultTextStyle
/// - Simpler API
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Text.rich(TextSpan(text: 'Hello'))
/// ```
///
/// #### GOOD:
/// ```dart
/// RichText(text: TextSpan(text: 'Hello'))
/// ```
class PreferRichTextOverTextRichRule extends SaropaLintRule {
  PreferRichTextOverTextRichRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_richtext_over_text_rich',
    '[prefer_richtext_over_text_rich] Text.rich() inherits DefaultTextStyle implicitly, which can cause unexpected styling. Use RichText instead for explicit control over the base text style without hidden theme inheritance. {v3}',
    correctionMessage:
        'Replace Text.rich() with RichText for full control over the base text style without implicit DefaultTextStyle inheritance.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
      final String? namedConstructor = node.constructorName.name?.name;

      if (constructorName == 'Text' && namedConstructor == 'rich') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when EdgeInsets.only() could be simplified to EdgeInsets.symmetric().
///
/// Since: v4.9.5 | Updated: v4.13.0 | Rule version: v4
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of EdgeInsets.symmetric():**
/// - More concise for symmetric padding
/// - Clearer intent when values mirror
/// - Less repetition
///
/// **Cons (why some teams prefer .only()):**
/// - More explicit about each side
/// - Easier to modify individual values later
/// - Consistent API regardless of symmetry
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8)
/// ```
///
/// #### GOOD:
/// ```dart
/// EdgeInsets.symmetric(horizontal: 16, vertical: 8)
/// ```
class PreferEdgeInsetsSymmetricRule extends SaropaLintRule {
  PreferEdgeInsetsSymmetricRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  //  cspell:ignore edgeinsets
  static const LintCode _code = LintCode(
    'prefer_edgeinsets_symmetric',
    '[prefer_edgeinsets_symmetric] EdgeInsets.only() was used with equal left/right or top/bottom values, which adds unnecessary repetition. Use EdgeInsets.symmetric() to express mirrored padding concisely. {v4}',
    correctionMessage:
        'Replace EdgeInsets.only() with EdgeInsets.symmetric() when horizontal or vertical values are equal, for brevity.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
      final String? namedConstructor = node.constructorName.name?.name;

      if (constructorName != 'EdgeInsets') return;
      if (namedConstructor != 'only') return;

      // Extract values
      final args = <String, String>{};
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          args[arg.name.label.name] = arg.expression.toString();
        }
      }

      // Check if symmetric conversion is possible
      final left = args['left'];
      final right = args['right'];
      final top = args['top'];
      final bottom = args['bottom'];

      final hasH = left != null && right != null;
      final hasV = top != null && bottom != null;
      final horizontalSymmetric = hasH && left == right;
      final verticalSymmetric = hasV && top == bottom;

      if (!horizontalSymmetric && !verticalSymmetric) return;

      // Reject unpaired sides (e.g., right without left) — no clean
      // EdgeInsets.symmetric() replacement exists for these cases.
      if ((left == null) != (right == null)) return;
      if ((top == null) != (bottom == null)) return;

      // Reject when one axis is symmetric but the other has mismatched
      // values — the fix would lose the non-symmetric axis.
      if (hasH && !horizontalSymmetric) return;
      if (hasV && !verticalSymmetric) return;

      reporter.atNode(node);
    });
  }
}

/// Warns when EdgeInsets.symmetric() is used instead of .only() (opposite rule).
///
/// Since: v4.9.5 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of EdgeInsets.only():**
/// - More explicit about each side
/// - Easier to modify individual values later
/// - Consistent API across all EdgeInsets usage
///
/// **Cons (why some teams prefer .symmetric()):**
/// - More verbose for symmetric padding
/// - Repetition of values
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// EdgeInsets.symmetric(horizontal: 16, vertical: 8)
/// ```
///
/// #### GOOD:
/// ```dart
/// EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8)
/// ```
class PreferEdgeInsetsOnlyRule extends SaropaLintRule {
  PreferEdgeInsetsOnlyRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_edgeinsets_only',
    '[prefer_edgeinsets_only] EdgeInsets.symmetric() hides which sides receive padding, making future per-side adjustments harder. Use EdgeInsets.only() to declare each side explicitly so values can be changed independently. {v3}',
    correctionMessage:
        'Replace EdgeInsets.symmetric() with EdgeInsets.only() for explicit per-side values that are easier to adjust independently.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
      final String? namedConstructor = node.constructorName.name?.name;

      if (constructorName == 'EdgeInsets' && namedConstructor == 'symmetric') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when BorderRadius.all(Radius.circular()) is used instead of
///
/// Since: v4.9.5 | Updated: v4.13.0 | Rule version: v3
///
/// BorderRadius.circular().
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of BorderRadius.circular():**
/// - More concise syntax
/// - Clearer intent for uniform corners
/// - Less nesting
///
/// **Cons:**
/// - BorderRadius.all() is more explicit
/// - Consistent with other BorderRadius constructors
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// BorderRadius.all(Radius.circular(8))
/// ```
///
/// #### GOOD:
/// ```dart
/// BorderRadius.circular(8)
/// ```
class PreferBorderRadiusCircularRule extends SaropaLintRule {
  PreferBorderRadiusCircularRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  // cspell:ignore borderradius
  static const LintCode _code = LintCode(
    'prefer_borderradius_circular',
    '[prefer_borderradius_circular] Use BorderRadius.circular() instead of BorderRadius.all(Radius.circular()). This is an opinionated rule - not included in any tier by default. {v3}',
    correctionMessage:
        'Replace BorderRadius.all(Radius.circular(r)) with BorderRadius.circular(r) for a shorter single-call equivalent.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
      final String? namedConstructor = node.constructorName.name?.name;

      if (constructorName != 'BorderRadius' || namedConstructor != 'all') {
        return;
      }

      // Check if the argument is Radius.circular()
      final args = node.argumentList.arguments;
      if (args.length != 1) return;

      final arg = args.first;
      if (arg is InstanceCreationExpression) {
        final argName = arg.constructorName.type.element?.name;
        final argConstructor = arg.constructorName.name?.name;
        if (argName == 'Radius' && argConstructor == 'circular') {
          reporter.atNode(node);
        }
      }
    });
  }
}

/// Warns when Flexible(fit: FlexFit.tight) is used instead of Expanded.
///
/// Since: v4.9.5 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of Expanded:**
/// - More concise for the common case
/// - Clearer intent - "expand to fill"
/// - Idiomatic Flutter
///
/// **Cons (why some teams prefer Flexible):**
/// - Flexible is more general
/// - Consistent API regardless of fit
/// - Can easily switch between tight/loose
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Flexible(fit: FlexFit.tight, child: widget)
/// ```
///
/// #### GOOD:
/// ```dart
/// Expanded(child: widget)
/// ```
class PreferExpandedOverFlexibleRule extends SaropaLintRule {
  PreferExpandedOverFlexibleRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_expanded_over_flexible',
    '[prefer_expanded_over_flexible] Flexible with fit: FlexFit.tight is equivalent to Expanded, adding unnecessary verbosity. Use Expanded directly for clearer intent and less boilerplate. {v3}',
    correctionMessage:
        'Replace Flexible(fit: FlexFit.tight) with Expanded, which is the idiomatic shorthand for tight-fit flex children.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'Flexible') return;

      // Check for fit: FlexFit.tight
      for (final arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'fit') {
          final expr = arg.expression;
          if (expr is PrefixedIdentifier) {
            if (expr.prefix.name == 'FlexFit' &&
                expr.identifier.name == 'tight') {
              reporter.atNode(node);
              return;
            }
          }
        }
      }
    });
  }
}

/// Warns when Expanded is used instead of Flexible (opposite rule).
///
/// Since: v4.9.5 | Updated: v4.13.0 | Rule version: v3
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of Flexible:**
/// - More general and explicit
/// - Consistent API for all flex scenarios
/// - Easy to switch between tight/loose
///
/// **Cons (why some teams prefer Expanded):**
/// - Expanded is more concise
/// - Clearer intent for "fill available space"
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Expanded(child: widget)
/// ```
///
/// #### GOOD:
/// ```dart
/// Flexible(fit: FlexFit.tight, child: widget)
/// ```
class PreferFlexibleOverExpandedRule extends SaropaLintRule {
  PreferFlexibleOverExpandedRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_flexible_over_expanded',
    '[prefer_flexible_over_expanded] Expanded widget detected, which hides its fit parameter. Use Flexible with an explicit fit argument instead for greater clarity and easier adjustments to flex behavior. {v3}',
    correctionMessage:
        'Replace Expanded with Flexible(fit: FlexFit.tight) so the fit parameter is always visible and easy to change later.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName == 'Expanded') {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when hardcoded colors are used instead of Theme.of(context).colorScheme.
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of theme colors:**
/// - Automatic dark/light mode support
/// - Consistent theming across the app
/// - Easier to change colors globally
///
/// **Cons (why some teams prefer explicit colors):**
/// - More predictable - no context dependency
/// - Simpler for one-off colors
/// - Faster (no Theme lookup)
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Container(color: Colors.blue)
/// Text('Hi', style: TextStyle(color: Colors.red))
/// ```
///
/// #### GOOD:
/// ```dart
/// Container(color: Theme.of(context).colorScheme.primary)
/// Text('Hi', style: TextStyle(color: Theme.of(context).colorScheme.error))
/// ```
class PreferMaterialThemeColorsRule extends SaropaLintRule {
  PreferMaterialThemeColorsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_material_theme_colors',
    '[prefer_material_theme_colors] Hardcoded Colors.* constant detected in a widget color parameter. Hardcoded colors ignore the active theme and break dark mode support. Use Theme.of(context).colorScheme for consistent theming. {v2}',
    correctionMessage:
        'Replace hardcoded Colors.* with Theme.of(context).colorScheme values to support dark mode and keep colors consistent.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addPrefixedIdentifier((node) {
      if (node.prefix.name == 'Colors') {
        // Check if this is a color assignment in a widget context
        // We look for common color parameter names
        final parent = node.parent;
        if (parent is NamedExpression) {
          final paramName = parent.name.label.name;
          if (_isColorParam(paramName)) {
            reporter.atNode(node);
          }
        } else if (parent is ArgumentList) {
          // Positional color argument (less common but possible)
          reporter.atNode(node);
        }
      }
    });
  }

  bool _isColorParam(String name) {
    return name == 'color' ||
        name == 'backgroundColor' ||
        name == 'foregroundColor' ||
        name == 'fillColor' ||
        name == 'splashColor' ||
        name == 'hoverColor' ||
        name == 'focusColor' ||
        name == 'highlightColor' ||
        name == 'shadowColor' ||
        name == 'surfaceTintColor';
  }
}

/// Warns when Theme.of(context).colorScheme is used instead of explicit Colors
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// (opposite rule).
///
/// This is an **opinionated rule** - not included in any tier by default.
///
/// **Pros of explicit colors:**
/// - More predictable - no context dependency
/// - No Theme lookup overhead
/// - Clearer about exact color being used
///
/// **Cons (why some teams prefer theme colors):**
/// - No automatic dark/light mode
/// - Harder to maintain consistency
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// Container(color: Theme.of(context).colorScheme.primary)
/// ```
///
/// #### GOOD:
/// ```dart
/// Container(color: Colors.blue)
/// ```
class PreferExplicitColorsRule extends SaropaLintRule {
  PreferExplicitColorsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_explicit_colors',
    '[prefer_explicit_colors] Theme.of(context).colorScheme requires a BuildContext lookup at runtime, adding indirection. Use explicit Colors constants for predictable output without runtime context dependency. {v2}',
    correctionMessage:
        'Replace Theme.of(context).colorScheme with explicit Colors.* values for predictable output without runtime context.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addMethodInvocation((node) {
      // Look for Theme.of(context)
      if (node.methodName.name != 'of') return;
      final target = node.target;
      if (target is! SimpleIdentifier) return;
      if (target.name != 'Theme') return;

      // Check if it's followed by .colorScheme
      final parent = node.parent;
      if (parent is PropertyAccess &&
          parent.propertyName.name == 'colorScheme') {
        reporter.atNode(parent);
      }
    });
  }
}

// =============================================================================
// CLIP R SUPERELLIPSE RULES - Batch 2
// =============================================================================

/// Suggests using ClipRSuperellipse instead of ClipRRect for rounded corners.
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// This is an **opinionated rule** — not included in any tier by default.
///
/// ClipRSuperellipse provides smoother, more aesthetically pleasing rounded
/// corners that match iOS design language (the "squircle" shape). The
/// superellipse curve creates a more natural transition between straight
/// edges and rounded corners than circular arcs.
///
/// This rule only fires when no custom `clipper` is used, so the quick fix
/// is a safe drop-in replacement. For custom clippers, see
/// [PreferClipRSuperellipseClipperRule].
///
/// **Requires Flutter 3.32+.** On platforms other than iOS and Android,
/// ClipRSuperellipse falls back to a standard rounded rectangle.
///
/// **Quick fix available:** Replaces `ClipRRect` with `ClipRSuperellipse`,
/// preserving all arguments (`key`, `borderRadius`, `clipBehavior`, `child`).
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// ClipRRect(
///   borderRadius: BorderRadius.circular(10),
///   child: Image.network('url'),
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// ClipRSuperellipse(
///   borderRadius: BorderRadius.circular(10),
///   child: Image.network('url'),
/// )
/// ```
class PreferClipRSuperellipseRule extends SaropaLintRule {
  PreferClipRSuperellipseRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_clip_r_superellipse',
    '[prefer_clip_r_superellipse] ClipRRect uses circular arcs for rounded corners, which produce a visible transition between straight edges and curves. Use ClipRSuperellipse for smoother continuous corners matching iOS design language. {v2}',
    correctionMessage:
        'ClipRSuperellipse provides smoother corner transitions matching iOS design language. Requires Flutter 3.32+.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'ClipRRect') return;

      // Only flag when no custom clipper is used (safe drop-in replacement)
      final args = node.argumentList.arguments;
      for (final arg in args) {
        if (arg is NamedExpression && arg.name.label.name == 'clipper') {
          return;
        }
      }

      reporter.atNode(node);
    });
  }
}

/// Suggests using ClipRSuperellipse instead of ClipRRect when a custom
///
/// Since: v4.9.11 | Updated: v4.13.0 | Rule version: v2
///
/// clipper is used.
///
/// This is an **opinionated rule** — not included in any tier by default.
///
/// Unlike [PreferClipRSuperellipseRule], this rule fires when a custom
/// `clipper` parameter is present. Because the clipper type differs
/// (`CustomClipper<RRect>` vs `CustomClipper<RSuperellipse>`), automatic
/// replacement is not possible — the clipper must be manually rewritten.
///
/// No quick fix is provided.
///
/// **Requires Flutter 3.32+.**
///
/// ### Example
///
/// #### BAD (with this rule enabled):
/// ```dart
/// ClipRRect(
///   clipper: MyCustomClipper(),
///   child: Image.network('url'),
/// )
/// ```
///
/// #### GOOD:
/// ```dart
/// ClipRSuperellipse(
///   clipper: MyCustomSuperellipseClipper(),
///   child: Image.network('url'),
/// )
/// ```
class PreferClipRSuperellipseClipperRule extends SaropaLintRule {
  PreferClipRSuperellipseClipperRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.opinionated;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_clip_r_superellipse_clipper',
    '[prefer_clip_r_superellipse_clipper] Use ClipRSuperellipse instead of ClipRRect for smoother continuous corners. This is an opinionated rule — not included in any tier by default. {v2}',
    correctionMessage:
        'The custom clipper must be rewritten as CustomClipper<RSuperellipse>. Requires Flutter 3.32+.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((node) {
      final constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'ClipRRect') return;

      // Only flag when a custom clipper IS used (no auto-fix possible)
      final hasClipper = node.argumentList.arguments.any(
        (arg) => arg is NamedExpression && arg.name.label.name == 'clipper',
      );
      if (!hasClipper) return;

      reporter.atNode(node);
    });
  }
}
