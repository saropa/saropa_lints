// ignore_for_file: unused_local_variable, unused_element, avoid_print
// Test fixture for test rules added in v2.3.10

// =========================================================================
// avoid_test_print_statements
// =========================================================================
// Warns when print statements are used in test files instead of expect().

void badTestWithPrint() {
  test('should fetch data', () async {
    final result = await fetchData();
    // expect_lint: avoid_test_print_statements
    print('Result: $result'); // Bad - use expect() instead!
  });
}

void badTestWithDebugPrint() {
  test('should process data', () async {
    final data = processData('input');
    // expect_lint: avoid_test_print_statements
    debugPrint('Processed: $data'); // Also bad
  });
}

void goodTestWithExpect() {
  test('should fetch data correctly', () async {
    final result = await fetchData();
    expect(result, equals('expected data')); // Good - proper assertion
  });
}

// =========================================================================
// require_mock_http_client
// =========================================================================
// Warns when tests make real HTTP calls instead of using mocks.

void badTestWithRealHttp() {
  test('should fetch user', () async {
    // expect_lint: require_mock_http_client
    final response = await http.get(Uri.parse('https://api.example.com/user'));
    expect(response.statusCode, equals(200));
  });
}

void badTestWithDioRealCall() {
  test('should post data', () async {
    final dio = Dio();
    // expect_lint: require_mock_http_client
    final response = await dio.post('https://api.example.com/data');
    expect(response.statusCode, equals(201));
  });
}

void goodTestWithMockClient() {
  test('should fetch user with mock', () async {
    final mockClient = MockHttpClient();
    when(mockClient.get(any)).thenReturn(Response(statusCode: 200));

    final response = await mockClient.get(Uri.parse('/user'));
    expect(response.statusCode, equals(200));
  });
}

// =========================================================================
// Helper mocks
// =========================================================================

void test(String description, Function body) {}
void expect(dynamic actual, Matcher matcher) {}
Matcher equals(dynamic value) => Matcher();

class Matcher {}

Future<String> fetchData() async => 'data';
String processData(String input) => input;
void debugPrint(String message) {}

class http {
  static Future<Response> get(Uri uri) async => Response(statusCode: 200);
}

class Dio {
  Future<Response> post(String url) async => Response(statusCode: 201);
  Future<Response> get(String url) async => Response(statusCode: 200);
}

class Response {
  Response({required this.statusCode});
  final int statusCode;
}

class MockHttpClient {
  Future<Response> get(Uri uri) async => Response(statusCode: 200);
}

void when(dynamic call) {}

class Uri {
  static Uri parse(String source) => Uri._();
  Uri._();
}
