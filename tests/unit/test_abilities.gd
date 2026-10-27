extends GutTest

func test_all_19_abilities_data_and_schemas() -> void:
	var ability_ids: Array[String] = [
		"ping", "sweep", "suction", "ram", "lift",
		"shoot", "overwatch", "pulse", "tow", "torch",
		"arc", "harpoon", "bubble", "claw", "cling",
		"parcel", "dash", "repair_beam", "patch"
	]
	
	assert_eq(ability_ids.size(), 19, "Must have exactly 19 abilities")
	
	for ab_id: String in ability_ids:
		var path: String = "res://data/abilities/%s.json" % ab_id
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		assert_not_null(file, "Ability file must exist: " + path)
		var json: JSON = JSON.new()
		assert_eq(json.parse(file.get_as_text()), OK, "Valid JSON for " + ab_id)
		var data: Dictionary = json.data as Dictionary
		var errs: Array[String] = Schema.validate_ability(data, path)
		assert_eq(errs.size(), 0, "Ability %s should have 0 schema errors" % ab_id)
