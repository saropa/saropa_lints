// ignore_for_file: prefer_final_locals, prefer_getters_before_setters, prefer_if_elements_to_conditional_expressions, prefer_inlined_adds, prefer_interpolation_to_compose, prefer_lowercase_constants, prefer_mixin_over_abstract, prefer_named_bool_params, prefer_noun_class_names, prefer_null_aware_method_calls, prefer_raw_strings, prefer_record_over_tuple_class, prefer_sealed_classes, prefer_sealed_for_state, prefer_static_before_instance, prefer_verb_method_names
// Fixture for roadmap-detail rules: bad examples (each would trigger its rule without ignore).

void preferFinalLocalsBad() {
  var count = 0;
  String msg = 'hi';
  print('$count $msg');
}

class PreferGettersBeforeSettersBad {
  int _x = 0;
  set x(int v) => _x = v;
  int get x => _x;
}

List<Object?> preferIfElementsBad(bool flag) {
  return [flag ? 'a' : null];
}

void preferInlinedAddsBad() {
  final list = <int>[];
  list.add(1);
  list.add(2);
}

String preferInterpolationBad(String name) {
  return 'Hello, ' + name + '!';
}

const MAX_VALUE = 42;
const DEFAULT_TIMEOUT_MS = 5000;

abstract class PreferMixinOverAbstractBad {
  void log(String s) => print(s);
}

void preferNamedBoolParamsBad(bool visible) {
  if (visible) {}
}

class Parsing {
  void parse() {}
}

void preferNullAwareBad(int? x) {
  if (x != null) {
    x.isEven;
  }
}

final preferRawStringsBad = RegExp('\\d+');

class PreferRecordOverTupleBad {
  final double lat;
  final double lng;
  const PreferRecordOverTupleBad(this.lat, this.lng);
}

abstract class PreferSealedClassesBad {}

class A extends PreferSealedClassesBad {}

class B extends PreferSealedClassesBad {}

abstract class PreferSealedForStateBad {}

class Idle extends PreferSealedForStateBad {}

class PreferStaticBeforeInstanceBad {
  int _x = 0;
  static int get zero => 0;
}

class PreferVerbMethodNamesBad {
  void data() {}
}
