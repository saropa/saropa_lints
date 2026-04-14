// ignore_for_file: unused_element
// Fixture for prefer_positional_bool_params: bool params as optional positional.

// LINT: named bool param
void showDialog({bool dismissible = true}) {}

// OK: optional positional bool
void show([bool dismissible = true]) {}
