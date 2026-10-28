extends GutTest

## Unit tests for puzzle entities and LogicSystem integration (P5.1).

var world: World = null

func before_each() -> void:
	var game_node: Node = get_node_or_null("/root/Game")
	if game_node != null and game_node.has_method("reset"):
		game_node.call("reset")
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	world = world_scene.instantiate() as World
	add_child_autofree(world)

func test_plate_weight_threshold_and_cursor_zero_weight() -> void:
	var room_data: Dictionary = {
		"entities": [
			{ "id": "plate_1", "kind": "plate", "weight": 2 }
		],
		"links": []
	}
	world.logic_system.setup_room(room_data)

	var plate: Plate = Plate.new()
	plate.entity_id = "plate_1"
	plate.position = Vector2(100, 100)
	plate.weight_threshold = 2
	world.entities_container.add_child(plate)
	world.logic_system.register_entity("plate_1", plate)

	# 1. No machines on plate -> weight 0 -> not pressed
	world.logic_system.step(world, 1)
	assert_false(plate.is_pressed, "Plate should be unpressed with 0 weight")
	assert_false(world.logic_system.is_active("plate_1"), "LogicGraph should report inactive")

	# 2. Cursor on plate (weight 0) -> still not pressed
	var cursor_m: Machine = Machine.new()
	cursor_m.position = Vector2(100, 100)
	cursor_m.operational_state = "cursor"
	cursor_m.weight = 0
	world.machines.append(cursor_m)
	world.entities_container.add_child(cursor_m)

	world.logic_system.step(world, 2)
	assert_false(plate.is_pressed, "Cursor has 0 weight and should not press plate")

	# 3. Janitor machine (weight 1) -> threshold is 2 -> still not pressed
	var janitor_m: Machine = Machine.new()
	janitor_m.position = Vector2(100, 100)
	janitor_m.operational_state = "player"
	janitor_m.weight = 1
	world.machines.append(janitor_m)
	world.entities_container.add_child(janitor_m)

	world.logic_system.step(world, 3)
	assert_false(plate.is_pressed, "Janitor (weight 1) < threshold 2, should not press")

	# 4. Add Crate (weight 1) -> total weight 2 >= 2 -> pressed!
	var crate: Crate = Crate.new()
	crate.position = Vector2(100, 100)
	crate.weight = 1
	world.crates.append(crate)
	world.entities_container.add_child(crate)

	world.logic_system.step(world, 4)
	assert_true(plate.is_pressed, "Total weight 2 should trigger plate")
	assert_true(world.logic_system.is_active("plate_1"), "LogicGraph should report active")

	# 5. Move crate away -> weight drops to 1 -> unpresses
	crate.position = Vector2(200, 200)
	world.logic_system.step(world, 5)
	assert_false(plate.is_pressed, "Moving crate away should release plate")

func test_switch_toggle_and_trigger() -> void:
	var room_data: Dictionary = {
		"entities": [
			{ "id": "switch_1", "kind": "switch", "on": false }
		],
		"links": []
	}
	world.logic_system.setup_room(room_data)

	var sw: Switch = Switch.new()
	sw.entity_id = "switch_1"
	sw.position = Vector2(50, 50)
	world.entities_container.add_child(sw)
	world.logic_system.register_entity("switch_1", sw)

	world.logic_system.step(world, 1)
	assert_false(sw.is_on, "Initial switch state should be false")

	# Trigger switch
	sw.trigger()
	world.logic_system.step(world, 2)
	assert_true(sw.is_on, "Switch should toggle to ON after trigger")
	assert_true(world.logic_system.is_active("switch_1"), "LogicGraph should report active")

	# Trigger switch again
	sw.trigger()
	world.logic_system.step(world, 3)
	assert_false(sw.is_on, "Switch should toggle back to OFF on second trigger")

