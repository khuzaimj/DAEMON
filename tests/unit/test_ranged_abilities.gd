extends GutTest

var world: World = null

func before_each() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	world = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_01")

func test_projectile_hit_and_damage() -> void:
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var sentry: Machine = machine_scene.instantiate() as Machine
	sentry.body_id = "sentry"
	sentry.position = Vector2(100, 100)
	world.entities_container.add_child(sentry)
	world.machines.append(sentry)

	var target: Machine = machine_scene.instantiate() as Machine
	target.body_id = "cursor"
	target.position = Vector2(140, 100)
	world.entities_container.add_child(target)
	world.machines.append(target)

	var start_hp: int = target.state.current_integrity
	RangedAbilities.start_projectile(sentry, {
		"params": { "speed": 14.0, "range": 8.0, "damage": 2 }
	}, Vector2.RIGHT)

	# Step world physics frames for projectile travel
	for i: int in range(15):
		for child: Node in world.entities_container.get_children():
			if child is Projectile:
				(child as Projectile).step(1.0 / 60.0)

	assert_lt(target.state.current_integrity, start_hp, "Projectile should deal damage to target machine")

func test_overload_shot_applies_overload_and_opens_target() -> void:
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var drone: Machine = machine_scene.instantiate() as Machine
	drone.body_id = "drone"
	drone.position = Vector2(100, 100)
	world.entities_container.add_child(drone)
	world.machines.append(drone)

	var target: Machine = machine_scene.instantiate() as Machine
	target.body_id = "janitor"
	target.position = Vector2(130, 100)
	world.entities_container.add_child(target)
	world.machines.append(target)

	assert_false(target.state.is_open())

	RangedAbilities.start_overload_shot(drone, {
		"params": { "speed": 12.0, "range": 4.5, "damage": 1, "status_duration": 2.0 }
	}, Vector2.RIGHT)

	for i: int in range(15):
		for child: Node in world.entities_container.get_children():
			if child is Projectile:
				(child as Projectile).step(1.0 / 60.0)

	assert_true(target.state.has_status("overload"), "Target should have overload status")
	assert_true(target.state.is_open(), "Target with overload must be open for hijack")

func test_sentry_stationary_rotation() -> void:
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	var sentry: Machine = machine_scene.instantiate() as Machine
	sentry.body_id = "sentry"
	sentry.base_speed_tiles = 0.0 # Stationary
	sentry.position = Vector2(100, 100)
	world.entities_container.add_child(sentry)
	world.machines.append(sentry)

	var start_pos: Vector2 = sentry.position
	sentry.controller = null
	sentry.current_intent.move = Vector2.UP
	sentry.step_controller(1)
	sentry.step_movement(1.0 / 60.0)

	assert_eq(sentry.position, start_pos, "Sentry with speed 0 must remain stationary")
	assert_eq(sentry.facing, Vector2.UP, "Sentry must update facing from move input")
