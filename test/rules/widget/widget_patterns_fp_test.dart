/// Resolved-AST false-positive / false-negative regression tests for
/// widget_patterns_avoid_prefer_rules.dart. Each group first reproduces the
/// audit-flagged defect (the FP/FN case), then pins the genuine BAD-fires and
/// GOOD-silent behavior so a future edit cannot silently regress either way.
///
/// The harness writes fixtures under example/lib (no Flutter dep) and ENFORCES
/// applicableFileTypes — every rule here is {FileType.widget}, so each fixture
/// must contain an `extends StatelessWidget` / `extends StatefulWidget` /
/// `extends State<...>` substring or the rule never runs. Flutter types resolve
/// to InvalidType, so rules whose detection needs a resolved Widget subtype get
/// LOCAL stub classes (Widget, StatelessWidget, StatefulWidget, ...).
library;

import 'package:saropa_lints/src/rules/widget/widget_patterns_avoid_prefer_rules.dart';
import 'package:test/test.dart';

import '../../support/resolved_rule_harness.dart';

void main() {
  // Minimal stub hierarchy reused across fixtures. `extends StatelessWidget`
  // appears verbatim so the file classifies as FileType.widget AND the rules
  // that resolve a returned/created type to a Widget subtype see real types.
  const stubs = '''
class Key {}
class ValueKey extends Key { ValueKey(Object value); }
class Widget { const Widget({Key? key}); }
abstract class StatelessWidget extends Widget { const StatelessWidget({Key? key}); }
abstract class StatefulWidget extends Widget { const StatefulWidget({Key? key}); }
class BuildContext {}
''';

  // ===========================================================================
  // avoid_stateful_widget_in_list — must resolve the returned type and only
  // flag StatefulWidget subclasses, not every keyless widget.
  // ===========================================================================
  group('avoid_stateful_widget_in_list', () {
    final rule = AvoidStatefulWidgetInListRule();
    const ruleName = 'avoid_stateful_widget_in_list';

    // NOTE: `ListView` is intentionally left UNDECLARED so `ListView.builder`
    // parses as a MethodInvocation (the rule's actual trigger path). Declaring
    // a `ListView` class would make it a constructor InstanceCreationExpression
    // and the rule's addMethodInvocation hook would never see it.

    // FP repro: a keyless STATELESS widget returned from itemBuilder must NOT
    // fire — the rule's own GOOD example is a stateless tile.
    test('FP: keyless StatelessWidget in itemBuilder stays silent', () async {
      final code = '''
$stubs
class Tile extends StatelessWidget { const Tile(); }
class Home extends StatelessWidget {
  const Home();
  Object build(BuildContext context) {
    return ListView.builder(itemBuilder: (context, index) => Tile());
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    // BAD: a keyless StatefulWidget returned from itemBuilder still fires.
    test('BAD: keyless StatefulWidget in itemBuilder fires', () async {
      final code = '''
$stubs
class Counter extends StatefulWidget { const Counter(); }
class Home extends StatelessWidget {
  const Home();
  Object build(BuildContext context) {
    return ListView.builder(itemBuilder: (context, index) => Counter());
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });

    // GOOD: a StatefulWidget WITH a key stays silent.
    test('GOOD: keyed StatefulWidget in itemBuilder stays silent', () async {
      final code = '''
$stubs
class Counter extends StatefulWidget { const Counter({Key? key, this.id}); final Object? id; }
class Home extends StatelessWidget {
  const Home();
  Object build(BuildContext context) {
    return ListView.builder(
      itemBuilder: (context, index) => Counter(key: ValueKey(index)),
    );
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });
  });

  // ===========================================================================
  // avoid_duplicate_widget_keys — Key('x') and ValueKey('x') are DIFFERENT key
  // types and must not collide; key identity is typeName:value.
  // ===========================================================================
  group('avoid_duplicate_widget_keys', () {
    final rule = AvoidDuplicateWidgetKeysRule();
    const ruleName = 'avoid_duplicate_widget_keys';

    // FP repro: distinct key TYPES with the same inner string are NOT
    // duplicates (Key('x') != ValueKey('x')).
    test('FP: different key types with same value do not collide', () async {
      final code = '''
$stubs
class Key2 { Key2(Object value); }
class ValueKey2 { ValueKey2(Object value); }
class Item extends StatelessWidget { const Item({Object? key}); }
class Home extends StatelessWidget {
  const Home();
  List build(BuildContext context) {
    return [
      Item(key: Key2('x')),
      Item(key: ValueKey2('x')),
    ];
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    // BAD: SAME key type with the SAME value collides.
    test('BAD: same key type and value collide', () async {
      final code = '''
$stubs
class Key2 { Key2(Object value); }
class Item extends StatelessWidget { const Item({Object? key}); }
class Home extends StatelessWidget {
  const Home();
  List build(BuildContext context) {
    return [
      Item(key: Key2('x')),
      Item(key: Key2('x')),
    ];
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });

    // GOOD: same key type with DIFFERENT values stays silent.
    test('GOOD: same key type different values stays silent', () async {
      final code = '''
$stubs
class Key2 { Key2(Object value); }
class Item extends StatelessWidget { const Item({Object? key}); }
class Home extends StatelessWidget {
  const Home();
  List build(BuildContext context) {
    return [
      Item(key: Key2('a')),
      Item(key: Key2('b')),
    ];
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });
  });

  // ===========================================================================
  // avoid_gesture_conflict — require DIRECT child-chain nesting, not nesting
  // across intervening scrollables/routes that break the hit-test path.
  // ===========================================================================
  group('avoid_gesture_conflict', () {
    final rule = AvoidGestureConflictRule();
    const ruleName = 'avoid_gesture_conflict';

    // FP repro: an InkWell separated from an ancestor InkWell by a ListView
    // (a new hit-test boundary) must NOT be flagged.
    test('FP: nesting across an intervening ListView stays silent', () async {
      final code = '''
$stubs
class InkWell extends StatelessWidget { const InkWell({Object? onTap, Object? child}); }
class ListView extends StatelessWidget { const ListView({Object? children}); }
class Home extends StatelessWidget {
  const Home();
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: ListView(
        children: [
          InkWell(onTap: () {}, child: Widget()),
        ],
      ),
    );
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    // BAD: a GestureDetector directly nested inside a GestureDetector fires.
    test('BAD: directly nested GestureDetector fires', () async {
      final code = '''
$stubs
class GestureDetector extends StatelessWidget { const GestureDetector({Object? onTap, Object? child}); }
class Home extends StatelessWidget {
  const Home();
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: GestureDetector(onTap: () {}, child: Widget()),
    );
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });
  });

  // ===========================================================================
  // prefer_tap_region_for_dismiss — substring pop/close/hide matched
  // populate/closest; inspect callback AST.
  // ===========================================================================
  group('prefer_tap_region_for_dismiss', () {
    final rule = PreferTapRegionForDismissRule();
    const ruleName = 'prefer_tap_region_for_dismiss';

    // FP repro: a callback that calls populate()/closest() (containing the
    // substrings pop/close) must NOT fire. Child is a plain non-barrier widget
    // (no color) so ONLY the dismiss-callback path could trigger — isolating
    // the substring bug from the separate barrier-detection trigger.
    test('FP: populate/closest substrings do not trigger', () async {
      final code = '''
$stubs
class GestureDetector extends StatelessWidget { const GestureDetector({Object? onTap, Object? child}); }
class Home extends StatelessWidget {
  const Home();
  void populate() {}
  void closest() {}
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { populate(); closest(); },
      child: Widget(),
    );
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    // BAD: a real Navigator.pop dismiss (non-barrier child) fires via the
    // dismiss-callback path — proving the AST method-name detection works.
    test('BAD: Navigator.pop dismiss callback fires', () async {
      final code = '''
$stubs
class Navigator { static void pop(BuildContext c) {} }
class GestureDetector extends StatelessWidget { const GestureDetector({Object? onTap, Object? child}); }
class Home extends StatelessWidget {
  const Home();
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Widget(),
    );
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });
  });

  // ===========================================================================
  // prefer_asset_image_for_local — contains('asset') matched /dataset/; only
  // string-literal paths starting with assets/ should fire.
  // ===========================================================================
  group('prefer_asset_image_for_local', () {
    final rule = PreferAssetImageForLocalRule();
    const ruleName = 'prefer_asset_image_for_local';

    // FP repro: a runtime path under /dataset/ (no assets/ prefix) must NOT
    // fire — that is a genuine filesystem file.
    test('FP: dataset path does not trigger', () async {
      final code = '''
$stubs
class FileImage extends StatelessWidget { const FileImage(Object f); }
class File { File(String p); }
class Home extends StatelessWidget {
  const Home();
  Widget build(BuildContext context) {
    return FileImage(File('/var/dataset/photo.png'));
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    // BAD: a string-literal path starting with assets/ fires.
    test('BAD: assets/ literal path fires', () async {
      final code = '''
$stubs
class FileImage extends StatelessWidget { const FileImage(Object f); }
class File { File(String p); }
class Home extends StatelessWidget {
  const Home();
  Widget build(BuildContext context) {
    return FileImage(File('assets/logo.png'));
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });
  });

  // ===========================================================================
  // avoid_nullable_widget_methods — endsWith('Widget') flagged MyFooWidget?;
  // resolve the return type and confirm assignability to Widget.
  // ===========================================================================
  group('avoid_nullable_widget_methods', () {
    final rule = AvoidNullableWidgetMethodsRule();
    const ruleName = 'avoid_nullable_widget_methods';

    // FP repro: a method returning a nullable NON-Widget type whose name ends
    // in "Widget" (e.g. a data holder) must NOT fire.
    test('FP: nullable non-Widget type ending in Widget stays silent',
        () async {
      final code = '''
$stubs
class FooWidget {}
class Home extends StatelessWidget {
  const Home();
  FooWidget? lookup() => null;
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    // BAD: a method returning a nullable real Widget subtype fires.
    test('BAD: nullable Widget subtype return fires', () async {
      final code = '''
$stubs
class Banner extends StatelessWidget { const Banner(); }
class Home extends StatelessWidget {
  const Home();
  Banner? maybeBanner() => null;
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });

    // GOOD: a non-nullable Widget return stays silent.
    test('GOOD: non-nullable Widget return stays silent', () async {
      final code = '''
$stubs
class Banner extends StatelessWidget { const Banner(); }
class Home extends StatelessWidget {
  const Home();
  Banner banner() => const Banner();
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });
  });

  // ===========================================================================
  // avoid_double_tap_submit — '?'/'null' substring suppressed; 'order' keyword
  // matched reorder/border. Inspect AST.
  // ===========================================================================
  group('avoid_double_tap_submit', () {
    final rule = AvoidDoubleTapSubmitRule();
    const ruleName = 'avoid_double_tap_submit';

    // FP repro: a "Reorder" button (contains 'order') with no guard must NOT
    // be treated as a submit button.
    test('FP: Reorder button is not a submit button', () async {
      final code = '''
$stubs
class Text { const Text(String s); }
class ElevatedButton extends StatelessWidget { const ElevatedButton({Object? onPressed, Object? child}); }
class Home extends StatelessWidget {
  const Home();
  void doReorder() {}
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: () => doReorder(), child: Text('Reorder'));
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    // BAD: a genuine Submit button with an unguarded callback fires.
    test('BAD: unguarded Submit button fires', () async {
      final code = '''
$stubs
class Text { const Text(String s); }
class ElevatedButton extends StatelessWidget { const ElevatedButton({Object? onPressed, Object? child}); }
class Home extends StatelessWidget {
  const Home();
  void submit() {}
  Widget build(BuildContext context) {
    return ElevatedButton(onPressed: () => submit(), child: Text('Submit'));
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });
  });

  // ===========================================================================
  // avoid_late_without_guarantee — initStateBody.contains('\$varName =')
  // matched '==' and 'other.foo ='. Walk initState AST for a real assignment.
  // ===========================================================================
  group('avoid_late_without_guarantee', () {
    final rule = AvoidLateWithoutGuaranteeRule();
    const ruleName = 'avoid_late_without_guarantee';

    // FP repro: a late field NOT assigned in initState, where initState only
    // contains an equality compare (`foo ==`) of that name, must still fire.
    test('FP: equality compare of field name is not an assignment', () async {
      final code = '''
class State<T> {}
class W {}
class MyState extends State<W> {
  late int foo;
  void initState() {
    if (foo == 0) {}
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });

    // FP repro 2: assignment to ANOTHER object's field (`other.foo =`) must not
    // count as initializing this State's `foo`.
    test('FP: other.foo assignment does not satisfy guarantee', () async {
      final code = '''
class State<T> {}
class W {}
class Other { int foo = 0; }
class MyState extends State<W> {
  late int foo;
  Other other = Other();
  void initState() {
    other.foo = 1;
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });

    // GOOD: a real assignment to the field in initState satisfies the guarantee.
    test('GOOD: real assignment in initState stays silent', () async {
      final code = '''
class State<T> {}
class W {}
class MyState extends State<W> {
  late int foo;
  void initState() {
    foo = 3;
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });
  });

  // ===========================================================================
  // avoid_static_route_config — substring matching flagged every
  // `static final MaterialApp`; use exact type-name equality for router types.
  // ===========================================================================
  group('avoid_static_route_config', () {
    final rule = AvoidStaticRouteConfigRule();
    const ruleName = 'avoid_static_route_config';

    // FP repro: a static final field whose type NAME merely contains a router
    // type as a substring must NOT fire.
    test('FP: MaterialAppConfig substring type does not fire', () async {
      final code = '''
class StatelessWidget {}
class MaterialAppConfig {}
class Holder extends StatelessWidget {
  static final MaterialAppConfig config = MaterialAppConfig();
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    // BAD: a static final GoRouter field fires.
    test('BAD: static final GoRouter fires', () async {
      final code = '''
class StatelessWidget {}
class GoRouter { GoRouter(); }
class Holder extends StatelessWidget {
  static final GoRouter router = GoRouter();
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });
  });

  // ===========================================================================
  // prefer_split_widget_const — counts ALL descendant widgets ignoring
  // const-ness though the message claims all-const children.
  // ===========================================================================
  group('prefer_split_widget_const', () {
    final rule = PreferSplitWidgetConstRule();
    const ruleName = 'prefer_split_widget_const';

    // FP repro: a large Column whose children are NON-const (carry dynamic
    // args) should not be claimed as an all-const splittable subtree.
    test('FP: large Column of non-const children stays silent', () async {
      final code = '''
$stubs
class Column extends StatelessWidget { const Column({Object? children}); }
class Text extends StatelessWidget { const Text(String s); }
class Home extends StatelessWidget {
  const Home();
  Widget build(BuildContext context) {
    final label = 'x';
    return Column(children: [
      Text(label), Text(label), Text(label),
      Text(label), Text(label), Text(label),
    ]);
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, isNot(contains(ruleName)));
    });

    // BAD: a large Column whose children are all const-constructible fires.
    test('BAD: large Column of const children fires', () async {
      final code = '''
$stubs
class Column extends StatelessWidget { const Column({Object? children}); }
class Text extends StatelessWidget { const Text(String s); }
class Home extends StatelessWidget {
  const Home();
  Widget build(BuildContext context) {
    return Column(children: [
      Text('a'), Text('b'), Text('c'),
      Text('d'), Text('e'), Text('f'),
    ]);
  }
}
''';
      final codes = await reportedRuleCodes(rule, code);
      expect(codes, contains(ruleName));
    });
  });
}