func test_door_clearance_and_logic_link() -> void:
	var room_data: Dictionary = {
		"entities": [
			{ "id": "door_0", "kind": "door", "clearance": 0 }, # unlinked
			{ "id": "plate_1", "kind": "plate", "weight": 1 },
			{ "id": "door_2", "kind": "door", "clearance": 2 }  # linked to plate_1
		],
		"links": [
			{ "from": "plate_1", "to": "door_2" }
		]
	}
	world.logic_system.setup_room(room_data)

	var door_l0: Door = Door.new()
	door_l0.entity_id = "door_0"
	door_l0.clearance_level = 0
	world.entities_container.add_child(door_l0)
	world.logic_system.register_entity("door_0", door_l0)

	var door_l2: Door = Door.new()
	door_l2.entity_id = "door_2"
	door_l2.clearance_level = 2
	world.entities_container.add_child(door_l2)
	world.logic_system.register_entity("door_2", door_l2)

	var plate: Plate = Plate.new()
	plate.entity_id = "plate_1"
	plate.position = Vector2(30, 30)
	plate.weight_threshold = 1
	world.entities_container.add_child(plate)
	world.logic_system.register_entity("plate_1", plate)

	# HijackFSM player clearance = 0
	world.hijack_fsm.player_clearance = 0
	world.logic_system.step(world, 1)

	# Unlinked door L0 should be open by default
	assert_true(door_l0.is_open, "Unlinked door with clearance 0 should be open")
	# Linked door L2 should be closed (plate unpressed + clearance 0 < 2)
	assert_false(door_l2.is_open, "Linked door L2 should be closed")

	# Press plate with loader machine (weight 3)
	var loader: Machine = Machine.new()
	loader.position = Vector2(30, 30)
	loader.weight = 3
	world.machines.append(loader)
	world.entities_container.add_child(loader)

	world.logic_system.step(world, 2)
	# Plate is active, but player clearance is still 0 < 2 -> door_2 remains closed
	assert_true(world.logic_system.is_active("door_2"), "Door 2 should be energized by plate")
	assert_false(door_l2.is_open, "Door 2 requires clearance L2, player has L0")

	# Grant player clearance L2
	world.hijack_fsm.player_clearance = 2
	world.logic_system.step(world, 3)
	assert_true(door_l2.is_open, "Door 2 should open with clearance L2 and active plate")

func test_firewall_disabled_while_energized() -> void:
	var room_data: Dictionary = {
		"entities": [
			{ "id": "switch_1", "kind": "switch", "on": false },
			{ "id": "firewall_1", "kind": "firewall" }
		],
		"links": [
			{ "from": "switch_1", "to": "firewall_1" }
		]
	}
	world.logic_system.setup_room(room_data)

	var fw: Firewall = Firewall.new()
	fw.entity_id = "firewall_1"
	world.entities_container.add_child(fw)
	world.logic_system.register_entity("firewall_1", fw)

	var sw: Switch = Switch.new()
	sw.entity_id = "switch_1"
	world.entities_container.add_child(sw)
	world.logic_system.register_entity("switch_1", sw)

	world.logic_system.step(world, 1)
	assert_true(fw.is_active, "Firewall should be active when not energized")
	assert_false(fw.collider.disabled, "Firewall collision should be active")

	# Toggle switch -> energizes firewall
	sw.trigger()
	world.logic_system.step(world, 2)
	assert_true(world.logic_system.is_active("firewall_1"), "Firewall should be energized")
	assert_false(fw.is_active, "Firewall is disabled while energized")
	assert_true(fw.collider.disabled, "Firewall collision disabled while energized")

func test_lift_movement_and_carrying() -> void:
	var room_data: Dictionary = {
		"entities": [
			{ "id": "sw_1", "kind": "switch", "on": true },
			{ "id": "lift_1", "kind": "lift" }
		],
		"links": [
			{ "from": "sw_1", "to": "lift_1" }
		]
	}
	world.logic_system.setup_room(room_data)

	var lift: Lift = Lift.new()
	lift.entity_id = "lift_1"
	lift.position = Vector2(50, 50)
	lift.travel_distance = 32.0
	lift.travel_direction = Vector2.DOWN
	lift.travel_speed = 320.0 # Fast for test
	world.entities_container.add_child(lift)
	world.logic_system.register_entity("lift_1", lift)

	var sw: Switch = Switch.new()
	sw.entity_id = "sw_1"
	sw.is_on = true
	world.entities_container.add_child(sw)
	world.logic_system.register_entity("sw_1", sw)

	var m: Machine = Machine.new()
	m.position = Vector2(50, 50)
	world.machines.append(m)
	world.entities_container.add_child(m)

	# Step 10 ticks (at 320 px/s * 1/60s = 5.33 px per tick)
	for _i in range(10):
		world.logic_system.step(world, _i + 1)

	assert_gt(lift.position.y, 50.0, "Lift should have moved downward")
	assert_eq(m.position.y, lift.position.y, "Machine standing on lift should have moved with it")

func test_bridge_pit_crossing() -> void:
	var room_data: Dictionary = {
		"entities": [
			{ "id": "bridge_1", "kind": "bridge" }
		],
		"links": []
	}
	world.logic_system.setup_room(room_data)

	var bridge: Bridge = Bridge.new()
	bridge.entity_id = "bridge_1"
	bridge.position = Vector2(80, 80)
	bridge.bridge_size = Vector2(16, 16)
	world.entities_container.add_child(bridge)
	world.logic_system.register_entity("bridge_1", bridge)

	var m: Machine = Machine.new()
	m.position = Vector2(80, 80)
	m.collision_mask = 1 << (10 - 1) # Layer 10: pit
	world.machines.append(m)
	world.entities_container.add_child(m)

	# When bridge is inactive:
	bridge.set_active(false)
	assert_true(m.collision_mask & (1 << (10 - 1)) != 0, "Machine should be blocked by pit when bridge inactive")

	# When bridge is active:
	bridge.set_active(true)
	assert_true(m.collision_mask & (1 << (10 - 1)) == 0, "Machine pit mask should be cleared while on active bridge")
	assert_true(bridge.is_point_on_active_bridge(Vector2(80, 80)), "Point should be on active bridge")

