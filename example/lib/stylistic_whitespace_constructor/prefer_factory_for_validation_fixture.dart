// ignore_for_file: unused_element

/// Fixture for `prefer_factory_for_validation`.

class Email {
  final String value;

  // LINT: validation in generative constructor — factory can express failure paths
  Email(this.value) {
    if (!value.contains('@')) {
      throw ArgumentError('Invalid email');
    }
  }
}
