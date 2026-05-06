# Roadmap detail: 12 rules implemented (v6.0.8)

**Completed:** 12 rules from `bugs/roadmap_detail_requirements/` task files.

| Rule | Tier | Summary |
|------|------|---------|
| `avoid_unnecessary_containers` | Recommended | Container with only child/key; use child directly (widget files). |
| `prefer_adjacent_strings` | Recommended | Use adjacent string literals instead of `+` for literals. |
| `prefer_adjective_bool_getters` | Professional | Bool getters: predicate names (is/has/can) not verb names (validate/load). |
| `prefer_asserts_in_initializer_lists` | Professional | Move leading assert() from constructor body to initializer list. |
| `prefer_const_constructors_in_immutables` | Professional | @immutable / StatelessWidget with only final fields → const constructor. |
| `prefer_const_declarations` | Recommended | final with constant initializer → const (locals/static/top-level). |
| `prefer_const_literals_to_create_immutables` | Recommended | Non-const list/set/map passed to immutable widget constructor (widget files). |
| `prefer_constructors_first` | Professional | Constructors before methods in class body. |
| `prefer_extension_methods` | Professional | Top-level function → extension on first parameter type (by name heuristic). |
| `prefer_extension_over_utility_class` | Professional | Class with only static methods, same first param type → extension. |
| `prefer_extension_type_for_wrapper` | Professional | Single-field wrapper class → extension type (Dart 3.3+). |
| `prefer_final_fields` | Professional | Field never reassigned (except via setter) → final. |

Task files moved from `bugs/roadmap_detail_requirements/` to `bugs/history/roadmap/`.
