// ignore_for_file: depend_on_referenced_packages, deprecated_member_use

/// Accessibility lint rules for Flutter applications.
///
/// These rules help ensure your app is usable by people with disabilities,
/// including those using screen readers, switch controls, or other
/// assistive technologies.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../ignore_utils.dart';
import '../saropa_lint_rule.dart';
import '../fixes/accessibility/increase_animation_duration_fix.dart';

/// Warns when IconButton is used without a tooltip for accessibility.
///
/// Since: v4.10.0 | Updated: v4.13.0 | Rule version: v5
///
/// Alias: prefer_action_button_tooltip
///
/// IconButtons without tooltips are not accessible to screen readers.
/// The tooltip provides the accessible label that screen readers announce.
///
/// **BAD:**
/// ```dart
/// IconButton(
///   icon: Icon(Icons.add),
///   onPressed: () {},
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// IconButton(
///   icon: Icon(Icons.add),
///   onPressed: () {},
///   tooltip: 'Add item',
/// )
/// ```
class AvoidIconButtonsWithoutTooltipRule extends SaropaLintRule {
  AvoidIconButtonsWithoutTooltipRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_icon_buttons_without_tooltip',
    '[avoid_icon_buttons_without_tooltip] This IconButton does not provide a tooltip, making it inaccessible to screen readers and users with visual impairments. Without a tooltip, users cannot understand the button’s purpose, which reduces usability and fails accessibility standards. Tooltips are essential for describing the action of icon-only buttons. {v5}',
    correctionMessage:
        "Always provide a tooltip for every IconButton, describing its action clearly (e.g., tooltip: 'Open settings'). Audit your codebase for IconButton usage and add tooltips where missing. Refer to Flutter accessibility documentation for best practices on labeling interactive elements.",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'IconButton') return;

      final bool hasTooltip = node.argumentList.arguments.any((Expression arg) {
        if (arg is NamedExpression) {
          return arg.name.label.name == 'tooltip';
        }
        return false;
      });

      if (!hasTooltip) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when touch targets are potentially too small for accessibility.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// WCAG 2.1 recommends touch targets be at least 44x44 CSS pixels.
/// Material Design recommends 48x48 dp minimum.
///
/// This rule checks for explicit small sizes on interactive widgets.
///
/// **BAD:**
/// ```dart
/// SizedBox(
///   width: 24,
///   height: 24,
///   child: IconButton(...),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// SizedBox(
///   width: 48,
///   height: 48,
///   child: IconButton(...),
/// )
/// ```
class AvoidSmallTouchTargetsRule extends SaropaLintRule {
  AvoidSmallTouchTargetsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_small_touch_targets',
    '[avoid_small_touch_targets] Touch target under 44px violates WCAG 2.5.5 (Target Size). Users with motor impairments, tremors, or limited dexterity will struggle to tap accurately, causing frustration and excluding them from core functionality. The minimum recommended touch target size is 48x48 logical pixels to ensure reliable interaction across all ability levels. {v5}',
    correctionMessage:
        'Wrap the interactive element in a SizedBox(width: 48, height: 48) or set MaterialTapTargetSize.padded to ensure the touch area meets the 48px minimum.',
    severity: DiagnosticSeverity.INFO,
  );

  static const double _minTouchTarget = 44.0;

  static const Set<String> _interactiveWidgets = <String>{
    'IconButton',
    'TextButton',
    'ElevatedButton',
    'OutlinedButton',
    'GestureDetector',
    'InkWell',
    'InkResponse',
    'Checkbox',
    'Radio',
    'Switch',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'SizedBox' && constructorName != 'Container') {
        return;
      }

      // Check if it contains an interactive widget
      final bool hasInteractiveChild = _containsInteractiveWidget(node);
      if (!hasInteractiveChild) return;

      // Check width and height
      double? width;
      double? height;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'width' || name == 'height') {
            final double? value = _extractNumericValue(arg.expression);
            if (name == 'width') {
              width = value;
            } else {
              height = value;
            }
          }
        }
      }

      if ((width != null && width < _minTouchTarget) ||
          (height != null && height < _minTouchTarget)) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  bool _containsInteractiveWidget(InstanceCreationExpression node) {
    bool found = false;
    node.visitChildren(
      _InteractiveWidgetVisitor((String name) {
        if (_interactiveWidgets.contains(name)) {
          found = true;
        }
      }),
    );
    return found;
  }

  double? _extractNumericValue(Expression expr) {
    if (expr is IntegerLiteral) {
      return expr.value?.toDouble();
    } else if (expr is DoubleLiteral) {
      return expr.value;
    }
    return null;
  }
}

class _InteractiveWidgetVisitor extends RecursiveAstVisitor<void> {
  _InteractiveWidgetVisitor(this.onFound);

  final void Function(String) onFound;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? name = node.constructorName.type.element?.name;
    if (name != null) {
      onFound(name);
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when ExcludeSemantics is used without a comment explaining why.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// ExcludeSemantics removes content from the accessibility tree.
/// This should be intentional and documented.
///
/// **BAD:**
/// ```dart
/// ExcludeSemantics(
///   child: DecorativeImage(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // Decorative image, no semantic meaning
/// ExcludeSemantics(
///   child: DecorativeImage(),
/// )
/// ```
class RequireExcludeSemanticsJustificationRule extends SaropaLintRule {
  RequireExcludeSemanticsJustificationRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_exclude_semantics_justification',
    '[require_exclude_semantics_justification] ExcludeSemantics without '
        'justification makes accessibility audits harder to pass. {v5}',
    correctionMessage:
        'Add a comment above ExcludeSemantics explaining the rationale.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'ExcludeSemantics') return;

      // Check for preceding comment
      final AstNode? parent = node.parent;
      if (parent == null) {
        reporter.atNode(node.constructorName, code);
        return;
      }

      // Look for comments in the compilation unit
      final CompilationUnit? unit = node
          .thisOrAncestorOfType<CompilationUnit>();
      if (unit == null) {
        reporter.atNode(node.constructorName, code);
        return;
      }

      final int nodeOffset = node.offset;
      bool hasComment = false;

      // Check if there's a comment within 200 characters before this node
      for (final Token? token in _getPrecedingTokens(node)) {
        if (token == null) break;
        if (nodeOffset - token.offset > 200) break;

        Token? comment = token.precedingComments;
        while (comment != null) {
          if (nodeOffset - comment.offset < 200) {
            hasComment = true;
            break;
          }
          comment = comment.next;
        }
        if (hasComment) break;
      }

      if (!hasComment) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }

  Iterable<Token?> _getPrecedingTokens(AstNode node) sync* {
    Token? token = node.beginToken.previous;
    for (int i = 0; i < 5 && token != null; i++) {
      yield token;
      token = token.previous;
    }
  }
}

/// Warns when using color alone to convey information.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Users with color blindness may not be able to distinguish colors.
/// Always provide an additional indicator (icon, text, pattern).
///
/// This rule checks for color-only status indicators.
///
/// **BAD:**
/// ```dart
/// Container(
///   color: isError ? Colors.red : Colors.green,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Row(
///   children: [
///     Icon(isError ? Icons.error : Icons.check),
///     Container(color: isError ? Colors.red : Colors.green),
///   ],
/// )
/// ```
class AvoidColorOnlyIndicatorsRule extends SaropaLintRule {
  AvoidColorOnlyIndicatorsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_color_only_indicators',
    '[avoid_color_only_indicators] Color-only status indicator fails for approximately 8% of men and 0.5% of women who have color vision deficiency and cannot distinguish red from green, making the UI completely inaccessible to colorblind users. Relying solely on color to convey meaning violates WCAG 1.4.1 (Use of Color), which requires a secondary visual cue such as an icon, text label, or pattern to communicate status information. {v6}',
    correctionMessage:
        'Add a secondary visual cue alongside the color, such as Icon(isError ? Icons.error : Icons.check), a text label, or a distinct shape to convey status.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'Container') return;

      // Check if color is set conditionally
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'color') {
          if (arg.expression is ConditionalExpression) {
            // Check if Container only has color (simple status indicator)
            final bool hasOnlyColorAndChild = node.argumentList.arguments
                .whereType<NamedExpression>()
                .every(
                  (NamedExpression na) =>
                      na.name.label.name == 'color' ||
                      na.name.label.name == 'child' ||
                      na.name.label.name == 'key' ||
                      na.name.label.name == 'width' ||
                      na.name.label.name == 'height',
                );

            if (hasOnlyColorAndChild) {
              reporter.atNode(arg);
            }
          }
        }
      }
    });
  }
}

/// Warns when GestureDetector is used without keyboard accessibility.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v6
///
/// Touch gestures like tap, long press, etc. need keyboard equivalents
/// for users who cannot use touch input.
///
/// **BAD:**
/// ```dart
/// GestureDetector(
///   onTap: () => doSomething(),
///   child: MyWidget(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Focus(
///   onKeyEvent: (node, event) {
///     if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
///       doSomething();
///       return KeyEventResult.handled;
///     }
///     return KeyEventResult.ignored;
///   },
///   child: GestureDetector(
///     onTap: () => doSomething(),
///     child: MyWidget(),
///   ),
/// )
/// ```
class AvoidGestureOnlyInteractionsRule extends SaropaLintRule {
  AvoidGestureOnlyInteractionsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_gesture_only_interactions',
    '[avoid_gesture_only_interactions] GestureDetector is used without providing keyboard or accessibility support, making the interaction inaccessible to users with motor disabilities or those relying on switch control. This excludes users who cannot use touch input and fails to meet accessibility standards for interactive elements. {v6}',
    correctionMessage:
        'Wrap GestureDetector with Focus and provide onKeyEvent handlers, or use InkWell, ElevatedButton, or other accessible widgets that support keyboard and assistive technologies. Audit your codebase for GestureDetector usage and refactor to ensure all interactions are accessible. See Flutter accessibility documentation for guidance.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'GestureDetector') return;

      // Check if inside a Focus, FocusableActionDetector, or Shortcuts widget
      AstNode? current = node.parent;
      bool hasKeyboardSupport = false;

      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String? parentName = current.constructorName.type.element?.name;
          if (parentName == 'Focus' ||
              parentName == 'FocusableActionDetector' ||
              parentName == 'Shortcuts' ||
              parentName == 'Actions') {
            hasKeyboardSupport = true;
            break;
          }
        }
        current = current.parent;
      }

      if (!hasKeyboardSupport) {
        // Check if GestureDetector has interactive callbacks
        final bool hasInteractiveCallback = node.argumentList.arguments.any((
          Expression arg,
        ) {
          if (arg is NamedExpression) {
            final String name = arg.name.label.name;
            return name == 'onTap' ||
                name == 'onDoubleTap' ||
                name == 'onLongPress';
          }
          return false;
        });

        if (hasInteractiveCallback) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

/// Warns when Semantics widget is missing the label property.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Interactive elements need semantic labels for screen readers.
///
/// **BAD:**
/// ```dart
/// Semantics(
///   button: true,
///   child: MyCustomButton(),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Semantics(
///   button: true,
///   label: 'Submit form',
///   child: MyCustomButton(),
/// )
/// ```
class RequireSemanticsLabelRule extends SaropaLintRule {
  RequireSemanticsLabelRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_semantics_label',
    '[require_semantics_label] This Semantics child element with a button, link, or other interactive role is missing a label, making it inaccessible to screen readers. Without a label, users cannot understand the purpose of the interactive element, which reduces usability and fails accessibility standards. Labels are essential for describing the action or purpose of interactive elements in the widget tree. {v5}',
    correctionMessage:
        "Always provide a descriptive label for Semantics child elements with interactive roles (e.g., label: 'Submit form'). Audit your build methods for Semantics usage and add labels where missing. Refer to Flutter accessibility documentation for labeling interactive elements.",
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _interactiveProperties = <String>{
    'button',
    'link',
    'slider',
    'textField',
    'toggled',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'Semantics') return;

      bool hasLabel = false;
      bool isInteractive = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'label') {
            hasLabel = true;
          }
          if (_interactiveProperties.contains(name)) {
            // Check if the value is true
            if (arg.expression is BooleanLiteral) {
              final BooleanLiteral boolLit = arg.expression as BooleanLiteral;
              if (boolLit.value) {
                isInteractive = true;
              }
            }
          }
        }
      }

      if (isInteractive && !hasLabel) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when MergeSemantics might hide important information.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// MergeSemantics combines all descendant semantics into one node.
