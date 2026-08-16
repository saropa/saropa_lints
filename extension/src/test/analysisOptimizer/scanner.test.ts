import * as assert from 'assert';
import { computeFileMetrics } from '../../analysisOptimizer/scanner';

// computeFileMetrics drives the exclude-pattern cost estimates shown in
// the Analysis Optimizer panel, so its widget/async/generated heuristics
// need explicit positive AND negative cases — a false positive here would
// misclassify ordinary data classes as expensive widget files.
describe('scanner computeFileMetrics', () => {
  it('counts imports, classes, and lines', () => {
    const content = `import 'package:flutter/material.dart';
import 'dart:async';

class Foo {
  void bar() {}
}
`;
    const m = computeFileMetrics(content, 'lib/foo.dart');
    assert.strictEqual(m.importCount, 2);
    assert.strictEqual(m.classCount, 1);
    assert.strictEqual(m.lineCount, content.split('\n').length);
  });

  it('detects widgets and async code', () => {
    const content = `class MyWidget extends StatelessWidget {
  Future<void> load() async {}
}
`;
    const m = computeFileMetrics(content, 'lib/my_widget.dart');
    assert.strictEqual(m.hasWidgets, true);
    assert.strictEqual(m.hasAsyncCode, true);
  });

  it('does not flag plain data classes as widgets or async', () => {
    const content = `class Point {
  final int x;
  final int y;
  Point(this.x, this.y);
}
`;
    const m = computeFileMetrics(content, 'lib/point.dart');
    assert.strictEqual(m.hasWidgets, false);
    assert.strictEqual(m.hasAsyncCode, false);
  });

  it('flags generated-file suffixes', () => {
    assert.strictEqual(computeFileMetrics('', 'lib/model.g.dart').isGenerated, true);
    assert.strictEqual(computeFileMetrics('', 'lib/model.freezed.dart').isGenerated, true);
    assert.strictEqual(computeFileMetrics('', 'lib/model.mocks.dart').isGenerated, true);
    assert.strictEqual(computeFileMetrics('', 'lib/model.dart').isGenerated, false);
  });
});
