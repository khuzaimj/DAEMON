extends Node

var tick: int = 0
var is_transitioning: bool = false
var paused: bool = false
var current_room_id: String = ""

var scrap: int = 0
var clearance: int = 0
var upgrades: Dictionary = {
	"link_range": 0,
	"integrity_chip": 0,
	"heat_sink": 0,
	"ttl_extender": 0,
	"garage_slot": 0,
	"shards": 0
}
var has_bus_pass: bool = false
var logs: Array[String] = []
var discovered_rooms: Array[String] = []
var last_dock_room_id: String = ""
var last_dock_spawn_pos: Vector2 = Vector2.ZERO
var visited_docks: Array[String] = []
var garage_slots_cap: int = 3
var persistent_parked_hosts: Dictionary = {} # room_id -> Array[Dictionary]
var registered_models: Array[String] = ["cursor"]

func add_upgrade(type: String, count: int = 1) -> void:
	if upgrades.has(type):
		upgrades[type] = int(upgrades[type]) + count
	else:
		upgrades[type] = count

	if type == "shards" and int(upgrades["shards"]) >= 3:
		clearance = maxi(clearance, 2)
	elif type == "garage_slot":
		garage_slots_cap += count
	elif type == "clearance":
		clearance = maxi(clearance, count)
	elif type == "bus_pass":
		has_bus_pass = true

func discover_room(room_id: String) -> void:
	if room_id != "" and not discovered_rooms.has(room_id):
		discovered_rooms.append(room_id)
		var events_node: Node = get_node_or_null("/root/Events")
		if events_node != null and events_node.has_signal("room_discovered"):
			events_node.emit_signal("room_discovered", room_id)

func add_log(log_id: String) -> void:
	if log_id != "" and not logs.has(log_id):
		logs.append(log_id)
		var events_node: Node = get_node_or_null("/root/Events")
		if events_node != null and events_node.has_signal("log_found"):
			events_node.emit_signal("log_found", log_id)

func fast_travel_to_dock(dock_id: String, world: Node) -> bool:
	if not has_bus_pass or not visited_docks.has(dock_id):
		return false
	if world != null and world.has_method("load_room"):
		world.call("load_room", dock_id)
		return true
	return false

func advance_tick() -> void:
	if paused or is_transitioning:
		return
	tick += 1
	var events_node: Node = get_node_or_null("/root/Events")
	if events_node != null:
		events_node.emit_signal("tick_advanced", tick)

func reset() -> void:
	tick = 0
	is_transitioning = false
	paused = false
	current_room_id = ""
	scrap = 0
	clearance = 0
	upgrades = {
		"link_range": 0,
		"integrity_chip": 0,
		"heat_sink": 0,
		"ttl_extender": 0,
		"garage_slot": 0,
		"shards": 0
	}
	has_bus_pass = false
	logs.clear()
	discovered_rooms.clear()
	last_dock_room_id = ""
	last_dock_spawn_pos = Vector2.ZERO
	visited_docks.clear()
	garage_slots_cap = 3
	persistent_parked_hosts.clear()
	registered_models = ["cursor"]
