class_name SaveData
extends RefCounted

const CURRENT_VERSION: int = 1
const BUILD_ID: String = "v0.5.0-dev"

const REQUIRED_ROOT_KEYS: Array[String] = [
	"version", "build_id", "playtime", "player", "flags", "scrap", "logs", "map", "rooms"
]

const REQUIRED_PLAYER_KEYS: Array[String] = [
	"host_body", "registered_models", "garage_slots", "clearance", "upgrades", "has_bus_pass"
]

const UPGRADE_KEYS: Array[String] = [
	"link_range", "integrity_chip", "heat_sink", "ttl_extender", "garage_slot", "shards"
]

static func create_default_state() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"build_id": BUILD_ID,
		"playtime": 0,
		"player": {
			"host_body": "cursor",
			"registered_models": ["cursor"],
			"garage_slots": 3,
			"clearance": 0,
			"upgrades": {
				"link_range": 0,
				"integrity_chip": 0,
				"heat_sink": 0,
				"ttl_extender": 0,
				"garage_slot": 0,
				"shards": 0
			},
			"has_bus_pass": false
		},
		"flags": {},
		"scrap": 0,
		"logs": [],
		"map": {
			"discovered_rooms": [],
			"visited_docks": []
		},
		"rooms": {}
	}

static func serialize(game: Node, world: Node) -> Dictionary:
	var data: Dictionary = create_default_state()
	if game != null:
		data["playtime"] = int(game.get("tick"))
		data["scrap"] = int(game.get("scrap"))

		var p_dict: Dictionary = data["player"] as Dictionary
		p_dict["clearance"] = int(game.get("clearance"))
		p_dict["garage_slots"] = int(game.get("garage_slots_cap"))
		p_dict["has_bus_pass"] = bool(game.get("has_bus_pass"))

		var reg_models: Variant = game.get("registered_models")
		if reg_models is Array:
			var arr: Array[String] = []
			for m: Variant in (reg_models as Array):
				arr.append(str(m))
			p_dict["registered_models"] = arr

		var upg: Variant = game.get("upgrades")
		if upg is Dictionary:
			var u_dict: Dictionary = p_dict["upgrades"] as Dictionary
			for k: Variant in (upg as Dictionary).keys():
				u_dict[str(k)] = int((upg as Dictionary)[k])

		var logs_var: Variant = game.get("logs")
		if logs_var is Array:
			var logs_arr: Array[String] = []
			for l: Variant in (logs_var as Array):
				logs_arr.append(str(l))
			data["logs"] = logs_arr

		var map_dict: Dictionary = data["map"] as Dictionary
		var disc_rooms: Variant = game.get("discovered_rooms")
		if disc_rooms is Array:
			var d_arr: Array[String] = []
			for r: Variant in (disc_rooms as Array):
				d_arr.append(str(r))
			map_dict["discovered_rooms"] = d_arr

		var vis_docks: Variant = game.get("visited_docks")
		if vis_docks is Array:
			var v_arr: Array[String] = []
			for d: Variant in (vis_docks as Array):
				v_arr.append(str(d))
			map_dict["visited_docks"] = v_arr

		var p_hosts: Variant = game.get("persistent_parked_hosts")
		if p_hosts is Dictionary:
			var rooms_dict: Dictionary = data["rooms"] as Dictionary
			for r_id: Variant in (p_hosts as Dictionary).keys():
				var r_key: String = str(r_id)
				if not rooms_dict.has(r_key):
					rooms_dict[r_key] = _create_empty_room_delta()
				rooms_dict[r_key]["parked_hosts"] = (p_hosts as Dictionary)[r_id]

	if world != null:
		var player_m: Variant = world.get("player_machine")
		if player_m != null and is_instance_valid(player_m as Node):
			(data["player"] as Dictionary)["host_body"] = str((player_m as Machine).body_id)

	return data

static func _create_empty_room_delta() -> Dictionary:
	return {
		"opened_doors": [],
		"broken_tiles": [],
		"latches": {},
		"taken_pickups": [],
		"defeated_unique": [],
		"parked_hosts": []
	}

static func deserialize(raw: Dictionary) -> Dictionary:
	var migrated: Dictionary = migrate(raw)
	return _restore_types(migrated)

