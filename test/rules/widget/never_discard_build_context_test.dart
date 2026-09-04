import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:saropa_lints/src/rules/widget/never_discard_build_context_rules.dart';
import 'package:test/test.dart';

/// Tests for [NeverDiscardBuildContextRule].
///
/// The rule's detection is purely syntactic (first-parameter name/type of a
/// `builder:` closure, plus a body-scoped identifier-usage scan) — no
/// resolved-type information is required, so these tests parse source
/// directly via `parseString` and call the rule's own
/// [NeverDiscardBuildContextRule.wouldReportForTesting] entry point, which
/// runs the SAME detection code path the live rule registers via
/// `context.addFunctionExpression`. There is no hand-copied mirror here to
/// drift out of sync with the rule (see Finish Report 2026-09-04,
/// Recommendation 4) — a rule change is automatically exercised by these
/// tests without any parallel edit.
///
/// End-to-end firing (via the scan CLI, confirming the rule actually
/// reports on its fixture) is verified separately — see
/// `example/lib/widget_lifecycle/never_discard_build_context_fixture.dart`.
void main() {
  // Rule Instantiation: metadata smoke test.
  group('NeverDiscardBuildContextRule — instantiation', () {
    test('rule metadata satisfies the LintCode message contract', () {
      final rule = NeverDiscardBuildContextRule();
      expect(rule.code.lowerCaseName, 'never_discard_build_context');
      expect(
        rule.code.problemMessage,
        contains('[never_discard_build_context]'),
      );
      expect(rule.code.problemMessage.length, greaterThan(200));
      expect(rule.code.correctionMessage, isNotNull);
    });
  });

  group('NeverDiscardBuildContextRule — Builder', () {
    test('unused typed BuildContext param is reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext innerContext) {
      return Text(Theme.of(context).toString());
    },
  );
}
'''),
        isTrue,
      );
    });

    test('used typed BuildContext param is not reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext innerContext) {
      return Text(Theme.of(innerContext).toString());
    },
  );
}
'''),
        isFalse,
      );
    });

    test('param renamed to `_` is never flagged (escape hatch)', () {
      expect(
        _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext _) {
      return const SizedBox();
    },
  );
}
'''),
        isFalse,
      );
    });
  });

  group('NeverDiscardBuildContextRule — LayoutBuilder', () {
    test(
      'unused context with a USED second param (constraints) still reports',
      () {
        // Edge case 3 in the proposal: using another builder-supplied param
        // does not excuse ignoring context.
        expect(
          _wouldReport(r'''
