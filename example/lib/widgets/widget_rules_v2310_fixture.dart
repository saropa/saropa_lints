// ignore_for_file: unused_local_variable, unused_element, unused_field
// ignore_for_file: prefer_const_constructors
// Test fixture for widget rules added in v2.3.10

import '../flutter_mocks.dart';

// =========================================================================
// avoid_expanded_outside_flex
// =========================================================================
// Warns when Expanded or Flexible is used outside Row, Column, or Flex.

// BAD: Expanded inside Stack (not a Flex widget)
class BadExpandedInStack extends StatelessWidget {
  const BadExpandedInStack({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // expect_lint: avoid_expanded_outside_flex
        Expanded(child: Container()),
      ],
    );
  }
}

// BAD: Flexible inside Center (not a Flex widget)
class BadFlexibleInCenter extends StatelessWidget {
  const BadFlexibleInCenter({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      // expect_lint: avoid_expanded_outside_flex
      child: Flexible(child: Container()),
    );
  }
}

// GOOD: Expanded inside Column (Flex widget)
class GoodExpandedInColumn extends StatelessWidget {
  const GoodExpandedInColumn({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: Container()),
        Container(),
      ],
    );
  }
}

// GOOD: Flexible inside Row (Flex widget)
class GoodFlexibleInRow extends StatelessWidget {
  const GoodFlexibleInRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(child: Container()),
        Container(),
      ],
    );
  }
}

// =========================================================================
// avoid_stack_without_positioned
// =========================================================================
// Warns when Stack has non-Positioned children that may overlap incorrectly.

// BAD: Stack with non-Positioned children
class BadStackWithoutPositioned extends StatelessWidget {
  const BadStackWithoutPositioned({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: avoid_stack_without_positioned
    return Stack(
      children: [
        Container(color: Colors.red),
        Container(color: Colors.blue), // Not positioned!
      ],
    );
  }
}

// GOOD: Stack with Positioned children
class GoodStackWithPositioned extends StatelessWidget {
  const GoodStackWithPositioned({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: Container(color: Colors.red)),
        Positioned(
          top: 10,
          left: 10,
          child: Container(color: Colors.blue),
        ),
      ],
    );
  }
}

// GOOD: Stack with single child (no overlap concern)
class GoodStackSingleChild extends StatelessWidget {
  const GoodStackSingleChild({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: Colors.red),
      ],
    );
  }
}

// =========================================================================
// Helper mocks
// =========================================================================

class Expanded extends Widget {
  const Expanded({super.key, required this.child});
  final Widget child;
}

class Flexible extends Widget {
  const Flexible({super.key, required this.child});
  final Widget child;
}

class Stack extends Widget {
  const Stack({super.key, this.children = const []});
  final List<Widget> children;
}

class Center extends Widget {
  const Center({super.key, this.child});
  final Widget? child;
}

class Positioned extends Widget {
  const Positioned({
    super.key,
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.child,
  });
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final Widget child;

  const Positioned.fill({super.key, required this.child})
      : top = 0,
        left = 0,
        right = 0,
        bottom = 0;
}

class Colors {
  static const Color red = Color(0xFFFF0000);
  static const Color blue = Color(0xFF0000FF);
}

class Color {
  const Color(this.value);
  final int value;
}
