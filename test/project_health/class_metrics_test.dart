/// Tests for LCOM* cohesion and class member counts.
import 'package:saropa_lints/src/cli/project_health/class_metrics.dart';
import 'package:test/test.dart';

void main() {
  group('scanClassMetrics', () {
    test('disjoint field use yields high LCOM (split candidate)', () {
      const code = '''
class C {
  int _a = 0;
  int _b = 0;
  int useA() => _a;
  int useB() => _b;
}
''';
      expect(scanClassMetrics(code).single.lcom, closeTo(1.0, 0.001));
    });

    test('shared field use yields low LCOM (cohesive)', () {
      const code = '''
class C {
  int _a = 0;
  int _b = 0;
  int both1() => _a + _b;
  int both2() => _a - _b;
}
''';
      expect(scanClassMetrics(code).single.lcom, closeTo(0.0, 0.001));
    });

    test('counts fields, methods, and public members', () {
      const code =
          'class C { int x = 0; int _y = 0; void m() {} void _n() {} }';
      final c = scanClassMetrics(code).single;
      expect(c.fieldCount, 2);
      expect(c.methodCount, 2);
      expect(c.publicMembers, 2); // x and m
    });
  });
}
