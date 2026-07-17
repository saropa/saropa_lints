// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_identifier, undefined_method, undefined_class
// Compliant examples for require_intl_locale_initialization, kept in their own
// file. The rule is whole-file: a locale init anywhere marks the file
// initialized, so these must not share a file with the BAD fixture.
import 'package:saropa_lints_example/flutter_mocks.dart';

// GOOD: initializes the locale before any intl usage.
void main() async {
  Intl.defaultLocale = 'en_US';
  await initializeDateFormatting('en_US');
  runApp(MyApp());
}

// GOOD: initializes from the device locale.
void mainFromDevice() async {
  final deviceLocale = Platform.localeName;
  Intl.defaultLocale = deviceLocale;
  await initializeDateFormatting(deviceLocale);
  runApp(MyApp());
}
