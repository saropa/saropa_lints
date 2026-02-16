// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: unused_field
// ignore_for_file: prefer_const_constructors, unnecessary_import
// ignore_for_file: unused_import, avoid_unused_constructor_parameters
// ignore_for_file: override_on_non_overriding_member, annotate_overrides
// ignore_for_file: duplicate_ignore, non_abstract_class_inherits_abstract_member
// ignore_for_file: extends_non_class, mixin_of_non_class
// ignore_for_file: field_initializer_outside_constructor, final_not_initialized
// ignore_for_file: super_in_invalid_context, concrete_class_with_abstract_member
// ignore_for_file: type_argument_not_matching_bounds, missing_required_argument
// ignore_for_file: undefined_named_parameter, argument_type_not_assignable
// ignore_for_file: invalid_constructor_name, super_formal_parameter_without_associated_named
// ignore_for_file: undefined_annotation, creation_with_non_type
// ignore_for_file: invalid_factory_name_not_a_class, invalid_reference_to_this
// ignore_for_file: expected_class_member, body_might_complete_normally
// ignore_for_file: not_initialized_non_nullable_instance_field, unchecked_use_of_nullable_value
// ignore_for_file: return_of_invalid_type, use_of_void_result
// ignore_for_file: missing_function_body, extra_positional_arguments
// ignore_for_file: not_enough_positional_arguments, unused_label
// ignore_for_file: unused_element_parameter, non_type_as_type_argument
// ignore_for_file: expected_identifier_but_got_keyword, expected_token
// ignore_for_file: missing_identifier, unexpected_token
// ignore_for_file: duplicate_definition, override_on_non_overriding_member
// ignore_for_file: extends_non_class, no_default_super_constructor
// ignore_for_file: extra_positional_arguments_could_be_named, missing_function_parameters
// ignore_for_file: invalid_annotation, invalid_assignment
// ignore_for_file: expected_executable, named_parameter_outside_group
// ignore_for_file: obsolete_colon_for_default_value, referenced_before_declaration
// ignore_for_file: await_in_wrong_context, non_type_in_catch_clause
// ignore_for_file: could_not_infer, uri_does_not_exist
// ignore_for_file: const_method, redirect_to_non_class
// ignore_for_file: unused_catch_clause, type_test_with_undefined_name
// ignore_for_file: undefined_identifier, undefined_function
// ignore_for_file: undefined_method, undefined_getter
// ignore_for_file: undefined_setter, undefined_class
// ignore_for_file: undefined_super_member, extraneous_modifier
// ignore_for_file: experiment_not_enabled, missing_const_final_var_or_type
// ignore_for_file: undefined_operator, dead_code
// ignore_for_file: invalid_override, not_initialized_non_nullable_variable
// ignore_for_file: list_element_type_not_assignable, assignment_to_final
// ignore_for_file: equal_elements_in_set, prefix_shadowed_by_local_declaration
// ignore_for_file: const_initialized_with_non_constant_value, non_constant_list_element
// ignore_for_file: missing_statement, unnecessary_cast
// ignore_for_file: unnecessary_null_comparison, unnecessary_type_check
// ignore_for_file: invalid_super_formal_parameter_location, assignment_to_type
// ignore_for_file: instance_member_access_from_factory, field_initializer_not_assignable
// ignore_for_file: constant_pattern_with_non_constant_expression, undefined_identifier_await
// ignore_for_file: cast_to_non_type, read_potentially_unassigned_final
// ignore_for_file: mixin_with_non_class_superclass, instantiate_abstract_class
// ignore_for_file: dead_code_on_catch_subtype, unreachable_switch_case
// ignore_for_file: new_with_undefined_constructor, assignment_to_final_local
// ignore_for_file: late_final_local_already_assigned, missing_default_value_for_parameter
// ignore_for_file: non_bool_condition, non_exhaustive_switch_expression
// ignore_for_file: illegal_async_return_type, type_test_with_non_type
// ignore_for_file: invocation_of_non_function_expression, return_of_invalid_type_from_closure
// ignore_for_file: wrong_number_of_type_arguments_constructor, definitely_unassigned_late_local_variable
// ignore_for_file: static_access_to_instance_member, const_with_undefined_constructor
// ignore_for_file: abstract_super_member_reference, equal_keys_in_map
// ignore_for_file: unused_catch_stack, non_constant_default_value
// ignore_for_file: not_a_type
// Test fixture for internationalization rules

// Mock DateFormat class
class DateFormat {
  final String pattern;
  final String? locale;

  DateFormat(this.pattern, [this.locale]);

  factory DateFormat.yMd([String? locale]) => DateFormat('yMd', locale);
  factory DateFormat.yMMMd([String? locale]) => DateFormat('yMMMd', locale);
  factory DateFormat.yMMMMd([String? locale]) => DateFormat('yMMMMd', locale);
  factory DateFormat.Hm([String? locale]) => DateFormat('Hm', locale);
  factory DateFormat.jm([String? locale]) => DateFormat('jm', locale);

  String format(DateTime date) => '';
}

// Mock NumberFormat class
class NumberFormat {
  final String? pattern;
  final String? locale;

