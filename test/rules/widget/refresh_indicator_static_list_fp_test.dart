import 'package:saropa_lints/saropa_lints.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

/// Behavioral tests for the refresh-indicator false positive on a static list
/// shown in a dialog. Flutter is not resolvable in the harness, so minimal
/// stand-ins are declared inline; that makes `ListView.builder(...)` resolve to
/// the InstanceCreationExpression both rules listen for.
const String _stubs = '''
class Widget {}
class StatelessWidget extends Widget {}
class StatefulWidget extends Widget {}
class State<T> {}
class ListView extends Widget {
  ListView.builder({Object? itemCount, Object? itemBuilder});
}
void showDialog({Object? builder}) {}
void showDialogCommon({Object? child}) {}
void push(Object? page) {}
''';

/// A private stateful picker whose list is runtime data held in State, the
/// shape of the real report (the file also has unrelated async members).
const String _picker = '''
/// Documented member reference [_Picker.hashCode] is not a use of the widget.
class _Picker extends StatefulWidget {}
class _PickerState extends State<_Picker> {
  List<String> items = <String>[];
  Future<void> select() async {}
  Widget build() =>
      ListView.builder(itemCount: items.length + 1, itemBuilder: null);
}
''';

void main() {
  // Both rules share the skip logic, so every scenario runs against each.
  final Map<String, SaropaLintRule Function()> rules = {
    'require_refresh_indicator': RequireRefreshIndicatorRule.new,
    'require_refresh_indicator_on_lists':
        RequireRefreshIndicatorOnListsRule.new,
  };

  for (final MapEntry<String, SaropaLintRule Function()> entry
      in rules.entries) {
    group(entry.key, () {
      Future<int> count(String code) async =>
          (await runRuleResolved(entry.value(), '$_stubs$code')).length;

      test('still fires on a runtime list on a normal screen', () async {
        expect(
          await count('''
class Feed extends StatelessWidget {
  Feed(this.items);
  final List<String> items;
  Widget build() =>
      ListView.builder(itemCount: items.length, itemBuilder: null);
}
'''),
          1,
        );
      });

      test('skips a private widget only shown by a dialog', () async {
        expect(
          await count(
            '$_picker void open() { showDialogCommon(child: _Picker()); }',
          ),
          0,
        );
        expect(
          await count(
            '$_picker void open() { showDialog(builder: (c) => _Picker()); }',
          ),
          0,
        );
      });

      test('fires when the private widget is also used elsewhere', () async {
        expect(
          await count('''
$_picker
void open() { showDialogCommon(child: _Picker()); }
void route() { push(_Picker()); }
'''),
          1,
        );
      });

      test('fires when the private widget has no visible use', () async {
        expect(await count(_picker), 1);
      });

      test('skips a list backed by a constant', () async {
        expect(
          await count('''
const List<String> zones = <String>['a'];
class Zones extends StatelessWidget {
  static const List<String> more = <String>['b'];
  final List<String> fixed = const <String>['c'];
  Widget a() => ListView.builder(itemCount: zones.length, itemBuilder: null);
  Widget b() => ListView.builder(itemCount: more.length + 1, itemBuilder: null);
  Widget c() => ListView.builder(itemCount: fixed.length, itemBuilder: null);
  Widget d() =>
      ListView.builder(itemCount: Zones.more.length, itemBuilder: null);
}
'''),
          0,
        );
      });

      test('fires when a parameter shadows a constant', () async {
        expect(
          await count('''
const List<String> items = <String>['a'];
class Feed extends StatelessWidget {
  Widget build(List<String> items) =>
      ListView.builder(itemCount: items.length, itemBuilder: null);
}
'''),
          1,
        );
      });
    });
  }
}
