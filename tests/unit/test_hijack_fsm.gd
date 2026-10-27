extends GutTest

func test_targeting_slow_mo_and_valid_candidate_filtering() -> void:
	var fsm: HijackFSM = HijackFSM.new()
	assert_eq(fsm.state, HijackFSM.State.CURSOR)
	assert_almost_eq(fsm.get_time_scale(), 1.0, 0.001)

	var origin: Vector2 = Vector2(100, 100)
	var candidates: Array[Dictionary] = [
		{ "id": "dormant_ok", "kind": "machine", "model": "janitor", "state": "dormant", "pos": Vector2(140, 100), "clearance": 0, "has_los": true },
		{ "id": "hostile_closed", "kind": "machine", "model": "janitor", "state": "hostile", "is_open": false, "pos": Vector2(130, 100), "clearance": 0, "has_los": true },
		{ "id": "hostile_open", "kind": "machine", "model": "loader", "state": "hostile", "is_open": true, "pos": Vector2(100, 150), "clearance": 0, "has_los": true },
		{ "id": "no_los", "kind": "machine", "model": "sentry", "state": "dormant", "pos": Vector2(120, 100), "clearance": 0, "has_los": false },
		{ "id": "out_of_range", "kind": "machine", "model": "drone", "state": "dormant", "pos": Vector2(300, 100), "clearance": 0, "has_los": true },
		{ "id": "high_clearance", "kind": "machine", "model": "welder", "state": "dormant", "pos": Vector2(120, 100), "clearance": 2, "has_los": true },
		{ "id": "immune_sentinel", "kind": "machine", "model": "sentinel", "state": "hostile", "is_open": true, "is_immune_unit": true, "pos": Vector2(110, 100), "clearance": 0, "has_los": true }
	]

	var started: bool = fsm.start_targeting(origin, candidates, Vector2.RIGHT)
	assert_true(started)
	assert_eq(fsm.state, HijackFSM.State.TARGETING)
	assert_almost_eq(fsm.get_time_scale(), 0.25, 0.001, "Targeting must slow time scale to 0.25")
	assert_eq(fsm.valid_targets.size(), 2, "Only dormant_ok and hostile_open should be valid")
	assert_eq(fsm.selected_target_id, "dormant_ok", "Aiming RIGHT should select dormant_ok")

	# Aim DOWN to switch selection to hostile_open
	fsm.step_targeting_tick(Vector2.DOWN, false, false, origin)
	assert_eq(fsm.selected_target_id, "hostile_open", "Aiming DOWN should switch selection to hostile_open")

	# Timeout after 60 ticks cancels targeting
	for _i: int in range(60):
		fsm.step_targeting_tick(Vector2.ZERO, false, false, origin)
	assert_eq(fsm.state, HijackFSM.State.CURSOR, "Targeting should auto-cancel after 60 ticks")
	assert_almost_eq(fsm.get_time_scale(), 1.0, 0.001, "Time scale restored to 1.0 after cancel")

func test_confirm_hop_transit_seize_and_registration() -> void:
	var fsm: HijackFSM = HijackFSM.new()
	var origin: Vector2 = Vector2(100, 100)
	var target_pos: Vector2 = Vector2(164, 100) # 64px away (4 tiles)
	var candidates: Array[Dictionary] = [
		{ "id": "jan_1", "kind": "machine", "model": "janitor", "state": "dormant", "pos": target_pos, "clearance": 0, "has_los": true }
	]

	var seized_events: Array[String] = []
	var registered_events: Array[String] = []
	fsm.host_seized.connect(func(hid: String, _m: String) -> void: seized_events.append(hid))
	fsm.model_registered.connect(func(m: String) -> void: registered_events.append(m))

	fsm.start_targeting(origin, candidates, Vector2.RIGHT)
	var confirmed: bool = fsm.confirm_targeting(origin, Vector2.RIGHT)
	assert_true(confirmed)
	assert_eq(fsm.state, HijackFSM.State.TRANSIT)

	# 64px at 320px/s takes 0.2s (12 ticks)
	for _i: int in range(15):
		fsm.step_transit(1.0 / 60.0)

	assert_eq(fsm.state, HijackFSM.State.HOSTED, "Should arrive and become HOSTED")
	assert_eq(fsm.current_host_id, "jan_1")
	assert_eq(seized_events, ["jan_1"])
	assert_eq(registered_events, ["janitor"], "First seizure of janitor registers it in Garage")
	assert_true(fsm.registered_models.has("janitor"))

