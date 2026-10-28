class_name LogicSystem
extends RefCounted

## LogicSystem: handles System 6 in World._physics_process (§2.5).
## Pure simulation adapter that steps LogicGraph once per tick and pushes
## energized states to room actuators.

var graph: LogicGraph = LogicGraph.new()
var logic_entities: Dictionary = {} # id -> Node
var unlinked_relays: Dictionary = {} # id -> bool
var pending_switch_triggers: Array[String] = []
var initial_step_done: bool = false
var _last_player_clearance: int = -1

func setup_room(room_data: Dictionary, persistent_latches: Dictionary = {}) -> Array[String]:
	graph.clear()
	unlinked_relays.clear()
	pending_switch_triggers.clear()
	initial_step_done = false

	var entities: Array = room_data.get("entities", [])
	var links: Array = room_data.get("links", [])

	# Detect unlinked relays (e.g. doors, beam gates, etc.)
	var linked_targets: Dictionary = {}
	for l_item: Variant in links:
		if l_item is Dictionary:
			var to_id: String = str((l_item as Dictionary).get("to", ""))
			if not to_id.is_empty():
				linked_targets[to_id] = true

	for ent_item: Variant in entities:
		if ent_item is Dictionary:
			var ent_dict: Dictionary = ent_item as Dictionary
			var kind: String = str(ent_dict.get("kind", ""))
			var id: String = str(ent_dict.get("id", ""))
			if not id.is_empty() and (kind == "door" or kind == "beam_gate" or kind == "lift" or kind == "bridge"):
				if not linked_targets.has(id):
					unlinked_relays[id] = true

	var errors: Array[String] = graph.setup(entities, links)
	if not errors.is_empty():
		printerr("LogicSystem: Graph setup reported errors: ", errors)
		return errors

	if not persistent_latches.is_empty():
		graph.restore_persistent_state(persistent_latches)

	initial_step_done = false
	return errors

func clear() -> void:
	graph.clear()
	logic_entities.clear()
	unlinked_relays.clear()
	pending_switch_triggers.clear()
	initial_step_done = false

func register_entity(id: String, node: Node) -> void:
	if not id.is_empty() and node != null:
		logic_entities[id] = node

func unregister_entity(id: String) -> void:
	logic_entities.erase(id)

func trigger_switch(switch_id: String) -> void:
	if not pending_switch_triggers.has(switch_id):
		pending_switch_triggers.append(switch_id)

func force_state(id: String, on: bool) -> void:
	graph.force_state(id, on)

func is_active(id: String) -> bool:
	return graph.is_active(id)

func get_persistent_state() -> Dictionary:
	return graph.get_persistent_state()

func restore_persistent_state(latches: Dictionary) -> void:
	graph.restore_persistent_state(latches)

func step(world: World, _tick: int) -> void:
	if world == null or not is_instance_valid(world):
		return

	# 1. Update plate loads
	_update_plate_loads(world)

	# 2. Update sensor nodes
	_update_sensor_nodes(world)

	# 3. Apply pending switch triggers
	for switch_id: String in pending_switch_triggers:
		graph.trigger(switch_id)
	pending_switch_triggers.clear()

	# 4. Step the graph exactly once
	graph.step()

	# 5. Push energized states to actuators
	_apply_graph_outputs(world)

	# 6. Step moving platforms (Lifts)
	_step_lifts(1.0 / 60.0)

	initial_step_done = true

func _update_plate_loads(world: World) -> void:
	for id: String in logic_entities.keys():
		var node: Node = logic_entities[id]
		if not is_instance_valid(node) or not (node is Plate):
			continue
		var plate: Plate = node as Plate
		var total_weight: int = 0
		var p_rect: Rect2 = Rect2(plate.global_position - Vector2(8, 8), Vector2(16, 16))

		for m: Machine in world.machines:
			if not is_instance_valid(m) or (m.state != null and m.state.is_crashed):
				continue
			# Cursor weighs 0 (never presses a plate)
			if m.operational_state == "cursor":
				continue
			var m_rect: Rect2 = Rect2(m.global_position - Vector2(8, 8), Vector2(16, 16))
			if p_rect.intersects(m_rect):
				total_weight += m.weight

		for c: Crate in world.crates:
			if not is_instance_valid(c):
				continue
			var c_rect: Rect2 = Rect2(c.global_position - Vector2(8, 8), Vector2(16, 16))
			if p_rect.intersects(c_rect):
				total_weight += c.weight

		graph.set_load(plate.entity_id, total_weight)

func _update_sensor_nodes(world: World) -> void:
	for id: String in logic_entities.keys():
		var node: Node = logic_entities[id]
		if not is_instance_valid(node) or not (node is InfraNode):
			continue
		var inode: InfraNode = node as InfraNode
		var is_inside: bool = false
		if world.hijack_fsm != null and world.hijack_fsm.state == HijackFSM.State.NODE_PILOT:
			if world.hijack_fsm.current_node_id == inode.entity_id:
				is_inside = true
		graph.set_sensor(inode.entity_id, is_inside)

func _apply_graph_outputs(world: World) -> void:
	var player_clearance: int = 0
	if world.hijack_fsm != null:
		player_clearance = world.hijack_fsm.player_clearance
	var game_node: Node = world.get_node_or_null("/root/Game")
	if game_node != null and game_node.get("clearance") != null:
		player_clearance = maxi(player_clearance, int(game_node.get("clearance")))

	var clearance_changed: bool = (player_clearance != _last_player_clearance)
	_last_player_clearance = player_clearance

	var ids_to_update: Array = []
	if not initial_step_done or clearance_changed:
		ids_to_update = logic_entities.keys()
	else:
		var changed_list: Array[String] = graph.get_changed()
		for ch_id: String in changed_list:
			ids_to_update.append(ch_id)

	for id_val: Variant in ids_to_update:
		var id: String = str(id_val)
		var node: Node = logic_entities.get(id) as Node
		if node == null or not is_instance_valid(node):
			continue

		var active: bool = graph.is_active(id)
		var is_unlinked: bool = unlinked_relays.has(id)

		if node is Door:
			var door: Door = node as Door
			var energized: bool = true if is_unlinked else active
			door.set_energized(energized, player_clearance)
		elif node is Plate:
			var plate: Plate = node as Plate
			plate.set_pressed(active)
		elif node is Switch:
			var sw: Switch = node as Switch
			sw.set_active(active)
		elif node is Firewall:
			# Firewall disabled while energized
			var fw: Firewall = node as Firewall
			fw.set_active(not active)
		elif node is Lift:
			var lift: Lift = node as Lift
			lift.set_active(active)
		elif node is Bridge:
			var bridge: Bridge = node as Bridge
			bridge.set_active(active)
		elif node is Crusher:
			var crusher: Crusher = node as Crusher
			crusher.set_active(active)
		elif node is BeamGate:
			var bg: BeamGate = node as BeamGate
			bg.set_active(active)
		elif node is BrokenStructure:
			var bs: BrokenStructure = node as BrokenStructure
			bs.set_repaired(active)

func _step_lifts(delta: float) -> void:
	for id: String in logic_entities.keys():
		var node: Node = logic_entities[id]
		if is_instance_valid(node) and node is Lift:
			(node as Lift).step(delta)
