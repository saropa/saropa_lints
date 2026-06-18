Status: Fixed

## Root cause

"Lint integration: Off" only flipped the `saropaLints.enabled` workspace setting and showed a toast (`runDisable` in `extension/src/setup.ts`). That flag is an extension-UI-only signal — the Dart analysis server never reads it. saropa_lints diagnostics come from the analyzer plugin wired through the top-level `plugins:` block in `analysis_options.yaml`, which was left untouched, so every diagnostic kept appearing.

## Fix

`runDisable` now comments out the `plugins:` block in `analysis_options.yaml` (bracketed by restore sentinels), so the analyzer actually stops loading saropa_lints and the Problems pane clears. `runEnable` calls the new `restorePluginsIntegration()` before `write_config`, stripping the comments back so the block returns with the user's rule packs and overrides intact (no regeneration from tier defaults). New toast `notify.setup.disabledAnalyzer` tells the user diagnostics will clear shortly and how to restore.

---

I turned off lint integration in the settings side menu.

but still i get the following. DO NOT try to debug the following issues, just note them

[{
	"resource": "/d:/src/contacts/lib/components/contact/detail_panels/nav_icons/nav_icon.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_unawaited_future",
	"severity": 4,
	"message": "[avoid_unawaited_future] Not awaiting a Future means any errors or exceptions it throws may be silently lost, leading to missed bugs and unreliable app behavior. This is especially risky in production code where error reporting is critical. {v3}\nAlways use await or unawaited() to explicitly handle Futures and ensure errors are not lost.",
	"source": "dart",
	"startLineNumber": 128,
	"startColumn": 5,
	"endLineNumber": 128,
	"endColumn": 39,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/components/event/special_events/focus_card_simple_teaser.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_unsafe_cast",
	"severity": 4,
	"message": "[avoid_unsafe_cast] Direct cast with \"as\" may throw at runtime. Direct casting with as can throw if the value is null or wrong type. Prefer is check first or use as? for nullable result. {v5}\nUse \"is\" check or pattern matching instead. Verify the change works correctly with existing tests and add coverage for the new behavior.",
	"source": "dart",
	"startLineNumber": 191,
	"startColumn": 40,
	"endLineNumber": 191,
	"endColumn": 49,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/components/event/special_events/focus_card_simple_teaser.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_unsafe_cast",
	"severity": 4,
	"message": "[avoid_unsafe_cast] Direct cast with \"as\" may throw at runtime. Direct casting with as can throw if the value is null or wrong type. Prefer is check first or use as? for nullable result. {v5}\nUse \"is\" check or pattern matching instead. Verify the change works correctly with existing tests and add coverage for the new behavior.",
	"source": "dart",
	"startLineNumber": 200,
	"startColumn": 50,
	"endLineNumber": 200,
	"endColumn": 59,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/components/event/special_events/focus_card_simple_teaser.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_unsafe_cast",
	"severity": 4,
	"message": "[avoid_unsafe_cast] Direct cast with \"as\" may throw at runtime. Direct casting with as can throw if the value is null or wrong type. Prefer is check first or use as? for nullable result. {v5}\nUse \"is\" check or pattern matching instead. Verify the change works correctly with existing tests and add coverage for the new behavior.",
	"source": "dart",
	"startLineNumber": 211,
	"startColumn": 67,
	"endLineNumber": 211,
	"endColumn": 76,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/components/primitive/avatar/common_avatar.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_duplicate_object_elements",
	"severity": 4,
	"message": "[avoid_duplicate_object_elements] Duplicate object reference or literal (bool, null, identifier) in collection typically indicates a copy-paste error. In Sets, the duplicate is silently ignored, producing a smaller collection than expected. {v2}\nRemove the duplicate object element or verify the references are intentionally repeated. In Sets, duplicates are silently discarded.",
	"source": "dart",
	"startLineNumber": 569,
	"startColumn": 45,
	"endLineNumber": 569,
	"endColumn": 56,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/components/primitive/avatar/common_avatar.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_duplicate_object_elements",
	"severity": 4,
	"message": "[avoid_duplicate_object_elements] Duplicate object reference or literal (bool, null, identifier) in collection typically indicates a copy-paste error. In Sets, the duplicate is silently ignored, producing a smaller collection than expected. {v2}\nRemove the duplicate object element or verify the references are intentionally repeated. In Sets, duplicates are silently discarded.",
	"source": "dart",
	"startLineNumber": 571,
	"startColumn": 46,
	"endLineNumber": 571,
	"endColumn": 57,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/components/primitive/panels/common_title_panel.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_unawaited_future",
	"severity": 4,
	"message": "[avoid_unawaited_future] Not awaiting a Future means any errors or exceptions it throws may be silently lost, leading to missed bugs and unreliable app behavior. This is especially risky in production code where error reporting is critical. {v3}\nAlways use await or unawaited() to explicitly handle Futures and ensure errors are not lost.",
	"source": "dart",
	"startLineNumber": 204,
	"startColumn": 7,
	"endLineNumber": 204,
	"endColumn": 28,
	"modelVersionId": 1,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/components/primitive/panels/common_title_panel.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_unawaited_future",
	"severity": 4,
	"message": "[avoid_unawaited_future] Not awaiting a Future means any errors or exceptions it throws may be silently lost, leading to missed bugs and unreliable app behavior. This is especially risky in production code where error reporting is critical. {v3}\nAlways use await or unawaited() to explicitly handle Futures and ensure errors are not lost.",
	"source": "dart",
	"startLineNumber": 206,
	"startColumn": 7,
	"endLineNumber": 206,
	"endColumn": 28,
	"modelVersionId": 1,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/utils/native_phone_import/native_import_utils.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_parameter_mutation",
	"severity": 4,
	"message": "[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v2}\nCreate a copy of the data instead of mutating the parameter.",
	"source": "dart",
	"startLineNumber": 926,
	"startColumn": 7,
	"endLineNumber": 926,
	"endColumn": 41,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/utils/native_phone_import/native_import_utils.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_parameter_mutation",
	"severity": 4,
	"message": "[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v2}\nCreate a copy of the data instead of mutating the parameter.",
	"source": "dart",
	"startLineNumber": 940,
	"startColumn": 7,
	"endLineNumber": 940,
	"endColumn": 56,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/utils/native_phone_import/native_import_utils.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_parameter_mutation",
	"severity": 4,
	"message": "[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v2}\nCreate a copy of the data instead of mutating the parameter.",
	"source": "dart",
	"startLineNumber": 941,
	"startColumn": 7,
	"endLineNumber": 941,
	"endColumn": 54,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/utils/native_phone_import/native_import_utils.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_parameter_mutation",
	"severity": 4,
	"message": "[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v2}\nCreate a copy of the data instead of mutating the parameter.",
	"source": "dart",
	"startLineNumber": 942,
	"startColumn": 7,
	"endLineNumber": 942,
	"endColumn": 52,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/utils/native_phone_import/native_import_utils.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_parameter_mutation",
	"severity": 4,
	"message": "[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v2}\nCreate a copy of the data instead of mutating the parameter.",
	"source": "dart",
	"startLineNumber": 943,
	"startColumn": 7,
	"endLineNumber": 943,
	"endColumn": 52,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/utils/native_phone_import/native_import_utils.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_parameter_mutation",
	"severity": 4,
	"message": "[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v2}\nCreate a copy of the data instead of mutating the parameter.",
	"source": "dart",
	"startLineNumber": 947,
	"startColumn": 7,
	"endLineNumber": 947,
	"endColumn": 70,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/utils/native_phone_import/native_import_utils.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_parameter_mutation",
	"severity": 4,
	"message": "[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v2}\nCreate a copy of the data instead of mutating the parameter.",
	"source": "dart",
	"startLineNumber": 950,
	"startColumn": 7,
	"endLineNumber": 950,
	"endColumn": 73,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/utils/native_phone_import/native_import_utils.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_parameter_mutation",
	"severity": 4,
	"message": "[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v2}\nCreate a copy of the data instead of mutating the parameter.",
	"source": "dart",
	"startLineNumber": 951,
	"startColumn": 7,
	"endLineNumber": 951,
	"endColumn": 67,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/utils/system/toasts/popup_toast_message.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_unawaited_future",
	"severity": 4,
	"message": "[avoid_unawaited_future] Not awaiting a Future means any errors or exceptions it throws may be silently lost, leading to missed bugs and unreliable app behavior. This is especially risky in production code where error reporting is critical. {v3}\nAlways use await or unawaited() to explicitly handle Futures and ensure errors are not lost.",
	"source": "dart",
	"startLineNumber": 714,
	"startColumn": 5,
	"endLineNumber": 714,
	"endColumn": 26,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/utils/web/link_preview/link_parser_chain.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_parameter_mutation",
	"severity": 4,
	"message": "[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v2}\nCreate a copy of the data instead of mutating the parameter.",
	"source": "dart",
	"startLineNumber": 67,
	"startColumn": 3,
	"endLineNumber": 67,
	"endColumn": 32,
	"modelVersionId": 1,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/utils/web/link_preview/link_parser_chain.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_parameter_mutation",
	"severity": 4,
	"message": "[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v2}\nCreate a copy of the data instead of mutating the parameter.",
	"source": "dart",
	"startLineNumber": 68,
	"startColumn": 3,
	"endLineNumber": 68,
	"endColumn": 30,
	"modelVersionId": 1,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/utils/web/link_preview/link_parser_chain.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_parameter_mutation",
	"severity": 4,
	"message": "[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v2}\nCreate a copy of the data instead of mutating the parameter.",
	"source": "dart",
	"startLineNumber": 69,
	"startColumn": 3,
	"endLineNumber": 69,
	"endColumn": 32,
	"modelVersionId": 1,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/utils/web/link_preview/link_parser_chain.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_parameter_mutation",
	"severity": 4,
	"message": "[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v2}\nCreate a copy of the data instead of mutating the parameter.",
	"source": "dart",
	"startLineNumber": 70,
	"startColumn": 3,
	"endLineNumber": 70,
	"endColumn": 38,
	"modelVersionId": 1,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/utils/web/link_preview/link_parser_chain.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_parameter_mutation",
	"severity": 4,
	"message": "[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v2}\nCreate a copy of the data instead of mutating the parameter.",
	"source": "dart",
	"startLineNumber": 71,
	"startColumn": 3,
	"endLineNumber": 71,
	"endColumn": 35,
	"modelVersionId": 1,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/utils/web/link_preview/link_parser_chain.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_parameter_mutation",
	"severity": 4,
	"message": "[avoid_parameter_mutation] Parameter object is being mutated. This modifies the caller's data. {v2}\nCreate a copy of the data instead of mutating the parameter.",
	"source": "dart",
	"startLineNumber": 87,
	"startColumn": 5,
	"endLineNumber": 87,
	"endColumn": 55,
	"modelVersionId": 1,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/views/contact/contact_view_screen.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_unawaited_future",
	"severity": 4,
	"message": "[avoid_unawaited_future] Not awaiting a Future means any errors or exceptions it throws may be silently lost, leading to missed bugs and unreliable app behavior. This is especially risky in production code where error reporting is critical. {v3}\nAlways use await or unawaited() to explicitly handle Futures and ensure errors are not lost.",
	"source": "dart",
	"startLineNumber": 391,
	"startColumn": 5,
	"endLineNumber": 391,
	"endColumn": 26,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/views/home/contact_tab.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_builder_index_out_of_bounds",
	"severity": 4,
	"message": "[avoid_builder_index_out_of_bounds] itemBuilder accesses list without bounds check. If the index is out of bounds due to list changes, this will cause runtime exceptions, app crashes, and unpredictable UI behavior. This is a common source of production bugs in dynamic lists and can lead to negative user reviews. {v7}\nAdd bounds check: if (index >= items.length) return a fallback widget or null. Always validate index (or idx/realIndex when that is the subscript) before accessing list elements in itemBuilder. Add tests for edge cases and dynamic list updates.",
	"source": "dart",
	"startLineNumber": 532,
	"startColumn": 11,
	"endLineNumber": 535,
	"endColumn": 98,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/components/contact/contact_status_list.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "prefer_value_listenable_builder",
	"severity": 2,
	"message": "[prefer_value_listenable_builder] Simple single-value state managed with setState causes the entire widget subtree to rebuild on every change. ValueListenableBuilder isolates rebuilds to only the affected subtree, significantly reducing unnecessary widget tree comparisons, improving frame rendering performance, and lowering battery consumption. {v4}\nReplace setState with a ValueNotifier field and wrap the dependent UI in ValueListenableBuilder to isolate rebuilds to only the affected subtree.",
	"source": "dart",
	"startLineNumber": 473,
	"startColumn": 7,
	"endLineNumber": 473,
	"endColumn": 36,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/components/contact/detail_panels/timezone/contact_timezone_picker.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "avoid_listview_without_item_extent",
	"severity": 2,
	"message": "[avoid_listview_without_item_extent] ListView.builder should specify itemExtent, prototypeItem, or itemExtentBuilder for predictable scroll layout. Omitting all three forces per-child layout measurement, which hurts jump/scrollbar accuracy and large-list performance (Flutter 3.16+ adds itemExtentBuilder for varying per-index heights). ListView.separated is excluded because its constructor does not accept these parameters. {v7}\nAdd itemExtent for uniform height, prototypeItem for a single representative size, or itemExtentBuilder when each index can have a different extent. Test on multiple screen sizes.",
	"source": "dart",
	"startLineNumber": 260,
	"startColumn": 19,
	"endLineNumber": 260,
	"endColumn": 35,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/components/country/country_at_a_glance_table.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "prefer_value_listenable_builder",
	"severity": 2,
	"message": "[prefer_value_listenable_builder] Simple single-value state managed with setState causes the entire widget subtree to rebuild on every change. ValueListenableBuilder isolates rebuilds to only the affected subtree, significantly reducing unnecessary widget tree comparisons, improving frame rendering performance, and lowering battery consumption. {v4}\nReplace setState with a ValueNotifier field and wrap the dependent UI in ValueListenableBuilder to isolate rebuilds to only the affected subtree.",
	"source": "dart",
	"startLineNumber": 58,
	"startColumn": 7,
	"endLineNumber": 58,
	"endColumn": 34,
	"origin": "extHost3"
},{
	"resource": "/d:/src/contacts/lib/components/home/components/language_picker_dialog.dart",
	"owner": "_generated_diagnostic_collection_name_#3",
	"code": "prefer_value_listenable_builder",
	"severity": 2,
	"message": "[prefer_value_listenable_builder] Simple single-value state managed with setState causes the entire widget subtree to rebuild on every change. ValueListenableBuilder isolates rebuilds to only the affected subtree, significantly reducing unnecessary widget tree comparisons, improving frame rendering performance, and lowering battery consumption. {v4}\nReplace setState with a ValueNotifier field and wrap the dependent UI in ValueListenableBuilder to isolate rebuilds to only the affected subtree.",
	"source": "dart",
	"startLineNumber": 125,
	"startColumn": 7,
	"endLineNumber": 125,
	"endColumn": 31,
	"origin": "extHost3"
}]