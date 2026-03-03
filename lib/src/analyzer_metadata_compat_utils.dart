// ignore_for_file: depend_on_referenced_packages

library;

import 'package:analyzer/dart/element/element.dart';

/// Compatibility helpers for analyzer API shape changes.
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
    final anns = (metadata as dynamic).annotations;
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
  try {
    final v = (element as dynamic).hasDeprecated;
    if (v is bool) return v;
  } on Object {
    // Defensive: ignore any throw, return false.
  }
  try {
    final v = (element as dynamic).isDeprecated;
    if (v is bool) return v;
  } on Object {
    // Defensive: ignore any throw, return false.
  }
  return false;
}
