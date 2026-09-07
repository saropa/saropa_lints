/// Pure helper functions for the [AlwaysSpecifyParameterNamesRule].
///
/// Extracted from the rule file to stay within the 200-line-per-file limit.
/// These are side-effect-free and unit-testable without the analyzer — the
/// rule file handles AST wiring and type resolution, this file handles the
/// string-level confusability algebra.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

/// Well-known constructors where positional pairs are idiomatic Dart/Flutter
/// convention and the swap risk is understood/accepted by the ecosystem.
/// Keyed by class name; values are the minimum positional arg count that
/// triggers the allowlist bypass (typically 2).
const Map<String, int> allowlistedConstructors = <String, int>{
  'Offset': 2, // Offset(dx, dy)
  'Point': 2, // Point(x, y)
  'Size': 2, // Size(width, height)
  'Rect': 4, // Rect.fromLTRB(l, t, r, b)
  'MutableRectangle': 4, // MutableRectangle(x, y, w, h)
  'Rectangle': 4, // Rectangle(x, y, w, h)
};

/// Extracts the positional (non-named) arguments from an [ArgumentList],
/// preserving call-site order.
List<Expression> collectPositionalArgs(ArgumentList arguments) {
  final positionalArgs = <Expression>[];
  for (final arg in arguments.arguments) {
    // Named expressions are already disambiguated — skip them
    if (arg is NamedExpression) continue;
    positionalArgs.add(arg);
  }
  return positionalArgs;
}

/// Maps each positional argument to its confusable-type-group name.
/// Unknown/unresolved types get a unique sentinel that breaks runs.
List<String> buildTypeNames(List<Expression> positionalArgs) {
  final typeNames = <String>[];
  for (int i = 0; i < positionalArgs.length; i++) {
    final staticType = positionalArgs[i].staticType;
    if (staticType == null) {
      // Unknown type — unique sentinel to prevent false-positive runs
      typeNames.add('__unknown_$i');
      continue;
    }
    typeNames.add(normalizeTypeName(staticType));
  }
  return typeNames;
}

/// Normalizes a DartType to a group name for confusability comparison.
///
/// Types in the same group are considered "confusable" — swapping two args
/// of the same group compiles cleanly and may silently produce wrong behavior.
String normalizeTypeName(DartType type) {
  // Skip dynamic/Object? — too noisy, everything is confusable with them
  if (type is DynamicType) return '__dynamic';
  if (type is VoidType) return '__void';

  final element = type.element;
  final name = element?.name ?? type.getDisplayString();

  // Numeric group: int, double, num are all interchangeable in many contexts
  if (type.isDartCoreInt || type.isDartCoreDouble || type.isDartCoreNum) {
    return 'numeric';
  }

  // String group
  if (type.isDartCoreString) return 'String';

  // Bool group
  if (type.isDartCoreBool) return 'bool';

  // Object? is too broad — skip
  if (type.isDartCoreObject) return '__object';

  // For all other types, use the element name so identical custom types
  // (e.g. two Duration args, two Color args) are also caught
  // getDisplayString() is non-nullable, so name is always a String.
  return name;
}

/// Finds runs of 2+ consecutive entries in [typeNames] that belong to the
/// same confusable group. Returns a list of (startIndex, endIndex) inclusive.
///
/// Entries starting with '__' are sentinel values (dynamic, void, object,
/// unknown) that never form confusable runs.
List<(int, int)> findConfusableRuns(List<String> typeNames) {
  final runs = <(int, int)>[];
  if (typeNames.length < 2) return runs;

  int runStart = 0;

  for (int i = 1; i < typeNames.length; i++) {
    // Delegate to areTypesConfusable so the confusability definition is in
    // one place (also exercised independently by unit tests)
    if (areTypesConfusable(typeNames[i], typeNames[runStart])) {
      // Extend the current run — same confusable group
      continue;
    }

    // End the current run if it was 2+ elements
    if (i - runStart >= 2) {
      runs.add((runStart, i - 1));
    }
    // Start a new run from this position
    runStart = i;
  }

  // Check the final run
  if (typeNames.length - runStart >= 2) {
    runs.add((runStart, typeNames.length - 1));
  }

  return runs;
}

/// Returns true if two type-group names are "confusable" — i.e. swapping
/// arguments of these types would compile silently.
///
/// Exposed for unit testing.
bool areTypesConfusable(String type1, String type2) {
  // Sentinels are never confusable with anything
  if (type1.startsWith('__') || type2.startsWith('__')) return false;
  return type1 == type2;
}
