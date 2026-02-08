ref:
[{
	"resource": "/D:/src/contacts/lib/components/activity/activity_view_widget.dart",
	"owner": "_generated_diagnostic_collection_name_#2",
	"code": "require_yield_between_db_awaits",
	"severity": 4,
	"message": "[require_yield_between_db_awaits] Database/IO await without yieldToUI() may cause UI jank.\nInsert `await DelayUtils.yieldToUI();` after this database/IO operation.",
	"source": "dart",
	"startLineNumber": 256,
	"startColumn": 9,
	"endLineNumber": 259,
	"endColumn": 11,
	"modelVersionId": 1,
	"origin": "extHost1"
}]

1. both the message and fix are too short. aim for 200+ characters

2. a quick fix that inserts this code after the await should be easy. 

``` dart

  // Let the UI catch up to reduce locks
  await DelayUtils.yieldToUI();

```

NOTE: we want the code comment or something better; also we want the linebreak before _and_ after the yieldToUI()

