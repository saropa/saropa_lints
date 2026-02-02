// ignore_for_file: unused_local_variable, prefer_const_constructors
// ignore_for_file: prefer_const_literals_to_create_immutables
// Fixtures for layout crash detection rules

import '../flutter_mocks.dart';

// ============================================================
// avoid_table_cell_outside_table
// ============================================================

Widget testTableCellBad() {
  // expect_lint: avoid_table_cell_outside_table
  return Column(children: [TableCell(child: Text('x'))]);
}

Widget testTableCellGood() {
  return Table(children: [
    TableRow(children: [TableCell(child: Text('x'))]),
  ]);
}

// ============================================================
// avoid_positioned_outside_stack
// ============================================================

Widget testPositionedBad() {
  // expect_lint: avoid_positioned_outside_stack
  return Column(children: [Positioned(top: 10, child: Text('x'))]);
}

Widget testPositionedGood() {
  return Stack(children: [Positioned(top: 10, child: Text('x'))]);
}

// ============================================================
// avoid_spacer_in_wrap
// ============================================================

Widget testSpacerInWrapBad() {
  // expect_lint: avoid_spacer_in_wrap
  return Wrap(children: [Text('a'), Spacer(), Text('b')]);
}

Widget testSpacerInWrapGood() {
  return Wrap(children: [Text('a'), SizedBox(width: 8), Text('b')]);
}

Widget testSpacerInRowGood() {
  // Spacer in Row is fine
  return Row(children: [Text('a'), Spacer(), Text('b')]);
}

// ============================================================
// avoid_scrollable_in_intrinsic
// ============================================================

Widget testScrollableInIntrinsicBad() {
  // expect_lint: avoid_scrollable_in_intrinsic
  return IntrinsicHeight(child: ListView());
}

Widget testScrollableInIntrinsicGood() {
  return SizedBox(height: 200, child: ListView());
}

// ============================================================
// require_baseline_text_baseline
// ============================================================

Widget testBaselineBad() {
  // expect_lint: require_baseline_text_baseline
  return Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    children: [Text('a'), Text('b')],
  );
}

Widget testBaselineGood() {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [Text('a'), Text('b')],
  );
}

Widget testBaselineNotUsed() {
  // No baseline alignment -- should not trigger
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [Text('a'), Text('b')],
  );
}

// ============================================================
// avoid_unconstrained_dialog_column
// ============================================================

Widget testDialogColumnBad(BuildContext context) {
  // expect_lint: avoid_unconstrained_dialog_column
  return AlertDialog(content: Column(children: [Text('a'), Text('b')]));
}

Widget testDialogColumnGood(BuildContext context) {
  return AlertDialog(
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [Text('a'), Text('b')],
    ),
  );
}

Widget testColumnOutsideDialog() {
  // Column outside dialog is fine without mainAxisSize.min
  return Column(children: [Text('a'), Text('b')]);
}

// ============================================================
// avoid_unbounded_listview_in_column
// ============================================================

Widget testListViewInColumnBad() {
  // expect_lint: avoid_unbounded_listview_in_column
  return Column(children: [Text('header'), ListView()]);
}

Widget testListViewInColumnGood() {
  return Column(children: [Text('header'), Expanded(child: ListView())]);
}

Widget testListViewInColumnShrinkWrap() {
  // shrinkWrap: true avoids the crash
  return Column(children: [Text('header'), ListView(shrinkWrap: true)]);
}

// ============================================================
// avoid_textfield_in_row
// ============================================================

Widget testTextFieldInRowBad() {
  // expect_lint: avoid_textfield_in_row
  return Row(children: [Icon(Icons.search), TextField()]);
}

Widget testTextFieldInRowGood() {
  return Row(children: [Icon(Icons.search), Expanded(child: TextField())]);
}

// ============================================================
// avoid_fixed_size_in_scaffold_body
// ============================================================

Widget testScaffoldBodyBad() {
  // expect_lint: avoid_fixed_size_in_scaffold_body
  return Scaffold(body: Column(children: [TextField(), TextField()]));
}

Widget testScaffoldBodyGood() {
  return Scaffold(
    body: SingleChildScrollView(
      child: Column(children: [TextField(), TextField()]),
    ),
  );
}

Widget testScaffoldBodyNoTextField() {
  // No text fields -- should not trigger
  return Scaffold(body: Column(children: [Text('hello')]));
}