  NumberFormat(this.pattern, [this.locale]);

  factory NumberFormat.compact({String? locale}) =>
      NumberFormat('compact', locale);
  factory NumberFormat.currency({String? locale, String? symbol}) =>
      NumberFormat('currency', locale);
  factory NumberFormat.decimalPattern([String? locale]) =>
      NumberFormat('decimal', locale);
  factory NumberFormat.percentPattern([String? locale]) =>
      NumberFormat('percent', locale);
  factory NumberFormat.simpleCurrency({String? locale}) =>
      NumberFormat('simpleCurrency', locale);

  String format(num number) => '';
}

// =========================================================================
// require_intl_date_format_locale
// =========================================================================

void testDateFormatLocale() {
  final date = DateTime.now();
  const locale = 'en_US';

  // BAD: DateFormat constructor without locale
  // expect_lint: require_intl_date_format_locale
  final badFormat1 = DateFormat('yyyy-MM-dd');

  // BAD: DateFormat factory without locale
  // expect_lint: require_intl_date_format_locale
  final badFormat2 = DateFormat.yMd();

  // expect_lint: require_intl_date_format_locale
  final badFormat3 = DateFormat.yMMMd();

  // expect_lint: require_intl_date_format_locale
  final badFormat4 = DateFormat.Hm();

  // GOOD: DateFormat constructor with locale
  final goodFormat1 = DateFormat('yyyy-MM-dd', 'en_US');

  // GOOD: DateFormat factory with locale
  final goodFormat2 = DateFormat.yMd('en_US');
  final goodFormat3 = DateFormat.yMMMd(locale);
  final goodFormat4 = DateFormat.Hm('de_DE');
}

// =========================================================================
// require_number_format_locale
// =========================================================================

void testNumberFormatLocale() {
  final number = 1234.56;
  const locale = 'en_US';

  // BAD: NumberFormat constructor without locale
  // expect_lint: require_number_format_locale
  final badFormat1 = NumberFormat('#,###');

  // BAD: NumberFormat factory without locale
  // expect_lint: require_number_format_locale
  final badFormat2 = NumberFormat.compact();

  // expect_lint: require_number_format_locale
  final badFormat3 = NumberFormat.currency();

  // GOOD: NumberFormat constructor with locale
  final goodFormat1 = NumberFormat('#,###', 'en_US');

  // GOOD: NumberFormat factory with locale
  final goodFormat2 = NumberFormat.compact(locale: 'en_US');
  final goodFormat3 = NumberFormat.currency(locale: locale, symbol: r'$');
  final goodFormat4 = NumberFormat.decimalPattern('de_DE');
  final goodFormat5 = NumberFormat.percentPattern('fr_FR');

  // GOOD: Explicit device locale — intentionally uses user's locale
  final goodFormat6 = NumberFormat('#,###', Intl.defaultLocale);
  final goodFormat7 = NumberFormat.decimalPattern(Intl.defaultLocale);
  final goodFormat8 = NumberFormat.compact(locale: Intl.defaultLocale);
  final goodFormat9 = NumberFormat.percentPattern(Intl.defaultLocale);
}

// =========================================================================
// avoid_manual_date_formatting
// =========================================================================

void testManualDateFormatting() {
  final date = DateTime.now();

  // BAD: Manual date formatting with string interpolation
  // expect_lint: avoid_manual_date_formatting
  final badDate1 = '${date.day}/${date.month}/${date.year}';

  // expect_lint: avoid_manual_date_formatting
  final badDate2 = '${date.year}-${date.month}-${date.day}';

  // expect_lint: avoid_manual_date_formatting
  final badTime = '${date.hour}:${date.minute}:${date.second}';

  // BAD: Using toIso8601String with substring
  // expect_lint: avoid_manual_date_formatting
  final badDate3 = date.toIso8601String().substring(0, 10);

  // GOOD: Using DateFormat
  final goodDate1 = DateFormat.yMd('en_US').format(date);
  final goodDate2 = DateFormat('yyyy-MM-dd', 'en_US').format(date);

  // GOOD: Single date property (not formatting)
  final day = date.day;
  final month = date.month;

  // GOOD: Map key from DateTime properties (non-display context)
  final Map<String, int> counts = <String, int>{};
  final String monthKey = '${date.year}-${date.month}';
  counts[monthKey] = 42;

  // GOOD: Direct map subscript with DateTime properties
  counts['${date.year}-${date.month}'] = 42;

  // GOOD: Cache key variable name
  final String cacheKey = '${date.year}-${date.month}-${date.day}';

  // GOOD: Used with putIfAbsent
  counts.putIfAbsent('${date.year}-${date.month}', () => 0);

  // GOOD: Used with containsKey
  counts.containsKey('${date.year}-${date.month}');
}

// =========================================================================
// require_intl_currency_format
// =========================================================================

