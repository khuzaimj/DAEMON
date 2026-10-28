class_name TestCombatPerf
extends GutTest

## TestCombatPerf: Benchmarks simulation tick budget under heavy combat load (§2.15).
## Verifies <= 4.0 ms budget per tick with 20+ active machines, AI FSMs, and pathfinding.

func test_combat_simulation_performance_budget() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autoqfree(world)
	world.load_room("debug_09")

	# Spawn additional combat entities to reach 20+ active machines
	var machine_scene: PackedScene = load("res://scenes/machine.tscn")
	for i: int in range(15):
		var m: Machine = machine_scene.instantiate() as Machine
		m.entity_id = "bench_enemy_%d" % i
		m.body_id = "janitor" if i % 2 == 0 else "loader"
		m.operational_state = "hostile"
		m.faction = "hostile"
		m.position = Vector2(float(60 + (i % 6) * 40), float(60 + int(i / 6) * 40))
		m.current_room = world.active_room
		world.entities_container.add_child(m)
		world.register_machine(m)

		var old_ctrl: Node = m.get_node_or_null("Controller")
		if old_ctrl != null:
			m.remove_child(old_ctrl)
			old_ctrl.free()

		var ai_ctrl: AIController = AIController.new()
		ai_ctrl.name = "Controller"
		ai_ctrl.setup({
			"id": "bench_ai",
			"initial": "patrol",
			"params": { "move_speed": 3.0 },
			"states": {
				"patrol": { "do": "patrol_waypoints", "transitions": [] }
			}
		})
		ai_ctrl.patrol_waypoints = [m.position, m.position + Vector2(32, 0), m.position + Vector2(0, 32)]
		m.add_child(ai_ctrl)
		m.controller = ai_ctrl

	assert_gt(world.machines.size(), 20, "Simulation should have 20+ active combat machines")

	# Warmup 30 ticks
	for i: int in range(30):
		world._physics_process(1.0 / 60.0)

	# Profile 600 ticks (10.0 seconds)
	var total_usec: int = 0
	var max_usec: int = 0
	var sample_ticks: int = 600

	for i: int in range(sample_ticks):
		var t0: int = Time.get_ticks_usec()
		world._physics_process(1.0 / 60.0)
		var elapsed: int = Time.get_ticks_usec() - t0
		total_usec += elapsed
		if elapsed > max_usec:
			max_usec = elapsed

	var avg_ms: float = (float(total_usec) / float(sample_ticks)) / 1000.0
	var max_ms: float = float(max_usec) / 1000.0

	print("Combat Performance Profile (%d ticks, %d entities): avg=%.3f ms, max=%.3f ms (Budget: <= 4.0 ms)" % [
		sample_ticks, world.machines.size(), avg_ms, max_ms
	])

	assert_lt(avg_ms, 4.0, "Average simulation tick time must remain within <= 4.0 ms budget")
