// ignore_for_file: unused_local_variable, unused_element, undefined_class
// ignore_for_file: non_constant_identifier_names

/// Fixture for `avoid_dio_error` lint rule.
///
/// dio 5.0 removed `DioError` in favor of `DioException`. The rule flags the
/// removed type in files that import dio. Gated to the `dio_5` pack.
library;

import 'package:dio/dio.dart';

// BAD: removed type used as a catch-clause type.
Future<void> badCatch(Dio dio) async {
  try {
    await dio.get<void>('/x');
  } on DioError catch (e) {
    // LINT: DioError was removed in dio 5.0 — use DioException
    print(e);
  }
}

// BAD: removed type used as a variable / parameter type.
void badParam(DioError error) {
  // LINT: DioError was removed in dio 5.0 — use DioException
  print(error);
}

// GOOD: the replacement type does not trigger.
Future<void> goodCatch(Dio dio) async {
  try {
    await dio.get<void>('/x');
  } on DioException catch (e) {
    // OK: DioException is the dio 5.0+ type
    print(e);
  }
}
