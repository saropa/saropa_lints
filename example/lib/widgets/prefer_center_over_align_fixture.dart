// ignore_for_file: unused_local_variable, prefer_const_constructors
// Test fixture for prefer_center_over_align rule

import '../flutter_mocks.dart';

void testPreferCenterOverAlign() {
  // BAD: Align with Alignment.center
  // BAD: Align with Alignment.center, should trigger lint
  // expect_lint: prefer_center_over_align
  final bad1 = Align(
    alignment: Alignment.center,
    child: Text('Hello'),
  );

  // GOOD: Using Center widget
  final good1 = Center(
    child: Text('Hello'),
  );

  // GOOD: Align with different alignment
  final good2 = Align(
    alignment: Alignment.topLeft,
    child: Text('Hello'),
  );

  // GOOD: Align with Alignment.centerLeft
  final good3 = Align(
    alignment: Alignment.centerLeft,
    child: Text('Hello'),
  );

  // GOOD: Align with Alignment.centerRight
  final good4 = Align(
    alignment: Alignment.centerRight,
    child: Text('Hello'),
  );
}

class TestWidget extends StatelessWidget {
  const TestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: In widget tree
        // BAD: Align with Alignment.center in widget tree, should trigger lint
        // expect_lint: prefer_center_over_align
        Align(
          alignment: Alignment.center,
          child: Icon(Icons.star),
        ),

        // GOOD: Already using Center
        Center(
          child: Icon(Icons.star),
        ),
      ],
    );
  }
}
