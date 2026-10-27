extends Node

var tick: int = 0
var is_transitioning: bool = false
var paused: bool = false
var current_room_id: String = ""

var scrap: int = 0
var last_dock_room_id: String = ""
var last_dock_spawn_pos: Vector2 = Vector2.ZERO
var visited_docks: Array[String] = []
var garage_slots_cap: int = 3
var persistent_parked_hosts: Dictionary = {} # room_id -> Array[Dictionary]

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
	last_dock_room_id = ""
	last_dock_spawn_pos = Vector2.ZERO
	visited_docks.clear()
	persistent_parked_hosts.clear()
