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
