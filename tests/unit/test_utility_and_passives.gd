extends GutTest

var world: World = null

func before_each() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	world = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_01")

func test_utility_patch_and_bubble() -> void:
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var medic: Machine = machine_scene.instantiate() as Machine
	medic.body_id = "medic"
	medic.state.current_integrity = 3
	medic.state.max_integrity = 6
	world.entities_container.add_child(medic)
	world.machines.append(medic)

	UtilityAbilities.start_patch(medic, { "params": { "heal": 2 } }, Vector2.ZERO)
	assert_eq(medic.state.current_integrity, 5, "Patch should heal 2 HP")

	UtilityAbilities.start_bubble_shield(medic, { "params": { "duration": 1.0 } }, Vector2.ZERO)
	assert_gt(medic.state.invulnerability_ticks, 0, "Bubble shield should grant invulnerability")

func test_lift_and_throw_crate() -> void:
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var loader: Machine = machine_scene.instantiate() as Machine
	loader.body_id = "loader"
	loader.weight = 3
	loader.position = Vector2(100, 100)
	loader.facing = Vector2.RIGHT
	world.entities_container.add_child(loader)
	world.machines.append(loader)

	var crate: Crate = Crate.new()
	crate.weight = 1
	crate.position = Vector2(116, 100)
	world.entities_container.add_child(crate)

	# Lift crate
	UtilityAbilities.start_lift_carry(loader, {}, Vector2.RIGHT)
	assert_eq(loader.carried_object, crate, "Loader should pick up adjacent crate")
	assert_true(crate.is_carried)

	# Throw crate
	UtilityAbilities.start_lift_carry(loader, {}, Vector2.RIGHT)
	assert_null(loader.carried_object, "Loader throws carried crate")
	assert_false(crate.is_carried)
	assert_gt(crate.velocity.x, 0.0, "Thrown crate moves forward")

func test_passive_rules() -> void:
	var room: RoomRuntime = world.active_room
	assert_not_null(room)

	# Place coolant tile '~' at (5, 5)
	room.set_tile_at(Vector2i(5, 5), "~", false)

	var machine_scene: PackedScene = load("res://scenes/machine.tscn")

	# Diver in coolant (immune to coolant heat penalty)
	var diver: Machine = machine_scene.instantiate() as Machine
	diver.body_id = "diver"
	diver.mediums = ["ground", "liquid"]
	diver.current_room = room
	diver.position = Grid.tile_to_pixel_center(Vector2i(5, 5))
	world.entities_container.add_child(diver)
	world.machines.append(diver)

	diver.step_movement(1.0)
	assert_eq(diver.state.current_heat, 0.0, "Diver does not accumulate heat in coolant")

	# Janitor in coolant (takes 15 Heat/s)
	var janitor: Machine = machine_scene.instantiate() as Machine
	janitor.body_id = "janitor"
	janitor.mediums = ["ground"]
	janitor.current_room = room
	janitor.position = Grid.tile_to_pixel_center(Vector2i(5, 5))
	world.entities_container.add_child(janitor)
	world.machines.append(janitor)

	janitor.step_movement(1.0)
	assert_almost_eq(janitor.state.current_heat, 15.0, 0.5, "Non-diver in coolant takes 15 Heat/s")

	# Welder fire immunity
	var welder: Machine = machine_scene.instantiate() as Machine
	welder.body_id = "welder"
	welder.passives = ["fire_immune"]
	world.entities_container.add_child(welder)
	world.machines.append(welder)

	var took_dmg: bool = welder.take_damage(3, "thermal")
	assert_false(took_dmg, "Welder with fire_immune ignores thermal damage")
