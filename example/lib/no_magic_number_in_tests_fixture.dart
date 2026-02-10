// Test fixture for no_magic_number_in_tests rule
// ignore_for_file: avoid_double_for_money

void badExamples() {
  // LINT: Domain-specific values should be named constants
  final product = Product(price: 29.99); // LINT
  final discount = 0.15; // LINT
  final maxAttempts = 137; // LINT
  final timeout = 5000; // LINT
}

void goodExamples() {
  // Named constants for domain values
  const validPrice = 29.99;
  final product = Product(price: validPrice);

  const discountRate = 0.15;
  final discount = discountRate;

  // Allowed common values
  final statusCode = 200; // OK: Common HTTP status
  final notFound = 404; // OK: Common HTTP status
  final serverError = 500; // OK: Common HTTP status
  final count = 0; // OK: Allowed value
  final index = 1; // OK: Allowed value
  final size = 10; // OK: Allowed value
  final factor = 0.5; // OK: Allowed double
  final percentage = 1.0; // OK: Allowed double

  // Const context
  const maxRetries = 999; // OK: In const context
}

class Product {
  final double price;
  Product({required this.price});
}