/// This can hide important information from screen reader users.
///
/// **BAD:**
/// ```dart
/// MergeSemantics(
///   child: Column(
///     children: [
///       Text('Price:'),
///       Text('\$99.99'),
///       ElevatedButton(onPressed: () {}, child: Text('Buy')),
///     ],
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Column(
///   children: [
///     MergeSemantics(
///       child: Row(children: [Text('Price:'), Text('\$99.99')]),
///     ),
///     ElevatedButton(onPressed: () {}, child: Text('Buy')),
///   ],
/// )
/// ```
class AvoidMergedSemanticsHidingInfoRule extends SaropaLintRule {
  AvoidMergedSemanticsHidingInfoRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_merged_semantics_hiding_info',
    '[avoid_merged_semantics_hiding_info] MergeSemantics hides interactive '
        'elements from screen readers, making buttons/inputs unusable. {v5}',
    correctionMessage:
        'Move interactive widgets outside MergeSemantics, or wrap only related text content.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _interactiveWidgets = <String>{
    'ElevatedButton',
    'TextButton',
    'OutlinedButton',
    'IconButton',
    'FloatingActionButton',
    'TextField',
    'TextFormField',
    'Checkbox',
    'Radio',
    'Switch',
    'Slider',
    'DropdownButton',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'MergeSemantics') return;

      // Check if it contains interactive widgets
      int interactiveCount = 0;
      node.visitChildren(
        _InteractiveCountVisitor((String name) {
          if (_interactiveWidgets.contains(name)) {
            interactiveCount++;
          }
        }),
      );

      // If MergeSemantics contains interactive widgets, warn
      if (interactiveCount > 0) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

class _InteractiveCountVisitor extends RecursiveAstVisitor<void> {
  _InteractiveCountVisitor(this.onFound);

  final void Function(String) onFound;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? name = node.constructorName.type.element?.name;
    if (name != null) {
      onFound(name);
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when dynamic content doesn't use live region semantics.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Screen readers need to be notified when content changes dynamically.
/// Use Semantics with liveRegion: true for important updates.
///
/// **BAD:**
/// ```dart
/// Text(errorMessage) // Error message that changes dynamically
/// ```
///
/// **GOOD:**
/// ```dart
/// Semantics(
///   liveRegion: true,
///   child: Text(errorMessage),
/// )
/// ```
class RequireLiveRegionRule extends SaropaLintRule {
  RequireLiveRegionRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_live_region',
    '[require_live_region] Dynamic content that changes (such as error messages, notifications, or status updates) should use Semantics with liveRegion enabled. Without liveRegion, screen readers will not announce updates, leaving users unaware of important changes. This is critical for accessibility in apps with real-time or changing content. {v5}',
    correctionMessage:
        'Wrap dynamic content with Semantics(liveRegion: true) to ensure screen readers announce changes. Audit your codebase for dynamic UI updates and add liveRegion where appropriate. Refer to Flutter accessibility documentation for best practices on live regions and dynamic content.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _dynamicIndicators = <String>{
    'error',
    'warning',
    'alert',
    'notification',
    'message',
    'status',
    'loading',
    'progress',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'Text') return;

      // Check if the text content suggests dynamic content
      final Expression? textArg = node.argumentList.arguments.firstOrNull;
      if (textArg == null) return;

      String? variableName;
      if (textArg is SimpleIdentifier) {
        variableName = textArg.name.toLowerCase();
      } else if (textArg is PrefixedIdentifier) {
        variableName = textArg.identifier.name.toLowerCase();
      }

      if (variableName == null) return;

      final bool suggestsDynamic = _dynamicIndicators.any(
        (String indicator) => variableName!.contains(indicator),
      );

      if (!suggestsDynamic) return;

      // Check if already wrapped in Semantics with liveRegion
      AstNode? current = node.parent;
      bool hasLiveRegion = false;

      while (current != null && !hasLiveRegion) {
        if (current is InstanceCreationExpression) {
          final String? parentName = current.constructorName.type.element?.name;
          if (parentName == 'Semantics') {
            hasLiveRegion = current.argumentList.arguments.any((
              Expression arg,
            ) {
              if (arg is NamedExpression &&
                  arg.name.label.name == 'liveRegion') {
                if (arg.expression is BooleanLiteral) {
                  return (arg.expression as BooleanLiteral).value;
                }
              }
              return false;
            });
            break;
          }
        }
        current = current.parent;
      }

      if (!hasLiveRegion) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when section headers don't have heading semantics.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Screen reader users rely on heading semantics to navigate content.
/// Use Semantics with header: true for section titles.
///
/// **BAD:**
/// ```dart
/// Text(
///   'Settings',
///   style: Theme.of(context).textTheme.headlineMedium,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Semantics(
///   header: true,
///   child: Text(
///     'Settings',
///     style: Theme.of(context).textTheme.headlineMedium,
///   ),
/// )
/// ```
class RequireHeadingSemanticsRule extends SaropaLintRule {
  RequireHeadingSemanticsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_heading_semantics',
    '[require_heading_semantics] Missing header semantics prevents screen '
        'reader users from navigating by headings. {v5}',
    correctionMessage:
        'Wrap with Semantics(header: true) for screen reader navigation.',
    severity: DiagnosticSeverity.INFO,
  );

  static const Set<String> _headingStyles = <String>{
    'displayLarge',
    'displayMedium',
    'displaySmall',
    'headlineLarge',
    'headlineMedium',
    'headlineSmall',
    'titleLarge',
    'titleMedium',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'Text') return;

      // Check if using a heading text style
      bool usesHeadingStyle = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'style') {
          final String styleSource = arg.expression.toSource();
          usesHeadingStyle = _headingStyles.any(
            (String style) => styleSource.contains(style),
          );
          break;
        }
      }

      if (!usesHeadingStyle) return;

      // Check if wrapped in Semantics with header: true
      AstNode? current = node.parent;
      bool hasHeaderSemantics = false;

      while (current != null && !hasHeaderSemantics) {
        if (current is InstanceCreationExpression) {
          final String? parentName = current.constructorName.type.element?.name;
          if (parentName == 'Semantics') {
            hasHeaderSemantics = current.argumentList.arguments.any((
              Expression arg,
            ) {
              if (arg is NamedExpression && arg.name.label.name == 'header') {
                if (arg.expression is BooleanLiteral) {
                  return (arg.expression as BooleanLiteral).value;
                }
              }
              return false;
            });
            break;
          }
        }
        current = current.parent;
      }

      if (!hasHeaderSemantics) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when image-based buttons lack tooltips.
///
/// Since: v0.1.4 | Updated: v4.13.0 | Rule version: v5
///
/// Buttons that only show an image or icon need text descriptions
/// for screen reader users.
///
/// **BAD:**
/// ```dart
/// InkWell(
///   onTap: () {},
///   child: Image.asset('assets/logo.png'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Tooltip(
///   message: 'Go to home',
///   child: InkWell(
///     onTap: () {},
///     child: Image.asset('assets/logo.png'),
///   ),
/// )
/// ```
class AvoidImageButtonsWithoutTooltipRule extends SaropaLintRule {
  AvoidImageButtonsWithoutTooltipRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_image_buttons_without_tooltip',
    '[avoid_image_buttons_without_tooltip] This image-only button does not provide an accessible label, making it invisible to screen readers and users with visual impairments. Without a tooltip or semantic label, users cannot understand or interact with the button, which fails accessibility standards and excludes blind users from key actions. {v5}',
    correctionMessage:
        'Always wrap image-only buttons with Tooltip or add a Semantics widget with a descriptive label to ensure accessibility. Audit your codebase for image buttons and add labels where missing. Refer to Flutter accessibility documentation for best practices on labeling interactive elements.',
    severity: DiagnosticSeverity.WARNING,
  );

  static const Set<String> _tapWidgets = <String>{
    'InkWell',
    'InkResponse',
    'GestureDetector',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (!_tapWidgets.contains(constructorName)) return;

      // Check if has onTap
      final bool hasOnTap = node.argumentList.arguments.any((Expression arg) {
        if (arg is NamedExpression) {
          return arg.name.label.name == 'onTap';
        }
        return false;
      });

      if (!hasOnTap) return;

      // Check if child is an image
      bool hasImageChild = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          if (arg.expression is InstanceCreationExpression) {
            final InstanceCreationExpression child =
                arg.expression as InstanceCreationExpression;
            final String? childName = child.constructorName.type.element?.name;
            if (childName == 'Image' ||
                childName == 'Icon' ||
                childName == 'SvgPicture') {
              hasImageChild = true;
            }
          }
        }
      }

      if (!hasImageChild) return;

      // Check if wrapped in Tooltip or Semantics
      AstNode? current = node.parent;
      bool hasAccessibility = false;

      while (current != null && !hasAccessibility) {
        if (current is InstanceCreationExpression) {
          final String? parentName = current.constructorName.type.element?.name;
          if (parentName == 'Tooltip' || parentName == 'Semantics') {
            hasAccessibility = true;
            break;
          }
        }
        current = current.parent;
      }

      if (!hasAccessibility) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when textScaleFactor is set to 1.0, ignoring user accessibility settings.
///
/// Since: v1.5.0 | Updated: v4.13.0 | Rule version: v3
///
/// Users with visual impairments rely on system text scaling to make text
/// readable. Hardcoding textScaleFactor: 1.0 overrides their preferences.
///
/// **BAD:**
/// ```dart
/// Text(
///   'Hello',
///   textScaleFactor: 1.0, // Ignores accessibility settings!
/// )
/// MediaQuery(
///   data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
///   child: child,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Text('Hello') // Respects system text scale
/// // Or if you need to limit scaling:
/// Text(
///   'Hello',
///   textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.5),
/// )
/// ```
class AvoidTextScaleFactorIgnoreRule extends SaropaLintRule {
  AvoidTextScaleFactorIgnoreRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_text_scale_factor_ignore',
    '[avoid_text_scale_factor_ignore] Setting textScaleFactor to 1.0 on a text child element overrides user accessibility settings, preventing users from increasing text size for readability. This excludes users with low vision and fails accessibility standards. Respecting user-configured text scaling in the widget tree is essential for inclusive design. {v3}',
    correctionMessage:
        'Remove hardcoded textScaleFactor values or use clamp() to limit scaling range while still allowing user adjustments. Audit your build methods for textScaleFactor usage and refactor to respect accessibility settings. See Flutter documentation on text scaling and accessibility.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'textScaleFactor') {
            // Check if value is 1.0
            final Expression value = arg.expression;
            if (value is DoubleLiteral && value.value == 1.0) {
              reporter.atNode(arg);
            } else if (value is IntegerLiteral && value.value == 1) {
              reporter.atNode(arg);
            }
          }
        }
      }
    });

    // Also check for copyWith(textScaleFactor: 1.0)
    context.addMethodInvocation((MethodInvocation node) {
      if (node.methodName.name != 'copyWith') return;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'textScaleFactor') {
            final Expression value = arg.expression;
            if (value is DoubleLiteral && value.value == 1.0) {
              reporter.atNode(arg);
            } else if (value is IntegerLiteral && value.value == 1) {
              reporter.atNode(arg);
            }
          }
        }
      }
    });
  }
}

