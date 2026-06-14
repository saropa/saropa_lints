// Oracle-backed regression tests for widget_layout_constraints_rules
// false-positive / false-negative audit (2026.06 audit). Flutter types are
// stubbed locally so the resolved harness runs without a Flutter dependency.
//
// Each fixture is wrapped in a `class X extends StatelessWidget` so the
// harness's FileType.widget gate is satisfied (the harness enforces
// applicableFileTypes, and FileType.widget is content-detected from the
// literal `extends StatelessWidget`).
library;

import 'package:saropa_lints/src/rules/widget/widget_layout_constraints_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

// Minimal local stubs. The rules under test key off constructor NAMES
// (node.constructorName.type.name.lexeme) for most checks, so the stubs only
// need to make the source parse and resolve. Constructors accept the union of
// arguments used across all fixtures.
const String _stubs = '''
class Widget { const Widget(); }
class StatelessWidget extends Widget { const StatelessWidget(); }
class BuildContext { const BuildContext(); }
class Key { const Key(); }
class PageStorageKey extends Key { const PageStorageKey(this.value); final Object value; }
class ValueKey extends Key { const ValueKey(this.value); final Object value; }
class Clip { static const Clip none = Clip(); const Clip(); }
class Alignment { static const Alignment center = Alignment(); const Alignment(); }
class StackFit { static const StackFit expand = StackFit(); const StackFit(); }
class SizedBox extends Widget {
  const SizedBox({this.width, this.height, this.child});
  final double? width; final double? height; final Widget? child;
}
class Container extends Widget {
  const Container({this.width, this.height, this.padding, this.margin, this.child});
  final double? width; final double? height; final Object? padding;
  final Object? margin; final Widget? child;
}
class Padding extends Widget {
  const Padding({this.padding, this.child});
  final Object? padding; final Widget? child;
}
class EdgeInsets {
  const EdgeInsets.all(this.value);
  final double value;
}
class Opacity extends Widget {
  const Opacity({this.opacity, this.child});
  final double? opacity; final Widget? child;
}
class AnimatedOpacity extends Widget {
  const AnimatedOpacity({this.opacity, this.child});
  final double? opacity; final Widget? child;
}
class Stack extends Widget {
  const Stack({this.alignment, this.fit, this.clipBehavior, this.children});
  final Alignment? alignment; final StackFit? fit; final Clip? clipBehavior;
  final List<Widget>? children;
}
class Positioned extends Widget {
  const Positioned({this.top, this.left, this.child});
  final double? top; final double? left; final Widget? child;
}
class Text extends Widget { const Text(this.data); final String data; }
class CircleAvatar extends Widget { const CircleAvatar(); }
class Badge extends Widget { const Badge(); }
class ListView extends Widget {
  const ListView.builder({this.itemCount, this.itemBuilder, this.key});
  final int? itemCount; final Object? itemBuilder; final Key? key;
}
class GridView extends Widget {
  const GridView.builder({this.itemCount, this.itemBuilder, this.key});
  final int? itemCount; final Object? itemBuilder; final Key? key;
}
class MediaQuery {
  const MediaQuery();
  static MediaQueryData of(BuildContext context) => const MediaQueryData();
}
class MediaQueryData {
  const MediaQueryData();
  Size get size => const Size();
}
class Size {
  const Size();
  double get width => 0; double get height => 0; double get aspectRatio => 0;
}
// A user type whose source text contains the "MediaQuery" + "size" substrings
// the old string-matching rule keyed on, but is not a real MediaQuery read.
class MyMediaQuerySize {
  const MyMediaQuerySize();
  double get scale => 1.0;
}
// A factory whose name contains "PageStorageKey" as a substring but returns a
// plain Key (not a PageStorageKey).
Key myPageStorageKeyFactory() => const ValueKey('x');
const double kDisabledOpacity = 0.5;
const double _privateOpacity = 0.5;
''';

