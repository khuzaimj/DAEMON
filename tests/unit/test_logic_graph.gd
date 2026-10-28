extends GutTest

# Evaluation rules of LogicGraph: plates, gates, switches, latches, timers, persistence.

## Runs a two-input gate through all four input combinations. Returns outputs for
## (0,0), (1,0), (0,1), (1,1).
func _truth_table(kind: String) -> Array[bool]:
	var g: LogicGraph = LogicFixtures.build(self, 
		[LogicFixtures.el("a", "node"), LogicFixtures.el("b", "node"), LogicFixtures.el("g", kind), LogicFixtures.el("d", "door")],
		[LogicFixtures.ln("a", "g"), LogicFixtures.ln("b", "g"), LogicFixtures.ln("g", "d")])
	var result: Array[bool] = []
	for combo: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		g.set_sensor("a", combo.x == 1)
		g.set_sensor("b", combo.y == 1)
		g.step()
		result.append(g.is_active("g"))
		assert_eq(g.is_active("d"), g.is_active("g"), "door follows its gate in the same step")
	return result

func test_logic_kinds() -> void:
	for kind: String in ["plate", "switch", "latch", "timer", "and", "or", "not", "door", "lift", "bridge", "crusher", "beam_gate", "emitter", "node", "firewall", "broken_structure"]:
		assert_true(LogicGraph.is_logic_kind(kind), kind + " is a logic kind")
	for kind: String in ["machine", "spawn_cursor", "pickup", "crate", ""]:
		assert_false(LogicGraph.is_logic_kind(kind), kind + " is not a logic kind")

func test_plate_weight_threshold() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("p", "plate", { "weight": 3 }), LogicFixtures.el("d", "door")], [LogicFixtures.ln("p", "d")])
	for pair: Vector2i in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(3, 1), Vector2i(5, 1), Vector2i(1, 0)]:
		g.set_load("p", pair.x)
		g.step()
		assert_eq(g.is_active("p"), pair.y == 1, "load %d on weight-3 plate" % pair.x)
		assert_eq(g.is_active("d"), pair.y == 1, "door follows plate at load %d" % pair.x)

func test_plate_default_weight_is_one() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("p", "plate")], [])
	g.set_load("p", 1)
	g.step()
	assert_true(g.is_active("p"))

func test_negative_load_is_clamped() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("p", "plate")], [])
	g.set_load("p", -4)
	g.step()
	assert_false(g.is_active("p"))

func test_and_truth_table() -> void:
	assert_eq(_truth_table("and"), [false, false, false, true] as Array[bool])

func test_or_truth_table() -> void:
	assert_eq(_truth_table("or"), [false, true, true, true] as Array[bool])

func test_not_inverts_and_is_nor_with_many_inputs() -> void:
	var g: LogicGraph = LogicFixtures.build(self, 
		[LogicFixtures.el("a", "node"), LogicFixtures.el("b", "node"), LogicFixtures.el("n", "not")], [LogicFixtures.ln("a", "n"), LogicFixtures.ln("b", "n")])
	var seen: Array[bool] = []
	for combo: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		g.set_sensor("a", combo.x == 1)
		g.set_sensor("b", combo.y == 1)
		g.step()
		seen.append(g.is_active("n"))
	assert_eq(seen, [true, false, false, false] as Array[bool], "NOT of several inputs is NOR")

func test_gates_without_inputs_are_false() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("a", "and"), LogicFixtures.el("o", "or"), LogicFixtures.el("n", "not")], [])
	g.step()
	for id: String in ["a", "o", "n"]:
		assert_false(g.is_active(id), id + " with no inputs is false")

