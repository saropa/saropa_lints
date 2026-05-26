/// Tests the incremental cache: stable hashing and entry JSON round-trip.
import 'package:saropa_lints/src/cli/project_health/health_cache.dart';
import 'package:saropa_lints/src/cli/project_health/metrics_model.dart';
import 'package:test/test.dart';

void main() {
  group('stableHash', () {
    test('is deterministic and content-sensitive', () {
      expect(stableHash('abc'), stableHash('abc'));
      expect(stableHash('abc'), isNot(stableHash('abd')));
    });

    test('empty string hashes without error', () {
      expect(stableHash(''), isA<int>());
    });
  });

  test('CacheEntry round-trips through JSON (incl. topFunctions)', () {
    const entry = CacheEntry(
      hash: 12345,
      maintainability: 42.5,
      maintainabilityRaw: -10.2,
      docCoverage: 0.6,
      complexity: FileComplexity(
        functionCount: 2,
        maxCyclomatic: 9,
        maxCognitive: 15,
        maxVariableCount: 7,
        maxBooleanTerms: 3,
        maxNesting: 4,
        worstLcom: 0.5,
        topFunctions: [
          FunctionMetric(
            name: 'big',
            lineStart: 10,
            lineEnd: 40,
            cyclomatic: 9,
            cognitive: 15,
            variableCount: 7,
            parameterCount: 2,
            maxBooleanTerms: 3,
            nesting: 4,
            exitPoints: 2,
          ),
        ],
      ),
    );
    final restored = CacheEntry.fromJson(entry.toJson());
    expect(restored.hash, 12345);
    expect(restored.maintainabilityRaw, -10.2);
    expect(restored.complexity.maxCognitive, 15);
    expect(restored.complexity.topFunctions.single.name, 'big');
    expect(restored.complexity.topFunctions.single.lineStart, 10);
  });
}
