// ignore_for_file: unused_element
// Fixture for prefer_extension_suffix: extension name should end with Ext.

// LINT: named extension without Ext suffix
extension IntHelpers on int {
  int doubleIt() => this * 2;
}

// OK (ends with Ext)
extension IntExt on int {
  int doubleIt() => this * 2;
}
