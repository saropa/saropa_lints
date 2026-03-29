import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:saropa_lints/src/rules/widget/flutter_migration_widget_detection.dart';
import 'package:test/test.dart';

CompilationUnit _parse(String code) => parseString(content: code).unit;

ClassDeclaration _singleClass(CompilationUnit unit) {
  final decls = unit.declarations.whereType<ClassDeclaration>().toList();
  expect(decls, isNotEmpty);
  return decls.last;
}

ConstructorDeclaration _firstConstructor(ClassDeclaration cls) {
  final ctors = cls.body.members.whereType<ConstructorDeclaration>().toList();
  expect(ctors, isNotEmpty);
  return ctors.first;
}

void main() {
  group('PreferSuperKeyDetection', () {
    test(
      'shouldReport true for StatelessWidget Key? key + super(key: key)',
      () {
        final unit = _parse(r'''
import 'package:flutter/widgets.dart';
class W extends StatelessWidget {
  const W({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext c) => const Placeholder();
}
''');
        final cls = _singleClass(unit);
        final ctor = _firstConstructor(cls);
        expect(
          PreferSuperKeyDetection.shouldReportPreferSuperKey(
            ctor: ctor,
            parent: cls,
          ),
          isTrue,
        );
      },
    );

    test('shouldReport false when super.key already used', () {
      final unit = _parse(r'''
import 'package:flutter/widgets.dart';
class W extends StatelessWidget {
  const W({super.key});
  @override
  Widget build(BuildContext c) => const Placeholder();
}
''');
      final cls = _singleClass(unit);
      final ctor = _firstConstructor(cls);
      expect(
        PreferSuperKeyDetection.shouldReportPreferSuperKey(
          ctor: ctor,
          parent: cls,
        ),
        isFalse,
      );
    });

    test('shouldReport false for ValueKey? key (not Key type)', () {
      final unit = _parse(r'''
import 'package:flutter/widgets.dart';
class W extends StatelessWidget {
  const W({ValueKey<String>? key}) : super(key: key);
  @override
  Widget build(BuildContext c) => const Placeholder();
}
''');
      final cls = _singleClass(unit);
      final ctor = _firstConstructor(cls);
      expect(
        PreferSuperKeyDetection.shouldReportPreferSuperKey(
          ctor: ctor,
          parent: cls,
        ),
        isFalse,
      );
    });

    test('shouldReport false when super has key plus other arguments', () {
      final unit = _parse(r'''
import 'package:flutter/widgets.dart';
class W extends InheritedWidget {
  const W({Key? key, required Widget child}) : super(key: key, child: child);
  @override
  bool updateShouldNotify(covariant W oldWidget) => false;
}
''');
      final cls = _singleClass(unit);
      final ctor = _firstConstructor(cls);
      expect(
        PreferSuperKeyDetection.shouldReportPreferSuperKey(
          ctor: ctor,
          parent: cls,
        ),
        isFalse,
      );
    });

    test('shouldReport false for non-Widget superclass', () {
      final unit = _parse(r'''
class Base {
  Base({Key? key});
}
class W extends Base {
  W({Key? key}) : super(key: key);
}
''');
      final cls = _singleClass(unit);
      final ctor = _firstConstructor(cls);
      expect(
        PreferSuperKeyDetection.shouldReportPreferSuperKey(
          ctor: ctor,
          parent: cls,
        ),
        isFalse,
      );
    });

    test('findKeyTypedKeyParameter still finds Key after a super formal', () {
      final unit = _parse(r'''
class Base {
  Base({Object? x});
}
class Sub extends Base {
  Sub({super.x, Key? key}) : super(x: key);
}
''');
      final cls = _singleClass(unit);
      final ctor = _firstConstructor(cls);
      expect(PreferSuperKeyDetection.findKeyTypedKeyParameter(ctor), isNotNull);
    });
  });

  group('ChipDeleteInkWellCircleBorderDetection', () {
    test('flags const InputChip InstanceCreationExpression', () {
      final unit = _parse(r'''
class Widget {
  const Widget();
}
class Text extends Widget {
  const Text(String _);
}
class Icon extends Widget {
  const Icon(Object _);
}
class InkWell extends Widget {
  const InkWell({this.child, this.onTap, this.customBorder});
  final Widget? child;
  final void Function()? onTap;
  final Object? customBorder;
}
class CircleBorder {
  const CircleBorder();
}
class InputChip extends Widget {
  const InputChip({this.label, this.onDeleted, this.deleteIcon});
  final Widget? label;
  final void Function()? onDeleted;
  final Widget? deleteIcon;
}
void w() {
  const InputChip(
    label: Text('x'),
    deleteIcon: InkWell(
      customBorder: CircleBorder(),
      onTap: null,
      child: Icon(0),
    ),
  );
}
''');
      final chip = _firstChipCreation(unit);
      expect(
        ChipDeleteInkWellCircleBorderDetection.violationForChipConstructor(
          chip,
        ),
        isNotNull,
      );
    });

    test(
      'flags unqualified InputChip MethodInvocation (non-const call shape)',
      () {
        final unit = _parse(r'''
class Widget {
  const Widget();
}
class Text extends Widget {
  const Text(String _);
}
class Icon extends Widget {
  const Icon(Object _);
}
class InkWell extends Widget {
  const InkWell({this.child, this.onTap, this.customBorder});
  final Widget? child;
  final void Function()? onTap;
  final Object? customBorder;
}
class CircleBorder {
  const CircleBorder();
}
class InputChip extends Widget {
  InputChip({this.label, this.onDeleted, this.deleteIcon});
  final Widget? label;
  final void Function()? onDeleted;
  final Widget? deleteIcon;
}
void w() {
  InputChip(
    label: Text('x'),
    onDeleted: () {},
    deleteIcon: InkWell(
      customBorder: CircleBorder(),
      onTap: () {},
      child: Icon(0),
    ),
  );
}
''');
        final mi = _firstUnqualifiedMethodInvocation(unit, 'InputChip');
        expect(
          ChipDeleteInkWellCircleBorderDetection.violationForChipMethodInvocation(
            mi,
          ),
          isNotNull,
        );
      },
    );

    test('does not flag deleteIcon InkWell without CircleBorder', () {
      final unit = _parse(r'''
class Widget {
  const Widget();
}
class Text extends Widget {
  const Text(String _);
}
class Icon extends Widget {
  const Icon(Object _);
}
class InkWell extends Widget {
  const InkWell({this.child, this.onTap, this.customBorder});
  final Widget? child;
  final void Function()? onTap;
  final Object? customBorder;
}
class InputChip extends Widget {
  InputChip({this.label, this.onDeleted, this.deleteIcon});
  final Widget? label;
  final void Function()? onDeleted;
  final Widget? deleteIcon;
}
void w() {
  InputChip(
    label: Text('x'),
    onDeleted: () {},
    deleteIcon: InkWell(
      onTap: () {},
      child: Icon(0),
    ),
  );
}
''');
      final mi = _firstUnqualifiedMethodInvocation(unit, 'InputChip');
      expect(
        ChipDeleteInkWellCircleBorderDetection.violationForChipMethodInvocation(
          mi,
        ),
        isNull,
      );
    });

    test('does not flag non-chip InkWell + CircleBorder', () {
      final unit = _parse(r'''
class Widget {
  const Widget();
}
class Text extends Widget {
  const Text(String _);
}
class InkWell extends Widget {
  const InkWell({this.child, this.onTap, this.customBorder});
  final Widget? child;
  final void Function()? onTap;
  final Object? customBorder;
}
class CircleBorder {
  const CircleBorder();
}
class ListTile extends Widget {
  ListTile({this.title});
  final Widget? title;
}
void w() {
  ListTile(
    title: InkWell(
      customBorder: CircleBorder(),
      onTap: () {},
      child: Text('t'),
    ),
  );
}
''');
      final mi = _firstUnqualifiedMethodInvocation(unit, 'ListTile');
      expect(
        ChipDeleteInkWellCircleBorderDetection.violationForChipMethodInvocation(
          mi,
        ),
        isNull,
      );
    });

    test('finds violation nested under deleteIcon wrapper', () {
      final unit = _parse(r'''
class Widget {
  const Widget();
}
class Text extends Widget {
  const Text(String _);
}
class Icon extends Widget {
  const Icon(Object _);
}
class InkWell extends Widget {
  const InkWell({this.child, this.onTap, this.customBorder});
  final Widget? child;
  final void Function()? onTap;
  final Object? customBorder;
}
class CircleBorder {
  const CircleBorder();
}
class Padding extends Widget {
  const Padding({this.child});
  final Widget? child;
}
class RawChip extends Widget {
  RawChip({this.label, this.deleteIcon});
  final Widget? label;
  final Widget? deleteIcon;
}
void w() {
  RawChip(
    label: Text('y'),
    deleteIcon: Padding(
      child: InkWell(
        customBorder: CircleBorder(),
        onTap: () {},
        child: Icon(0),
      ),
    ),
  );
}
''');
      final mi = _firstUnqualifiedMethodInvocation(unit, 'RawChip');
      expect(
        ChipDeleteInkWellCircleBorderDetection.violationForChipMethodInvocation(
          mi,
        ),
        isNotNull,
      );
    });
  });
}

InstanceCreationExpression _firstChipCreation(CompilationUnit unit) {
  final v = _ChipCreationCollector();
  unit.accept(v);
  expect(
    v.chip,
    isNotNull,
    reason: 'expected a chip InstanceCreationExpression',
  );
  return v.chip!;
}

MethodInvocation _firstUnqualifiedMethodInvocation(
  CompilationUnit unit,
  String name,
) {
  final v = _FirstMethodInvocationCollector(name);
  unit.accept(v);
  expect(v.found, isNotNull, reason: 'expected MethodInvocation $name');
  return v.found!;
}

class _ChipCreationCollector extends RecursiveAstVisitor<void> {
  InstanceCreationExpression? chip;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final String t = node.constructorName.type.name.lexeme;
    if (ChipDeleteInkWellCircleBorderDetection.chipTypes.contains(t)) {
      chip = node;
    }
    super.visitInstanceCreationExpression(node);
  }
}

class _FirstMethodInvocationCollector extends RecursiveAstVisitor<void> {
  _FirstMethodInvocationCollector(this._name);

  final String _name;
  MethodInvocation? found;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (found == null && node.target == null && node.methodName.name == _name) {
      found = node;
    }
    super.visitMethodInvocation(node);
  }
}
