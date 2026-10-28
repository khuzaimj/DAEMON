extends GutTest

var world: World = null

func before_each() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	world = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_01")

func test_flame_cone_cuts_weld_tile() -> void:
	var room: RoomRuntime = world.active_room
	assert_not_null(room)

	# Place a weld barrier at cell (5, 5)
	var weld_cell: Vector2i = Vector2i(5, 5)
	room.set_tile_at(weld_cell, "%", true)
	assert_eq(room.grid[5][5], "%")

	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var welder: Machine = machine_scene.instantiate() as Machine
	welder.body_id = "welder"
	welder.position = Grid.tile_to_pixel_center(Vector2i(4, 5))
	welder.facing = Vector2.RIGHT
	welder.current_room = room
	world.entities_container.add_child(welder)
	world.machines.append(welder)

	ChannelledAbilities.start_flame_cone(welder, {
		"params": { "angle": 45.0, "range": 32.0, "damage": 1 }
	}, Vector2.RIGHT)

	assert_eq(room.grid[5][5], ".", "Flame cone must cut weld tile '%' to '.'")

func test_beam_channel_cuts_weld_barrier() -> void:
	var room: RoomRuntime = world.active_room
	assert_not_null(room)

	var weld_cell: Vector2i = Vector2i(7, 5)
	room.set_tile_at(weld_cell, "%", true)
	assert_eq(room.grid[5][7], "%")

	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var welder: Machine = machine_scene.instantiate() as Machine
	welder.body_id = "welder"
	welder.position = Grid.tile_to_pixel_center(Vector2i(4, 5))
	welder.facing = Vector2.RIGHT
	welder.current_room = room
	world.entities_container.add_child(welder)
	world.machines.append(welder)

	ChannelledAbilities.start_beam_channel(welder, {
		"params": { "range": 64.0, "damage": 2 }
	}, Vector2.RIGHT)

	assert_eq(room.grid[5][7], ".", "Beam channel must cut weld barrier '%' to '.'")

func test_repair_beam_heals_friendly_machine() -> void:
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var medic: Machine = machine_scene.instantiate() as Machine
	medic.body_id = "medic"
	medic.position = Vector2(100, 100)
	medic.facing = Vector2.RIGHT
	world.entities_container.add_child(medic)
	world.machines.append(medic)

	var patient: Machine = machine_scene.instantiate() as Machine
	patient.body_id = "cursor"
	patient.position = Vector2(125, 100) # In front of medic
	patient.state.current_integrity = 5
	patient.state.max_integrity = 10
	world.entities_container.add_child(patient)
	world.machines.append(patient)

	ChannelledAbilities.start_repair_beam(medic, {
		"params": { "range": 48.0, "heal_amount": 3 }
	}, Vector2.RIGHT)

	assert_eq(patient.state.current_integrity, 8, "Repair beam should heal machine by 3 HP")

	# Hostile medic should heal hostile patient, not player patient
	var hostile_medic: Machine = machine_scene.instantiate() as Machine
	hostile_medic.faction = "hostile"
	hostile_medic.position = Vector2(200, 100)
	hostile_medic.facing = Vector2.RIGHT
	world.entities_container.add_child(hostile_medic)
	world.machines.append(hostile_medic)

	var player_target: Machine = machine_scene.instantiate() as Machine
	player_target.faction = "player"
	player_target.position = Vector2(225, 100)
	player_target.state.current_integrity = 5
	world.entities_container.add_child(player_target)
	world.machines.append(player_target)

	ChannelledAbilities.start_repair_beam(hostile_medic, {
		"params": { "range": 48.0, "heal_amount": 3 }
	}, Vector2.RIGHT)
	assert_eq(player_target.state.current_integrity, 5, "Hostile repair beam should not heal player unit")

	var hostile_target: Machine = machine_scene.instantiate() as Machine
	hostile_target.faction = "hostile"
	hostile_target.position = Vector2(225, 100)
	hostile_target.state.current_integrity = 5
	world.entities_container.add_child(hostile_target)
	world.machines.append(hostile_target)

	ChannelledAbilities.start_repair_beam(hostile_medic, {
		"params": { "range": 48.0, "heal_amount": 3 }
	}, Vector2.RIGHT)
	assert_eq(hostile_target.state.current_integrity, 8, "Hostile repair beam should heal hostile unit")
