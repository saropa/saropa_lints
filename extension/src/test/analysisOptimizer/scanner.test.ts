import * as assert from 'assert';
import { computeFileMetrics, isInDotFolder } from '../../analysisOptimizer/scanner';

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

// isInDotFolder mirrors the Dart analyzer's context-root exclusion so the
// Optimizer's cost estimates and exclusion suggestions match what the
// analysis server actually analyzes.
describe('scanner isInDotFolder', () => {
  it('flags files under agent-tool worktree dot-folders', () => {
    assert.strictEqual(isInDotFolder('.claude/worktrees/a/lib/x.dart'), true);
  });

  it('flags files under nested dot-folders like ios/.symlinks', () => {
    assert.strictEqual(isInDotFolder('ios/.symlinks/plugins/p/lib/x.dart'), true);
  });

  it('does not flag ordinary paths', () => {
    assert.strictEqual(isInDotFolder('lib/src/x.dart'), false);
  });

  it('flags a dot-prefixed file basename', () => {
    assert.strictEqual(isInDotFolder('lib/.hidden.dart'), true);
  });

  it('does not flag a file whose name merely contains dots', () => {
    assert.strictEqual(isInDotFolder('lib/foo.bar.dart'), false);
  });
});
