// ignore_for_file: unused_element

/// Fixture for `prefer_grouped_by_purpose` (many required/optional alternations).

void bad({required int a, int? b, required int c, int? d, required int e}) {}

void good({required int a, required int c, required int e, int? b, int? d}) {}
