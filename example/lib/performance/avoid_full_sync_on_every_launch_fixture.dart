// ignore_for_file: unused_local_variable, unused_element
// ignore_for_file: undefined_function, undefined_identifier
// ignore_for_file: undefined_class, undefined_method

/// Fixture for `avoid_full_sync_on_every_launch` lint rule.

// NOTE: avoid_full_sync_on_every_launch fires on bulk DB fetch
// methods (.findAll(), .getAll()) in initState() of widgets.
// Requires widget State class context.
//
// BAD:
// void initState() { super.initState(); db.findAll(); }
//
// GOOD:
// void initState() { super.initState(); db.findSince(lastSync); }

void main() {}
