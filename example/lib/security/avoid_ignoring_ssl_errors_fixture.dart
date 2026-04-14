// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_ignoring_ssl_errors` lint rule.

// NOTE: avoid_ignoring_ssl_errors fires on badCertificateCallback
// property assignments that return true (ignoring all SSL errors).
//
// BAD:
// client.badCertificateCallback = (cert, host, port) => true;
//
// GOOD:
// client.badCertificateCallback = (cert, host, port) =>
//     _verifyCertificate(cert, host);

void main() {}
