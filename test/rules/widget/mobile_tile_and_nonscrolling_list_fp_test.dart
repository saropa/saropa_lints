import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/saropa_lints.dart';
import 'package:saropa_lints/src/widget_ancestor_utils.dart';
import 'package:test/test.dart';

import '../../support/syntactic_rule_harness.dart';

/// Behavioral tests for the false-positive fixes covering marker tap targets,
/// non-scrolling / dialog lists and stretch Columns. `new Foo(...)` is used so
/// the parse-only harness yields InstanceCreationExpression nodes (bare calls
/// stay MethodInvocation until resolved).
void main() {
  int count(SaropaLintRule rule, String body) =>
      runRuleSyntactic(
        rule,
        // Flutter import + widget class so file-type gates classify as widget.
        "import 'package:flutter/material.dart';\n"
        'class W extends StatelessWidget { void f() { $body } }',
      ).length;

  group('marker / Semantics-button tap targets', () {
    const String bare = 'new GestureDetector(onTap: f, child: x)';
    const String inMarker = 'new Marker(child: $bare)';
    const String inSemantics = 'new Semantics(button: true, child: $bare)';
    const String inSemanticsNoButton = 'new Semantics(label: "a", child: $bare)';

    test('require_focus_indicator', () {
      expect(count(RequireFocusIndicatorRule(), '$bare;'), 1);
      expect(count(RequireFocusIndicatorRule(), '$inMarker;'), 0);
      expect(count(RequireFocusIndicatorRule(), '$inSemantics;'), 0);
      expect(count(RequireFocusIndicatorRule(), '$inSemanticsNoButton;'), 1);
    });

    test('require_hover_states', () {
      expect(count(RequireHoverStatesRule(), '$bare;'), 1);
      expect(count(RequireHoverStatesRule(), '$inMarker;'), 0);
      expect(count(RequireHoverStatesRule(), '$inSemantics;'), 0);
    });

    test('prefer_cursor_for_buttons', () {
      expect(count(PreferCursorForButtonsRule(), '$bare;'), 1);
      expect(count(PreferCursorForButtonsRule(), '$inMarker;'), 0);
      expect(count(PreferCursorForButtonsRule(), '$inSemantics;'), 0);
    });
  });

  group('avoid_gesture_without_behavior', () {
    final rule = AvoidGestureWithoutBehaviorRule();

    test('flags a bare detector over a plain child (true positive)', () {
      expect(count(rule, 'new GestureDetector(onTap: f, child: new Text(a));'), 1);
    });

    test('skips sized Stack and painted-box children', () {
      expect(
        count(
          rule,
          'new GestureDetector(onTap: f, child: new SizedBox(width: 9, '
          'child: new Stack(children: [])));',
        ),
        0,
      );
      expect(
        count(
          rule,
          'new GestureDetector(onTap: f, child: new Container(color: c));',
        ),
        0,
      );
    });

    test('still flags an undecorated Container child', () {
      expect(
        count(
          rule,
          'new GestureDetector(onTap: f, child: new Container(child: t));',
        ),
        1,
      );
    });
  });

  group('refresh indicator and scroll controller on non-scrolling lists', () {
    // The parse-only harness yields `ListView.builder` as a prefixed type
    // (`builder` with import prefix `ListView`), which the `.builder`-only
    // rules cannot match until resolved; so true positives for those rules
    // are proven at the helper level below, and here only the silent cases
    // are asserted (they guard against regressions once resolved).
    const String never =
        'new ListView.builder(shrinkWrap: true, '
        'physics: const NeverScrollableScrollPhysics(), '
        'itemCount: items.length, itemBuilder: b)';
    const String plain =
        'new ListView.builder(itemCount: items.length, itemBuilder: b)';

    test('require_refresh_indicator_on_lists: true positive + skips', () {
      final r = RequireRefreshIndicatorOnListsRule();
      expect(count(r, 'new ListView(children: c);'), 1);
      expect(
        count(
          r,
          'new GridView(shrinkWrap: true, '
          'physics: const NeverScrollableScrollPhysics(), children: c);',
        ),
        0,
      );
      expect(count(r, 'new AlertDialog(content: new ListView(children: c));'), 0);
      expect(
        count(r, 'showDialog(builder: (c) => new ListView(children: c));'),
        0,
      );
    });

    test('require_refresh_indicator / require_scroll_controller stay silent', () {
      expect(count(RequireRefreshIndicatorRule(), '$never;'), 0);
      expect(count(RequireScrollControllerRule(), '$never;'), 0);
      expect(
        count(RequireRefreshIndicatorRule(), 'new AlertDialog(content: $plain);'),
        0,
      );
      expect(
        count(RequireScrollControllerRule(), 'new AlertDialog(content: $plain);'),
        0,
      );
    });
  });

  group('widget_ancestor_utils helpers (true positives)', () {
    ArgumentList argsOf(String src) {
      final unit = parseString(content: 'void f() { $src; }').unit;
      final finder = _FirstCreation();
      unit.accept(finder);
      return finder.found!.argumentList;
    }

    test('hasNeverScrollablePhysics detects only the never-scroll physics', () {
      expect(
        hasNeverScrollablePhysics(
          argsOf('new ListView(physics: const NeverScrollableScrollPhysics())'),
        ),
        isTrue,
      );
      expect(
        hasNeverScrollablePhysics(
          argsOf('new ListView(physics: const BouncingScrollPhysics())'),
        ),
        isFalse,
      );
      expect(hasNeverScrollablePhysics(argsOf('new ListView()')), isFalse);
    });

    test('isInsideTransientOverlay is true only under dialog-like hosts', () {
      bool inside(String src) {
        final unit = parseString(content: 'void f() { $src; }').unit;
        final finder = _FirstCreation(typeName: 'Target');
        unit.accept(finder);
        return isInsideTransientOverlay(finder.found!);
      }

      expect(inside('new AlertDialog(content: new Target())'), isTrue);
      expect(inside('showDialog(builder: (c) => new Target())'), isTrue);
      expect(inside('new Column(children: [new Target()])'), isFalse);
    });
  });

  group('prefer_intrinsic_dimensions', () {
    final rule = PreferIntrinsicDimensionsRule();
    const String col =
        'new Column(crossAxisAlignment: CrossAxisAlignment.stretch)';

    test('flags stretch Column as direct Row child (true positive)', () {
      expect(count(rule, 'new Row(children: [$col]);'), 1);
    });

    test('skips stretch Column where the parent bounds width', () {
      expect(count(rule, '$col;'), 0);
      expect(count(rule, 'new Row(children: [new Expanded(child: $col)]);'), 0);
      expect(count(rule, 'new Padding(child: $col);'), 0);
    });
  });
}

/// Finds the first InstanceCreationExpression (optionally of [typeName]).
class _FirstCreation extends RecursiveAstVisitor<void> {
  _FirstCreation({this.typeName});
  final String? typeName;
  InstanceCreationExpression? found;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (found == null &&
        (typeName == null ||
            node.constructorName.type.name.lexeme == typeName)) {
      found = node;
    }
    super.visitInstanceCreationExpression(node);
  }
}