/// Warns when Image widget lacks a semanticLabel for screen readers.
///
/// Since: v1.5.0 | Updated: v4.13.0 | Rule version: v6
///
/// Alias: require_image_description
///
/// Images without semanticLabel are invisible to screen readers, making
/// content inaccessible to users with visual impairments. Use
/// excludeFromSemantics: true only for purely decorative images.
///
/// **BAD:**
/// ```dart
/// Image.network('https://example.com/photo.jpg')
/// Image.asset('assets/icon.png')
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(
///   'https://example.com/photo.jpg',
///   semanticLabel: 'Profile photo of user',
/// )
/// // For decorative images:
/// Image.asset(
///   'assets/decoration.png',
///   excludeFromSemantics: true,
/// )
/// ```
class RequireImageSemanticsRule extends SaropaLintRule {
  RequireImageSemanticsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_image_semantics',
    '[require_image_semantics] Image constructor lacks a semanticLabel parameter. Screen readers cannot describe this image to users with visual impairments, making the content inaccessible. This violates WCAG 1.1.1 (Non-text Content) and may exclude your app from accessibility-mandated markets. {v6}',
    correctionMessage:
        "Add semanticLabel: 'description' or excludeFromSemantics: true for decorative images.",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'Image') return;

      bool hasSemanticLabel = false;
      bool isExcludedFromSemantics = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'semanticLabel') {
            hasSemanticLabel = true;
          }
          if (name == 'excludeFromSemantics') {
            if (arg.expression is BooleanLiteral) {
              isExcludedFromSemantics =
                  (arg.expression as BooleanLiteral).value;
            }
          }
        }
      }

      if (!hasSemanticLabel && !isExcludedFromSemantics) {
        reporter.atNode(node.constructorName, code);
      }
    });

    // Also check Image.network, Image.asset, Image.file, Image.memory
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      if (target is! SimpleIdentifier || target.name != 'Image') return;
      if (!<String>{
        'network',
        'asset',
        'file',
        'memory',
      }.contains(methodName)) {
        return;
      }

      bool hasSemanticLabel = false;
      bool isExcludedFromSemantics = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'semanticLabel') {
            hasSemanticLabel = true;
          }
          if (name == 'excludeFromSemantics') {
            if (arg.expression is BooleanLiteral) {
              isExcludedFromSemantics =
                  (arg.expression as BooleanLiteral).value;
            }
          }
        }
      }

      if (!hasSemanticLabel && !isExcludedFromSemantics) {
        reporter.atNode(node.methodName, code);
      }
    });
  }
}

/// Warns when interactive elements have excludeFromSemantics but also have tap handlers.
///
/// Since: v1.5.0 | Updated: v4.13.0 | Rule version: v3
///
/// Elements with tap handlers that are excluded from semantics are completely
/// inaccessible to screen reader users. This is a critical accessibility bug.
///
/// **BAD:**
/// ```dart
/// Semantics(
///   excludeFromSemantics: true,
///   child: GestureDetector(
///     onTap: () => doSomething(),
///     child: Icon(Icons.add),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Semantics(
///   button: true,
///   label: 'Add item',
///   child: GestureDetector(
///     onTap: () => doSomething(),
///     child: Icon(Icons.add),
///   ),
/// )
/// ```
class AvoidHiddenInteractiveRule extends SaropaLintRule {
  AvoidHiddenInteractiveRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_hidden_interactive',
    '[avoid_hidden_interactive] This interactive element uses excludeFromSemantics, making it completely inaccessible to screen readers and users with assistive technologies. Excluding interactive child elements from the semantics tree prevents users with disabilities from discovering or activating key actions, which fails accessibility standards and can break critical workflows. {v3}',
    correctionMessage:
        'Remove excludeFromSemantics from interactive elements, or wrap them in a Semantics parent with a descriptive label to ensure accessibility. Audit your build methods for excludeFromSemantics usage and refactor to provide proper semantic information. Refer to Flutter accessibility documentation for guidance.',
    severity: DiagnosticSeverity.ERROR,
  );

  static const Set<String> _interactiveWidgets = <String>{
    'GestureDetector',
    'InkWell',
    'InkResponse',
    'IconButton',
    'TextButton',
    'ElevatedButton',
    'OutlinedButton',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;

      // Check for ExcludeSemantics wrapping interactive widgets
      if (constructorName == 'ExcludeSemantics') {
        // Check if child contains interactive widget
        bool hasInteractiveChild = false;
        node.visitChildren(
          _InteractiveChildVisitor((String name) {
            if (_interactiveWidgets.contains(name)) {
              hasInteractiveChild = true;
            }
          }),
        );

        if (hasInteractiveChild) {
          reporter.atNode(node.constructorName, code);
        }
      }

      // Check for Semantics(excludeSemantics: true) with interactive child
      if (constructorName == 'Semantics') {
        bool hasExcludeSemantics = false;

        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression &&
              arg.name.label.name == 'excludeSemantics') {
            if (arg.expression is BooleanLiteral) {
              hasExcludeSemantics = (arg.expression as BooleanLiteral).value;
            }
          }
        }

        if (hasExcludeSemantics) {
          bool hasInteractiveChild = false;
          node.visitChildren(
            _InteractiveChildVisitor((String name) {
              if (_interactiveWidgets.contains(name)) {
                hasInteractiveChild = true;
              }
            }),
          );

          if (hasInteractiveChild) {
            reporter.atNode(node.constructorName, code);
          }
        }
      }
    });
  }
}

class _InteractiveChildVisitor extends RecursiveAstVisitor<void> {
  _InteractiveChildVisitor(this.onFound);

  final void Function(String) onFound;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String? name = node.constructorName.type.element?.name;
    if (name != null) {
      onFound(name);
    }
    super.visitInstanceCreationExpression(node);
  }
}

/// Warns when text uses fixed pixel sizes that don't scale with system settings.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// Text should scale with system font size settings for users with visual
/// impairments. Avoid fixed pixel sizes and let text scale naturally.
///
/// **BAD:**
/// ```dart
/// Text(
///   'Hello',
///   style: TextStyle(fontSize: 14), // Fixed size - won't scale!
/// )
/// Text(
///   'Hello',
///   textScaleFactor: 1.0, // Forces no scaling!
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(
///   'Hello',
///   style: Theme.of(context).textTheme.bodyMedium, // Scales with system
/// )
/// // Or use relative sizing:
/// Text(
///   'Hello',
///   style: TextStyle(fontSize: 14 * MediaQuery.textScaleFactorOf(context)),
/// )
/// ```
class PreferScalableTextRule extends SaropaLintRule {
  PreferScalableTextRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_scalable_text',
    '[prefer_scalable_text] Text uses a fixed font size and does not respect user accessibility settings. This prevents users who rely on larger text for readability from accessing your content. All text should scale with the system text scale factor for accessibility compliance. {v2}',
    correctionMessage:
        'Use Theme.of(context).textTheme for text styles, or apply MediaQuery.textScaleFactorOf(context) to scale text. Avoid hardcoded font sizes. Ensure your text widgets respond to user accessibility settings.',
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

      // Check for fontSize argument with literal value
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'fontSize') {
          final Expression valueExpr = arg.expression;

          // Report if it's a literal number
          if (valueExpr is IntegerLiteral || valueExpr is DoubleLiteral) {
            reporter.atNode(arg);
            return;
          }
        }
      }
    });
  }
}

/// Warns when custom tap targets lack Semantics with button: true.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// GestureDetector and InkWell on non-button widgets are invisible to
/// screen readers unless wrapped with Semantics indicating they're buttons.
///
/// **BAD:**
/// ```dart
/// GestureDetector(
///   onTap: () => doSomething(),
///   child: Container(
///     child: Icon(Icons.add),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Semantics(
///   button: true,
///   label: 'Add item',
///   child: GestureDetector(
///     onTap: () => doSomething(),
///     child: Container(
///       child: Icon(Icons.add),
///     ),
///   ),
/// )
/// // Or use IconButton which has built-in semantics:
/// IconButton(
///   onPressed: () => doSomething(),
///   icon: Icon(Icons.add),
///   tooltip: 'Add item',
/// )
/// ```
class RequireButtonSemanticsRule extends SaropaLintRule {
  RequireButtonSemanticsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_button_semantics',
    '[require_button_semantics] Custom interactive elements (e.g., GestureDetector, InkWell) are missing Semantics with button: true. Without proper semantics, assistive technologies cannot identify these child elements as buttons, making them inaccessible to screen reader users who rely on the widget tree for navigation. {v2}',
    correctionMessage:
        'Wrap custom tap targets in a Semantics parent (button: true, label: "...") or use built-in child elements like IconButton, TextButton, or ElevatedButton that provide correct accessibility roles and labels.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'GestureDetector' && typeName != 'InkWell') return;

      // Check if has onTap
      bool hasOnTap = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'onTap' || name == 'onPressed' || name == 'onLongPress') {
            hasOnTap = true;
            break;
          }
        }
      }

      if (!hasOnTap) return;

      // Check if wrapped in Semantics
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (parentType == 'Semantics') {
            // Check for button: true
            for (final Expression arg in current.argumentList.arguments) {
              if (arg is NamedExpression && arg.name.label.name == 'button') {
                return; // Has Semantics with button property
              }
            }
          }
        }
        // Stop at method boundaries
        if (current is MethodDeclaration || current is FunctionDeclaration) {
          break;
        }
        current = current.parent;
      }

      reporter.atNode(node.constructorName, code);
    });
  }
}

/// Warns when custom widgets lack explicit Semantics wrapper.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v2
///
/// Custom widgets that display meaningful content need Semantics to be
/// accessible. Screen readers can't understand custom-painted or composed
/// widgets without explicit semantic information.
///
/// **BAD:**
/// ```dart
/// class StarRating extends StatelessWidget {
///   Widget build(context) {
///     return Row(
///       children: List.generate(5, (i) => Icon(
///         i < rating ? Icons.star : Icons.star_border,
///       )),
///     ); // Screen reader sees nothing useful
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class StarRating extends StatelessWidget {
///   Widget build(context) {
///     return Semantics(
///       label: '$rating out of 5 stars',
///       child: Row(
///         children: List.generate(5, (i) => Icon(
///           i < rating ? Icons.star : Icons.star_border,
///         )),
///       ),
///     );
///   }
/// }
/// ```
class PreferExplicitSemanticsRule extends SaropaLintRule {
  PreferExplicitSemanticsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_explicit_semantics',
    '[prefer_explicit_semantics] Custom build methods lack explicit Semantics, making their child elements invisible or meaningless to screen readers and assistive technologies. All non-trivial elements in the widget tree must provide a semantic label or description for accessibility. {v2}',
    correctionMessage:
        'Add a Semantics parent with a descriptive label to your custom build output, or ensure that all important child content is accessible via semantics. Example: Semantics(label: "Rating: 4 out of 5 stars").',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addClassDeclaration((ClassDeclaration node) {
      // Check if extends StatelessWidget or StatefulWidget
      final ExtendsClause? extendsClause = node.extendsClause;
      if (extendsClause == null) return;

      final String? superName = extendsClause.superclass.element?.name;
      if (superName != 'StatelessWidget' && superName != 'StatefulWidget') {
        return;
      }

      // Check if widget name suggests visual/custom content
      final String className = node.name.lexeme;
      final List<String> visualPatterns = <String>[
        'Rating',
        'Chart',
        'Graph',
        'Progress',
        'Avatar',
        'Badge',
        'Indicator',
        'Status',
        'Custom',
        'Canvas',
        'Painter',
      ];

      bool needsSemantics = false;
      for (final String pattern in visualPatterns) {
        if (className.contains(pattern)) {
          needsSemantics = true;
          break;
        }
      }

      if (!needsSemantics) return;

      // Check if build method has Semantics
      final String classSource = node.toSource();
      if (!classSource.contains('Semantics')) {
        reporter.atToken(node.name, code);
      }
    });
  }
}

/// Warns when MouseRegion or Listener is used without tap alternative.
///
/// Since: v1.7.2 | Updated: v4.13.0 | Rule version: v3
///
/// Hover-only interactions are inaccessible on touch devices and for
/// screen reader users. Always provide tap or button alternatives.
///
/// **BAD:**
/// ```dart
/// MouseRegion(
///   onEnter: (_) => showTooltip(),
///   onExit: (_) => hideTooltip(),
///   child: Icon(Icons.info),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GestureDetector(
///   onTap: () => showTooltip(), // Touch alternative
///   child: MouseRegion(
///     onEnter: (_) => showTooltip(),
///     onExit: (_) => hideTooltip(),
///     child: Icon(Icons.info),
///   ),
/// )
/// // Or use Tooltip which handles both:
/// Tooltip(
///   message: 'Information',
///   child: Icon(Icons.info),
/// )
/// ```
class AvoidHoverOnlyRule extends SaropaLintRule {
  AvoidHoverOnlyRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_hover_only',
    '[avoid_hover_only] Interactive elements respond only to hover events, excluding mobile and touch users as well as people with motor disabilities. All actionable child elements in the widget tree must support both pointer and touch interactions for universal accessibility. {v3}',
    correctionMessage:
        'Add onTap or onPressed handlers using GestureDetector, InkWell, or use built-in components like Tooltip that support both mouse and touch input. Never rely solely on hover for interactivity.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'MouseRegion' && typeName != 'Listener') return;

