// ignore_for_file: depend_on_referenced_packages, unused_local_variable
// ignore_for_file: unused_element, unused_import

import 'package:flutter/services.dart';

class MethodChannelInstrumented {
  const MethodChannelInstrumented([this.rationale]);
  final String? rationale;
}

Future<T> noteIfSlow<T>(String label, Future<T> Function() fn) => fn();

// ---------------------------------------------------------------------------
// BAD — annotated class with bare invokeMethod (not wrapped in noteIfSlow)
// ---------------------------------------------------------------------------

@MethodChannelInstrumented('all calls instrumented')
class BareInvokeService {
  final channel = const MethodChannel('bare');

  // expect_lint: prefer_method_channel_note_if_slow
  Future<String?> getName() => channel.invokeMethod('getName');

  // expect_lint: prefer_method_channel_note_if_slow
  Future<List<Object?>?> getAll() => channel.invokeListMethod('getAll');

  // expect_lint: prefer_method_channel_note_if_slow
  Future<Map<Object?, Object?>?> getMap() =>
      channel.invokeMapMethod('getMap');
}

// ---------------------------------------------------------------------------
// GOOD — annotated class with invokeMethod wrapped in noteIfSlow
// ---------------------------------------------------------------------------

@MethodChannelInstrumented('all calls wrapped with noteIfSlow')
class WrappedInvokeService {
  final channel = const MethodChannel('wrapped');

  Future<String?> getName() =>
      noteIfSlow('getName', () => channel.invokeMethod('getName'));

  Future<List<Object?>?> getAll() =>
      noteIfSlow('getAll', () => channel.invokeListMethod('getAll'));
}

// ---------------------------------------------------------------------------
// GOOD — class WITHOUT the annotation (rule does not apply)
// ---------------------------------------------------------------------------

class UnannotatedService {
  final channel = const MethodChannel('unannotated');

  Future<String?> getName() => channel.invokeMethod('getName');
}

// ---------------------------------------------------------------------------
// GOOD — top-level function (no class, no annotation to check)
// ---------------------------------------------------------------------------

Future<void> topLevelBareInvoke() async {
  const channel = MethodChannel('top');
  await channel.invokeMethod('ping');
}
