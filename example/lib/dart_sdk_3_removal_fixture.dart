// ignore_for_file: undefined_class, undefined_annotation, undefined_getter
// ignore_for_file: undefined_function, new_with_undefined_constructor_default
// ignore_for_file: undefined_method, invalid_use_of_void_result
// ignore_for_file: unused_element, unused_local_variable, dead_code
//
// Test fixture: Dart SDK 3.0 removed APIs (dart_sdk_3_removal_rules.dart)

// expect_lint: avoid_removed_deferred_library
@DeferredLibrary('other.dart')
library dart_sdk_3_removal_fixture;

import 'dart:collection';
import 'dart:developer';
import 'dart:io';

// expect_lint: avoid_removed_proxy_annotation
@proxy
class _ProxyHolder {}

// expect_lint: avoid_removed_provisional_annotation
@Provisional()
class _ProvisionalHolder {}

void badListLiteral() {
  // expect_lint: avoid_deprecated_list_constructor
  final _ = List();
}

void badListTyped() {
  // expect_lint: avoid_deprecated_list_constructor
  final _ = List<int>();
}

void badExpires() {
  const d = Deprecated('migrate');
  // expect_lint: avoid_deprecated_expires_getter
  final _ = d.expires;
}

// expect_lint: avoid_removed_cast_error
void badCastErrorParameter(CastError e) {}

void badCastErrorVar() {
  // expect_lint: avoid_removed_cast_error
  CastError? x;
}

// expect_lint: avoid_removed_fall_through_error
void badFallThrough(FallThroughError e) {}

// expect_lint: avoid_removed_abstract_class_instantiation_error
void badAbstractInst(AbstractClassInstantiationError e) {}

// expect_lint: avoid_removed_cyclic_initialization_error
void badCyclic(CyclicInitializationError e) {}

void badNoSuchMethod() {
  // expect_lint: avoid_removed_nosuchmethoderror_default_constructor
  throw NoSuchMethodError();
}

// expect_lint: avoid_removed_bidirectional_iterator
void badBidirectional(BidirectionalIterator<int> i) {}

void badDeferredCall() {
  // expect_lint: avoid_removed_deferred_library
  DeferredLibrary('other.dart');
}

// ── dart:collection / dart:developer / dart:io (SDK 3.0 migrations) ─────────

void badHasNextIterator() {
  // expect_lint: avoid_deprecated_has_next_iterator
  final _ = HasNextIterator([1].iterator);
}

void badMaxUserTags() {
  // expect_lint: avoid_removed_max_user_tags_constant
  final _ = UserTag.MAX_USER_TAGS;
}

void badDeveloperMetrics() {
  // expect_lint: avoid_removed_dart_developer_metrics
  Metrics? m;
  // expect_lint: avoid_removed_dart_developer_metrics
  Metric? t;
  // expect_lint: avoid_removed_dart_developer_metrics
  Counter? c;
  // expect_lint: avoid_removed_dart_developer_metrics
  Gauge<int>? g;
}

Future<void> badListSupported() async {
  // expect_lint: avoid_deprecated_network_interface_list_supported
  await NetworkInterface.listSupported;
}
