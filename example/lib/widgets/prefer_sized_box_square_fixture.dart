// ignore_for_file: unused_local_variable, prefer_const_constructors
// Test fixture for prefer_sized_box_square rule

import '../flutter_mocks.dart';

void testPreferSizedBoxSquare() {
  // BAD: SizedBox with identical width and height
  // BAD: SizedBox with identical width and height, should trigger lint
  // expect_lint: prefer_sized_box_square
  final bad1 = SizedBox(width: 50, height: 50);

  // BAD: SizedBox with identical variable values
  const size = 100.0;
  // BAD: SizedBox with identical variable values, should trigger lint
  // expect_lint: prefer_sized_box_square
  final bad2 = SizedBox(width: size, height: size);

  // BAD: SizedBox with identical expressions
  // BAD: SizedBox with identical expressions, should trigger lint
  // expect_lint: prefer_sized_box_square
  final bad3 = SizedBox(width: 20.0, height: 20.0);

  // GOOD: Already using SizedBox.square
  final good1 = SizedBox.square(dimension: 50);

  // GOOD: Different width and height
  final good2 = SizedBox(width: 50, height: 100);

  // GOOD: Only width specified
  final good3 = SizedBox(width: 50);

  // GOOD: Only height specified
  final good4 = SizedBox(height: 50);

  // GOOD: SizedBox.shrink
  final good5 = SizedBox.shrink();

  // GOOD: SizedBox.expand
  final good6 = SizedBox.expand();
}

class TestWidget extends StatelessWidget {
  const TestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: In widget tree
        // BAD: SizedBox with identical width and height in widget tree, should trigger lint
        // expect_lint: prefer_sized_box_square
        SizedBox(width: 16, height: 16),

        // GOOD: Already correct
        SizedBox.square(dimension: 16),
      ],
    );
  }
}