Object w() {
  return LayoutBuilder(
    builder: (BuildContext ctx, BoxConstraints constraints) {
      return SizedBox(width: constraints.maxWidth);
    },
  );
}
'''),
          isTrue,
        );
      },
    );

    test('used context is not reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return LayoutBuilder(
    builder: (BuildContext ctx, BoxConstraints constraints) {
      return Text(Theme.of(ctx).toString());
    },
  );
}
'''),
        isFalse,
      );
    });
  });

  group('NeverDiscardBuildContextRule — untyped params', () {
    test('untyped conventional name (ctx) unused is reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return Builder(
    builder: (ctx) {
      return Text(Theme.of(context).toString());
    },
  );
}
'''),
        isTrue,
      );
    });

    test('untyped conventional name (ctx) used is not reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return Builder(
    builder: (ctx) {
      return Text(Theme.of(ctx).toString());
    },
  );
}
'''),
        isFalse,
      );
    });

    test('untyped non-conventional name is not treated as BuildContext', () {
      // e.g. an unrelated builder-style API whose first param isn't context.
      expect(
        _wouldReport(r'''
Object w() {
  return Builder(
    builder: (value) {
      return const SizedBox();
    },
  );
}
'''),
        isFalse,
      );
    });
  });

  group('NeverDiscardBuildContextRule — nested closures', () {
    test(
      'nested builder using its OWN context does not excuse the outer one',
      () {
        // Edge case 2 in the proposal.
        expect(
          _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext outerContext) {
      return Builder(
        builder: (BuildContext innerContext) {
          return Text(Theme.of(innerContext).toString());
        },
      );
    },
  );
}
'''),
          isTrue,
        );
      },
    );

    test('context captured into a variable and used later is not reported', () {
      // Edge case 4 in the proposal.
      expect(
        _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext innerContext) {
      final captured = innerContext;
      return Text(Theme.of(captured).toString());
    },
  );
}
'''),
        isFalse,
      );
    });

    test(
      'context used inside a nested onPressed callback is not reported',
      () {
        // Regression for Finish Report 2026-09-04 Issue #1: a very common
        // Flutter pattern is deferring a Navigator/ScaffoldMessenger call to
        // a button callback declared inside the builder body. That read must
        // count as a genuine use of the outer context.
        expect(
          _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext ctx) {
      return ElevatedButton(
        onPressed: () {
          Navigator.of(ctx).pop();
        },
        child: const Text('Close'),
      );
    },
  );
}
'''),
          isFalse,
        );
      },
    );

    test(
      'context used inside a nested Future.then callback is not reported',
      () {
        expect(
          _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext ctx) {
      future.then((value) {
        Navigator.of(ctx).pop();
      });
      return const SizedBox();
    },
  );
}
'''),
          isFalse,
        );
      },
    );

    test(
      'context used inside addPostFrameCallback is not reported',
      () {
        expect(
          _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext ctx) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Scrollable.ensureVisible(ctx);
      });
      return const SizedBox();
    },
  );
}
'''),
          isFalse,
        );
      },
    );

    test(
      'context used inside a locally-declared named function is not '
      'reported',
      () {
        // Regression for Finish Report 2026-09-04 Issue #2:
        // FunctionDeclarationStatement (a local named function) hides the
        // read the same way a FunctionExpression closure did.
        expect(
          _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext ctx) {
      void handleTap() {
        Navigator.of(ctx).pop();
      }
      return ElevatedButton(onPressed: handleTap, child: const Text('Go'));
    },
  );
}
'''),
          isFalse,
        );
      },
    );

    test(
      'nested onPressed that redeclares its own `ctx` param shadows the '
      'outer one, so the outer context is still unused',
      () {
        // True shadowing must still stop descent — the inner `ctx` here
        // refers to the inner parameter, not the outer builder's context.
        expect(
          _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext ctx) {
      return Builder(
        builder: (ctx) {
          return Text(ctx.toString());
        },
      );
    },
  );
}
'''),
          isTrue,
        );
      },
    );
  });

  group('NeverDiscardBuildContextRule — non-builder callbacks', () {
    test('unused first param on a non-`builder:` named argument is ignored', () {
      expect(
        _wouldReport(r'''
Object w() {
  return GestureDetector(
    onTap: (BuildContext unused) {},
  );
}
'''),
        isFalse,
      );
    });
  });

  // v2 false-positive fix. Before the widget-type gate, ANY `builder:`
  // argument was checked, so every one of these extremely common Flutter
  // patterns produced a warning by default in the Recommended tier. The
  // callbacks below exist to deliver snapshot/animation/provider values —
  // their context parameter is incidental and discarding it is idiomatic.
  group('NeverDiscardBuildContextRule — non-context-supplying builders', () {
    test('FutureBuilder with an unused context is not reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return FutureBuilder<int>(
    future: f,
    builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
      return Text('${snapshot.data}');
    },
  );
}
'''),
        isFalse,
      );
    });

    test('StreamBuilder with an unused context is not reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return StreamBuilder<int>(
    stream: s,
    builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
      return Text('${snapshot.data}');
    },
  );
}
'''),
        isFalse,
      );
    });

    test('AnimatedBuilder with an unused context is not reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return AnimatedBuilder(
    animation: controller,
    builder: (BuildContext context, Widget? child) {
      return Opacity(opacity: controller.value, child: child);
    },
  );
}
'''),
        isFalse,
      );
    });

    test('ValueListenableBuilder with an unused context is not reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return ValueListenableBuilder<int>(
    valueListenable: notifier,
    builder: (BuildContext context, int value, Widget? child) {
      return Text('$value');
    },
  );
}
'''),
        isFalse,
      );
    });

    test('Provider Consumer with an unused context is not reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return Consumer<CartModel>(
    builder: (BuildContext context, CartModel cart, Widget? child) {
      return Text('${cart.total}');
    },
  );
}
'''),
        isFalse,
      );
    });

    test('Provider Selector with an unused context is not reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return Selector<CartModel, int>(
    selector: (_, model) => model.count,
    builder: (BuildContext context, int count, Widget? child) {
      return Text('$count');
    },
  );
}
'''),
        isFalse,
      );
    });

    test('DraggableScrollableSheet with an unused context is not reported', () {
      expect(
        _wouldReport(r'''
