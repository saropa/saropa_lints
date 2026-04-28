// ignore_for_file: unused_element, undefined_class
// Test fixture for: prefer_layout_builder_for_constraints
// BAD: MediaQuery screen dimensions used like parent constraints
// GOOD: LayoutBuilder, screen fractions, breakpoints, viewInsets
import 'package:flutter/material.dart';

/// Narrow parent: using full screen width here ignores the 200px cap.
class BadMediaQueryWidthInConstrainedParent extends StatelessWidget {
  const BadMediaQueryWidthInConstrainedParent({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 200,
        child: SizedBox(
          // expect_lint: prefer_layout_builder_for_constraints
          width: MediaQuery.of(context).size.width,
          child: const Placeholder(),
        ),
      ),
    );
  }
}

class BadMediaQueryWidthAndHeight extends StatelessWidget {
  const BadMediaQueryWidthAndHeight({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // expect_lint: prefer_layout_builder_for_constraints
      width: MediaQuery.of(context).size.width,
      // expect_lint: prefer_layout_builder_for_constraints
      height: MediaQuery.sizeOf(context).height,
    );
  }
}

class BadMediaQuerySizeOfWidth extends StatelessWidget {
  const BadMediaQuerySizeOfWidth({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // expect_lint: prefer_layout_builder_for_constraints
      width: MediaQuery.sizeOf(context).width,
    );
  }
}

class BadDoubleWidthAccess extends StatelessWidget {
  const BadDoubleWidthAccess({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:
          // expect_lint: prefer_layout_builder_for_constraints
          MediaQuery.of(context).size.width +
          // expect_lint: prefer_layout_builder_for_constraints
          MediaQuery.of(context).size.width,
    );
  }
}

class BadAnimatedBuilderCallbackDimension extends StatefulWidget {
  const BadAnimatedBuilderCallbackDimension({super.key});

  @override
  State<BadAnimatedBuilderCallbackDimension> createState() =>
      _BadAnimatedBuilderCallbackDimensionState();
}

class _BadAnimatedBuilderCallbackDimensionState
    extends State<BadAnimatedBuilderCallbackDimension>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          // expect_lint: prefer_layout_builder_for_constraints
          width: MediaQuery.of(context).size.width,
          child: child ?? const Placeholder(),
        );
      },
    );
  }
}

// GOOD: intentional screen-relative sizing (not replaceable by LayoutBuilder)
class OkScreenFraction extends StatelessWidget {
  const OkScreenFraction({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.85,
      height: MediaQuery.of(context).size.height / 2,
    );
  }
}

// GOOD: responsive breakpoint (reads screen width, not parent slot)
class OkBreakpoint extends StatelessWidget {
  const OkBreakpoint({super.key});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.width > 600) {
      return const Placeholder();
    }
    return const SizedBox();
  }
}

// GOOD: keyboard insets — not targeted by this rule
class OkViewInsets extends StatelessWidget {
  const OkViewInsets({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
    );
  }
}

// GOOD: LayoutBuilder for parent constraints
class GoodLayoutBuilder extends StatelessWidget {
  const GoodLayoutBuilder({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          SizedBox(width: constraints.maxWidth, height: constraints.maxHeight),
    );
  }
}

// GOOD: lifecycle method snapshots should not require LayoutBuilder.
class OkDidChangeDependenciesSnapshot extends StatefulWidget {
  const OkDidChangeDependenciesSnapshot({super.key});

  @override
  State<OkDidChangeDependenciesSnapshot> createState() =>
      _OkDidChangeDependenciesSnapshotState();
}

class _OkDidChangeDependenciesSnapshotState
    extends State<OkDidChangeDependenciesSnapshot> {
  bool _isInitialized = false;
  double? _screenHeight;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) return;
    _captureScreenSize();
    _isInitialized = true;
  }

  void _captureScreenSize() {
    _screenHeight = MediaQuery.of(context).size.height;
  }

  @override
  Widget build(BuildContext context) {
    return Text('h: ${_screenHeight ?? 0}');
  }
}

// GOOD: callback without BuildContext parameter is not a build scope.
class OkAsyncCallbackSnapshot extends StatelessWidget {
  const OkAsyncCallbackSnapshot({super.key});

  @override
  Widget build(BuildContext context) {
    Future<void>.delayed(const Duration(milliseconds: 10), () {
      final double width = MediaQuery.of(context).size.width;
      debugPrint('captured width: $width');
    });
    return const SizedBox();
  }
}