void main() {
  // ==========================================================================
  // avoid_opacity_misuse: an underscore in the opacity source (e.g. a private
  // const `_privateOpacity`) is NOT animation intent. Detection must look at
  // expression node type, not a `_` substring.
  // ==========================================================================
  group('avoid_opacity_misuse', () {
    test('BAD: ternary opacity (animation intent) fires', () async {
      final codes = await reportedRuleCodes(AvoidOpacityMisuseRule(), '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) =>
      Opacity(opacity: visible ? 1.0 : 0.0, child: const Text('a'));
}
const bool visible = true;
''');
      expect(codes, contains('avoid_opacity_misuse'));
    });

    test('GOOD: static private const opacity does not fire', () async {
      final codes = await reportedRuleCodes(AvoidOpacityMisuseRule(), '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) =>
      Opacity(opacity: _privateOpacity, child: const Text('a'));
}
''');
      expect(codes, isEmpty);
    });

    test('GOOD: literal opacity does not fire', () async {
      final codes = await reportedRuleCodes(AvoidOpacityMisuseRule(), '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) =>
      const Opacity(opacity: 0.5, child: Text('a'));
}
''');
      expect(codes, isEmpty);
    });
  });

  // ==========================================================================
  // prefer_fractional_sizing: string `.contains('MediaQuery')` + `.contains('.size.')`
  // matched unrelated user code. Match the AST property-access chain instead.
  // ==========================================================================
  group('prefer_fractional_sizing', () {
    test('BAD: MediaQuery.of(context).size.width * 0.5 fires', () async {
      final codes = await reportedRuleCodes(PreferFractionalSizingRule(), '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) => SizedBox(
    width: MediaQuery.of(context).size.width * 0.5,
    child: const Text('a'),
  );
}
''');
      expect(codes, contains('prefer_fractional_sizing'));
    });

    test(
      'GOOD: unrelated user type with MediaQuery/size in its name',
      () async {
        final codes = await reportedRuleCodes(PreferFractionalSizingRule(), '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) {
    const MyMediaQuerySize myMediaQuerySize = MyMediaQuerySize();
    return SizedBox(width: myMediaQuerySize.scale * 0.5, child: const Text('a'));
  }
}
''');
        expect(codes, isEmpty);
      },
    );

    // Stronger probe: a receiver whose name contains "MediaQuery" AND a property
    // chain that literally contains ".size." but is not a MediaQuery API read.
    // This is the worst case the substring heuristic could mishandle.
    test(
      'GOOD: non-MediaQuery chain literally containing ".size." stays silent',
      () async {
        final codes = await reportedRuleCodes(PreferFractionalSizingRule(), '''
$_stubs
class FakeMediaQueryHolder {
  const FakeMediaQueryHolder();
  Size get size => const Size();
}
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) {
    const FakeMediaQueryHolder fakeMediaQuery = FakeMediaQueryHolder();
    return SizedBox(width: fakeMediaQuery.size.width * 0.5, child: const Text('a'));
  }
}
''');
        // After the fix this must stay silent (only real MediaQuery.of/.sizeOf
        // reads should match). Documented as the expectation the fix must meet.
        expect(codes, isEmpty);
      },
    );
  });

  // ==========================================================================
  // prefer_page_storage_key: `keySource.contains('PageStorageKey')` was fooled
  // by names containing the substring. Inspect the key expression's static type.
  // ==========================================================================
  group('prefer_page_storage_key', () {
    test('BAD: ListView.builder without a key fires', () async {
      final codes = await reportedRuleCodes(PreferPageStorageKeyRule(), '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) => ListView.builder(
    itemCount: 3,
    itemBuilder: (BuildContext c, int i) => const Text('a'),
  );
}
''');
      expect(codes, contains('prefer_page_storage_key'));
    });

    test('GOOD: real PageStorageKey suppresses the warning', () async {
      final codes = await reportedRuleCodes(PreferPageStorageKeyRule(), '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) => ListView.builder(
    key: const PageStorageKey('list'),
    itemCount: 3,
    itemBuilder: (BuildContext c, int i) => const Text('a'),
  );
}
''');
      expect(codes, isEmpty);
    });

    test('BAD: factory whose NAME contains PageStorageKey but returns a plain '
        'Key must still fire (was a false negative)', () async {
      final codes = await reportedRuleCodes(PreferPageStorageKeyRule(), '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) => ListView.builder(
    key: myPageStorageKeyFactory(),
    itemCount: 3,
    itemBuilder: (BuildContext c, int i) => const Text('a'),
  );
}
''');
      expect(codes, contains('prefer_page_storage_key'));
    });
  });

  // ==========================================================================
  // avoid_stack_without_positioned: a badge over an avatar where the Stack
  // declares its own `alignment` is intentional; do not flag.
  // ==========================================================================
  group('avoid_stack_without_positioned', () {
    test(
      'BAD: Stack with no alignment/fit and an unpositioned child fires',
      () async {
        final codes = await reportedRuleCodes(
          AvoidStackWithoutPositionedRule(),
          '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) => const Stack(
    children: <Widget>[CircleAvatar(), Badge()],
  );
}
''',
        );
        expect(codes, contains('avoid_stack_without_positioned'));
      },
    );

    test(
      'GOOD: Stack with alignment (intentional overlap) stays silent',
      () async {
        final codes = await reportedRuleCodes(
          AvoidStackWithoutPositionedRule(),
          '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) => const Stack(
    alignment: Alignment.center,
    children: <Widget>[CircleAvatar(), Badge()],
  );
}
''',
        );
        expect(codes, isEmpty);
      },
    );
  });

  // ==========================================================================
  // avoid_hardcoded_layout_values: the two `value > 4.0` arms reported
  // identically (dead carve-out). After the fix only the intended condition
  // fires; verify a representative BAD case still reports.
  // ==========================================================================
  // Fixtures exercise the EdgeInsets argument path: the rule registers its
  // SizedBox/Container check and its EdgeInsets check as two separate
  // addInstanceCreationExpression callbacks, and the CompatVisitor keeps only
  // the last-registered callback per node type, so the EdgeInsets check is the
  // one that actually executes. Both paths share `_checkForHardcodedValue`,
  // where the dead `value > 4.0` carve-out lives.
  group('avoid_hardcoded_layout_values', () {
    test('BAD: EdgeInsets.all(13) fires (integer)', () async {
      final codes = await reportedRuleCodes(
        AvoidHardcodedLayoutValuesRule(),
        '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.all(13), child: Text('a'));
}
''',
      );
      expect(codes, contains('avoid_hardcoded_layout_values'));
    });

    test('BAD: EdgeInsets.all(12.5) fires (non-integer double)', () async {
      final codes = await reportedRuleCodes(
        AvoidHardcodedLayoutValuesRule(),
        '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.all(12.5), child: Text('a'));
}
''',
      );
      expect(codes, contains('avoid_hardcoded_layout_values'));
    });

    test('BAD: EdgeInsets.all(8.0) fires (integer-valued double)', () async {
      final codes = await reportedRuleCodes(
        AvoidHardcodedLayoutValuesRule(),
        '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.all(8.0), child: Text('a'));
}
''',
      );
      expect(codes, contains('avoid_hardcoded_layout_values'));
    });

    test(
      'GOOD: small acceptable value (EdgeInsets.all(2)) stays silent',
      () async {
        final codes = await reportedRuleCodes(
          AvoidHardcodedLayoutValuesRule(),
          '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.all(2), child: Text('a'));
}
''',
        );
        expect(codes, isEmpty);
      },
    );
  });

  // ==========================================================================
  // prefer_spacing_over_sizedbox: toSource() equality treated SizedBox(height: 8)
  // and SizedBox(height: 8.0) as distinct spacers. Compare numeric values.
  // ==========================================================================
  group('prefer_spacing_over_sizedbox', () {
    test(
      'BAD: numerically-equal spacers (8 vs 8.0) are one spacer => fires',
      () async {
        final codes = await reportedRuleCodes(
          PreferSpacingOverSizedBoxRule(),
          '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) => const Column(
    children: <Widget>[
      Text('A'),
      SizedBox(height: 8),
      Text('B'),
      SizedBox(height: 8.0),
      Text('C'),
    ],
  );
}
class Column extends Widget {
  const Column({this.spacing, this.children});
  final double? spacing; final List<Widget>? children;
}
''',
        );
        expect(codes, contains('prefer_spacing_over_sizedbox'));
      },
    );

    test('GOOD: genuinely different spacer heights stay silent', () async {
      final codes = await reportedRuleCodes(PreferSpacingOverSizedBoxRule(), '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) => const Column(
    children: <Widget>[
      Text('A'),
      SizedBox(height: 8),
      Text('B'),
      SizedBox(height: 16),
      Text('C'),
    ],
  );
}
class Column extends Widget {
  const Column({this.spacing, this.children});
  final double? spacing; final List<Widget>? children;
}
''');
      expect(codes, isEmpty);
    });
  });

  // ==========================================================================
  // avoid_builder_index_out_of_bounds: `_extractListName` stripped the receiver
  // chain, so a guard on a DIFFERENT object's `items` was accepted as valid.
  // Compare full receiver chains via AST IndexExpression traversal.
  // ==========================================================================
  group('avoid_builder_index_out_of_bounds', () {
    test('GOOD: itemCount + guard on the same list stays silent', () async {
      final codes = await reportedRuleCodes(
        AvoidBuilderIndexOutOfBoundsRule(),
        '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) {
    final List<String> items = <String>['a'];
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (BuildContext c, int index) {
        if (index >= items.length) return const Text('');
        return Text(items[index]);
      },
    );
  }
}
''',
      );
      expect(codes, isEmpty);
    });

    test('BAD: subscript on widget.items but guard is on a DIFFERENT '
        'object.items (was a false negative)', () async {
      final codes = await reportedRuleCodes(
        AvoidBuilderIndexOutOfBoundsRule(),
        '''
$_stubs
class Other { const Other(); List<String> get items => const <String>['a']; }
class W extends StatelessWidget {
  const W();
  final List<String> items = const <String>['a'];
  Widget build(BuildContext context) {
    const Other other = Other();
    return ListView.builder(
      itemBuilder: (BuildContext c, int index) {
        if (index >= other.items.length) return const Text('');
        return Text(items[index]);
      },
    );
  }
}
''',
      );
      expect(codes, contains('avoid_builder_index_out_of_bounds'));
    });

    test(
      'GOOD: guard on the same receiver chain (widget.items) stays silent',
      () async {
        final codes = await reportedRuleCodes(
          AvoidBuilderIndexOutOfBoundsRule(),
          '''
$_stubs
class W extends StatelessWidget {
  const W();
  final List<String> items = const <String>['a'];
  Widget build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (BuildContext c, int index) {
        if (index >= items.length) return const Text('');
        return Text(items[index]);
      },
    );
  }
}
''',
        );
        expect(codes, isEmpty);
      },
    );
  });

  // ==========================================================================
  // avoid_fixed_dimensions: a negative literal width (`-300.0`) is a
  // PrefixExpression, never captured as Integer/DoubleLiteral.
  // ==========================================================================
  group('avoid_fixed_dimensions', () {
    test('BAD: large positive fixed width fires', () async {
      final codes = await reportedRuleCodes(AvoidFixedDimensionsRule(), '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) =>
      const SizedBox(width: 300.0, child: Text('a'));
}
''');
      expect(codes, contains('avoid_fixed_dimensions'));
    });

    test('reproduce: negative large fixed width (-300.0) handling', () async {
      final codes = await reportedRuleCodes(AvoidFixedDimensionsRule(), '''
$_stubs
class W extends StatelessWidget {
  const W();
  Widget build(BuildContext context) =>
      const SizedBox(width: -300.0, child: Text('a'));
}
''');
      // Documented behavior after the fix: negative dimensions are below the
      // positive threshold, so the rule does not flag them. See report.
      expect(codes, isEmpty);
    });
  });
}
