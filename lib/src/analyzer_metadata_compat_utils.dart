// ignore_for_file: depend_on_referenced_packages

library;

import 'package:analyzer/dart/element/element.dart';

/// Compatibility helpers for analyzer API shape changes.
///
/// These functions are intentionally defensive: if metadata/flags cannot be
/// read safely, they return empty/false instead of throwing (plugin safety).

Iterable<ElementAnnotation> readElementAnnotationsFromMetadata(
  Object? metadata,
) {
  if (metadata == null) return const <ElementAnnotation>[];

  // analyzer 9+: `metadata` is a wrapper (e.g. MetadataImpl) that exposes an
  // `.annotations` list.
  if (metadata is Metadata) return metadata.annotations;

  // Older analyzer: metadata may be a direct iterable.
  if (metadata is Iterable<ElementAnnotation>) return metadata;
  if (metadata is Iterable) return metadata.whereType<ElementAnnotation>();

  // Some analyzer versions expose a wrapper object with `.annotations` but the
  // type may not be `Metadata` in our constraints. Treat unknown shapes as empty.
  try {
    final anns = (metadata as dynamic).annotations;
    if (anns is Iterable<ElementAnnotation>) return anns;
    if (anns is Iterable) return anns.whereType<ElementAnnotation>();
  } catch (_) {}

  return const <ElementAnnotation>[];
}

bool hasDeprecatedFlag(Object? element) {
  if (element == null) return false;

  try {
    final v = (element as dynamic).hasDeprecated;
    if (v is bool) return v;
  } catch (_) {}

  try {
    final v = (element as dynamic).isDeprecated;
    if (v is bool) return v;
  } catch (_) {}

  return false;
}