      // Check if has hover callbacks
      bool hasHover = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'onEnter' || name == 'onExit' || name == 'onHover') {
            hasHover = true;
            break;
          }
        }
      }

      if (!hasHover) return;

      // Check if wrapped in GestureDetector or similar
      AstNode? current = node.parent;
      while (current != null) {
        if (current is InstanceCreationExpression) {
          final String parentType = current.constructorName.type.name.lexeme;
          if (parentType == 'GestureDetector' ||
              parentType == 'InkWell' ||
              parentType == 'Tooltip' ||
              parentType == 'IconButton' ||
              parentType == 'TextButton') {
            return; // Has tap alternative
          }
        }
        if (current is MethodDeclaration || current is FunctionDeclaration) {
          break;
        }
        current = current.parent;
      }

      // Also check if child contains tap widgets
      final String nodeSource = node.toSource();
      if (nodeSource.contains('GestureDetector') ||
          nodeSource.contains('InkWell') ||
          nodeSource.contains('onTap') ||
          nodeSource.contains('onPressed')) {
        return;
      }

      reporter.atNode(node.constructorName, code);
    });
  }
}

/// Warns when error states don't have non-color indicators.
///
/// Since: v2.3.0 | Updated: v4.13.0 | Rule version: v2
///
/// Errors must be identifiable without color. Users with color blindness
/// cannot distinguish red from other colors. Add icons, text labels,
/// and positional cues alongside color changes.
///
/// **BAD:**
/// ```dart
/// Container(
///   color: hasError ? Colors.red : Colors.grey,
///   child: Text('Email'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Row(
///   children: [
///     if (hasError) Icon(Icons.error, color: Colors.red),
///     Text(
///       'Email',
///       style: TextStyle(color: hasError ? Colors.red : null),
///     ),
///     if (hasError) Text(' - Required field'),
///   ],
/// )
/// ```
class RequireErrorIdentificationRule extends SaropaLintRule {
  RequireErrorIdentificationRule() : super(code: _code);

  /// Accessibility issue affecting colorblind users.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'require_error_identification',
    '[require_error_identification] Error or alert states are indicated only by color, which is not accessible to users with color vision deficiencies. All error indicators must include a non-color cue such as an icon, text label, or pattern for full accessibility. {v2}',
    correctionMessage:
        'Add a visible error icon (e.g., Icons.error), descriptive text, or another non-color indicator in addition to color changes. Never rely on color alone to convey critical information.',
    severity: DiagnosticSeverity.WARNING,
  );

  // Cached regex for performance
  // cspell:ignore errorcolor redaccent
  static final RegExp _errorColorPattern = RegExp(
    r'colors\.red|\.red\b|\.error\b|errorcolor|redaccent',
    caseSensitive: false,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addConditionalExpression((ConditionalExpression node) {
      // Check for pattern: condition ? Colors.red/error : something
      final String conditionSource = node.condition.toSource().toLowerCase();
      final String thenSource = node.thenExpression.toSource().toLowerCase();
      final String elseSource = node.elseExpression.toSource().toLowerCase();

      // cspell:ignore haserror iserror isvalid
      // Check if this is an error-related condition
      if (!conditionSource.contains('error') &&
          !conditionSource.contains('invalid') &&
          !conditionSource.contains('haserror') &&
          !conditionSource.contains('iserror') &&
          !conditionSource.contains('isvalid')) {
        return;
      }

      // Check if using error colors - use patterns to avoid false positives
      // like 'thread', 'spread', 'shredded' matching 'red'
      if (!_errorColorPattern.hasMatch(thenSource) &&
          !_errorColorPattern.hasMatch(elseSource)) {
        return;
      }

      // Check if this is in a color-only context (no icon nearby)
      // Look for Icon, errorText, or helperText in surrounding context
      AstNode? current = node.parent;
      int depth = 0;
      bool hasNonColorIndicator = false;

      while (current != null && depth < 10) {
        final String source = current.toSource();
        if (source.contains('Icon(') ||
            source.contains('Icons.error') ||
            source.contains('Icons.warning') ||
            source.contains('errorText') ||
            source.contains('helperText') ||
            source.contains('decoration:') && source.contains('error')) {
          hasNonColorIndicator = true;
          break;
        }
        current = current.parent;
        depth++;
      }

      if (!hasNonColorIndicator) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when text may have insufficient contrast ratio.
///
/// Since: v4.13.0 | Rule version: v1
///
/// Text must have 4.5:1 contrast ratio against background (3:1 for large text).
/// This rule flags potential issues when light colors are used on light
/// backgrounds or dark colors on dark backgrounds.
///
/// **BAD:**
/// ```dart
/// Text(
///   'Hello',
///   style: TextStyle(color: Colors.grey[300]), // Light gray on white
/// )
/// Container(
///   color: Colors.black,
///   child: Text('Hello', style: TextStyle(color: Colors.grey[700])),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Text(
///   'Hello',
///   style: TextStyle(color: Colors.grey[700]), // Darker gray on white
/// )
/// Container(
///   color: Colors.black,
///   child: Text('Hello', style: TextStyle(color: Colors.white)),
/// )
/// ```
class RequireMinimumContrastRule extends SaropaLintRule {
  RequireMinimumContrastRule() : super(code: _code);

  /// Accessibility issue affecting users with low vision.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_minimum_contrast',
    '[require_minimum_contrast] Low contrast text excludes users with low vision, cataracts, or age-related sight loss who cannot distinguish foreground from background. WCAG 2.1 Success Criterion 1.4.3 requires a minimum contrast ratio of 4.5:1 for normal text and 3:1 for large text. Failing to meet this threshold makes content unreadable for millions of users worldwide. {v2}',
    correctionMessage:
        'Increase the contrast ratio by using darker text on light backgrounds or lighter text on dark backgrounds, aiming for at least 4.5:1 for normal text.',
    severity: DiagnosticSeverity.WARNING,
  );

  // Light colors that may have contrast issues on white/light backgrounds
  static const Set<String> _lightColors = <String>{
    'grey[100]',
    'grey[200]',
    'grey[300]',
    'grey[400]',
    'grey.shade100',
    'grey.shade200',
    'grey.shade300',
    'grey.shade400',
    'white',
    'white10',
    'white12',
    'white24',
    'white30',
    'white38',
    'white54',
    'yellow[100]',
    'yellow[200]',
    'yellow.shade100',
    'yellow.shade200',
    'amber[100]',
    'amber[200]',
    'lime[100]',
    'lime[200]',
    'cyan[100]',
    'cyan[200]',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      if (typeName != 'TextStyle') return;

      // Check for color argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'color') {
          final String colorSource = arg.expression.toSource();

          // Check if it's a light color
          for (final String lightColor in _lightColors) {
            if (colorSource.contains(lightColor)) {
              // Check if there's an explicit dark background nearby
              if (!_hasDarkBackgroundContext(node)) {
                // Honor // ignore: and // ignore_for_file: (and hyphenated names).
                if (IgnoreUtils.isIgnoredForFile(
                  context.fileContent,
                  _code.name,
                )) {
                  return;
                }
                if (IgnoreUtils.hasIgnoreComment(arg, _code.name)) return;
                reporter.atNode(arg);
              }
              return;
            }
          }
        }
      }
    });
  }

  /// Light color keywords (lowercased) — if the background contains one
  /// of these, the contrast problem persists and we should still fire.
  static const Set<String> _lightBackgroundKeywords = <String>{
    'white',
    'grey[100]',
    'grey[200]',
    'grey.shade100',
    'grey.shade200',
    'yellow[100]',
    'amber[100]',
    'lime[100]',
    'cyan[100]',
  };

  bool _hasDarkBackgroundContext(AstNode node) {
    AstNode? current = node.parent;
    int depth = 0;

    while (current != null && depth < 8) {
      if (current is InstanceCreationExpression) {
        final String typeName = current.constructorName.type.name.lexeme;
        if (typeName == 'Container' ||
            typeName == 'DecoratedBox' ||
            typeName == 'ColoredBox') {
          final _BgColorResult bg = _getBackgroundColor(current);
          if (bg == _BgColorResult.dark) return true;
          // Background set but unresolvable (variable/expression) —
          // assume developer chose an appropriate color.
          if (bg == _BgColorResult.unresolvable) return true;
          // If light or absent, keep walking up
        }
      }
      current = current.parent;
      depth++;
    }
    return false;
  }

  /// Classifies the background color of a container widget.
  _BgColorResult _getBackgroundColor(InstanceCreationExpression node) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is! NamedExpression) continue;
      final String name = arg.name.label.name;
      if (name != 'color' && name != 'decoration') continue;

      final String colorSrc = arg.expression.toSource();

      // Known dark backgrounds
      if (colorSrc.contains('black') ||
          colorSrc.contains('grey[800]') ||
          colorSrc.contains('grey[900]') ||
          colorSrc.contains('grey.shade800') ||
          colorSrc.contains('grey.shade900')) {
        return _BgColorResult.dark;
      }

      // Known light backgrounds — not helpful for contrast
      if (_lightBackgroundKeywords.any(colorSrc.contains)) {
        return _BgColorResult.light;
      }

      // Has a color but can't determine if dark or light (variable, etc.)
      return _BgColorResult.unresolvable;
    }
    return _BgColorResult.absent;
  }
}

/// Result of checking a container widget's background color.
enum _BgColorResult { dark, light, unresolvable, absent }

/// Warns when CircleAvatar lacks a semanticLabel for accessibility.
///
/// Since: v1.8.2 | Updated: v4.13.0 | Rule version: v2
///
/// Screen readers need a description to announce what the avatar represents.
/// Without semanticLabel, the avatar is invisible to blind users.
///
/// **BAD:**
/// ```dart
/// CircleAvatar(
///   backgroundImage: NetworkImage(user.photoUrl),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// CircleAvatar(
///   backgroundImage: NetworkImage(user.photoUrl),
///   semanticLabel: 'Profile photo of ${user.name}',
/// )
/// ```
class RequireAvatarAltTextRule extends SaropaLintRule {
  RequireAvatarAltTextRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_avatar_alt_text',
    '[require_avatar_alt_text] Avatar or profile image is missing a semanticLabel or alt text. Screen readers cannot describe the image, making it inaccessible to users who rely on assistive technology. All meaningful images must have a descriptive label. {v2}',
    correctionMessage:
        'Add a semanticLabel property to CircleAvatar or provide alt text describing the avatar (e.g., "Profile photo of John Doe") so screen readers can announce its purpose.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'CircleAvatar') return;

      // Check for semanticLabel argument
      bool hasSemanticLabel = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'semanticLabel') {
          hasSemanticLabel = true;
          break;
        }
      }

      if (!hasSemanticLabel) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when Badge widget lacks accessibility semantics.
