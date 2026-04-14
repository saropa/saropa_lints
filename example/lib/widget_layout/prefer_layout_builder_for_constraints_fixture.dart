// ignore_for_file: unused_element, undefined_class
// Test fixture for: prefer_layout_builder_for_constraints
// BAD: MediaQuery for sizing
// expect_lint: prefer_layout_builder_for_constraints
import 'package:flutter/material.dart';

class BadWidget extends StatelessWidget {
  const BadWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.sizeOf(context).height,
    );
  }
}

// GOOD: LayoutBuilder
class GoodWidget extends StatelessWidget {
  const GoodWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
      ),
    );
  }
}
