// ignore_for_file: unused_element, unused_field, unused_local_variable
// Fixture for prefer_final_fields.
//
// The rule flags a PRIVATE instance field that is never reassigned anywhere in
// the compilation unit (resolved by element, so a write through any holder
// counts). Public fields are never flagged: a write from another library is
// invisible to single-unit analysis, so suggesting `final` could fail to
// compile. See plans/history/2026.06/2026.06.19/
// prefer_final_fields_false_positive_cross_class_mutation.md.

// Case 1 — same-file sibling-class mutation via `holder._field++`.
// `_count` is reassigned by _Counter below, so it must NOT be final.
class _WindowEntry {
  _WindowEntry(this.windowSecond);
  final int windowSecond;
  int _count = 1; // OK: reassigned by _Counter.bump (cross-class, same file).
}

class _Counter {
  final Map<String, _WindowEntry> _windows = <String, _WindowEntry>{};

  int bump(String key) {
    final _WindowEntry entry = _windows[key]!;
    entry._count++; // cross-class reassignment, matched by element.
    return entry._count;
  }
}

// Case 2 — same-file mutation via a PrefixedIdentifier assignment.
// `_flag` is reassigned by configure(), so it must NOT be final.
class _Settings {
  bool _flag = true; // OK: reassigned through `other._flag = ...` below.
}

void configure(_Settings other, bool enabled) {
  other._flag = enabled;
}

// Control — `this`-only mutation. Existing behavior: still NOT flagged.
class _Accumulator {
  int _total = 0; // OK: reassigned via this.

  void add(int n) {
    _total += n;
  }
}

// Control — genuinely never reassigned. True positive must still fire.
class _Holder {
  _Holder(this._label);
  String _label; // LINT prefer_final_fields — no write anywhere in the unit.
}

// Control — public field. Never flagged (could be written from another
// library), even though it is never reassigned in this unit.
class PublicConfig {
  PublicConfig(this.name);
  String name; // OK: public field is out of scope for prefer_final_fields.
}
