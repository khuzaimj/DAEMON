class_name BossController
extends Node

## BossController: Manages multi-phase boss fights and hijackable subsystems.
## Driven by data/bosses/<boss_id>.json.

signal phase_changed(new_phase: int)
signal boss_defeated(boss_id: String, reward: String)

var boss_id: String = "bootloader"
var boss_data: Dictionary = {}
var boss_machine: Machine = null
var subsystems: Array[Subsystem] = []
var current_phase_index: int = 0
var is_defeated: bool = false

var slam_timer: int = 0
var spawn_timer: int = 0

func setup(p_boss_id: String, data: Dictionary, p_boss_machine: Machine) -> void:
	boss_id = p_boss_id
	boss_data = data
	boss_machine = p_boss_machine
	current_phase_index = 0
	is_defeated = false
	slam_timer = 0
	spawn_timer = 0

	if boss_machine != null:
		boss_machine.is_boss_body = true
		boss_machine.operational_state = "hostile"
		boss_machine.faction = "hostile"
		boss_machine.entity_id = boss_id

	_refresh_subsystem_states()

func register_subsystem(sub: Subsystem) -> void:
	if not subsystems.has(sub):
		subsystems.append(sub)
		sub.subsystem_overloaded.connect(_on_subsystem_overloaded)
		_refresh_subsystem_states()

func _refresh_subsystem_states() -> void:
	var active_phase_num: int = current_phase_index + 1
	for sub: Subsystem in subsystems:
		if is_instance_valid(sub):
			if sub.target_phase == active_phase_num and not sub.is_disabled:
				sub.set_phase_active(true)
			else:
				sub.set_phase_active(false)

func _on_subsystem_overloaded(_sub_id: String) -> void:
	advance_phase()

func advance_phase() -> void:
	if is_defeated:
		return
	current_phase_index += 1
	var phases: Array = boss_data.get("phases", [])
	if current_phase_index >= phases.size():
		defeat_boss()
	else:
		_refresh_subsystem_states()
		phase_changed.emit(current_phase_index + 1)

func defeat_boss() -> void:
	is_defeated = true
	var reward: String = str(boss_data.get("reward", "clearance_l1"))
	for sub: Subsystem in subsystems:
		if is_instance_valid(sub):
			sub.set_phase_active(false)
	if boss_machine != null and is_instance_valid(boss_machine):
		boss_machine.operational_state = "dormant"

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var events_node: Node = tree.root.get_node_or_null("Events")
		if events_node != null and events_node.has_signal("log_found"):
			events_node.emit_signal("log_found", "boss_defeated_%s" % boss_id)
		var game_node: Node = tree.root.get_node_or_null("Game")
		if game_node != null:
			if reward.begins_with("clearance_"):
				var lvl: int = int(reward.substr(reward.length() - 1))
				game_node.set("clearance_level", lvl)

	boss_defeated.emit(boss_id, reward)

func step(world: World, _tick: int, _delta: float) -> void:
	if is_defeated or boss_machine == null or not is_instance_valid(boss_machine):
		return

	# Attack pattern based on phase
	slam_timer += 1
	var slam_interval: int = 120 # 2 seconds
	if current_phase_index == 1:
		slam_interval = 90 # 1.5 seconds in phase 2
	elif current_phase_index == 2:
		slam_interval = 60 # 1.0 second in phase 3

	if slam_timer >= slam_interval:
		slam_timer = 0
		_execute_slam(world)

	# In phase 2+, spawn minion occasionally
	if current_phase_index >= 1:
		spawn_timer += 1
		if spawn_timer >= 180: # 3 seconds
			spawn_timer = 0
			_spawn_minion(world)

func _execute_slam(world: World) -> void:
	if world == null:
		return
	if world.has_method("trigger_screen_shake"):
		world.call("trigger_screen_shake", 2.0, 8)
	if world.has_method("trigger_hit_stop"):
		world.call("trigger_hit_stop", 2)

	var origin: Vector2 = boss_machine.global_position + Vector2(0, 16.0)
	var dirs: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2(0.7, 0.7), Vector2(-0.7, 0.7)]
	for d: Vector2 in dirs:
		var proj: Projectile = Projectile.new()
		proj.setup(boss_machine, d, 90.0, 180.0, 1, "kinetic")
		proj.proj_color = Color(1.0, 0.6, 0.2)
		if world.entities_container != null:
			world.entities_container.add_child(proj)
		else:
			world.add_child(proj)
		world.register_projectile(proj)

func _spawn_minion(world: World) -> void:
	if world == null or world.entities_container == null:
		return
	var mite: ImmuneUnit = ImmuneUnit.new("glitch_mite")
	var stream: RandomNumberGenerator = world.rng_streams.get_stream("boss") if world != null and world.rng_streams != null else null
	var offset_x: float = stream.randf_range(-40.0, 40.0) if stream != null else 0.0
	mite.position = boss_machine.global_position + Vector2(offset_x, 32.0)
	mite.current_room = world.active_room
	world.entities_container.add_child(mite)
	world.register_machine(mite)
