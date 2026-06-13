// Oracle-backed regression tests for accessibility_rules false positives
// (2026.06.12 audit). Flutter types are stubbed locally so the resolved
// harness runs without a Flutter dependency.
library;

import 'package:saropa_lints/src/rules/ui/accessibility_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

const String _stubs = '''
class SortKey { const SortKey(); }
class Widget { const Widget(); }
class StatelessWidget extends Widget { const StatelessWidget(); }
class Text extends Widget { const Text(this.data); final String data; }
class Container extends Widget { const Container(); }
class Semantics extends Widget {
  const Semantics({this.child, this.label, this.sortKey, this.explicitChildNodes});
  final Widget? child; final String? label; final Object? sortKey;
  final bool? explicitChildNodes;
}
class TextField extends Widget { const TextField(); }
class FocusTraversalOrder extends Widget {
  const FocusTraversalOrder({this.order, this.child});
  final Object? order; final Widget? child;
}
class Row extends Widget { const Row({this.children}); final List<Widget>? children; }
''';

void main() {
  group('prefer_semantics_sort', () {
    test('BAD: explicitChildNodes:true without sortKey fires', () async {
      final codes = await reportedRuleCodes(PreferSemanticsSortRule(), '''
$_stubs
Widget build() => const Semantics(explicitChildNodes: true, child: Text('a'));
''');
      expect(codes, contains('prefer_semantics_sort'));
    });

    test('GOOD: plain Semantics (no explicitChildNodes) stays silent', () async {
      final codes = await reportedRuleCodes(PreferSemanticsSortRule(), '''
$_stubs
Widget build() => const Semantics(label: 'a', child: Text('a'));
''');
      expect(codes, isEmpty);
    });

    test('GOOD: explicitChildNodes with sortKey stays silent', () async {
      final codes = await reportedRuleCodes(PreferSemanticsSortRule(), '''
$_stubs
Widget build() => const Semantics(
  explicitChildNodes: true, sortKey: SortKey(), child: Text('a'),
);
''');
      expect(codes, isEmpty);
    });
  });

  group('prefer_explicit_semantics', () {
    test('BAD: CustomChart widget without Semantics fires', () async {
      final codes = await reportedRuleCodes(PreferExplicitSemanticsRule(), '''
$_stubs
class CustomChart extends StatelessWidget {
  const CustomChart();
  Widget build() => const Container();
}
''');
      expect(codes, contains('prefer_explicit_semantics'));
    });

    test('GOOD: Customer* no longer matches the Custom pattern', () async {
      final codes = await reportedRuleCodes(PreferExplicitSemanticsRule(), '''
$_stubs
class CustomerList extends StatelessWidget {
  const CustomerList();
  Widget build() => const Container();
}
''');
      expect(codes, isEmpty);
    });

    test('GOOD: a real Semantics widget present stays silent', () async {
      final codes = await reportedRuleCodes(PreferExplicitSemanticsRule(), '''
$_stubs
class CustomChart extends StatelessWidget {
  const CustomChart();
  Widget build() => const Semantics(label: 'chart', child: Container());
}
''');
      expect(codes, isEmpty);
    });
  });

  group('prefer_focus_traversal_order', () {
    test('BAD: Row with 3 real focusable fields, no traversal fires', () async {
      final codes = await reportedRuleCodes(PreferFocusTraversalOrderRule(), '''
$_stubs
Widget build() => const Row(children: [TextField(), TextField(), TextField()]);
''');
      expect(codes, contains('prefer_focus_traversal_order'));
    });

    test('GOOD: focusable names only in strings are not counted', () async {
      final codes = await reportedRuleCodes(PreferFocusTraversalOrderRule(), '''
$_stubs
Widget build() => const Row(children: [
  TextField(),
  Text('Switch to dark mode'),
  Text('Radio silence and Checkbox tips'),
]);
''');
      expect(codes, isEmpty);
    });

    test('GOOD: FocusTraversalOrder inside the row stays silent', () async {
      final codes = await reportedRuleCodes(PreferFocusTraversalOrderRule(), '''
$_stubs
Widget build() => const Row(children: [
  FocusTraversalOrder(order: 1, child: TextField()),
  FocusTraversalOrder(order: 2, child: TextField()),
  FocusTraversalOrder(order: 3, child: TextField()),
]);
''');
      expect(codes, isEmpty);
    });
  });
}
