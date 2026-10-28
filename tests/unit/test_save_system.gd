class_name TestSaveSystem
extends GutTest

const TEST_SLOT: int = 99

func after_each() -> void:
	var save_sys: Node = get_node_or_null("/root/SaveSystem")
	if save_sys != null:
		var p_main: String = "%s/slot%d.json" % [SaveSystem.SAVES_DIR, TEST_SLOT]
		var p_bak: String = p_main + ".bak"
		var p_tmp: String = p_main + ".tmp"
		if FileAccess.file_exists(p_main):
			DirAccess.remove_absolute(p_main)
		if FileAccess.file_exists(p_bak):
			DirAccess.remove_absolute(p_bak)
		if FileAccess.file_exists(p_tmp):
			DirAccess.remove_absolute(p_tmp)

	var game: Node = get_node_or_null("/root/Game")
	if game != null and game.has_method("reset"):
		game.call("reset")

func test_save_data_schema_and_defaults() -> void:
	var default_data: Dictionary = SaveData.create_default_state()
	var errors: Array[String] = SaveData.validate(default_data)
	assert_eq(errors.size(), 0, "Default state validates cleanly")

	var bad_data: Dictionary = { "version": 1 }
	var bad_errors: Array[String] = SaveData.validate(bad_data)
	assert_gt(bad_errors.size(), 0, "Incomplete state fails validation")

func test_round_trip_equality_and_integer_restoration() -> void:
	var original: Dictionary = SaveData.create_default_state()
	original["playtime"] = 1200
	original["scrap"] = 45
	(original["player"] as Dictionary)["clearance"] = 2
	(original["player"] as Dictionary)["garage_slots"] = 4
	((original["player"] as Dictionary)["upgrades"] as Dictionary)["shards"] = 3
	(original["map"] as Dictionary)["discovered_rooms"] = ["debug_01", "debug_02"]
	(original["rooms"] as Dictionary)["debug_01"] = {
		"opened_doors": ["door_1"],
		"broken_tiles": [[5, 2], [5, 3]],
		"latches": { "latch_1": true },
		"taken_pickups": ["chip_01"],
		"defeated_unique": ["rogue_loader_boss"],
		"parked_hosts": []
	}

	# Serialize to JSON string and parse back (simulating JSON file read)
	var json_str: String = SaveData.to_json_string(original)
	var parsed: Variant = JSON.parse_string(json_str)
	assert_true(parsed is Dictionary)

	# Deserialization must restore integer types (float 45.0 -> int 45)
	var restored: Dictionary = SaveData.deserialize(parsed as Dictionary)
	assert_true(restored["playtime"] is int, "playtime restored to int")
	assert_true(restored["scrap"] is int, "scrap restored to int")
	assert_true((restored["player"] as Dictionary)["clearance"] is int, "clearance restored to int")

	# Save again from restored dictionary
	var json_str_2: String = SaveData.to_json_string(restored)
	assert_eq(json_str, json_str_2, "Round-trip save -> load -> save produces identical JSON string")

func test_version_migration_v0_to_v1() -> void:
	var v0_fixture: Dictionary = {
		"version": 0,
		"playtime": 300,
		"discovered_rooms": ["debug_01"],
		"visited_docks": ["dock_alpha"],
		"player": {
			"host_body": "janitor",
			"registered_models": ["cursor", "janitor"],
			"garage_slots": 3,
			"clearance": 1
		}
	}

	var migrated: Dictionary = SaveData.deserialize(v0_fixture)
	assert_eq(migrated["version"], 1, "Migrated to version 1")
	assert_true(migrated.has("map"), "Map dictionary created")
	var map_d: Dictionary = migrated["map"] as Dictionary
	assert_true(map_d["discovered_rooms"].has("debug_01"), "discovered_rooms migrated to map")
	assert_true(map_d["visited_docks"].has("dock_alpha"), "visited_docks migrated to map")
	assert_false(migrated.has("discovered_rooms"), "Legacy key cleaned up")
	assert_true((migrated["player"] as Dictionary).has("has_bus_pass"), "has_bus_pass added to player")

func test_atomic_write_and_bak_recovery() -> void:
	var save_sys: Node = get_node_or_null("/root/SaveSystem")
	if save_sys == null:
		return

	var path: String = save_sys.call("get_slot_path", TEST_SLOT)
	var bak_path: String = path + ".bak"

	# First save
	var success_1: bool = save_sys.call("save_slot", TEST_SLOT)
	assert_true(success_1, "First save succeeds")
	assert_true(FileAccess.file_exists(path), "Main save file exists")

	# Second save creates backup of the first
	var game: Node = get_node_or_null("/root/Game")
	if game != null:
		game.set("scrap", 99)
	var success_2: bool = save_sys.call("save_slot", TEST_SLOT)
	assert_true(success_2, "Second save succeeds")
	assert_true(FileAccess.file_exists(bak_path), "Backup .bak file created")

	# Corrupt the main file
	var bad_f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	bad_f.store_string("corrupt not valid json { [")
	bad_f.close()

	# Loading should gracefully fall back to .bak
	var loaded: Dictionary = save_sys.call("load_slot", TEST_SLOT)
	assert_false(loaded.is_empty(), "Loaded successfully from .bak fallback")