func test_firewall_blocks_transit_and_drops_cursor() -> void:
	var fsm: HijackFSM = HijackFSM.new()
	var origin: Vector2 = Vector2(100, 100)
	var target_pos: Vector2 = Vector2(164, 100)
	var candidates: Array[Dictionary] = [
		{ "id": "jan_1", "kind": "machine", "model": "janitor", "state": "dormant", "pos": target_pos, "clearance": 0, "has_los": true }
	]

	var blocked_positions: Array[Vector2] = []
	fsm.transit_blocked_by_firewall.connect(func(p: Vector2) -> void: blocked_positions.append(p))

	fsm.start_targeting(origin, candidates, Vector2.RIGHT)
	fsm.confirm_targeting(origin, Vector2.RIGHT)
	assert_eq(fsm.state, HijackFSM.State.TRANSIT)

	var block_pt: Vector2 = Vector2(132, 100)
	fsm.step_transit(1.0 / 60.0, block_pt)

	assert_eq(fsm.state, HijackFSM.State.CURSOR, "Firewall interception drops daemon to CURSOR")
	assert_eq(fsm.spark_pos, block_pt, "Cursor drops at firewall hit position")
	assert_eq(blocked_positions.size(), 1)

func test_voluntary_and_forced_eject_and_parking() -> void:
	var fsm: HijackFSM = HijackFSM.new()
	fsm.state = HijackFSM.State.HOSTED
	fsm.current_host_id = "loader_1"
	fsm.cycle_routine() # hold -> guard

	var parked_records: Array[Dictionary] = []
	fsm.host_parked.connect(func(hid: String, routine: String, pin: Vector2) -> void:
		parked_records.append({ "id": hid, "routine": routine, "pin": pin })
	)

	var ejected_ok: bool = fsm.voluntary_eject(Vector2(200, 100), Vector2.RIGHT)
	assert_true(ejected_ok)
	assert_eq(fsm.state, HijackFSM.State.CURSOR)
	assert_eq(fsm.current_host_id, "")
	assert_eq(parked_records.size(), 1)
	assert_eq(parked_records[0]["id"], "loader_1")
	assert_eq(parked_records[0]["routine"], "guard")

	# Forced eject (overheated / crashed)
	fsm.state = HijackFSM.State.HOSTED
	fsm.current_host_id = "welder_1"
	var forced_reasons: Array[String] = []
	fsm.ejected.connect(func(_id: String, reason: String) -> void: forced_reasons.append(reason))

	assert_true(fsm.force_eject(Vector2(220, 100), "overheated"))
	assert_eq(fsm.state, HijackFSM.State.CURSOR)
	assert_eq(forced_reasons, ["overheated"])

func test_cursor_ttl_pause_rules_and_expiry_reboot() -> void:
	var fsm: HijackFSM = HijackFSM.new()
	fsm.reset_for_room(true) # pause_ttl_until_hijack = true

	# Should not drain while tutorial pause is active before first hijack
	fsm.step_cursor_ttl(false, 60)
	assert_eq(fsm.ttl_ticks, HijackFSM.BASE_TTL_TICKS, "TTL must pause until first hijack when room rule is set")

	fsm.has_hijacked_in_room = true
	# Safe zone (conduit, Dock, Node) pauses TTL
	fsm.step_cursor_ttl(true, 60)
	assert_eq(fsm.ttl_ticks, HijackFSM.BASE_TTL_TICKS, "TTL must not drain inside safe zones")

	# Exposed cursor drains TTL and triggers reboot at 0
	var reboot_reasons: Array[String] = []
	fsm.reboot_triggered.connect(func(r: String) -> void: reboot_reasons.append(r))

	fsm.step_cursor_ttl(false, 480)
	assert_eq(fsm.ttl_ticks, 0)
	assert_eq(reboot_reasons, ["ttl_expired"], "TTL reaching 0 must trigger station reboot")
