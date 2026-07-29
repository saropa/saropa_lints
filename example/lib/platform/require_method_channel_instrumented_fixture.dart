// ignore_for_file: depend_on_referenced_packages, unused_local_variable
// ignore_for_file: unused_element, unused_import

import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// BAD — class calls invokeMethod without @MethodChannelInstrumented
// ---------------------------------------------------------------------------

class ContactsService {
  final channel = const MethodChannel('contacts');

  // expect_lint: require_method_channel_instrumented
  Future<List<Object?>?> getAll() => channel.invokeListMethod('getAll');

  Future<void> delete(String id) => channel.invokeMethod('delete', id);
}

class PaymentGateway {
  final _channel = const MethodChannel('payments');

  // expect_lint: require_method_channel_instrumented
  Future<Map<Object?, Object?>?> charge(int amount) =>
      _channel.invokeMapMethod('charge', {'amount': amount});
}

// ---------------------------------------------------------------------------
// BAD — invokeMethod with type parameter (still detected)
// ---------------------------------------------------------------------------

class TypedInvokeService {
  final _channel = const MethodChannel('typed');

  // expect_lint: require_method_channel_instrumented
  Future<String?> getName() => _channel.invokeMethod<String>('getName');
}

// ---------------------------------------------------------------------------
// GOOD — class has @MethodChannelInstrumented annotation (bare import)
// ---------------------------------------------------------------------------

class MethodChannelInstrumented {
  const MethodChannelInstrumented([this.rationale]);
  final String? rationale;
}

@MethodChannelInstrumented('all calls wrapped with noteIfSlow')
class InstrumentedService {
  final channel = const MethodChannel('instrumented');

  Future<String?> getName() => channel.invokeMethod('getName');
}

// ---------------------------------------------------------------------------
// GOOD — no invoke-method calls, no annotation needed
// ---------------------------------------------------------------------------

class PureDartService {
  String greet(String name) => 'Hello, $name';
}

// ---------------------------------------------------------------------------
// GOOD — top-level function, not in a class (no class to annotate)
// ---------------------------------------------------------------------------

Future<void> topLevelCall() async {
  const channel = MethodChannel('top');
  await channel.invokeMethod('ping');
}

// ---------------------------------------------------------------------------
// GOOD — method named invokeMethod on a non-MethodChannel class (near-miss)
// ---------------------------------------------------------------------------

class CustomRpc {
  Future<void> invokeMethod(String name) async {}
}

class UsesCustomRpc {
  final rpc = CustomRpc();

  // NOTE: This WILL fire because the rule is name-based. Consumers with
  // a custom invokeMethod should add the annotation to suppress.
}
