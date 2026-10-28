extends Node

# Simulation and gameplay events
signal hit(target: Node, source: Node, amount: int, damage_type: String)
signal enemy_killed(enemy_id: String, pos: Vector2)
signal hopped(from_target: Node, to_target: Node)
signal door_changed(door_id: String, is_open: bool)
signal pickup_taken(pickup_id: String, kind: String, amount: int)
signal log_found(log_id: String)
signal room_transition_started(from_room: String, to_room: String, direction: Vector2i)
signal room_transition_finished(room_id: String)
signal tick_advanced(current_tick: int)
signal reboot_triggered(reason: String)
signal dock_visited(dock_id: String, room_id: String)
signal host_parked(host_id: String, room_id: String, routine: String)
signal host_recycled(host_id: String, scrap_refund: int)
