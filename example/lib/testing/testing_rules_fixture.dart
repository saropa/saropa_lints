// ignore_for_file: unused_local_variable, unused_element

/// Test fixture for testing-related lint rules.
///
/// This file demonstrates patterns that trigger the following rules:
/// - prefer_fake_over_mock
/// - require_edge_case_tests
/// - prefer_test_data_builder
/// - avoid_test_implementation_details

// Note: These rules only run in test files (_test.dart)
// This fixture demonstrates the patterns they detect.

// =============================================================================
// prefer_fake_over_mock
// =============================================================================
// Warns about excessive mocking with verify() chains when simpler fakes
// would be more maintainable.

// BAD: Excessive mocking with verify chains
// test('loads user with excessive mocking', () {
//   final mockRepo = MockUserRepository();
//   final mockApi = MockApiClient();
//   when(mockRepo.getUser(any)).thenReturn(user);
//   when(mockApi.fetch(any)).thenReturn(response);
//   when(mockRepo.save(any)).thenReturn(true);
//
//   service.loadUser(1);
//
//   verify(mockRepo.getUser(1)).called(1);
//   verify(mockApi.fetch('/user/1')).called(1);
//   verify(mockRepo.save(any)).called(1);
// });

// GOOD: Using fakes for simpler, more maintainable tests
class FakeUserRepository {
  final Map<int, User> users = {};

  User? getUser(int id) => users[id];
  void save(User user) => users[user.id] = user;
}

// test('loads user', () {
//   final fakeRepo = FakeUserRepository()..users[1] = testUser;
//   final result = service.loadUser(1);
//   expect(result, testUser); // Test behavior, not implementation
// });

// =============================================================================
// require_edge_case_tests
// =============================================================================
// Warns when test files have many tests but few edge case patterns.
// Edge cases include: empty collections, null values, boundary numbers.

// BAD: Only happy path tests (file would need 5+ tests with <2 edge cases)
// test('calculates total', () {
//   expect(calculateTotal([10, 20, 30]), 60);
// });
// test('calculates average', () {
//   expect(calculateAverage([10, 20, 30]), 20);
// });
// ... more happy path tests

// GOOD: Include edge case tests
// test('calculates total with empty list', () {
//   expect(calculateTotal([]), 0);
// });
// test('calculates total with null safety', () {
//   expect(calculateTotal(null), 0);
// });
// test('handles maximum integer boundary', () {
//   expect(() => calculateTotal([maxInt, 1]), throwsOverflowException);
// });
// test('handles negative numbers', () {
//   expect(calculateTotal([-5, 10]), 5);
// });

// =============================================================================
// prefer_test_data_builder
// =============================================================================
// Warns when tests create complex objects with many constructor parameters.
// Builder pattern makes tests more readable and maintainable.

class User {
  final int id;
  final String name;
  final String email;
  final int age;
  final String? phone;
  final String? address;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.age,
    this.phone,
    this.address,
  });
}

// BAD: Complex object construction inline in tests
// test('user profile displays correctly', () {
//   final user = User(
//     id: 1,
//     name: 'Test User',
//     email: 'test@example.com',
//     age: 30,
//     phone: '+1234567890',
//     address: '123 Test Street, Test City, TC 12345',
//   );
//   // ... test assertions
// });

// GOOD: Use builder pattern
class UserBuilder {
  int _id = 1;
  String _name = 'Test User';
  String _email = 'test@example.com';
  int _age = 25;
  String? _phone;
  String? _address;

  UserBuilder withId(int id) {
    _id = id;
    return this;
  }

  UserBuilder withName(String name) {
    _name = name;
    return this;
  }

  UserBuilder withEmail(String email) {
    _email = email;
    return this;
  }

  UserBuilder withAge(int age) {
    _age = age;
    return this;
  }

  UserBuilder withPhone(String phone) {
    _phone = phone;
    return this;
  }

  UserBuilder withAddress(String address) {
    _address = address;
    return this;
  }

  User build() => User(
        id: _id,
        name: _name,
        email: _email,
        age: _age,
        phone: _phone,
        address: _address,
      );
}

// Usage:
// test('user profile displays correctly', () {
//   final user = UserBuilder()
//     .withName('Custom Name')
//     .withAge(35)
//     .build();
//   // ... test assertions
// });

// =============================================================================
// avoid_test_implementation_details
// =============================================================================
// Warns when tests verify internal method calls instead of observable behavior.
// Tests should be resilient to refactoring.

// BAD: Testing implementation details
// test('loads user', () {
//   final mockApi = MockApiClient();
//   when(mockApi.get(any)).thenReturn(userData);
//
//   service.loadUser(1);
//
//   // Testing internal implementation - breaks if we refactor
//   verify(mockApi.get('/users/1')).called(1);
//   verify(mockApi.headers = any).called(1);
//   verify(mockApi.setCache(any)).called(1);
// });

// GOOD: Testing observable behavior
// test('loads user returns correct data', () {
//   final user = service.loadUser(1);
//   expect(user.name, 'John');
//   expect(user.email, 'john@example.com');
// });
//
// test('loads user throws on invalid id', () {
//   expect(() => service.loadUser(-1), throwsArgumentError);
// });