func test_broken_structure_repair_and_persistence() -> void:
	var room_data: Dictionary = {
		"entities": [
			{ "id": "broken_1", "kind": "broken_structure" },
			{ "id": "door_1", "kind": "door" }
		],
		"links": [
			{ "from": "broken_1", "to": "door_1" }
		]
	}
	world.logic_system.setup_room(room_data)

	var bs: BrokenStructure = BrokenStructure.new()
	bs.entity_id = "broken_1"
	world.entities_container.add_child(bs)
	world.logic_system.register_entity("broken_1", bs)

	var door: Door = Door.new()
	door.entity_id = "door_1"
	world.entities_container.add_child(door)
	world.logic_system.register_entity("door_1", door)

	world.logic_system.step(world, 1)
	assert_false(bs.is_repaired, "Broken structure starts unrepaired")
	assert_false(door.is_open, "Door starts closed")

	# Apply repair beam hits
	bs.apply_repair(1.0)
	world.logic_system.step(world, 2)
	assert_true(bs.is_repaired, "Broken structure should be repaired")
	assert_true(door.is_open, "Door should open when linked broken structure is repaired")

	# Check persistent state export (broken_structure is in ALWAYS_PERSIST_KINDS)
	var saved_delta: Dictionary = world.logic_system.get_persistent_state()
	assert_true(saved_delta.has("broken_1"), "Broken structure state should be present in persistent delta")
	assert_true(saved_delta["broken_1"], "Broken structure state should be true in delta")

func test_switch_interact_and_attack_triggers() -> void:
	var room_data: Dictionary = {
		"entities": [
			{ "id": "sw_test", "kind": "switch", "on": false }
		],
		"links": []
	}
	world.logic_system.setup_room(room_data)

	var sw: Switch = Switch.new()
	sw.entity_id = "sw_test"
	sw.position = Vector2(100, 100)
	world.entities_container.add_child(sw)
	world.logic_system.register_entity("sw_test", sw)
	world.logic_system.step(world, 1)
	assert_false(sw.is_on, "Switch starts off")

	# 1. Interact trigger when player is within 20 px
	var p_m: Machine = Machine.new()
	p_m.operational_state = "player"
	p_m.position = Vector2(110, 100) # 10 px away <= 20 px
	p_m.current_intent.interact = true
	world.player_machine = p_m
	world.machines.append(p_m)
	world.entities_container.add_child(p_m)

	world._step_hijack(0.016)
	world.logic_system.step(world, 2)
	assert_true(sw.is_on, "Switch toggled on by player interact within 20 px")

	# 2. Attack trigger via Projectile
	var proj: Projectile = Projectile.new()
	proj.position = Vector2(98, 100)
	proj.velocity = Vector2(100, 0)
	proj.radius = 4.0
	world.entities_container.add_child(proj)
	world.projectiles.append(proj)
	proj._check_direct_hits()
	world.logic_system.step(world, 3)
	assert_false(sw.is_on, "Switch toggled off by projectile hit")

	# 3. Attack trigger via Melee Arc
	var arc_data: Dictionary = {
		"params": {
			"arc": 90.0,
			"radius": 32.0,
			"damage": 2
		}
	}
	p_m.position = Vector2(85, 100)
	p_m.facing = Vector2.RIGHT
	MeleeAbilities.start_melee_arc(p_m, arc_data, Vector2.RIGHT)
	world.logic_system.step(world, 4)
	assert_true(sw.is_on, "Switch toggled on by melee arc attack")

func test_lift_start_end_pos_and_duration() -> void:
	var lift: Lift = Lift.new()
	lift.entity_id = "lift_endpoints"
	lift.configure_endpoints(Vector2(50, 50), Vector2(50, 110), 2.0)
	assert_eq(lift.start_pos, Vector2(50, 50), "Start position configured")
	assert_eq(lift.target_pos, Vector2(50, 110), "Target position configured")
	assert_eq(lift.travel_distance, 60.0, "Travel distance computed accurately")
	assert_eq(lift.travel_speed, 30.0, "Travel speed computed accurately from duration (60 / 2 = 30)")

	world.entities_container.add_child(lift)
	world.logic_system.register_entity("lift_endpoints", lift)

	lift.set_active(true)
	lift.step(1.0) # Step 1 second -> moves 30 px down
	assert_eq(lift.position, Vector2(50, 80), "Lift moved halfway (30 px) after 1.0s at 30 px/s")
