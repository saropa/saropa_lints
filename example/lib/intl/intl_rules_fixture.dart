// ignore_for_file: unused_local_variable, unused_element, depend_on_referenced_packages
// ignore_for_file: unused_field
// Test fixture for internationalization rules (v2.3.9)

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
