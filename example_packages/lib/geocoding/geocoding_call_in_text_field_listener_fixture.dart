// ignore_for_file: unused_local_variable, unused_element

/// Fixture for `geocoding_call_in_text_field_listener`.
library;

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';

TextField bad() {
  return TextField(
    onChanged: (q) async {
      // expect_lint: geocoding_call_in_text_field_listener
      await locationFromAddress(q);
    },
  );
}
