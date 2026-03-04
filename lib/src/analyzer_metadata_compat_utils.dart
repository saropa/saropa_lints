// ignore_for_file: depend_on_referenced_packages

library;

import 'package:analyzer/dart/element/element.dart';

/// Compatibility helpers for analyzer API shape changes.
///
/// **Element.metadata (analyzer 9+):** In analyzer 9+, [Element.metadata] returns
/// [Metadata] (runtime `MetadataImpl`), not `Iterable`. Iterating it directly
/// causes "MetadataImpl is not a subtype of Iterable". Annotations must be read
/// via [Metadata.annotations] or through [readElementAnnotationsFromMetadata].
/// In this repo only two call sites read Element metadata: HandleThrowingInvocationsRule
/// (_hasThrowsAnnotation) and AvoidDeprecatedUsageRule (_isDeprecated); both use
/// this helper. AST `node.metadata` / `member.metadata` (AnnotatedNode) remains
/// iterable and is unchanged.
///
/// **Plugin safety (fatal-crash prevention):** All functions are defensive.
/// - Never throw. Use `on Object` to catch both Exception and Error.
/// - Never return live references to host analyzer objects that might throw
///   when iterated (e.g. MetadataImpl). Always return a defensive copy (list).
/// - Do not rely on the analyzer's [Metadata] type; host may use a different version.

/// Returns a **defensive copy** of annotations from [metadata]. Never returns
/// a live reference to host objects, so iteration cannot trigger a fatal crash.
List<ElementAnnotation> readElementAnnotationsFromMetadata(Object? metadata) {
  try {
    // Outer try: any throw (e.g. from .annotations getter or .toList() iteration) returns [].
    if (metadata == null) return const <ElementAnnotation>[];

    // 1) Prefer .annotations via dynamic (no dependency on Metadata type).
    final dynamic m = metadata;
    final anns = m.annotations;
    if (anns != null) {
      if (anns is Iterable<ElementAnnotation>) return anns.toList();
      if (anns is Iterable) return anns.whereType<ElementAnnotation>().toList();
    }

    // 2) Older analyzer: metadata may be a direct iterable.
    if (metadata is Iterable<ElementAnnotation>) return metadata.toList();
    if (metadata is Iterable) {
      return metadata.whereType<ElementAnnotation>().toList();
    }

    return const <ElementAnnotation>[];
  } on Object {
    return const <ElementAnnotation>[];
  }
}

bool hasDeprecatedFlag(Object? element) {
  if (element == null) return false;
  final dynamic e = element;
  try {
    final v = e.hasDeprecated;
    if (v is bool) return v;
  } on NoSuchMethodError {
    return false;
  } on TypeError {
    return false;
  }
  try {
    final v = e.isDeprecated;
    if (v is bool) return v;
  } on NoSuchMethodError {
    return false;
  } on TypeError {
    return false;
  }
  return false;
}
