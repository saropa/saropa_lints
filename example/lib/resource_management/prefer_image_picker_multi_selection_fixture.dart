// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `prefer_image_picker_multi_selection` lint rule.

// NOTE: prefer_image_picker_multi_selection fires on pickImage()
// called inside a loop — use pickMultiImage() instead.
//
// BAD:
// for (int i = 0; i < count; i++) { await picker.pickImage(...); }
//
// GOOD:
// final images = await picker.pickMultiImage();

void main() {}
