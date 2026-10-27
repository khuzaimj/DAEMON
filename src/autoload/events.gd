extends Node

# Simulation and gameplay events
signal hit(target: Node, source: Node, amount: int, damage_type: String)
signal hopped(from_target: Node, to_target: Node)
signal door_changed(door_id: String, is_open: bool)
signal pickup_taken(pickup_id: String, kind: String, amount: int)
signal log_found(log_id: String)
signal room_transition_started(from_room: String, to_room: String, direction: Vector2i)
signal room_transition_finished(room_id: String)
signal tick_advanced(current_tick: int)
