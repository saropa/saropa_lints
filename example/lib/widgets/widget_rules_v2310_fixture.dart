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
        // BAD: Expanded outside Flex, should trigger lint
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
      // BAD: Flexible outside Flex, should trigger lint
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

// GOOD: Expanded returned from helper method used in Row
// This is a common pattern for caching children in StatefulWidget
class GoodExpandedInHelperMethod extends StatelessWidget {
  const GoodExpandedInHelperMethod({super.key});

  List<Widget> _buildChildren() {
    // OK: Helper method returns Expanded for use in Flex at call site
    return [Expanded(child: Container())];
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: _buildChildren());
  }
}

// GOOD: Expanded in List.generate used in Column
class GoodExpandedInListGenerate extends StatelessWidget {
  const GoodExpandedInListGenerate({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      // OK: List.generate builds children for Flex widget
      children: List.generate(3, (i) => Expanded(child: Text('$i'))),
    );
  }
}

// GOOD: Expanded in .map() used in Row
class GoodExpandedInMap extends StatelessWidget {
  const GoodExpandedInMap({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [1, 2, 3];
    return Row(
      // OK: .map() builds children for Flex widget
      children: items.map((i) => Expanded(child: Text('$i'))).toList(),
    );
  }
}

// GOOD: Expanded inside List.generate callback in helper method
// Combined pattern: return + List.generate + helper method
class GoodExpandedInListGenerateHelper extends StatelessWidget {
  const GoodExpandedInListGenerateHelper({super.key});

  List<Widget> _buildChildren() {
    return List<Widget>.generate(3, (int index) {
      return Expanded(child: Text('Item $index'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: _buildChildren());
  }
}

// GOOD: Expanded inside List.generate with field assignment in helper
class GoodExpandedInListGenerateField extends StatefulWidget {
  const GoodExpandedInListGenerateField({super.key});

  @override
  State<GoodExpandedInListGenerateField> createState() =>
      _GoodExpandedInListGenerateFieldState();
}

class _GoodExpandedInListGenerateFieldState
    extends State<GoodExpandedInListGenerateField> {
  List<Widget>? _cached;

  List<Widget> _buildChildren() {
    _cached ??= List<Widget>.generate(3, (int index) {
      return Expanded(child: Text('Item $index'));
    });
    return _cached!;
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: _buildChildren());
  }
}

// GOOD: Expanded assigned to variable
class GoodExpandedAssignedToVariable extends StatelessWidget {
  const GoodExpandedAssignedToVariable({super.key});

  @override
  Widget build(BuildContext context) {
    // OK: Assigned to variable, trust developer placement
    final Widget child = Expanded(child: Container());
    return Row(children: [child]);
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
    // BAD: Stack with non-Positioned children, should trigger lint
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
// prefer_expanded_at_call_site
// =========================================================================
// Warns when build() returns Expanded/Flexible directly.
// Better to add Expanded at the call site for flexibility.

// BAD: Returning Expanded from build()
class BadExpandedInBuild extends StatelessWidget {
  const BadExpandedInBuild({super.key});

  @override
  // BAD: Returning Expanded from build(), should trigger lint
  // expect_lint: prefer_expanded_at_call_site
  Widget build(BuildContext context) => Expanded(
        child: Column(children: const []),
      );
}

// BAD: Returning Flexible from build()
class BadFlexibleInBuild extends StatelessWidget {
  const BadFlexibleInBuild({super.key});

  @override
  Widget build(BuildContext context) {
    // BAD: Returning Flexible from build(), should trigger lint
    // expect_lint: prefer_expanded_at_call_site
    return Flexible(child: Container());
  }
}

// GOOD: Return content, let caller add Expanded
class GoodNoExpandedInBuild extends StatelessWidget {
  const GoodNoExpandedInBuild({super.key});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: const [],
      );
}

// GOOD: Expanded used inside build but not as return value
class GoodExpandedAsChild extends StatelessWidget {
  const GoodExpandedAsChild({super.key});

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

// BAD: Returning Expanded from conditional expression
class BadExpandedInTernary extends StatelessWidget {
  const BadExpandedInTernary({super.key});
  final bool useExpanded = true;

  @override
  Widget build(BuildContext context) {
    // BAD: Returning Expanded from conditional, should trigger lint
    // expect_lint: prefer_expanded_at_call_site
    return useExpanded ? Expanded(child: Container()) : Container();
  }
}

// BAD: Returning Expanded from else branch
class BadExpandedInElseBranch extends StatelessWidget {
  const BadExpandedInElseBranch({super.key});
  final bool showLoading = false;

  @override
  Widget build(BuildContext context) {
    if (showLoading) {
      return Container();
    } else {
      // BAD: Returning Flexible from else branch, should trigger lint
      // expect_lint: prefer_expanded_at_call_site
      return Flexible(child: Container());
    }
  }
}

// BAD: Multiple returns with Expanded in one branch
class BadExpandedInBranch extends StatelessWidget {
  const BadExpandedInBranch({super.key});
  final bool isActive = true;

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      // BAD: Expanded in branch, should trigger lint
      // expect_lint: prefer_expanded_at_call_site
      return Expanded(child: Container());
    }
    return Container();
  }
}

// GOOD: Ternary returning non-Expanded widgets
class GoodTernaryNoExpanded extends StatelessWidget {
  const GoodTernaryNoExpanded({super.key});
  final bool showA = true;

  @override
  Widget build(BuildContext context) {
    return showA ? Container() : Column(children: const []);
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

// =========================================================================
// Widget Rules (from v4.1.7)
// =========================================================================

// BAD: DateFormat without locale
class BadDateFormatWidget extends StatelessWidget {
  const BadDateFormatWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // expect_lint: require_locale_for_text
    final date = DateFormatMock.yMd().format(DateTime.now());
    return Text(date);
  }
}

// GOOD: DateFormat with locale
class GoodDateFormatWidget extends StatelessWidget {
  const GoodDateFormatWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final date = DateFormatMock.yMd('en_US').format(DateTime.now());
    return Text(date);
  }
}

// BAD: Destructive dialog without barrierDismissible
void showDeleteDialog(BuildContext context) {
  // expect_lint: require_dialog_barrier_consideration
  showDialogMock(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete account?'),
      content: Text('This action cannot be undone.'),
    ),
  );
}

// GOOD: Destructive dialog with barrierDismissible: false
void showDeleteDialogGood(BuildContext context) {
  showDialogMock(
    context: context,
    barrierDismissible: false, // Explicit
    builder: (context) => AlertDialog(
      title: Text('Delete account?'),
      content: Text('This action cannot be undone.'),
    ),
  );
}

// Mock classes for widget rules
class DateFormatMock {
  DateFormatMock.yMd([String? locale]);
  String format(DateTime date) => '';
}

Future<T?> showDialogMock<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool barrierDismissible = true,
}) async =>
    null;

class AlertDialog extends Widget {
  const AlertDialog({super.key, this.title, this.content});
  final Widget? title;
  final Widget? content;
}
