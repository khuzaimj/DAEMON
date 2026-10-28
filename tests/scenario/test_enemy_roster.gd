extends GutTest

const ROSTER: Array[String] = [
	"rogue_janitor", "rogue_janitor_heavy", "rogue_loader", "rogue_sentry",
	"diver_bot", "welder_bot", "drone_patrol", "crawler_bot", "courier_bot", "medic_bot"
]

func test_all_enemies_data_and_schemas() -> void:
	for enemy_id: String in ROSTER:
		var path: String = "res://data/enemies/%s.json" % enemy_id
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		assert_not_null(file, "Enemy file must exist: " + path)
		if file != null:
			var json: JSON = JSON.new()
			assert_eq(json.parse(file.get_as_text()), OK, "Valid JSON for " + path)
			var data: Dictionary = json.data as Dictionary
			var errors: Array[String] = Schema.validate_enemy(data, path)
			assert_eq(errors.size(), 0, "0 schema errors for %s: %s" % [enemy_id, str(errors)])

func test_spawning_all_enemy_types_in_world() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autofree(world)
	await get_tree().physics_frame

	var entities: Array[Dictionary] = []
	for i: int in range(ROSTER.size()):
		var e_id: String = ROSTER[i]
		entities.append({
			"kind": "enemy",
			"enemy_id": e_id,
			"at": [2 + (i % 5) * 4, 2 + (i / 5) * 4]
		})

	world._spawn_room_entities({ "entities": entities })

	# Verify every enemy instantiated and registered
	for e_id: String in ROSTER:
		var found: Machine = null
		for m: Machine in world.machines:
			if m.enemy_id == e_id:
				found = m
				break
		assert_not_null(found, "Enemy %s should be spawned and registered in world" % e_id)
		if found != null:
			assert_eq(found.operational_state, "hostile", "%s should be hostile" % e_id)
			assert_eq(found.get_faction(), "hostile", "%s should have hostile faction" % e_id)
			assert_true(found.controller is AIController, "%s must have AIController" % e_id)
			assert_gt(found.state.max_integrity, 0, "%s must have integrity > 0" % e_id)

func test_enemy_weaken_and_open_state() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autofree(world)
	await get_tree().physics_frame

	world._spawn_room_entities({
		"entities": [
			{ "kind": "enemy", "enemy_id": "rogue_loader", "at": [5, 5] }
		]
	})

	var loader_enemy: Machine = null
	for m: Machine in world.machines:
		if m.enemy_id == "rogue_loader":
			loader_enemy = m
			break

	assert_not_null(loader_enemy)
	if loader_enemy == null:
		return

	# Max integrity 12. At 12 HP, not open (threshold 0.35 = 4.2 HP)
	assert_false(loader_enemy.is_open(), "Full HP enemy should not be open")

	# Damage to 4 HP (<= 35%). Loader has kinetic resist 0.8:
	# 10 raw damage * 0.8 = 8 damage dealt -> 12 - 8 = 4 HP
	loader_enemy.take_damage(10, "kinetic", true)
	assert_eq(loader_enemy.state.current_integrity, 4)
	assert_true(loader_enemy.is_open(), "Weakened enemy (<= 35% HP) must become Open for hijack")

func test_medic_bot_healing_damaged_ally() -> void:
	var world_scene: PackedScene = load("res://scenes/world.tscn")
	var world: World = world_scene.instantiate() as World
	add_child_autofree(world)
	await get_tree().physics_frame

	world._spawn_room_entities({
		"entities": [
			{ "kind": "enemy", "enemy_id": "medic_bot", "at": [5, 5] },
			{ "kind": "enemy", "enemy_id": "rogue_janitor", "at": [6, 5] }
		]
	})

	var medic: Machine = null
	var janitor: Machine = null
	for m: Machine in world.machines:
		if m.enemy_id == "medic_bot":
			medic = m
		elif m.enemy_id == "rogue_janitor":
			janitor = m

	assert_not_null(medic)
	assert_not_null(janitor)
	if medic == null or janitor == null:
		return

	# Damage janitor ally
	janitor.state.current_integrity = 2
	assert_lt(janitor.state.current_integrity, janitor.state.max_integrity)

	# Step medic controller
	var ai: AIController = medic.controller as AIController
	var intent: Intent = ai.decide(medic, 1)

	# Medic is right next to Janitor (1 tile away = 16px <= 40px)
	assert_true(intent.primary, "Medic bot should activate primary ability to heal damaged ally")