func test_signal_crosses_a_deep_chain_in_one_step() -> void:
	var g: LogicGraph = LogicFixtures.build(self, 
		[LogicFixtures.el("p", "plate"), LogicFixtures.el("n1", "not"), LogicFixtures.el("n2", "not"), LogicFixtures.el("o", "or"), LogicFixtures.el("a", "and"), LogicFixtures.el("d", "door")],
		[LogicFixtures.ln("p", "n1"), LogicFixtures.ln("n1", "n2"), LogicFixtures.ln("n2", "o"), LogicFixtures.ln("o", "a"), LogicFixtures.ln("a", "d")])
	g.set_load("p", 1)
	g.step()
	assert_true(g.is_active("d"), "five links deep, one step")
	g.set_load("p", 0)
	g.step()
	assert_false(g.is_active("d"), "release also crosses in one step")

func test_relay_is_or_of_its_inputs_and_relays_chain() -> void:
	var g: LogicGraph = LogicFixtures.build(self, 
		[LogicFixtures.el("a", "node"), LogicFixtures.el("b", "node"), LogicFixtures.el("d", "door"), LogicFixtures.el("l", "lift")],
		[LogicFixtures.ln("a", "d"), LogicFixtures.ln("b", "d"), LogicFixtures.ln("d", "l")])
	g.set_sensor("b", true)
	g.step()
	assert_true(g.is_active("d"))
	assert_true(g.is_active("l"))

func test_switch_toggles_once_per_tick() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("s", "switch"), LogicFixtures.el("d", "door")], [LogicFixtures.ln("s", "d")])
	g.step()
	assert_false(g.is_active("d"))
	g.trigger("s")
	g.trigger("s") # a melee hit and a bolt in the same tick
	g.step()
	assert_true(g.is_active("d"), "two triggers in one tick toggle once")
	g.step()
	assert_true(g.is_active("d"), "stays toggled without a trigger")
	g.trigger("s")
	g.step()
	assert_false(g.is_active("d"), "next trigger toggles back")

func test_switch_initial_state() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("s", "switch", { "on": true })], [])
	g.step()
	assert_true(g.is_active("s"))
	g.trigger("s")
	g.step()
	assert_false(g.is_active("s"))

func test_latch_set_hold_reset() -> void:
	var g: LogicGraph = LogicFixtures.build(self, 
		[LogicFixtures.el("ps", "plate"), LogicFixtures.el("pr", "plate"), LogicFixtures.el("l", "latch"), LogicFixtures.el("d", "door")],
		[LogicFixtures.ln("ps", "l", "set"), LogicFixtures.ln("pr", "l", "reset"), LogicFixtures.ln("l", "d")])
	g.set_load("ps", 1)
	g.step()
	assert_true(g.is_active("d"), "set")
	g.set_load("ps", 0)
	g.step()
	assert_true(g.is_active("d"), "latch holds after the set input drops")
	g.set_load("pr", 1)
	g.step()
	assert_false(g.is_active("d"), "reset")
	g.set_load("pr", 0)
	g.step()
	assert_false(g.is_active("d"), "stays reset")

func test_latch_reset_wins_over_set() -> void:
	var g: LogicGraph = LogicFixtures.build(self, 
		[LogicFixtures.el("a", "node"), LogicFixtures.el("b", "node"), LogicFixtures.el("l", "latch")],
		[LogicFixtures.ln("a", "l", "set"), LogicFixtures.ln("b", "l", "reset")])
	g.set_sensor("a", true)
	g.set_sensor("b", true)
	g.step()
	assert_false(g.is_active("l"))

func test_latch_default_port_is_set() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("a", "node"), LogicFixtures.el("l", "latch")], [LogicFixtures.ln("a", "l")])
	g.set_sensor("a", true)
	g.step()
	g.set_sensor("a", false)
	g.step()
	assert_true(g.is_active("l"))