///
/// Since: v1.8.2 | Updated: v4.13.0 | Rule version: v4
///
/// Badges convey important information (like notification counts) that
/// screen reader users need to hear. Without proper semantics, this
/// information is hidden from blind users.
///
/// **BAD:**
/// ```dart
/// Badge(
///   label: Text('5'),
///   child: Icon(Icons.mail),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Semantics(
///   label: '5 unread messages',
///   child: Badge(
///     label: Text('5'),
///     child: Icon(Icons.mail),
///   ),
/// )
/// ```
class RequireBadgeSemanticsRule extends SaropaLintRule {
  RequireBadgeSemanticsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_badge_semantics',
    '[require_badge_semantics] Badge or status indicator is missing accessibility semantics. Without a semantic label, screen readers cannot announce the badge count or its meaning to users with visual impairments, hiding important notification or status information from a significant portion of your users. {v4}',
    correctionMessage:
        'Wrap the Badge widget in a Semantics widget with a descriptive label (e.g., "3 unread messages") so assistive technologies can announce its content and purpose.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Badge') return;

      // Check if wrapped in Semantics widget
      if (!_hasSemanticAncestor(node)) {
        reporter.atNode(node);
      }
    });
  }

  bool _hasSemanticAncestor(AstNode node) {
    AstNode? current = node.parent;
    int depth = 0;

    while (current != null && depth < 5) {
      if (current is InstanceCreationExpression) {
        final String typeName = current.constructorName.type.name.lexeme;
        if (typeName == 'Semantics') {
          return true;
        }
      }
      current = current.parent;
      depth++;
    }
    return false;
  }
}

/// Warns when Badge displays count greater than 99 without truncation.
///
/// Since: v1.8.2 | Updated: v4.13.0 | Rule version: v2
///
/// Large numbers in badges are hard to read and look unprofessional.
/// The convention is to show "99+" for counts above 99.
///
/// **BAD:**
/// ```dart
/// Badge(
///   label: Text('150'),
///   child: Icon(Icons.mail),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Badge(
///   label: Text(count > 99 ? '99+' : '$count'),
///   child: Icon(Icons.mail),
/// )
/// ```
class RequireBadgeCountLimitRule extends SaropaLintRule {
  RequireBadgeCountLimitRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_badge_count_limit',
    '[require_badge_count_limit] Badge count exceeds 99. Use "99+" pattern for large numbers. Large numbers in badges are hard to read and look unprofessional. The convention is to show "99+" for counts above 99. {v2}',
    correctionMessage:
        'Replace with: Text(count > 99 ? "99+" : "\$count"). Test with VoiceOver (iOS) and TalkBack (Android) to verify the change improves accessibility.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Badge') return;

      // Check label argument for literal number > 99
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'label') {
          final Expression labelExpr = arg.expression;

          // Check if it's a Text widget with a literal number
          if (labelExpr is InstanceCreationExpression) {
            final String labelTypeName =
                labelExpr.constructorName.type.name.lexeme;
            if (labelTypeName == 'Text' &&
                labelExpr.argumentList.arguments.isNotEmpty) {
              final Expression textArg = labelExpr.argumentList.arguments.first;
              if (textArg is SimpleStringLiteral) {
                final int? number = int.tryParse(textArg.value);
                if (number != null && number > 99) {
                  reporter.atNode(arg);
                }
              }
            }
          }
        }
      }
    });
  }
}

/// Warns when Image widget lacks semanticLabel or excludeFromSemantics.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// Images need descriptions for screen reader users. Either provide a
/// semanticLabel describing the image or explicitly exclude decorative
/// images from semantics.
///
/// **BAD:**
/// ```dart
/// Image.network('https://example.com/photo.jpg')
/// Image.asset('assets/logo.png')
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(
///   'https://example.com/photo.jpg',
///   semanticLabel: 'Product photo showing blue widget',
/// )
/// // Or for decorative images:
/// Image.asset(
///   'assets/decoration.png',
///   excludeFromSemantics: true,
/// )
/// ```
class RequireImageDescriptionRule extends SaropaLintRule {
  RequireImageDescriptionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_image_description',
    '[require_image_description] Image without semanticLabel is announced '
        'as "image" by screen readers, providing no useful information. {v2}',
    correctionMessage:
        'Add semanticLabel for content images or excludeFromSemantics: true '
        'for decorative images.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Image') return;

      bool hasSemanticLabel = false;
      bool hasExclude = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'semanticLabel') hasSemanticLabel = true;
          if (name == 'excludeFromSemantics') hasExclude = true;
        }
      }

      if (!hasSemanticLabel && !hasExclude) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

/// Warns when excludeFromSemantics is used without a comment explaining why.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v3
///
/// Excluding content from semantics should be a conscious decision.
/// Add a comment explaining why the content is decorative.
///
/// **BAD:**
/// ```dart
/// Image.asset(
///   'assets/icon.png',
///   excludeFromSemantics: true,
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// // Decorative background pattern, no informational content
/// Image.asset(
///   'assets/pattern.png',
///   excludeFromSemantics: true,
/// )
/// ```
class AvoidSemanticsExclusionRule extends SaropaLintRule {
  AvoidSemanticsExclusionRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_semantics_exclusion',
    '[avoid_semantics_exclusion] excludeFromSemantics: true detected without accompanying documentation. Screen reader users will encounter hidden content without understanding why it was excluded, making it difficult to debug accessibility issues or verify the exclusion was intentional. {v3}',
    correctionMessage:
        'Add a comment above this widget explaining why it is decorative or redundant content that screen readers should skip. Include the semantic information provided by surrounding context.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addNamedExpression((NamedExpression node) {
      if (node.name.label.name != 'excludeFromSemantics') return;

      // Check if value is true
      final Expression value = node.expression;
      if (value is! BooleanLiteral || !value.value) return;

      // Check for preceding comment
      final bool hasComment = node.beginToken.precedingComments != null;

      // Check parent for comment
      AstNode? parent = node.parent;
      while (parent != null && parent is! Statement) {
        if (parent.beginToken.precedingComments != null) {
          return; // Has comment
        }
        parent = parent.parent;
      }

      if (!hasComment) {
        reporter.atNode(node);
      }
    });
  }
}

/// Warns when Icon and Text are adjacent without MergeSemantics.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v3
///
/// Icon + Text combinations should be wrapped in MergeSemantics so
/// screen readers announce them as a single unit.
///
/// **BAD:**
/// ```dart
/// Row(children: [
///   Icon(Icons.star),
///   Text('Favorite'),
/// ])
/// ```
///
/// **GOOD:**
/// ```dart
/// MergeSemantics(
///   child: Row(children: [
///     Icon(Icons.star),
///     Text('Favorite'),
///   ]),
/// )
/// ```
class PreferMergeSemanticsRule extends SaropaLintRule {
  PreferMergeSemanticsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_merge_semantics',
    '[prefer_merge_semantics] Row or Column containing Icon and Text detected without MergeSemantics wrapper. Screen readers will announce each element separately instead of as a single cohesive label, forcing users to piece together fragmented information. {v3}',
    correctionMessage:
        'Wrap the Row or Column with MergeSemantics to combine the icon and text into a single unified announcement for screen readers, improving comprehension and navigation efficiency.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Row' && typeName != 'Column') return;

      // Check children for Icon + Text combination
      bool hasIcon = false;
      bool hasText = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'children') {
          final Expression children = arg.expression;
          if (children is ListLiteral) {
            for (final CollectionElement element in children.elements) {
              if (element is InstanceCreationExpression) {
                final String childType =
                    element.constructorName.type.name.lexeme;
                if (childType == 'Icon') hasIcon = true;
                if (childType == 'Text') hasText = true;
              }
            }
          }
        }
      }

      if (!hasIcon || !hasText) return;

      // Check if already wrapped in MergeSemantics
      if (_hasMergeSemanticsAncestor(node)) return;

      reporter.atNode(node.constructorName, code);
    });
  }

  bool _hasMergeSemanticsAncestor(AstNode node) {
    AstNode? current = node.parent;
    int depth = 0;

    while (current != null && depth < 5) {
      if (current is InstanceCreationExpression) {
        final String typeName = current.constructorName.type.name.lexeme;
        if (typeName == 'MergeSemantics') {
          return true;
        }
      }
      current = current.parent;
      depth++;
    }
    return false;
  }
}

/// Warns when interactive widget lacks visible focus styling.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v4
///
/// Keyboard users need visible focus indicators to know which element
/// is currently focused. Use Focus widget with visual feedback.
///
/// **BAD:**
/// ```dart
/// GestureDetector(
///   onTap: _handleTap,
///   child: Container(...),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Focus(
///   child: Builder(builder: (context) {
///     final hasFocus = Focus.of(context).hasFocus;
///     return GestureDetector(
///       onTap: _handleTap,
///       child: Container(
///         decoration: BoxDecoration(
///           border: hasFocus ? Border.all(color: Colors.blue, width: 2) : null,
///         ),
///         ...
///       ),
///     );
///   }),
/// )
/// ```
class RequireFocusIndicatorRule extends SaropaLintRule {
  RequireFocusIndicatorRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_focus_indicator',
    '[require_focus_indicator] GestureDetector or InkWell lacks visible focus indicator. Keyboard and assistive technology users cannot determine which element currently has focus, preventing effective navigation and interaction with your application. {v4}',
    correctionMessage:
        'Wrap the interactive widget in a Focus widget with a FocusNode, then show visual feedback (border, background color, or outline) when hasFocus is true to indicate keyboard focus state.',
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      // Check for custom interactive widgets (not built-in buttons)
      if (typeName != 'GestureDetector' && typeName != 'InkWell') return;

      // Check if has tap handler
      bool hasTapHandler = false;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'onTap' || name == 'onPressed') {
            hasTapHandler = true;
            break;
          }
        }
      }

      if (!hasTapHandler) return;

      // Check if wrapped in Focus widget
      if (_hasFocusAncestor(node)) return;

      reporter.atNode(node.constructorName, code);
    });
  }

  bool _hasFocusAncestor(AstNode node) {
    AstNode? current = node.parent;
    int depth = 0;

    while (current != null && depth < 5) {
      if (current is InstanceCreationExpression) {
        final String typeName = current.constructorName.type.name.lexeme;
        if (typeName == 'Focus' || typeName == 'FocusableActionDetector') {
          return true;
        }
      }
      current = current.parent;
      depth++;
    }
    return false;
  }
}

/// Warns when repeating animation may flash more than 3 times per second.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v4
///
/// Rapidly flashing content can trigger seizures in photosensitive users.
/// WCAG 2.3.1 requires no more than 3 flashes per second. A "flash" requires
/// alternating between states, so only repeating animations can cause flashing.
/// Single-direction animations (forward, reverse, animateTo) are not flagged.
///
/// **BAD:**
/// ```dart
/// AnimationController(
///   duration: Duration(milliseconds: 100), // 10 flashes/second!
/// )..repeat(reverse: true);
/// ```
///
/// **GOOD:**
/// ```dart
/// // Slow repeat is safe
/// AnimationController(
///   duration: Duration(milliseconds: 500), // 2 flashes/second
/// )..repeat(reverse: true);
///
/// // Single-direction animations don't flash
/// AnimationController(
///   duration: Duration(milliseconds: 100),
/// )..forward(); // OK - runs once, no flashing
/// ```
///
/// **Quick fix available:** Increases duration to 333ms (minimum safe threshold).
class AvoidFlashingContentRule extends SaropaLintRule {
  AvoidFlashingContentRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.critical;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  List<SaropaFixGenerator> get fixGenerators => [
    ({required CorrectionProducerContext context}) =>
        IncreaseAnimationDurationFix(context: context),
  ];

  static const LintCode _code = LintCode(
    'avoid_flashing_content',
    '[avoid_flashing_content] Flashing >3Hz can trigger seizures in users '
        'with photosensitive epilepsy. WCAG 2.3.1 compliance required. {v4}',
    correctionMessage:
        'Increase duration to at least 333ms to stay under 3 flashes/second.',
    severity: DiagnosticSeverity.WARNING,
  );
  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'AnimationController') return;

      // Only flag if animation repeats (actual flashing requires alternation)
      if (!_hasRepeatCascade(node)) return;

      // Check duration argument
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'duration') {
          final int? millis = _extractMilliseconds(arg.expression);
          if (millis != null && millis > 0 && millis < 333) {
            reporter.atNode(arg);
          }
        }
      }
    });
  }

  /// Check for cascade like `AnimationController(...)..repeat()`.
  bool _hasRepeatCascade(InstanceCreationExpression node) {
    final AstNode? parent = node.parent;
    if (parent is! CascadeExpression) return false;
    if (parent.target != node) return false;

    for (final Expression section in parent.cascadeSections) {
      if (section is MethodInvocation && section.methodName.name == 'repeat') {
        return true;
      }
    }
    return false;
  }

  /// Extract milliseconds from a Duration constructor expression.
  int? _extractMilliseconds(Expression duration) {
    if (duration is! InstanceCreationExpression) return null;

    final String durationTypeName = duration.constructorName.type.name.lexeme;
    if (durationTypeName != 'Duration') return null;

    for (final Expression durationArg in duration.argumentList.arguments) {
      if (durationArg is NamedExpression &&
          durationArg.name.label.name == 'milliseconds') {
        final Expression millisExpr = durationArg.expression;
        if (millisExpr is IntegerLiteral) {
          return millisExpr.value;
        }
      }
    }
    return null;
  }
}

