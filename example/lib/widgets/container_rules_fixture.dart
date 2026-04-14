// ignore_for_file: unused_local_variable, prefer_const_constructors
// Test fixture for Container widget replacement rules

import 'package:saropa_lints_example/flutter_mocks.dart';

void testPreferAlignOverContainer() {
  // BAD: Container with only alignment
  // BAD: Container with only alignment, should trigger lint
  // expect_lint: prefer_align_over_container
  final bad1 = Container(
    alignment: Alignment.topLeft,
    child: Text('Hello'),
  );

  // GOOD: Using Align widget
  final good1 = Align(
    alignment: Alignment.topLeft,
    child: Text('Hello'),
  );

  // GOOD: Container with multiple properties
  final good2 = Container(
    alignment: Alignment.center,
    color: Colors.red,
    child: Text('Hello'),
  );
}

void testPreferPaddingOverContainer() {
  // BAD: Container with only padding
  // BAD: Container with only padding, should trigger lint
  // expect_lint: prefer_padding_over_container
  final bad1 = Container(
    padding: EdgeInsets.all(16),
    child: Text('Hello'),
  );

  // GOOD: Using Padding widget
  final good1 = Padding(
    padding: EdgeInsets.all(16),
    child: Text('Hello'),
  );

  // GOOD: Container with multiple properties
  final good2 = Container(
    padding: EdgeInsets.all(16),
    margin: EdgeInsets.all(8),
    child: Text('Hello'),
  );
}

void testPreferConstrainedBoxOverContainer() {
  // BAD: Container with only constraints
  // BAD: Container with only constraints, should trigger lint
  // expect_lint: prefer_constrained_box_over_container
  final bad1 = Container(
    constraints: BoxConstraints(maxWidth: 200),
    child: Text('Hello'),
  );

  // GOOD: Using ConstrainedBox widget
  final good1 = ConstrainedBox(
    constraints: BoxConstraints(maxWidth: 200),
    child: Text('Hello'),
  );

  // GOOD: Container with multiple properties
  final good2 = Container(
    constraints: BoxConstraints(maxWidth: 200),
    color: Colors.blue,
    child: Text('Hello'),
  );
}

class TestWidget extends StatelessWidget {
  const TestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: Container with only alignment in widget tree
        // BAD: Container with only alignment in widget tree, should trigger lint
        // expect_lint: prefer_align_over_container
        Container(
          alignment: Alignment.bottomRight,
          child: Icon(Icons.star),
        ),

        // BAD: Container with only padding in widget tree
        // BAD: Container with only padding in widget tree, should trigger lint
        // expect_lint: prefer_padding_over_container
        Container(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Icon(Icons.star),
        ),

        // BAD: Container with only constraints in widget tree
        // BAD: Container with only constraints in widget tree, should trigger lint
        // expect_lint: prefer_constrained_box_over_container
        Container(
          constraints: BoxConstraints.tightFor(width: 100),
          child: Icon(Icons.star),
        ),
      ],
    );
  }
}
