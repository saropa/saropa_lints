// ignore_for_file: depend_on_referenced_packages, prefer_const_constructors
// ignore_for_file: prefer_const_literals_to_create_immutables

/// Fixture for `avoid_nested_scrollables_conflict` (same-axis nesting vs cross-axis).

import 'package:saropa_lints_example/flutter_mocks.dart';

void main() {}

/// Vertical outer, horizontal inner — no gesture conflict; must NOT lint.
class FixtureCrossAxisVerticalOuterHorizontalInner extends StatelessWidget {
  const FixtureCrossAxisVerticalOuterHorizontalInner({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: const Text('long overflowing button label'),
          ),
        ],
      ),
    );
  }
}

/// [PageView] defaults horizontal; [ListView] defaults vertical — cross-axis; no lint.
class FixtureCrossAxisPageViewOuterVerticalListInner extends StatelessWidget {
  const FixtureCrossAxisPageViewOuterVerticalListInner({super.key});

  @override
  Widget build(BuildContext context) {
    return PageView(
      children: <Widget>[
        ListView(children: const <Widget>[Text('page0')]),
      ],
    );
  }
}

/// Same axis (horizontal both) without physics — inner MUST lint.
class FixtureSameAxisHorizontalNested extends StatelessWidget {
  const FixtureSameAxisHorizontalNested({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // expect_lint: avoid_nested_scrollables_conflict
        child: const Text('wide content'),
      ),
    );
  }
}

/// Same axis vertical nesting — inner MUST lint.
class FixtureSameAxisVerticalNested extends StatelessWidget {
  const FixtureSameAxisVerticalNested({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        // expect_lint: avoid_nested_scrollables_conflict
        child: const Text('nested vertical'),
      ),
    );
  }
}

/// Cross-axis with explicit inner [physics] — no lint (physics satisfies rule).
class FixtureCrossAxisInnerHasExplicitPhysics extends StatelessWidget {
  const FixtureCrossAxisInnerHasExplicitPhysics({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: const Text('pinned horizontal strip'),
          ),
        ],
      ),
    );
  }
}