/// Quick fix to increase animation duration to 333ms (WCAG 2.3.1 compliant).

/// Warns when touch targets have insufficient spacing.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// Touch targets that are too close together make it difficult for
/// users with motor impairments to tap the correct target.
/// Recommended minimum spacing is 8dp.
///
/// **BAD:**
/// ```dart
/// Row(children: [
///   IconButton(onPressed: _action1, icon: Icon(Icons.add)),
///   IconButton(onPressed: _action2, icon: Icon(Icons.remove)),
/// ])
/// ```
///
/// **GOOD:**
/// ```dart
/// Row(children: [
///   IconButton(onPressed: _action1, icon: Icon(Icons.add)),
///   SizedBox(width: 8),
///   IconButton(onPressed: _action2, icon: Icon(Icons.remove)),
/// ])
/// ```
class PreferAdequateSpacingRule extends SaropaLintRule {
  PreferAdequateSpacingRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'prefer_adequate_spacing',
    '[prefer_adequate_spacing] Adjacent interactive buttons detected without spacing. Users may accidentally tap the wrong button, especially those with motor impairments or using touch interfaces where precision is limited. {v2}',
    correctionMessage:
        'Add SizedBox(width: 8) or SizedBox(height: 8) between adjacent touch targets to provide adequate spacing and reduce accidental taps. Consider 16px spacing for better accessibility compliance.',
    severity: DiagnosticSeverity.INFO,
  );

  // Interactive widgets that are touch targets
  static const Set<String> _touchTargets = <String>{
    'IconButton',
    'TextButton',
    'ElevatedButton',
    'OutlinedButton',
    'FloatingActionButton',
    'GestureDetector',
    'InkWell',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addListLiteral((ListLiteral node) {
      // Check if this is likely a children list
      final AstNode? parent = node.parent;
      if (parent is! NamedExpression) return;
      if (parent.name.label.name != 'children') return;

      // Check for adjacent touch targets
      bool lastWasTouchTarget = false;

      for (final CollectionElement element in node.elements) {
        if (element is InstanceCreationExpression) {
          final String typeName = element.constructorName.type.name.lexeme;
          final bool isTouchTarget = _touchTargets.contains(typeName);

          if (lastWasTouchTarget && isTouchTarget) {
            reporter.atNode(element);
          }

          lastWasTouchTarget = isTouchTarget;

          // SizedBox resets the pattern
          if (typeName == 'SizedBox' || typeName == 'Padding') {
            lastWasTouchTarget = false;
          }
        }
      }
    });
  }
}

/// Warns when animation plays without respecting user's reduce motion preference.
///
/// Since: v2.0.0 | Updated: v4.13.0 | Rule version: v2
///
/// Users with vestibular disorders may have enabled "Reduce Motion" in their
/// accessibility settings. Respect this preference for non-essential animations.
///
/// **BAD:**
/// ```dart
/// AnimatedContainer(
///   duration: Duration(milliseconds: 500),
///   ...
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// AnimatedContainer(
///   duration: MediaQuery.of(context).disableAnimations
///       ? Duration.zero
///       : Duration(milliseconds: 500),
///   ...
/// )
/// ```
class AvoidMotionWithoutReduceRule extends SaropaLintRule {
  AvoidMotionWithoutReduceRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_motion_without_reduce',
    '[avoid_motion_without_reduce] Animation should respect disableAnimations preference. Users with vestibular disorders may have enabled "Reduce Motion" in their accessibility settings. Respect this preference for non-essential animations. {v2}',
    correctionMessage:
        'Check MediaQuery.disableAnimations and reduce/skip animation if true. Test with VoiceOver (iOS) and TalkBack (Android) to verify the change improves accessibility.',
    severity: DiagnosticSeverity.INFO,
  );

  // Animated widgets that should respect reduce motion
  static const Set<String> _animatedWidgets = <String>{
    'AnimatedContainer',
    'AnimatedOpacity',
    'AnimatedPositioned',
    'AnimatedSize',
    'AnimatedCrossFade',
    'AnimatedSwitcher',
    'SlideTransition',
    'FadeTransition',
    'ScaleTransition',
    'RotationTransition',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_animatedWidgets.contains(typeName)) return;

      // Check if duration references disableAnimations
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'duration') {
          final String durationSource = arg.expression.toSource();
          if (durationSource.contains('disableAnimations') ||
              durationSource.contains('reduceMotion') ||
              durationSource.contains('accessibleNavigation')) {
            return; // Good - respects preference
          }
        }
      }

      reporter.atNode(node.constructorName, code);
    });
  }
}

/// Warns when Icon widget is used without a semanticLabel for accessibility.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v2
///
/// Icons without semanticLabel are invisible to screen readers. Provide a
/// semanticLabel to describe the icon's meaning or purpose.
///
/// **BAD:**
/// ```dart
/// Icon(Icons.add)
/// Icon(Icons.home)
/// ```
///
/// **GOOD:**
/// ```dart
/// Icon(Icons.add, semanticLabel: 'Add item')
/// Icon(Icons.home, semanticLabel: 'Home')
/// // Or for decorative icons that should be ignored:
/// Semantics(
///   excludeSemantics: true,
///   child: Icon(Icons.star),
/// )
/// ```
class RequireSemanticLabelIconsRule extends SaropaLintRule {
  RequireSemanticLabelIconsRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_semantic_label_icons',
    '[require_semantic_label_icons] Icon child element is missing a semanticLabel, making it invisible or meaningless to screen readers and assistive technologies. All icons that convey information or actions in the widget tree must have a descriptive semanticLabel for accessibility compliance. {v2}',
    correctionMessage:
        "Add a semanticLabel property to your Icon child element describing its meaning or purpose (e.g., semanticLabel: 'Add item'). This ensures screen readers can announce the icon to users with visual impairments.",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'Icon') return;

      bool hasSemanticLabel = false;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String name = arg.name.label.name;
          if (name == 'semanticLabel') {
            hasSemanticLabel = true;
            break;
          }
        }
      }

      if (!hasSemanticLabel) {
        // Check if wrapped in ExcludeSemantics or Semantics with excludeSemantics: true
        if (!_hasSemanticExclusion(node)) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }

  bool _hasSemanticExclusion(AstNode node) {
    AstNode? current = node.parent;
    int depth = 0;

    while (current != null && depth < 5) {
      if (current is InstanceCreationExpression) {
        final String? typeName = current.constructorName.type.element?.name;

        // Check for ExcludeSemantics widget
        if (typeName == 'ExcludeSemantics') {
          return true;
        }

        // Check for Semantics with excludeSemantics: true
        if (typeName == 'Semantics') {
          for (final Expression arg in current.argumentList.arguments) {
            if (arg is NamedExpression &&
                arg.name.label.name == 'excludeSemantics') {
              if (arg.expression is BooleanLiteral) {
                if ((arg.expression as BooleanLiteral).value) {
                  return true;
                }
              }
            }
          }
        }
      }
      current = current.parent;
      depth++;
    }
    return false;
  }
}

/// Warns when Image widget lacks semanticLabel or excludeFromSemantics.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v2
///
/// Images need descriptions for screen reader users. Either provide a
/// semanticLabel describing the image content, or explicitly mark decorative
/// images with excludeFromSemantics: true.
///
/// **BAD:**
/// ```dart
/// Image.network('https://example.com/photo.jpg')
/// Image.asset('assets/logo.png')
/// Image(image: AssetImage('assets/icon.png'))
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.network(
///   'https://example.com/photo.jpg',
///   semanticLabel: 'Profile photo of user',
/// )
/// // For decorative images:
/// Image.asset(
///   'assets/decoration.png',
///   excludeFromSemantics: true,
/// )
/// ```
class RequireAccessibleImagesRule extends SaropaLintRule {
  RequireAccessibleImagesRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'require_accessible_images',
    '[require_accessible_images] Image element lacks accessibility handling, making it invisible to screen readers and users with visual impairments. Without a semanticLabel describing the image content, assistive technologies skip over it entirely, leaving users unable to understand the visual context. This violates WCAG 1.1.1 (Non-text Content), which requires all meaningful images to have a text alternative. {v2}',
    correctionMessage:
        "Add semanticLabel: 'description' or excludeFromSemantics: true for decorative images.",
    severity: DiagnosticSeverity.WARNING,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    // Check Image constructor calls
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      if (constructorName != 'Image') return;

      if (!_hasAccessibilityHandling(node.argumentList.arguments)) {
        reporter.atNode(node.constructorName, code);
      }
    });

    // Check Image.network, Image.asset, Image.file, Image.memory factory methods
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;
      final Expression? target = node.target;

      if (target is! SimpleIdentifier || target.name != 'Image') return;
      if (!<String>{
        'network',
        'asset',
        'file',
        'memory',
      }.contains(methodName)) {
        return;
      }

      if (!_hasAccessibilityHandling(node.argumentList.arguments)) {
        reporter.atNode(node.methodName, code);
      }
    });
  }

  bool _hasAccessibilityHandling(NodeList<Expression> arguments) {
    bool hasSemanticLabel = false;
    bool hasExcludeFromSemantics = false;

    for (final Expression arg in arguments) {
      if (arg is NamedExpression) {
        final String name = arg.name.label.name;
        if (name == 'semanticLabel') {
          hasSemanticLabel = true;
        }
        if (name == 'excludeFromSemantics') {
          if (arg.expression is BooleanLiteral) {
            hasExcludeFromSemantics = (arg.expression as BooleanLiteral).value;
          }
        }
      }
    }

    return hasSemanticLabel || hasExcludeFromSemantics;
  }
}

/// Warns when video or audio widgets have autoPlay: true enabled.
///
/// Since: v2.3.7 | Updated: v4.13.0 | Rule version: v2
///
/// Auto-playing media can be disorienting and problematic for users with
/// vestibular disorders, cognitive disabilities, or those using screen readers.
/// Users should have control over when media plays.
///
/// **BAD:**
/// ```dart
/// VideoPlayer(
///   autoPlay: true,
///   ...
/// )
/// AudioPlayer(
///   autoPlay: true,
///   ...
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// VideoPlayer(
///   autoPlay: false,
///   ...
/// )
/// // Or without autoPlay (defaults to false in most players)
/// VideoPlayer(...)
/// ```
class AvoidAutoPlayMediaRule extends SaropaLintRule {
  AvoidAutoPlayMediaRule() : super(code: _code);