static func _restore_types(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	result["version"] = int(result.get("version", CURRENT_VERSION))
	result["playtime"] = int(result.get("playtime", 0))
	result["scrap"] = int(result.get("scrap", 0))
	result["build_id"] = str(result.get("build_id", BUILD_ID))

	if result.has("player") and result["player"] is Dictionary:
		var p: Dictionary = result["player"] as Dictionary
		p["garage_slots"] = int(p.get("garage_slots", 3))
		p["clearance"] = int(p.get("clearance", 0))
		p["has_bus_pass"] = bool(p.get("has_bus_pass", false))
		p["host_body"] = str(p.get("host_body", "cursor"))

		var reg: Array = []
		for item: Variant in p.get("registered_models", []):
			reg.append(str(item))
		p["registered_models"] = reg

		if p.has("upgrades") and p["upgrades"] is Dictionary:
			var u: Dictionary = p["upgrades"] as Dictionary
			for k: String in UPGRADE_KEYS:
				u[k] = int(u.get(k, 0))

	if result.has("logs") and result["logs"] is Array:
		var logs_arr: Array = []
		for l: Variant in result["logs"]:
			logs_arr.append(str(l))
		result["logs"] = logs_arr

	if result.has("map") and result["map"] is Dictionary:
		var m: Dictionary = result["map"] as Dictionary
		var disc: Array = []
		for r: Variant in m.get("discovered_rooms", []):
			disc.append(str(r))
		m["discovered_rooms"] = disc

		var docks: Array = []
		for d: Variant in m.get("visited_docks", []):
			docks.append(str(d))
		m["visited_docks"] = docks

	if result.has("rooms") and result["rooms"] is Dictionary:
		var r_map: Dictionary = result["rooms"] as Dictionary
		for r_key: Variant in r_map.keys():
			var r_entry: Dictionary = r_map[r_key] as Dictionary
			if r_entry.has("broken_tiles") and r_entry["broken_tiles"] is Array:
				var tiles: Array = []
				for pt: Variant in r_entry["broken_tiles"]:
					if pt is Array and (pt as Array).size() >= 2:
						tiles.append([int((pt as Array)[0]), int((pt as Array)[1])])
				r_entry["broken_tiles"] = tiles

	return result

static func migrate(data: Dictionary) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	var ver: int = int(result.get("version", 0))

	if ver == 0:
		result = _migrate_v0_to_v1(result)
		ver = 1

	result["version"] = CURRENT_VERSION
	return result

static func _migrate_v0_to_v1(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	migrated["version"] = 1
	if not migrated.has("build_id"):
		migrated["build_id"] = BUILD_ID
	if not migrated.has("playtime"):
		migrated["playtime"] = 0
	if not migrated.has("flags"):
		migrated["flags"] = {}
	if not migrated.has("scrap"):
		migrated["scrap"] = 0
	if not migrated.has("logs"):
		migrated["logs"] = []
	if not migrated.has("rooms"):
		migrated["rooms"] = {}

	if not migrated.has("map") or not (migrated["map"] is Dictionary):
		migrated["map"] = {
			"discovered_rooms": migrated.get("discovered_rooms", []),
			"visited_docks": migrated.get("visited_docks", [])
		}
	migrated.erase("discovered_rooms")
	migrated.erase("visited_docks")

	if not migrated.has("player") or not (migrated["player"] is Dictionary):
		migrated["player"] = {
			"host_body": "cursor",
			"registered_models": ["cursor"],
			"garage_slots": 3,
			"clearance": 0,
			"upgrades": {
				"link_range": 0,
				"integrity_chip": 0,
				"heat_sink": 0,
				"ttl_extender": 0,
				"garage_slot": 0,
				"shards": 0
			},
			"has_bus_pass": false
		}
	else:
		var p: Dictionary = migrated["player"] as Dictionary
		if not p.has("has_bus_pass"):
			p["has_bus_pass"] = false
		if not p.has("upgrades") or not (p["upgrades"] is Dictionary):
			p["upgrades"] = {
				"link_range": 0,
				"integrity_chip": 0,
				"heat_sink": 0,
				"ttl_extender": 0,
				"garage_slot": 0,
				"shards": 0
			}

	return migrated

static func validate(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for req: String in REQUIRED_ROOT_KEYS:
		if not data.has(req):
			errors.append("SaveData: missing required root key '%s'" % req)

	if data.has("player") and data["player"] is Dictionary:
		var p: Dictionary = data["player"] as Dictionary
		for req_p: String in REQUIRED_PLAYER_KEYS:
			if not p.has(req_p):
				errors.append("SaveData: missing required player key '%s'" % req_p)
	else:
		errors.append("SaveData: 'player' must be a Dictionary")

	if data.has("map") and not (data["map"] is Dictionary):
		errors.append("SaveData: 'map' must be a Dictionary")

	if data.has("rooms") and not (data["rooms"] is Dictionary):
		errors.append("SaveData: 'rooms' must be a Dictionary")

	return errors

static func to_json_string(data: Dictionary) -> String:
	return JSON.stringify(data, "\t", true)
