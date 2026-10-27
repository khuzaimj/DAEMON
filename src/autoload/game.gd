extends Node

var tick: int = 0
var is_transitioning: bool = false
var paused: bool = false
var current_room_id: String = ""

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