  /// Significant issue. Address when count exceeds 10.
  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_auto_play_media',
    '[avoid_auto_play_media] Media that auto-plays on page load can be disorienting, distracting, or even harmful for users with disabilities, especially those with cognitive or sensory sensitivities. Auto-play also reduces user control and can violate accessibility guidelines. {v2}',
    correctionMessage:
        'Set autoPlay: false for all video and audio widgets. Allow users to start media playback manually, and provide clear controls for play, pause, and stop. Audit your codebase for autoPlay usage and document this requirement in your team’s accessibility checklist.',
    severity: DiagnosticSeverity.WARNING,
  );

  // Common video/audio player widget names
  static const Set<String> _mediaWidgets = <String>{
    'VideoPlayer',
    'VideoPlayerController',
    'AudioPlayer',
    'AudioPlayerController',
    'Chewie',
    'ChewieController',
    'BetterPlayer',
    'BetterPlayerController',
    'FlickVideoPlayer',
    'FlickManager',
    'VlcPlayer',
    'VlcPlayerController',
    'PodVideoPlayer',
    'PodPlayerController',
    'JustAudioPlayer',
    'AssetsAudioPlayer',
  };

  // Common parameter names for autoplay functionality
  static const Set<String> _autoPlayParams = <String>{
    'autoPlay',
    'autoplay',
    'autoStart',
    'autostart',
    'playOnInit',
    'playAutomatically',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;
      final String typeName = node.constructorName.type.name.lexeme;

      // Check if this is a media-related widget (by type name or constructor name)
      final bool isMediaWidget =
          _mediaWidgets.contains(constructorName) ||
          _mediaWidgets.contains(typeName) ||
          typeName.toLowerCase().contains('video') ||
          typeName.toLowerCase().contains('audio') ||
          typeName.toLowerCase().contains('player');

      if (!isMediaWidget) return;

      // Check for autoPlay parameter set to true
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          final String paramName = arg.name.label.name;
          if (_autoPlayParams.contains(paramName)) {
            // Check if value is true
            final Expression value = arg.expression;
            if (value is BooleanLiteral && value.value) {
              reporter.atNode(arg);
            }
          }
        }
      }
    });

    // Also check method invocations for controller configurations
    context.addMethodInvocation((MethodInvocation node) {
      final String methodName = node.methodName.name;

      // Check common configuration methods
      if (methodName == 'initialize' ||
          methodName == 'init' ||
          methodName == 'configure' ||
          methodName == 'setConfig') {
        for (final Expression arg in node.argumentList.arguments) {
          if (arg is NamedExpression) {
            final String paramName = arg.name.label.name;
            if (_autoPlayParams.contains(paramName)) {
              final Expression value = arg.expression;
              if (value is BooleanLiteral && value.value) {
                reporter.atNode(arg);
              }
            }
          }
        }
      }
    });
  }
}

// =============================================================================
// prefer_large_touch_targets
// =============================================================================

/// Touch targets should be at least 48x48 logical pixels for accessibility.
///
/// Since: v4.1.5 | Updated: v4.13.0 | Rule version: v2
///
/// Small touch targets are difficult for users with motor impairments
/// or when using the app in challenging conditions.
///
/// **BAD:**
/// ```dart
/// GestureDetector(
///   child: Container(
///     width: 24,  // Too small!
///     height: 24,
///     child: Icon(Icons.close),
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// GestureDetector(
///   child: Container(
///     width: 48,  // Minimum accessible size
///     height: 48,
///     child: Icon(Icons.close),
///   ),
/// )
/// ```
class PreferLargeTouchTargetsRule extends SaropaLintRule {
  PreferLargeTouchTargetsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_large_touch_targets',
    '[prefer_large_touch_targets] Touch target is smaller than 48px. '
        'This makes it difficult for users with motor impairments. {v2}',
    correctionMessage:
        'Increase the touch target size to at least 48x48 '
        'logical pixels, or wrap in a larger touchable area.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Minimum recommended touch target size in logical pixels.
  static const double _minTouchSize = 48.0;

  /// Interactive widgets that need adequate touch targets.
  static const Set<String> _interactiveWidgets = <String>{
    'GestureDetector',
    'InkWell',
    'InkResponse',
    'IconButton',
    'TextButton',
    'ElevatedButton',
    'OutlinedButton',
    'FloatingActionButton',
    'Checkbox',
    'Radio',
    'Switch',
    'Slider',
    'Chip',
    'ActionChip',
    'FilterChip',
    'ChoiceChip',
    'InputChip',
    'PopupMenuButton',
    'DropdownButton',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_interactiveWidgets.contains(typeName)) return;

      // Check for explicit small size constraints
      double? width;
      double? height;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;

        final String paramName = arg.name.label.name;
        final Expression value = arg.expression;

        if (paramName == 'width' && value is DoubleLiteral) {
          width = value.value;
        } else if (paramName == 'height' && value is DoubleLiteral) {
          height = value.value;
        } else if (paramName == 'width' && value is IntegerLiteral) {
          width = value.value?.toDouble();
        } else if (paramName == 'height' && value is IntegerLiteral) {
          height = value.value?.toDouble();
        } else if (paramName == 'iconSize' && value is DoubleLiteral) {
          // IconButton uses iconSize
          if (value.value < _minTouchSize) {
            reporter.atNode(arg);
          }
        } else if (paramName == 'iconSize' && value is IntegerLiteral) {
          if ((value.value ?? 0) < _minTouchSize) {
            reporter.atNode(arg);
          }
        } else if (paramName == 'constraints') {
          // Check BoxConstraints
          _checkBoxConstraints(arg.expression, reporter);
        }
      }

      // Report if explicit dimensions are too small
      if (width != null && width < _minTouchSize) {
        reporter.atNode(node);
      } else if (height != null && height < _minTouchSize) {
        reporter.atNode(node);
      }
    });
  }

  void _checkBoxConstraints(
    Expression expr,
    SaropaDiagnosticReporter reporter,
  ) {
    if (expr is! InstanceCreationExpression) return;

    final String typeName = expr.constructorName.type.name.lexeme;
    if (typeName != 'BoxConstraints') return;

    for (final Expression arg in expr.argumentList.arguments) {
      if (arg is! NamedExpression) continue;

      final String paramName = arg.name.label.name;
      final Expression value = arg.expression;

      double? size;
      if (value is DoubleLiteral) {
        size = value.value;
      } else if (value is IntegerLiteral) {
        size = value.value?.toDouble();
      }

      if (size != null && size < _minTouchSize) {
        if (paramName == 'maxWidth' ||
            paramName == 'maxHeight' ||
            paramName == 'minWidth' ||
            paramName == 'minHeight') {
          reporter.atNode(arg);
        }
      }
    }
  }
}

// =============================================================================
// avoid_time_limits
// =============================================================================

/// Warns when timed interactions disadvantage users who need more time.
///
/// Since: v4.1.5 | Updated: v4.13.0 | Rule version: v2
///
/// Auto-logout, disappearing toasts, and timed actions can be problematic
/// for users with cognitive or motor disabilities who need more time.
///
/// **BAD:**
/// ```dart
/// Timer(Duration(seconds: 3), () {
///   Navigator.of(context).pop(); // Auto-dismiss after 3 seconds
/// });
///
/// ScaffoldMessenger.of(context).showSnackBar(
///   SnackBar(
///     content: Text('Action completed'),
///     duration: Duration(seconds: 2), // Too short!
///   ),
/// );
/// ```
///
/// **GOOD:**
/// ```dart
/// // Allow user to dismiss manually, or use longer duration
/// ScaffoldMessenger.of(context).showSnackBar(
///   SnackBar(
///     content: Text('Action completed'),
///     duration: Duration(seconds: 10),
///     action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
///   ),
/// );
/// ```
class AvoidTimeLimitsRule extends SaropaLintRule {
  AvoidTimeLimitsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'avoid_time_limits',
    '[avoid_time_limits] Short duration may disadvantage users who need '
        'more time. Consider longer durations or manual dismissal. {v2}',
    correctionMessage:
        'Use duration >= 10 seconds or provide manual dismiss option.',
    severity: DiagnosticSeverity.INFO,
  );

  // Minimum duration in seconds for accessibility
  static const int _minDurationSeconds = 5;

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String constructorName = node.constructorName.type.name.lexeme;
      if (constructorName != 'SnackBar' && constructorName != 'Toast') return;

      // Check for duration parameter
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'duration') {
          final durationValue = _extractDurationSeconds(arg.expression);
          if (durationValue != null && durationValue < _minDurationSeconds) {
            reporter.atNode(arg);
          }
        }
      }
    });

    // Also check Timer with auto-dismiss patterns
    context.addMethodInvocation((MethodInvocation node) {
      final target = node.target;
      if (target is! SimpleIdentifier || target.name != 'Timer') return;

      // Check for short timers that might auto-dismiss
      if (node.argumentList.arguments.isNotEmpty) {
        final firstArg = node.argumentList.arguments.first;
        final durationValue = _extractDurationSeconds(firstArg);
        if (durationValue != null && durationValue < _minDurationSeconds) {
          // Check if callback contains navigation or dismiss
          if (node.argumentList.arguments.length >= 2) {
            final callback = node.argumentList.arguments[1];
            final callbackSource = callback.toSource();
            if (callbackSource.contains('pop') ||
                callbackSource.contains('dismiss') ||
                callbackSource.contains('hide') ||
                callbackSource.contains('close')) {
              reporter.atNode(node);
            }
          }
        }
      }
    });
  }

  int? _extractDurationSeconds(Expression expr) {
    if (expr is! InstanceCreationExpression) return null;

    final typeName = expr.constructorName.type.name.lexeme;
    if (typeName != 'Duration') return null;

    final constructorNameNode = expr.constructorName.name;
    if (constructorNameNode != null) {
      // Named constructor like Duration.seconds(5)
      for (final arg in expr.argumentList.arguments) {
        if (arg is IntegerLiteral) {
          if (constructorNameNode.name == 'seconds') {
            return arg.value;
          } else if (constructorNameNode.name == 'milliseconds') {
            return (arg.value ?? 0) ~/ 1000;
          }
        }
      }
    } else {
      // Positional constructor Duration(seconds: 5)
      for (final arg in expr.argumentList.arguments) {
        if (arg is NamedExpression) {
          final name = arg.name.label.name;
          final value = arg.expression;
          if (value is IntegerLiteral) {
            if (name == 'seconds') {
              return value.value;
            } else if (name == 'milliseconds') {
              return (value.value ?? 0) ~/ 1000;
            }
          }
        }
      }
    }
    return null;
  }
}

// =============================================================================
// require_drag_alternatives
// =============================================================================

/// Warns when drag gestures lack button alternatives.
///
/// Since: v4.1.5 | Updated: v4.13.0 | Rule version: v2
///
/// Drag gestures are difficult for users with motor disabilities.
/// Provide button alternatives for drag-to-reorder, swipe-to-delete, etc.
///
/// **BAD:**
/// ```dart
/// ReorderableListView(
///   children: items.map((item) => ListTile(key: Key(item.id))).toList(),
///   onReorder: (oldIndex, newIndex) => reorder(oldIndex, newIndex),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ReorderableListView(
///   children: items.map((item) => ListTile(
///     key: Key(item.id),
///     trailing: ReorderableDragStartListener(
///       index: items.indexOf(item),
///       child: IconButton(
///         icon: Icon(Icons.drag_handle),
///         onPressed: () => showReorderDialog(item),
///       ),
///     ),
///   )).toList(),
///   onReorder: (oldIndex, newIndex) => reorder(oldIndex, newIndex),
/// )
/// ```
class RequireDragAlternativesRule extends SaropaLintRule {
  RequireDragAlternativesRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'require_drag_alternatives',
    '[require_drag_alternatives] `[HEURISTIC]` Drag-based widget without '
        'obvious button alternative. Some users cannot perform drag gestures. {v2}',
    correctionMessage: 'Provide button-based alternatives for drag operations.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String? constructorName = node.constructorName.type.element?.name;

      // Check for drag-based widgets
      if (constructorName != 'ReorderableListView' &&
          constructorName != 'Dismissible' &&
          constructorName != 'LongPressDraggable' &&
          constructorName != 'Draggable') {
        return;
      }

      // Check if there's an alternative mechanism nearby
      final parentSource = node.parent?.toSource() ?? '';

      // Look for button alternatives in nearby code
      final hasButtonAlternative =
          parentSource.contains('IconButton') ||
          parentSource.contains('ElevatedButton') ||
          parentSource.contains('TextButton') ||
          parentSource.contains('PopupMenuButton') ||
          parentSource.contains('showDialog') ||
          parentSource.contains('showModalBottomSheet');

      if (!hasButtonAlternative) {
        reporter.atNode(node.constructorName, code);
      }
    });
  }
}

// =============================================================================
// prefer_focus_traversal_order
// =============================================================================

