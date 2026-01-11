// ignore_for_file: unused_local_variable, unused_element
// Test fixture for API/network rules added in v2.3.10

// =========================================================================
// prefer_timeout_on_requests
// =========================================================================
// Warns when HTTP requests don't have a timeout specified.

// BAD: HTTP request without timeout
Future<void> badHttpGetNoTimeout() async {
  // expect_lint: prefer_timeout_on_requests
  final response = await http.get(Uri.parse('https://api.example.com/data'));
}

// BAD: HTTP client request without timeout
Future<void> badHttpClientNoTimeout() async {
  final client = HttpClient();
  // expect_lint: prefer_timeout_on_requests
  final response = await client.get(Uri.parse('/users'));
}

// GOOD: HTTP request with timeout
Future<void> goodHttpGetWithTimeout() async {
  final response = await http
      .get(Uri.parse('https://api.example.com/data'))
      .timeout(const Duration(seconds: 30));
}

// GOOD: Using Dio with base timeout configuration
Future<void> goodDioWithTimeout() async {
  final dio = Dio(BaseOptions(
    connectTimeout: Duration(seconds: 30),
    receiveTimeout: Duration(seconds: 30),
  ));
  final response = await dio.get('/data');
}

// =========================================================================
// prefer_dio_over_http
// =========================================================================
// Warns when using the http package instead of Dio.

// BAD: Importing http package
// expect_lint: prefer_dio_over_http
// import 'package:http/http.dart' as http;

// GOOD: Using Dio instead
// import 'package:dio/dio.dart';

// =========================================================================
// Helper mocks
// =========================================================================

class http {
  static Future<Response> get(Uri uri) async => Response();
  static Future<Response> post(Uri uri, {Object? body}) async => Response();
}

class HttpClient {
  Future<Response> get(Uri uri) async => Response();
}

class Dio {
  Dio([BaseOptions? options]);
  Future<DioResponse> get(String path) async => DioResponse();
  Future<DioResponse> post(String path, {Object? data}) async => DioResponse();
}

class BaseOptions {
  BaseOptions({this.connectTimeout, this.receiveTimeout});
  final Duration? connectTimeout;
  final Duration? receiveTimeout;
}

class Response {
  int get statusCode => 200;
}

class DioResponse {
  int get statusCode => 200;
}

class Uri {
  static Uri parse(String source) => Uri._();
  Uri._();
}

class Duration {
  const Duration({this.seconds = 0});
  final int seconds;
}

extension FutureTimeout<T> on Future<T> {
  Future<T> timeout(Duration duration) => this;
}