func test_persistent_latch_delta_round_trip() -> void:
	var elements: Array = [
		LogicFixtures.el("p", "plate"), LogicFixtures.el("keep", "latch", { "persist": true }),
		LogicFixtures.el("lose", "latch"), LogicFixtures.el("d", "door")]
	var links: Array = [LogicFixtures.ln("p", "keep"), LogicFixtures.ln("p", "lose"), LogicFixtures.ln("keep", "d")]
	var g: LogicGraph = LogicFixtures.build(self, elements, links)
	assert_eq(g.get_persistent_state(), {}, "nothing to save before anything changed")
	g.set_load("p", 1)
	g.step()
	var saved: Dictionary = g.get_persistent_state()
	assert_eq(saved, { "keep": true }, "only persist latches that differ from start are saved")

	var reloaded: LogicGraph = LogicFixtures.build(self, elements, links)
	reloaded.restore_persistent_state(saved)
	reloaded.step() # first tick of the room, nothing pressed
	assert_true(reloaded.is_active("keep"), "restored latch is high on the very first step")
	assert_true(reloaded.is_active("d"), "and the door it drives follows in that same step")
	assert_false(reloaded.is_active("lose"), "non-persistent latch is not restored")

func test_restore_ignores_unknown_ids_and_resets_missing() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("k", "latch", { "persist": true })], [])
	g.restore_persistent_state({ "k": true, "ghost": true })
	g.step()
	assert_true(g.is_active("k"))
	g.restore_persistent_state({})
	g.step()
	assert_false(g.is_active("k"), "missing from the delta means starting state")

func test_broken_structure_is_always_persistent() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("bs", "broken_structure"), LogicFixtures.el("d", "door")], [LogicFixtures.ln("bs", "d")])
	g.step()
	assert_false(g.is_active("d"), "broken until repaired")
	g.force_state("bs", true) # repair beam finished
	g.step()
	assert_true(g.is_active("d"))
	assert_eq(g.get_persistent_state(), { "bs": true })

func test_timer_runs_exactly_duration_ticks() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("s", "node"), LogicFixtures.el("t", "timer", { "duration": 0.05 })], [LogicFixtures.ln("s", "t")])
	g.set_sensor("s", true) # held high the whole time
	var seen: Array[bool] = []
	for i: int in range(6):
		g.step()
		seen.append(g.is_active("t"))
	assert_eq(seen, [true, true, true, false, false, false] as Array[bool], "0.05 s is 3 ticks, held input does not retrigger")

func test_timer_retrigger_restarts() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("s", "node"), LogicFixtures.el("t", "timer", { "duration": 0.05 })], [LogicFixtures.ln("s", "t")])
	g.set_sensor("s", true)
	g.step() # tick 0: starts, 3 left
	g.set_sensor("s", false)
	g.step() # 2 left
	g.set_sensor("s", true)
	g.step() # rising edge: restarts to 3
	assert_eq(g.timer_remaining("t"), 3)
	var highs: int = 1
	for i: int in range(6):
		g.step()
		if g.is_active("t"):
			highs += 1
	assert_eq(highs, 3, "one full run after the restart")

func test_timer_triggered_by_latched_or_gated_signal() -> void:
	var g: LogicGraph = LogicFixtures.build(self, 
		[LogicFixtures.el("a", "node"), LogicFixtures.el("b", "node"), LogicFixtures.el("g", "and"), LogicFixtures.el("t", "timer", { "duration": 0.1 }), LogicFixtures.el("d", "door")],
		[LogicFixtures.ln("a", "g"), LogicFixtures.ln("b", "g"), LogicFixtures.ln("g", "t"), LogicFixtures.ln("t", "d")])
	g.set_sensor("a", true)
	g.step()
	assert_false(g.is_active("d"), "AND not satisfied yet")
	g.set_sensor("b", true)
	g.step()
	assert_true(g.is_active("d"))
	assert_eq(g.timer_remaining("t"), 6)

func test_get_changed_lists_only_changes() -> void:
	var g: LogicGraph = LogicFixtures.build(self, [LogicFixtures.el("p", "plate"), LogicFixtures.el("d", "door")], [LogicFixtures.ln("p", "d")])
	g.set_load("p", 1)
	g.step()
	assert_eq(g.get_changed().size(), 2)
	assert_true(g.get_changed().has("p") and g.get_changed().has("d"))
	g.step()
	assert_eq(g.get_changed().size(), 0, "nothing changed on a quiet tick")