void testCurrencyFormatting() {
  final price = 99.99;
  final amount = 1234.56;
  final total = 500.00;

  // BAD: Manual currency formatting with $ symbol
  // expect_lint: require_intl_currency_format
  final badPrice1 = '\$${price.toStringAsFixed(2)}';

  // BAD: Currency symbol in string with price variable
  // expect_lint: require_intl_currency_format
  final badPrice2 = '\$$price';

  // BAD: Euro symbol with amount
  // expect_lint: require_intl_currency_format
  final badPrice3 = '${amount}EUR';

  // BAD: String concatenation with currency symbol
  // expect_lint: require_intl_currency_format
  final badPrice4 = r'$' + price.toString();

  // expect_lint: require_intl_currency_format
  final badPrice5 = 'USD ' + amount.toString();

  // GOOD: Using NumberFormat.currency
  final goodPrice1 =
      NumberFormat.currency(locale: 'en_US', symbol: r'$').format(price);
  final goodPrice2 =
      NumberFormat.simpleCurrency(locale: 'en_US').format(amount);

  // GOOD: Non-currency strings with $ (like shell variables)
  final shellVar = 'HOME=\$HOME';
  final regex = r'^\$[a-z]+';

  // GOOD: Non-currency toStringAsFixed in string interpolation
  final bearing = 270.5;
  final lat = 51.5074;
  final lon = -0.1278;
  final temp = 23.7;
  final level = 85.0;
  final angle = 45.0;
  final score = 4.3;
  final qibla = 'Qibla: ${bearing.toStringAsFixed(1)}° from North';
  final coords =
      'Lat ${lat.toStringAsFixed(2)}°, Lon ${lon.toStringAsFixed(2)}°';
  final temperature = 'Temperature: ${temp.toStringAsFixed(1)}°C';
  final battery = 'Battery: ${level.toStringAsFixed(0)}%';
  final rotation = 'Rotation: ${angle.toStringAsFixed(1)}°';
  final rating = 'Rating: ${score.toStringAsFixed(1)} / 5.0';
}

// =========================================================================
// avoid_print_error
// =========================================================================

Future<void> testPrintError() async {
  try {
    // Some operation
    throw Exception('Test error');
  } catch (e) {
    // BAD: Using print for error logging
    // expect_lint: avoid_print_error
    print(e);

    // expect_lint: avoid_print_error
    print('Error: $e');

    // expect_lint: avoid_print_error
    debugPrint('Failed: $e');
  }

  try {
    throw Exception('Another error');
  } catch (error, stackTrace) {
    // expect_lint: avoid_print_error
    print(error);

    // expect_lint: avoid_print_error
    print('$error\n$stackTrace');
  }

  // GOOD: Using proper logger (mock)
  try {
    throw Exception('Error');
  } catch (e, s) {
    // logger.error('Operation failed', error: e, stackTrace: s);
    // Crashlytics.recordError(e, s);
  }
}

void debugPrint(String message) {}

// =========================================================================
// require_key_for_collection
// =========================================================================

// Mock Flutter widgets for testing
abstract class Widget {
  const Widget({this.key});
  final Key? key;
}

abstract class Key {}

class ValueKey<T> implements Key {
  final T value;
  const ValueKey(this.value);
}

class BuildContext {}

class Container extends Widget {
  const Container({super.key});
}

class ListTile extends Widget {
  final Widget? title;
  const ListTile({super.key, this.title});
}

class Text extends Widget {
  final String data;
  const Text(this.data, {super.key});
}

class ListView {
  static Widget builder({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  }) {
    return Container();
  }

  static Widget separated({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    required Widget Function(BuildContext, int) separatorBuilder,
  }) {
    return Container();
  }
}

class GridView {
  static Widget builder({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  }) {
    return Container();
  }
}

Widget testKeyForCollection(List<String> items) {
  // BAD: ListView.builder without key on items
  // expect_lint: require_key_for_collection
  final badList = ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) => ListTile(
      title: Text(items[index]),
    ),
  );

  // expect_lint: require_key_for_collection
  final badGrid = GridView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) => Container(),
  );

  // GOOD: ListView.builder with key on items
  final goodList = ListView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) => ListTile(
      key: ValueKey(items[index]),
      title: Text(items[index]),
    ),
  );

  // GOOD: GridView.builder with key
  final goodGrid = GridView.builder(
    itemCount: items.length,
    itemBuilder: (context, index) => Container(
      key: ValueKey(index),
    ),
  );

  return goodList;
}

// =========================================================================
// Internationalization Rules
// =========================================================================

class NumberFormatWidget extends StatelessWidget {
  const NumberFormatWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final price = 1234.56;
    // expect_lint: prefer_number_format
    return Text(price.toStringAsFixed(2));
  }
}

void testIntlArgs() {
  final name = 'John';
  // expect_lint: provide_correct_intl_args
  Intl.message(
    'Hello {name}, you have {count} messages',
    args: [name], // Missing 'count' argument!
  );
}

// Mock Intl class
class Intl {
  static String? defaultLocale;
  static String message(String text, {String? desc, List<Object>? args}) =>
      text;
}

class StatelessWidget {
  const StatelessWidget({this.key});
  final Object? key;
}

abstract class StatelessWidgetBase extends StatelessWidget {
  const StatelessWidgetBase({super.key});
  Widget build(BuildContext context);
}