/// Warns when complex forms don't specify focus traversal order.
///
/// Since: v4.2.0 | Updated: v4.13.0 | Rule version: v2
///
/// Alias: focus_order, keyboard_navigation
///
/// For keyboard navigation, FocusTraversalOrder should be specified for
/// non-linear layouts. Without it, Tab key navigation may be confusing.
///
/// **BAD:**
/// ```dart
/// Row(
///   children: [
///     TextField(decoration: InputDecoration(labelText: 'City')),
///     TextField(decoration: InputDecoration(labelText: 'State')),
///     TextField(decoration: InputDecoration(labelText: 'ZIP')),
///   ],
/// )
/// // User tabs through in rendering order, which might not match visual order
/// ```
///
/// **GOOD:**
/// ```dart
/// FocusTraversalGroup(
///   policy: OrderedTraversalPolicy(),
///   child: Row(
///     children: [
///       FocusTraversalOrder(
///         order: NumericFocusOrder(1),
///         child: TextField(decoration: InputDecoration(labelText: 'City')),
///       ),
///       FocusTraversalOrder(
///         order: NumericFocusOrder(2),
///         child: TextField(decoration: InputDecoration(labelText: 'State')),
///       ),
///       FocusTraversalOrder(
///         order: NumericFocusOrder(3),
///         child: TextField(decoration: InputDecoration(labelText: 'ZIP')),
///       ),
///     ],
///   ),
/// )
/// ```
class PreferFocusTraversalOrderRule extends SaropaLintRule {
  PreferFocusTraversalOrderRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.low;

  @override
  RuleCost get cost => RuleCost.medium;

  @override
  Set<FileType>? get applicableFileTypes => {FileType.widget};

  static const LintCode _code = LintCode(
    'prefer_focus_traversal_order',
    '[prefer_focus_traversal_order] Form with multiple inputs in Row/Wrap '
        'layout without FocusTraversalOrder. Keyboard navigation may be confusing. {v2}',
    correctionMessage:
        'Wrap in FocusTraversalGroup and use FocusTraversalOrder for each input.',
    severity: DiagnosticSeverity.INFO,
  );

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;

      // Check for Row or Wrap containing multiple focusable widgets
      if (typeName != 'Row' && typeName != 'Wrap') return;

      // Count focusable children
      int focusableCount = 0;
      final String nodeSource = node.toSource();

      // Count common focusable widgets
      focusableCount += 'TextField'.allMatches(nodeSource).length;
      focusableCount += 'TextFormField'.allMatches(nodeSource).length;
      focusableCount += 'DropdownButton'.allMatches(nodeSource).length;
      focusableCount += 'Checkbox'.allMatches(nodeSource).length;
      focusableCount += 'Radio'.allMatches(nodeSource).length;
      focusableCount += 'Switch'.allMatches(nodeSource).length;

      // If 3+ focusable widgets and no FocusTraversalOrder, warn
      if (focusableCount >= 3) {
        if (!nodeSource.contains('FocusTraversalOrder') &&
            !nodeSource.contains('FocusTraversalGroup')) {
          reporter.atNode(node.constructorName, code);
        }
      }
    });
  }
}

// =============================================================================
// SEMANTICS CONTAINER RULES
// =============================================================================

/// Warns when Semantics wraps grouped widgets without `container: true`.
///
/// Since: v4.15.0 | Rule version: v1
///
/// Groups of related widgets inside a Semantics wrapper should set
/// `container: true` to indicate they form a single logical unit for
/// assistive technology navigation. Without it, screen readers may
/// announce each child separately rather than as a group.
///
/// **BAD:**
/// ```dart
/// Semantics(
///   label: 'User info',
///   child: Column(
///     children: [Text('Name'), Text('Email')],
///   ),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Semantics(
///   label: 'User info',
///   container: true,
///   child: Column(
///     children: [Text('Name'), Text('Email')],
///   ),
/// )
/// ```
class PreferSemanticsContainerRule extends SaropaLintRule {
  PreferSemanticsContainerRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'prefer_semantics_container',
    '[prefer_semantics_container] Semantics widget wraps a multi-child layout (Column, Row, Wrap, ListView) without container: true. Screen readers navigate each child individually rather than treating the group as a single logical unit, confusing users who expect related content to be announced together. Set container: true to group related semantic information. {v1}',
    correctionMessage:
        'Add container: true to the Semantics widget to group its children as a single navigable unit for screen readers.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Multi-child layout widgets that benefit from container grouping.
  static const Set<String> _groupWidgets = <String>{
    'Column',
    'Row',
    'Wrap',
    'ListView',
    'GridView',
    'Flex',
    'Stack',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Semantics') return;

      // Check if container: true is already set
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'container') {
          final String value = arg.expression.toSource();
          if (value == 'true') return; // Already has container: true
        }
      }

      // Check if child is a multi-child layout widget
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'child') {
          final Expression child = arg.expression;
          if (child is InstanceCreationExpression) {
            final String childType = child.constructorName.type.name.lexeme;
            if (_groupWidgets.contains(childType)) {
              reporter.atNode(node.constructorName, code);
              return;
            }
          }
        }
      }
    });
  }
}

/// Warns when Semantics wraps an Image that already has semanticLabel.
///
/// Since: v4.15.0 | Rule version: v1
///
/// An Image widget with a `semanticLabel` already provides accessible
/// information. Wrapping it in an additional Semantics widget causes
/// screen readers to announce the information twice, confusing users.
///
/// **BAD:**
/// ```dart
/// Semantics(
///   label: 'Company logo',
///   child: Image.asset('logo.png', semanticLabel: 'Company logo'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Image.asset('logo.png', semanticLabel: 'Company logo')
/// ```
class AvoidRedundantSemanticsRule extends SaropaLintRule {
  AvoidRedundantSemanticsRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.medium;

  @override
  RuleCost get cost => RuleCost.low;

  static const LintCode _code = LintCode(
    'avoid_redundant_semantics',
    '[avoid_redundant_semantics] Semantics widget wraps an Image that already has a semanticLabel. The screen reader announces the image description twice — once from the Semantics label and once from the Image semanticLabel — creating a confusing and repetitive experience for users relying on assistive technology. Remove the outer Semantics wrapper or the Image semanticLabel. {v1}',
    correctionMessage:
        'Remove the outer Semantics wrapper (preferred) or remove the semanticLabel from the Image to avoid duplicate announcements.',
    severity: DiagnosticSeverity.INFO,
  );

  /// Image widget types that support semanticLabel.
  static const Set<String> _imageTypes = <String>{'Image'};

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (typeName != 'Semantics') return;

      // Check if Semantics has a label
      bool hasLabel = false;
      Expression? childExpr;

      for (final Expression arg in node.argumentList.arguments) {
        if (arg is NamedExpression) {
          if (arg.name.label.name == 'label') hasLabel = true;
          if (arg.name.label.name == 'child') childExpr = arg.expression;
        }
      }

      if (!hasLabel || childExpr == null) return;

      // Check if child is an Image with semanticLabel
      if (childExpr is! InstanceCreationExpression) return;
      final String childType = childExpr.constructorName.type.name.lexeme;
      if (!_imageTypes.contains(childType)) return;

      // Check for semanticLabel in the Image
      for (final Expression arg in childExpr.argumentList.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'semanticLabel') {
          reporter.atNode(node.constructorName, code);
          return;
        }
      }
    });
  }
}

// =============================================================================
// avoid_color_only_meaning
// =============================================================================

/// Warns when color is the sole visual means of conveying meaning.
///
/// Since: v4.16.0 | Rule version: v1
///
/// Alias: color_only_meaning, wcag_1_4_1, colorblind_accessibility
///
/// Approximately 8% of men and 0.5% of women have color vision deficiency.
/// WCAG 1.4.1 (Use of Color) requires that color is never the only visual
/// means of conveying information. Always pair conditional color with a
/// secondary cue such as an icon, text label, or pattern.
///
/// This rule is broader than `avoid_color_only_indicators` (which only
/// checks Container). It checks any widget using conditional color and
/// verifies a companion Icon or Text exists nearby.
///
/// **BAD:**
/// ```dart
/// Card(
///   color: isError ? Colors.red : Colors.green,
///   child: SizedBox(width: 24, height: 24),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// Card(
///   color: isError ? Colors.red : Colors.green,
///   child: Icon(isError ? Icons.error : Icons.check),
/// )
/// ```
class AvoidColorOnlyMeaningRule extends SaropaLintRule {
  AvoidColorOnlyMeaningRule() : super(code: _code);

  @override
  LintImpact get impact => LintImpact.high;

  @override
  RuleCost get cost => RuleCost.medium;

  static const LintCode _code = LintCode(
    'avoid_color_only_meaning',
    '[avoid_color_only_meaning] Color is used as the sole visual indicator '
        'to convey meaning or state, which is inaccessible to approximately 8% '
        'of men and 0.5% of women with color vision deficiency. WCAG 1.4.1 '
        '(Use of Color) requires that color is never the only visual means of '
        'conveying information, indicating an action, or distinguishing a '
        'visual element. Always pair color with a secondary cue such as an '
        'icon, text label, underline, or pattern. {v1}',
    correctionMessage:
        'Add a non-color visual indicator alongside the conditional color: '
        'an Icon, Text label, border, shape, or pattern that conveys the '
        'same information independently of color.',
    severity: DiagnosticSeverity.WARNING,
  );

  // Container is excluded — already checked by avoid_color_only_indicators.
  static const Set<String> _colorBearingWidgets = <String>{
    'DecoratedBox',
    'ColoredBox',
    'Card',
    'AnimatedContainer',
    'Material',
    'PhysicalModel',
    'Chip',
    'CircleAvatar',
    'Badge',
  };

  static const Set<String> _companionWidgets = <String>{
    'Icon',
    'Text',
    'RichText',
    'Semantics',
  };

  @override
  void runWithReporter(
    SaropaDiagnosticReporter reporter,
    SaropaContext context,
  ) {
    context.addInstanceCreationExpression((InstanceCreationExpression node) {
      final String typeName = node.constructorName.type.name.lexeme;
      if (!_colorBearingWidgets.contains(typeName)) return;

      // Find color or backgroundColor named argument with conditional
      NamedExpression? conditionalColorArg;
      for (final Expression arg in node.argumentList.arguments) {
        if (arg is! NamedExpression) continue;
        final String name = arg.name.label.name;
        if ((name == 'color' || name == 'backgroundColor') &&
            arg.expression is ConditionalExpression) {
          conditionalColorArg = arg;
          break;
        }
      }
      if (conditionalColorArg == null) return;

      // Check if this widget or its parent has a companion Icon/Text
      if (_hasCompanionWidget(node)) return;

      reporter.atNode(conditionalColorArg);
    });
  }

  /// Walks the child/children of this widget and up to 3 parent levels
  /// looking for an Icon, Text, or Semantics companion widget.
  bool _hasCompanionWidget(InstanceCreationExpression node) {
    // Check own children
    if (_subtreeHasCompanion(node)) return true;

    // Walk up to 3 parent levels checking siblings
    AstNode? current = node;
    for (int i = 0; i < 3; i++) {
      current = current?.parent;
      if (current == null) break;
      if (current is InstanceCreationExpression) {
        if (_subtreeHasCompanion(current, excludeNode: node)) return true;
      }
    }
    return false;
  }

  bool _subtreeHasCompanion(
    InstanceCreationExpression node, {
    AstNode? excludeNode,
  }) {
    for (final Expression arg in node.argumentList.arguments) {
      if (arg is NamedExpression) {
        final String name = arg.name.label.name;
        if (name == 'child' || name == 'children') {
          return _expressionHasCompanion(arg.expression, excludeNode);
        }
      }
    }
    return false;
  }

  bool _expressionHasCompanion(Expression expr, AstNode? excludeNode) {
    if (identical(expr, excludeNode)) return false;
    if (expr is InstanceCreationExpression) {
      final String typeName = expr.constructorName.type.name.lexeme;
      if (_companionWidgets.contains(typeName)) return true;
      // Recurse into child/children
      return _subtreeHasCompanion(expr, excludeNode: excludeNode);
    }
    if (expr is ListLiteral) {
      for (final CollectionElement element in expr.elements) {
        if (element is Expression &&
            _expressionHasCompanion(element, excludeNode)) {
          return true;
        }
      }
    }
    return false;
  }
}