Object w() {
  return DraggableScrollableSheet(
    builder: (BuildContext context, ScrollController controller) {
      return ListView(controller: controller);
    },
  );
}
'''),
        isFalse,
      );
    });

    test('a third-party *Builder widget is not reported', () {
      // Guards against ever "simplifying" the exact-match set into a
      // `.contains('Builder')` suffix test, which would re-admit every
      // builder-named widget in the ecosystem.
      expect(
        _wouldReport(r'''
Object w() {
  return ResponsiveBuilder(
    builder: (BuildContext context, SizingInformation sizing) {
      return Text('${sizing.screenSize}');
    },
  );
}
'''),
        isFalse,
      );
    });

    test('StatefulBuilder with an unused context IS still reported', () {
      // The third context-supplying widget must stay in scope.
      expect(
        _wouldReport(r'''
Object w() {
  return StatefulBuilder(
    builder: (BuildContext ctx, StateSetter setState) {
      return Text(Theme.of(context).toString());
    },
  );
}
'''),
        isTrue,
      );
    });
  });

  // v2 false-NEGATIVE fix: the shadow check used to inspect only nested
  // PARAMETER lists, so a nested local variable that merely reused the
  // context parameter's name made every later read look like a genuine use
  // and suppressed a real violation.
  group('NeverDiscardBuildContextRule — local-variable shadowing', () {
    test(
      'nested block redeclaring the name as a local does not count as a use',
      () {
        expect(
          _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext ctx) {
      {
        final ctx = computeSomethingElse();
        print(ctx.toString());
      }
      return const SizedBox();
    },
  );
}
'''),
          isTrue,
        );
      },
    );

    test('for-in loop variable reusing the name does not count as a use', () {
      expect(
        _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext ctx) {
      for (final ctx in items) {
        print(ctx);
      }
      return const SizedBox();
    },
  );
}
'''),
        isTrue,
      );
    });

    test('catch clause variable reusing the name does not count as a use', () {
      expect(
        _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext ctx) {
      try {
        risky();
      } catch (ctx) {
        print(ctx);
      }
      return const SizedBox();
    },
  );
}
'''),
        isTrue,
      );
    });

    test(
      'a genuine read outside the shadowing block is still counted as a use',
      () {
        // The shadow skip must be scoped to the declaring block only — a real
        // read elsewhere in the builder body still clears the violation.
        expect(
          _wouldReport(r'''
Object w() {
  return Builder(
    builder: (BuildContext ctx) {
      {
        final ctx = computeSomethingElse();
        print(ctx.toString());
      }
      return Text(Theme.of(ctx).toString());
    },
  );
}
'''),
          isFalse,
        );
      },
    );
  });
}

/// Parses [unitSource] and delegates to
/// [NeverDiscardBuildContextRule.wouldReportForTesting] so every test above
/// exercises the actual rule implementation.
bool _wouldReport(String unitSource) {
  final result = parseString(
    content: unitSource,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  return NeverDiscardBuildContextRule.wouldReportForTesting(result.unit);
}
