/// Pure helper functions for the [AlwaysSpecifyParameterNamesRule].
///
/// Extracted from the rule file to stay within the 200-line-per-file limit.
/// These are side-effect-free and unit-testable without the analyzer — the
/// rule file handles AST wiring and type resolution, this file handles the
/// string-level confusability algebra.
library;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';

/// One allowlisted constructor: the class name, the declaring library's URI
/// (so a user-defined class that happens to share a name like `Size` is NOT
/// silently exempted — a false negative found in review), and the maximum
/// positional arg count the idiomatic form uses.
typedef AllowlistedConstructor = ({
  String className,
  String libraryUri,
  int maxArgs,
});

/// Well-known constructors where positional pairs are idiomatic Dart/Flutter
/// convention and the swap risk is understood/accepted by the ecosystem.
const List<AllowlistedConstructor>
allowlistedConstructors = <AllowlistedConstructor>[
  (className: 'Offset', libraryUri: 'dart:ui', maxArgs: 2), // Offset(dx, dy)
  (className: 'Size', libraryUri: 'dart:ui', maxArgs: 2), // Size(width, height)
  (
    className: 'Rect',
    libraryUri: 'dart:ui',
    maxArgs: 4,
  ), // Rect.fromLTRB(l, t, r, b)
  (className: 'Point', libraryUri: 'dart:math', maxArgs: 2), // Point(x, y)
  (
    className: 'Rectangle',
    libraryUri: 'dart:math',
    maxArgs: 4,
  ), // Rectangle(x, y, w, h)
  (
    className: 'MutableRectangle',
    libraryUri: 'dart:math',
    maxArgs: 4,
  ), // MutableRectangle(x, y, w, h)
];

/// Returns the max positional arg count for an allowlisted constructor
/// matching both [className] and [libraryUri], or null if not allowlisted.
/// Matching on library URI (not just class name) prevents a user-defined
/// class that happens to share a name like `Size` from being silently
/// exempted from the swap-risk check.
///
/// [extra] lets a caller add project-specific entries (e.g. from
/// `analysis_options_custom.yaml`) without this pure-logic file depending on
/// the config-loading module — passed in by the rule, not read globally
/// here, to keep this file free of I/O/config concerns.
int? findAllowlistedMaxArgs(
  String? className,
  String libraryUri, {
  List<AllowlistedConstructor> extra = const [],
}) {
  if (className == null) return null;
  for (final entry in allowlistedConstructors.followedBy(extra)) {
    if (entry.className == className && entry.libraryUri == libraryUri) {
      return entry.maxArgs;
    }
  }
  return null;
}

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

  // getDisplayString() includes type arguments (List<String> vs List<int>),
  // unlike element?.name (bare 'List' for both) — using the bare name would
  // silently merge two generic-collection args of incompatible element types
  // into one confusable group, a false positive found in review.
  final name = type.getDisplayString();

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

  // For all other types, use the full display string so identical custom
  // types (e.g. two Duration args, two Color args) are also caught, while
  // differently-parameterized generics (List<String> vs List<int>) are not.
  // Strip a single trailing '?' so a nullable and non-nullable variant of the
  // same outer type (Duration vs Duration?) still group as confusable — the
  // swap risk is the same either way, and getDisplayString() would otherwise
  // treat them as unrelated (found in review; the core-type branches above
  // already handle this correctly via isDartCoreString/-Int/etc., which
  // return true regardless of nullability).
  return name.endsWith('?') ? name.substring(0, name.length - 1) : name;
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
    // Compare against the immediately preceding entry (not runStart) — reads
    // as plain adjacent-pair comparison. Delegates to areTypesConfusable so
    // the confusability definition is in one place (also exercised
    // independently by unit tests).
    if (areTypesConfusable(typeNames[i], typeNames[i - 1])) {
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
