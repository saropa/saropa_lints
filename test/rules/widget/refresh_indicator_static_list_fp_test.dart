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
void showMenuPage({Object? child}) {}
void showBalanceSheet({Object? child}) {}
void showSpreadSheet({Object? child}) {}
void showAppBottomSheet({Object? child}) {}
void showShareActionSheet({Object? child}) {}
class AlertDialog extends Widget {
  AlertDialog({Object? content, Object? actions});
}
class TextButton extends Widget {
  TextButton({Object? onPressed, Object? child});
}
class MaterialPageRoute {
  MaterialPageRoute({Object? builder});
}
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

      // A button inside a dialog that pushes a route builds a full screen.
      test('fires when a dialog button pushes the widget', () async {
        for (final String body in <String>[
          'push(_Picker())',
          'push(MaterialPageRoute(builder: (c) => _Picker()))',
        ]) {
          expect(
            await count('''
$_picker
void open() {
  showDialog(
    builder: (c) => AlertDialog(
      actions: [TextButton(onPressed: () => $body, child: null)],
    ),
  );
}
'''),
            1,
            reason: body,
          );
        }
      });

      test('fires for a show...Menu...Page wrapper', () async {
        expect(
          await count(
            '$_picker void open() { showMenuPage(child: _Picker()); }',
          ),
          1,
        );
      });

      // "Sheet" alone names a document, not an overlay.
      test('fires for a wrapper that only ends in Sheet', () async {
        for (final String opener in <String>[
          'showBalanceSheet',
          'showSpreadSheet',
        ]) {
          expect(
            await count('$_picker void open() { $opener(child: _Picker()); }'),
            1,
            reason: opener,
          );
        }
      });

      test('skips a qualified sheet wrapper', () async {
        for (final String opener in <String>[
          'showAppBottomSheet',
          'showShareActionSheet',
        ]) {
          expect(
            await count('$_picker void open() { $opener(child: _Picker()); }'),
            0,
            reason: opener,
          );
        }
      });

      // Each of these binds `items` to something that is not the top-level
      // const, so the lint must stay.
      test('fires when another binding shadows a constant', () async {
        const String list =
            'ListView.builder(itemCount: items.length, itemBuilder: null)';
        final Map<String, String> cases = <String, String>{
          'for-in variable':
              'void f(List<List<String>> all) '
              '{ for (final items in all) { $list; } }',
          'catch parameter': 'void f() { try {} catch (items) { $list; } }',
          'pattern declaration':
              'void f((List<String>, int) r) '
              '{ final (items, _) = r; $list; }',
          'if-case pattern':
              'void f(Object o) '
              '{ if (o case final List<String> items) { $list; } }',
          'switch-case local':
              'void f(int n, List<String> v) '
              '{ switch (n) { case 1: final items = v; $list; } }',
          'mixin field':
              'mixin M { List<String> items = <String>[]; '
              'Object f() => $list; }',
          'enum field':
              'enum E { a; static List<String> items = <String>[]; '
              'Object f() => $list; }',
          'extension getter':
              'extension X on int { List<String> get items => <String>[]; '
              'Object f() => $list; }',
          'getter':
              'class C { List<String> get items => <String>[]; '
              'Object f() => $list; }',
        };
        // Both rules only run on widget files, so every case needs a widget.
        const String prefix =
            "const List<String> items = <String>['a'];\n"
            'class Marker extends StatelessWidget {}\n';
        // Control: without a second binding the same setup is skipped.
        expect(await count('${prefix}Object f() => $list;'), 0);
        for (final MapEntry<String, String> c in cases.entries) {
          expect(await count('$prefix${c.value}'), 1, reason: c.key);
        }
      });

      // Inherited and mixed-in members are not in lexical scope: Dart binds
      // the bare name to the top-level const, whatever the supertypes hold.
      test('skips a top-level constant despite supertypes', () async {
        const String list =
            'ListView.builder(itemCount: items.length, itemBuilder: null)';
        for (final String type in <String>[
          'class B { List<String> items = <String>[]; }\n'
              'class C extends B { Object f() => $list; }',
          'mixin M { List<String> items = <String>[]; }\n'
              'class C with M { Object f() => $list; }',
          'class C extends SomewhereElse { Object f() => $list; }',
          'class C extends StatelessWidget with Elsewhere '
              '{ Object f() => $list; }',
        ]) {
          expect(
            await count(
              "const List<String> items = <String>['a'];\n"
              'class Marker extends StatelessWidget {}\n$type',
            ),
            0,
            reason: type,
          );
        }
      });

      // `on...` callbacks that build content, and ordinary methods that
      // merely share a navigation name, stay inside the dialog.
      test('skips overlay content built by non-handler code', () async {
        for (final String body in <String>[
          'Holder(onSuccess: () => _Picker())',
          'Holder(onLoadingBuilder: () => _Picker())',
          'stack.push(_Picker())',
          'tween.to(_Picker())',
          'go(_Picker())',
        ]) {
          expect(
            await count('''
$_picker
void open() { showDialog(builder: (c) => AlertDialog(content: $body)); }
'''),
            0,
            reason: body,
          );
        }
      });

      test('fires for navigator receivers and event handlers', () async {
        for (final String body in <String>[
          'Navigator.of(c).push(_Picker())',
          'context.go(_Picker())',
          'Get.to(() => _Picker())',
          'router.push(_Picker())',
          'stack.pushNamed(_Picker())',
          'TextButton(onPressed: () => _Picker(), child: null)',
          'Holder(onLongPress: () => _Picker())',
        ]) {
          expect(
            await count('''
$_picker
void open() { showDialog(builder: (c) => AlertDialog(content: $body)); }
'''),
            1,
            reason: body,
          );
        }
      });

      test('still skips a constant used from a State class', () async {
        expect(
          await count('''
const List<String> items = <String>['a'];
class W extends StatefulWidget {}
class _S extends State<W> {
  Widget build() =>
      ListView.builder(itemCount: items.length, itemBuilder: null);
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
